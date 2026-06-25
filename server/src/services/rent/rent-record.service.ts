import { getDb, COLLECTIONS } from '@/lib/firebase';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { v4 as uuidv4 } from 'uuid';
import { logger } from '@/lib/logger';

export interface RentRecordWithTenant {
  id: string;
  recordId?: string;
  pgId: string;
  tenantId: string;
  roomId: string;
  month: number;
  year: number;
  amount: number;
  lateFine: number;
  dueDate: Timestamp;
  status: string;
  tenantName: string;
  createdAt?: Timestamp;
  [key: string]: unknown;
}

export interface GenerateRentRecordsResult {
  created: number;
  month: number;
  year: number;
}

export class RentRecordService {
  async listRecords(
    pgId: string,
    filters?: { month?: number; year?: number },
  ): Promise<RentRecordWithTenant[]> {
    const db = getDb();
    let query = db.collection(COLLECTIONS.RENT_RECORDS).where('pgId', '==', pgId);

    if (filters?.month != null) {
      query = query.where('month', '==', filters.month);
    }
    if (filters?.year != null) {
      query = query.where('year', '==', filters.year);
    }

    const snapshot = await query.limit(100).get();
    const sorted = snapshot.docs
      .map((doc) => ({ id: doc.id, ...doc.data() } as Record<string, unknown>))
      .sort((a, b) => {
        const aTime = (a.createdAt as Timestamp | undefined)?.toMillis?.() ?? 0;
        const bTime = (b.createdAt as Timestamp | undefined)?.toMillis?.() ?? 0;
        return bTime - aTime;
      });

    return Promise.all(
      sorted.map(async (data) => {
        const tenantDoc = await db
          .collection(COLLECTIONS.USERS)
          .doc(data.tenantId as string)
          .get();
        return {
          ...data,
          tenantName: tenantDoc.data()?.name || 'Unknown',
        } as RentRecordWithTenant;
      }),
    );
  }

  async generateForCurrentMonth(pgId: string): Promise<GenerateRentRecordsResult> {
    const db = getDb();
    const now = new Date();
    const month = now.getMonth() + 1;
    const year = now.getFullYear();

    const pgDoc = await db.collection(COLLECTIONS.PGS).doc(pgId).get();
    const rentDueDate = (pgDoc.data()?.rentDueDate as number) || 1;
    const dueDate = new Date(year, month - 1, rentDueDate);

    const tenantsSnapshot = await db
      .collection(COLLECTIONS.TENANTS)
      .where('pgId', '==', pgId)
      .where('status', '==', 'active')
      .get();

    let created = 0;
    const batch = db.batch();

    for (const tenantDoc of tenantsSnapshot.docs) {
      const tenantData = tenantDoc.data();
      const existing = await db
        .collection(COLLECTIONS.RENT_RECORDS)
        .where('pgId', '==', pgId)
        .where('tenantId', '==', tenantData.uid)
        .where('month', '==', month)
        .where('year', '==', year)
        .limit(1)
        .get();

      if (!existing.empty) continue;

      const recordId = uuidv4();
      const ref = db.collection(COLLECTIONS.RENT_RECORDS).doc(recordId);
      batch.set(ref, {
        recordId,
        pgId,
        tenantId: tenantData.uid,
        roomId: tenantData.roomId,
        month,
        year,
        amount: tenantData.rentAmount,
        lateFine: 0,
        dueDate: Timestamp.fromDate(dueDate),
        status: 'unpaid',
        paymentMethod: null,
        paymentDeepLink: null,
        paidAt: null,
        receiptUrl: null,
        createdAt: FieldValue.serverTimestamp(),
      });
      created++;
    }

    if (created > 0) {
      await batch.commit();
    }

    logger.info('rent_records.generated', { pgId, month, year, created });

    return { created, month, year };
  }
}

let rentRecordServiceInstance: RentRecordService | null = null;

export function getRentRecordService(): RentRecordService {
  if (!rentRecordServiceInstance) {
    rentRecordServiceInstance = new RentRecordService();
  }
  return rentRecordServiceInstance;
}
