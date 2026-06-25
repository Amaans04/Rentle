export type AuditAction =
  | 'CREATE'
  | 'UPDATE'
  | 'DELETE'
  | 'LOGIN'
  | 'LOGOUT'
  | 'EXPORT'
  | 'PAYMENT';

export interface AuditLogEntry {
  organizationId?: string;
  userId?: string;
  action: AuditAction;
  resource: string;
  metadata?: Record<string, unknown>;
  ipAddress?: string;
  userAgent?: string;
}

export interface AuditRepository {
  write(entry: AuditLogEntry): Promise<void>;
}
