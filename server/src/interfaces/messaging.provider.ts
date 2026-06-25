export interface SendMessageInput {
  to: string;
  body: string;
  templateId?: string;
  variables?: Record<string, string>;
}

export interface SendMessageResult {
  messageId: string;
  status: 'queued' | 'sent' | 'failed';
}

export interface SmsProvider {
  send(input: SendMessageInput): Promise<SendMessageResult>;
}

export interface EmailProvider {
  send(input: SendMessageInput & { subject: string }): Promise<SendMessageResult>;
}

export interface WhatsAppProvider {
  send(input: SendMessageInput): Promise<SendMessageResult>;
}
