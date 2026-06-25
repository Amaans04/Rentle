import { getDb, COLLECTIONS } from '@/lib/firebase';
import { ValidationError } from '@/lib/errors';

export interface UpiLinkParams {
  upiId: string;
  payeeName: string;
  amount: number;
  note: string;
  transactionRef: string;
}

export function buildUpiDeepLink(params: UpiLinkParams): string {
  const { upiId, payeeName, amount, note, transactionRef } = params;
  const query = new URLSearchParams({
    pa: upiId,
    pn: payeeName,
    am: amount.toFixed(2),
    tn: note,
    tr: transactionRef,
  });
  return `upi://pay?${query.toString()}`;
}

export async function getPgUpiConfig(pgId: string): Promise<{ upiId: string; name: string }> {
  const db = getDb();
  const pgDoc = await db.collection(COLLECTIONS.PGS).doc(pgId).get();
  if (!pgDoc.exists) {
    throw new ValidationError('Property not found');
  }
  const data = pgDoc.data()!;
  const upiId = (data.upiId as string | undefined)?.trim();
  if (!upiId) {
    throw new ValidationError('Owner UPI ID is not configured. Add it in Settings.');
  }
  return {
    upiId,
    name: (data.name as string) || (data.propertyName as string) || 'Rentle PG',
  };
}

export async function buildPaymentDeepLinkForPg(
  pgId: string,
  amount: number,
  note: string,
  transactionRef: string,
): Promise<string> {
  const { upiId, name } = await getPgUpiConfig(pgId);
  return buildUpiDeepLink({
    upiId,
    payeeName: name,
    amount,
    note,
    transactionRef,
  });
}
