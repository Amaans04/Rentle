export const CHARGE_TYPES = [
  'rent',
  'fine',
  'electricity',
  'water',
  'food',
  'laundry',
  'maintenance',
  'deposit',
  'other',
] as const;

export type ChargeType = (typeof CHARGE_TYPES)[number];

export function isValidChargeType(value: string): value is ChargeType {
  return (CHARGE_TYPES as readonly string[]).includes(value);
}
