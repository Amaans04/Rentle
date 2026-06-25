import { FieldValue } from 'firebase-admin/firestore';
import { COLLECTIONS, getDb } from '@/lib/firebase';
import type { AuditLogEntry, AuditRepository } from '@/interfaces/audit.repository';
import { logger } from '@/lib/logger';

export class FirestoreAuditRepository implements AuditRepository {
  async write(entry: AuditLogEntry): Promise<void> {
    const db = getDb();
    await db.collection(COLLECTIONS.AUDIT_LOGS).add({
      ...entry,
      createdAt: FieldValue.serverTimestamp(),
    });

    logger.info('audit.logged', {
      action: entry.action,
      resource: entry.resource,
      organizationId: entry.organizationId,
      userId: entry.userId,
    });
  }
}

let auditRepositoryInstance: FirestoreAuditRepository | null = null;

export function getAuditRepository(): FirestoreAuditRepository {
  if (!auditRepositoryInstance) {
    auditRepositoryInstance = new FirestoreAuditRepository();
  }
  return auditRepositoryInstance;
}

export async function writeAuditLog(entry: AuditLogEntry): Promise<void> {
  return getAuditRepository().write(entry);
}
