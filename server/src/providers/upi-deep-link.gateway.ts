import type {
  PaymentGatewayProvider,
  PaymentIntentInput,
  PaymentIntentResult,
} from '@/interfaces/payment-gateway.provider';
import { buildPaymentDeepLinkForPg } from '@/services/payment/upi.service';

export class UpiDeepLinkGateway implements PaymentGatewayProvider {
  readonly providerId = 'upi_deep_link' as const;

  async createPaymentIntent(input: PaymentIntentInput): Promise<PaymentIntentResult> {
    const deepLink = await buildPaymentDeepLinkForPg(
      input.pgId,
      input.amount,
      input.description,
      input.transactionRef,
    );
    return {
      provider: this.providerId,
      deepLink,
      amount: input.amount,
    };
  }
}

let gatewayInstance: UpiDeepLinkGateway | null = null;

export function getPaymentGateway(): PaymentGatewayProvider {
  // Future: if RAZORPAY_KEY_ID set, return RazorpayGateway instead.
  if (!gatewayInstance) {
    gatewayInstance = new UpiDeepLinkGateway();
  }
  return gatewayInstance;
}
