export interface PaymentIntentInput {
  pgId: string;
  amount: number;
  description: string;
  transactionRef: string;
  tenantId?: string;
}

export interface PaymentIntentResult {
  provider: 'upi_deep_link' | 'razorpay' | 'cashfree';
  deepLink?: string;
  orderId?: string;
  amount: number;
}

/**
 * Payment gateway abstraction — UPI deep links today; Razorpay/Cashfree later.
 */
export interface PaymentGatewayProvider {
  readonly providerId: PaymentIntentResult['provider'];
  createPaymentIntent(input: PaymentIntentInput): Promise<PaymentIntentResult>;
}
