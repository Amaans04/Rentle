import type {
  CreatePaymentOrderInput,
  PaymentOrder,
  PaymentProvider,
  PaymentWebhookEvent,
} from '@/interfaces/payment.provider';
import { logger } from '@/lib/logger';

/**
 * Razorpay adapter stub — wire real SDK when merchant keys are configured.
 */
export class RazorpayPaymentAdapter implements PaymentProvider {
  async createOrder(input: CreatePaymentOrderInput): Promise<PaymentOrder> {
    void input;
    logger.warn('payments.razorpay.not_configured', {
      message: 'Razorpay keys not set — using stub',
    });
    throw new Error('Razorpay is not configured');
  }

  verifyWebhookSignature(): boolean {
    return false;
  }

  parseWebhookEvent(payload: string): PaymentWebhookEvent {
    void payload;
    throw new Error('Razorpay is not configured');
  }
}

export function getPaymentProvider(): PaymentProvider {
  if (process.env.RAZORPAY_KEY_ID && process.env.RAZORPAY_KEY_SECRET) {
    // Real implementation added when keys are available.
    return new RazorpayPaymentAdapter();
  }
  return new RazorpayPaymentAdapter();
}
