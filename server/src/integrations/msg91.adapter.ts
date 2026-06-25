import type { SmsProvider, SendMessageInput, SendMessageResult } from '@/interfaces/messaging.provider';
import { logger } from '@/lib/logger';
import { env } from '@/lib/env';

interface Msg91Response {
  type?: string;
  message?: string;
}

export class Msg91SmsAdapter implements SmsProvider {
  async send(input: SendMessageInput): Promise<SendMessageResult> {
    const authKey = env.msg91AuthKey;
    const templateId = input.templateId || env.msg91OtpTemplateId;

    const url = new URL('https://control.msg91.com/api/v5/flow/');
    const response = await fetch(url.toString(), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        authkey: authKey,
      },
      body: JSON.stringify({
        template_id: templateId,
        recipients: [
          {
            mobiles: `91${input.to}`,
            var: input.variables?.otp ?? input.body,
          },
        ],
      }),
    });

    const data = (await response.json()) as Msg91Response;
    if (!response.ok) {
      logger.error('sms.msg91.failed', { status: response.status, data });
      throw new Error(data.message || 'Failed to send SMS');
    }

    logger.info('sms.msg91.sent', { to: input.to, templateId });
    return { messageId: `msg91-${Date.now()}`, status: 'sent' };
  }
}
