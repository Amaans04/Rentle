import type { SmsProvider, SendMessageInput, SendMessageResult } from '@/interfaces/messaging.provider';
import { logger } from '@/lib/logger';
import { env } from '@/lib/env';
import { v4 as uuidv4 } from 'uuid';
import { Msg91SmsAdapter } from './msg91.adapter';

export class ConsoleSmsAdapter implements SmsProvider {
  async send(input: SendMessageInput): Promise<SendMessageResult> {
    logger.info('sms.sent', { to: input.to, body: input.body, provider: 'console' });
    console.log(`[SMS DEV] To: +91${input.to} — ${input.body}`);
    return { messageId: uuidv4(), status: 'sent' };
  }
}

export function getSmsProvider(): SmsProvider {
  if (env.msg91AuthKey && env.msg91OtpTemplateId) {
    return new Msg91SmsAdapter();
  }
  return new ConsoleSmsAdapter();
}
