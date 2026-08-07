/**
 * Payment gateway integration is explicitly deferred (see plan §5). This
 * interface exists so the manual-payment flow (Phase 3) and a future
 * Razorpay/Cashfree binding share one seam — swapping providers later means
 * adding a new class, not rewriting call sites.
 */
export interface PaymentGatewayProvider {
  name: string;
  /** Records a payment that has already happened outside this system (cash, UPI screenshot, bank transfer). */
  recordManualPayment(input: {
    tenancyId: string;
    amount: number;
    method: "CASH" | "UPI" | "BANK_TRANSFER" | "CHEQUE" | "WALLET";
    utr?: string;
  }): Promise<{ externalId: string | null }>;
}

/** Only binding registered today — no live gateway routes exist. */
export class ManualPaymentGateway implements PaymentGatewayProvider {
  name = "manual";

  async recordManualPayment(): Promise<{ externalId: string | null }> {
    return { externalId: null };
  }
}

export function getPaymentGateway(): PaymentGatewayProvider {
  return new ManualPaymentGateway();
}
