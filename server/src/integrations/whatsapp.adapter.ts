import type { WhatsAppProvider, SendMessageInput, SendMessageResult } from '@/interfaces/messaging.provider';
import { logger } from '@/lib/logger';
import { v4 as uuidv4 } from 'uuid';

export class ConsoleWhatsAppAdapter implements WhatsAppProvider {
  async send(input: SendMessageInput): Promise<SendMessageResult> {
    logger.info('whatsapp.sent', {
      to: input.to,
      templateId: input.templateId,
      provider: 'console',
    });
    return { messageId: uuidv4(), status: 'queued' };
  }
}

export function getWhatsAppProvider(): WhatsAppProvider {
  return new ConsoleWhatsAppAdapter();
}
