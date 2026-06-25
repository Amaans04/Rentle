import { describe, it, expect } from 'vitest';
import { buildUpiDeepLink } from '@/services/payment/upi.service';

describe('buildUpiDeepLink', () => {
  it('builds a valid UPI deep link', () => {
    const link = buildUpiDeepLink({
      upiId: 'owner@paytm',
      payeeName: 'Sunshine PG',
      amount: 8450,
      note: 'Rent June 2026',
      transactionRef: 'rec-123',
    });

    expect(link.startsWith('upi://pay?')).toBe(true);
    expect(link).toContain('pa=owner%40paytm');
    expect(link).toContain('am=8450.00');
    expect(link).toContain('tr=rec-123');
  });

  it('encodes special characters in note and name', () => {
    const link = buildUpiDeepLink({
      upiId: 'test@upi',
      payeeName: 'PG & Hostel',
      amount: 100,
      note: 'Fine: late payment',
      transactionRef: 'x',
    });

    expect(link).toContain('pn=PG');
    expect(link).toContain('tn=Fine');
  });
});
