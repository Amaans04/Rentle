import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { v4 as uuidv4 } from 'uuid';
import { getDb, COLLECTIONS } from '@/lib/firebase';
import { ValidationError } from '@/lib/errors';
import { logger } from '@/lib/logger';
import type { ChargeType } from '@/lib/charge-types';
import { getPaymentGateway } from '@/providers/upi-deep-link.gateway';

export interface CreateChargeInput {
  pgId: string;
  tenantId: string;
  chargeType: ChargeType;
  description: string;
  amount: number;
  dueDate?: Date;
  createdBy: string;
}

export class ChargeService {
  async createCharge(input: CreateChargeInput) {
    const db = getDb();

    if (input.amount <= 0) {
      throw new ValidationError('Amount must be greater than zero');
    }

    const tenantDoc = await db.collection(COLLECTIONS.TENANTS).doc(input.tenantId).get();
    if (!tenantDoc.exists || tenantDoc.data()?.pgId !== input.pgId) {
      throw new ValidationError('Tenant not found');
    }
    if (tenantDoc.data()?.status !== 'active') {
      throw new ValidationError('Cannot charge inactive tenant');
    }

    const tenantData = tenantDoc.data()!;
    const now = new Date();
    const month = now.getMonth() + 1;
    const year = now.getFullYear();
    const dueDate = input.dueDate ?? new Date(year, month - 1, now.getDate() + 7);

    const recordId = uuidv4();
    const totalAmount = input.amount;

    const payment = await getPaymentGateway().createPaymentIntent({
      pgId: input.pgId,
      amount: totalAmount,
      description: input.description,
      transactionRef: recordId,
      tenantId: input.tenantId,
    });

    const ref = db.collection(COLLECTIONS.RENT_RECORDS).doc(recordId);
    const record = {
      recordId,
      pgId: input.pgId,
      tenantId: input.tenantId,
      roomId: tenantData.roomId,
      month,
      year,
      amount: totalAmount,
      lateFine: 0,
      chargeType: input.chargeType,
      description: input.description,
      dueDate: Timestamp.fromDate(dueDate),
      status: 'unpaid',
      paymentMethod: null,
      paymentProvider: payment.provider,
      paymentDeepLink: payment.deepLink ?? null,
      paidAt: null,
      receiptUrl: null,
      createdBy: input.createdBy,
      createdAt: FieldValue.serverTimestamp(),
    };

    await ref.set(record);

    logger.info('charge.created', {
      pgId: input.pgId,
      tenantId: input.tenantId,
      recordId,
      chargeType: input.chargeType,
      amount: totalAmount,
    });

    const saved = await ref.get();
    return { id: saved.id, ...saved.data() };
  }
}

let chargeServiceInstance: ChargeService | null = null;

export function getChargeService(): ChargeService {
  if (!chargeServiceInstance) {
    chargeServiceInstance = new ChargeService();
  }
  return chargeServiceInstance;
}
