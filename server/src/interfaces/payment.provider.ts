export interface CreatePaymentOrderInput {
  amount: number;
  currency: string;
  receipt: string;
  notes?: Record<string, string>;
}

export interface PaymentOrder {
  orderId: string;
  amount: number;
  currency: string;
}

export interface PaymentWebhookEvent {
  externalId: string;
  status: 'succeeded' | 'failed' | 'refunded';
  amount: number;
  metadata?: Record<string, string>;
}

/**
 * Payment gateway abstraction (Razorpay primary, Stripe-ready).
 */
export interface PaymentProvider {
  createOrder(input: CreatePaymentOrderInput): Promise<PaymentOrder>;
  verifyWebhookSignature(payload: string, signature: string): boolean;
  parseWebhookEvent(payload: string): PaymentWebhookEvent;
}
