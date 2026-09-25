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

export type ApprovalTarget = 'details' | 'production' | 'pickup' | 'categories' | 'verification';
export interface ApprovalItem { key: string; label: string; hint: string; done: boolean; target: ApprovalTarget }
export interface ApprovalGroup { title: string; items: ApprovalItem[] }

export const REQUIRED_VERIFICATION_CHECKS = ['phone_confirmed', 'identity_reviewed', 'location_confirmed', 'production_seen', 'pickup_access_checked'] as const;

const filled = (value: unknown) => (Array.isArray(value) ? value.length > 0 : value && typeof value === 'object' ? Object.keys(value).length > 0 : String(value ?? '').trim().length > 0);

// Everything the backend checks before it lets operations approve a supplier
// (ops_supplier_status in backend/app/main.py). Keep the two in step.
export function approvalRequirements(supplier: SupplierDetail): ApprovalGroup[] {
  const check = (key: (typeof REQUIRED_VERIFICATION_CHECKS)[number], label: string, hint: string): ApprovalItem =>
    ({ key, label, hint, done: supplier.verification[key] === true, target: 'verification' });
  return [
    { title: 'Supplier profile', items: [
      { key: 'public_alias', label: 'Farm / supplier alias', hint: 'The name buyers see', done: filled(supplier.public_alias), target: 'details' },
      { key: 'legal_name', label: 'Legal name', hint: 'Kept internal, used for payouts', done: filled(supplier.legal_name), target: 'details' },
      { key: 'region', label: 'Region', hint: 'General region of the farm', done: filled(supplier.region), target: 'details' },
      { key: 'district', label: 'District', hint: 'Used to match nearby demand', done: filled(supplier.district), target: 'details' },
      { key: 'internal_pickup_address', label: 'Private pickup address', hint: 'Where Omoterra collects from', done: filled(supplier.internal_pickup_address), target: 'pickup' },
      { key: 'categories', label: 'Supply categories', hint: 'At least one product they supply', done: filled(supplier.categories), target: 'categories' },
      { key: 'production_profile', label: 'Typical capacity', hint: 'Capacity for at least one category', done: filled(supplier.production_profile), target: 'categories' },
      { key: 'production_frequency', label: 'Production cycle', hint: 'How often they produce, e.g. every 6 weeks', done: filled(supplier.production_frequency), target: 'production' },
    ] },
    { title: 'Verification checks', items: [
      check('phone_confirmed', 'Phone confirmed', 'Called and reached the supplier'),
      check('identity_reviewed', 'Identity reviewed', 'Name matches their ID'),
      check('location_confirmed', 'Location confirmed', 'Farm location is known'),
      check('production_seen', 'Livestock or production seen', 'In person or by recent photos'),
      check('pickup_access_checked', 'Pickup access checked', 'Vehicles can reach the pickup point'),
    ] },
  ];
}
