import type { SupplierDetail } from './types';

// Fields the backend requires before it accepts any supplier profile save,
// mirroring SupplierProfileInput in backend/app/contracts.py.
export const REQUIRED_PROFILE_FIELDS = {
  public_alias: { label: 'Farm / supplier alias', min: 2 },
  legal_name: { label: 'Legal name', min: 2 },
  region: { label: 'Region', min: 2 },
  district: { label: 'District', min: 2 },
  internal_pickup_address: { label: 'Pickup address', min: 3 },
  categories: { label: 'Supply categories', min: 1 },
} as const;

export type RequiredProfileField = keyof typeof REQUIRED_PROFILE_FIELDS;

export function missingProfileFields(supplier: Pick<SupplierDetail, RequiredProfileField>): RequiredProfileField[] {
  return (Object.keys(REQUIRED_PROFILE_FIELDS) as RequiredProfileField[]).filter((key) => {
    const value = supplier[key];
    const length = Array.isArray(value) ? value.length : String(value ?? '').trim().length;
    return length < REQUIRED_PROFILE_FIELDS[key].min;
  });
}
