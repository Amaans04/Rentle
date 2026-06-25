import { ValidationError } from './errors';

export type UserRole = 'owner' | 'manager' | 'tenant';

export { ValidationError };

const PHONE_REGEX = /^[6-9]\d{9}$/;

export function sanitizePhone(phone: string): string {
  let cleaned = phone.replace(/\s+/g, '').replace(/-/g, '');
  if (cleaned.startsWith('+91')) cleaned = cleaned.slice(3);
  if (cleaned.startsWith('91') && cleaned.length === 12) cleaned = cleaned.slice(2);
  if (cleaned.startsWith('0') && cleaned.length === 11) cleaned = cleaned.slice(1);
  return cleaned;
}

export function isValidPhone(phone: string): boolean {
  return PHONE_REGEX.test(sanitizePhone(phone));
}

export function isValidOtp(otp: string): boolean {
  return /^\d{6}$/.test(otp);
}

export function isValidRole(role: string): role is UserRole {
  return ['owner', 'manager', 'tenant'].includes(role);
}

export function isPositiveInt(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value) && value > 0;
}

export function isNonNegativeNumber(value: unknown): value is number {
  return typeof value === 'number' && value >= 0 && !Number.isNaN(value);
}

export function requireString(value: unknown, field: string): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new ValidationError(`${field} is required`);
  }
  return value.trim();
}

export function requireNumber(value: unknown, field: string): number {
  const num = typeof value === 'string' ? parseFloat(value) : value;
  if (typeof num !== 'number' || Number.isNaN(num)) {
    throw new ValidationError(`${field} must be a valid number`);
  }
  return num;
}

export function validateRentDueDate(day: number): void {
  if (!Number.isInteger(day) || day < 1 || day > 28) {
    throw new ValidationError('Rent due date must be between 1 and 28');
  }
}

export function validateGenderType(type: string): void {
  if (!['boys', 'girls', 'unisex'].includes(type)) {
    throw new ValidationError('Invalid gender type');
  }
}

export function validateRoomType(type: string): void {
  if (!['single', 'double', 'triple', 'dormitory'].includes(type)) {
    throw new ValidationError('Invalid room type');
  }
}

export function validateComplaintType(type: string): void {
  if (!['maintenance', 'cleaning', 'other'].includes(type)) {
    throw new ValidationError('Invalid complaint type');
  }
}
