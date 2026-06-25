import type { SmsProvider, SendMessageInput, SendMessageResult } from '@/interfaces/messaging.provider';
import { logger } from '@/lib/logger';
import { v4 as uuidv4 } from 'uuid';

export class ConsoleSmsAdapter implements SmsProvider {
  async send(input: SendMessageInput): Promise<SendMessageResult> {
    logger.info('sms.sent', { to: input.to, body: input.body, provider: 'console' });
    return { messageId: uuidv4(), status: 'sent' };
  }
}

export function getSmsProvider(): SmsProvider {
  // Swap for MSG91/Twilio adapter when credentials are configured.
  return new ConsoleSmsAdapter();
}
