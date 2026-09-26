// Accepts 0712…, 712…, 255712… and +255712… the way people type them, and
// returns the +255 form the backend requires, or null.
export function tanzanianMobile(raw: string) {
  const local = raw.replace(/[\s()-]/g, '').replace(/^\+?255/, '').replace(/^0/, '');
  const phone = `+255${local}`;
  return /^\+255[67]\d{8}$/.test(phone) ? phone : null;
}
