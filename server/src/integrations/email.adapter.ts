import type { EmailProvider, SendMessageInput, SendMessageResult } from '@/interfaces/messaging.provider';
import { logger } from '@/lib/logger';
import { v4 as uuidv4 } from 'uuid';

export class ConsoleEmailAdapter implements EmailProvider {
  async send(input: SendMessageInput & { subject: string }): Promise<SendMessageResult> {
    logger.info('email.sent', {
      to: input.to,
      subject: input.subject,
      provider: 'console',
    });
    return { messageId: uuidv4(), status: 'sent' };
  }
}

export function getEmailProvider(): EmailProvider {
  return new ConsoleEmailAdapter();
}
