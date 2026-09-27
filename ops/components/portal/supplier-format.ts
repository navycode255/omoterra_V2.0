// Words and numbers for the supplier dashboard: category names, units,
// amounts and dates as the supplier reads them.
export const CATEGORY: Record<string, [label: string, one: string, many: string, image: string]> = {
  broilers: ['Broilers', 'bird', 'birds', 'category_broilers.jpg'], local_chicken: ['Local chicken', 'bird', 'birds', 'category_broilers.jpg'],
  layers: ['Layers', 'bird', 'birds', 'category_eggs.jpg'], eggs: ['Eggs', 'tray', 'trays', 'category_eggs.jpg'],
  goats: ['Goats', 'animal', 'animals', 'category_goats.jpg'], cattle: ['Cattle', 'animal', 'animals', 'category_cow.jpg'],
  chicken_meat: ['Chicken meat', 'kg', 'kg', 'category_broilers.jpg'], beef: ['Beef', 'kg', 'kg', 'category_cow.jpg'],
  goat_meat: ['Goat meat', 'kg', 'kg', 'category_goats.jpg'],
};
export const FORMS: Record<string, string> = { live: 'Live', dressed: 'Dressed', chilled: 'Chilled', frozen: 'Frozen' };
export const CONTACT: Record<string, string> = { phone: 'Phone call', whatsapp: 'WhatsApp', sms: 'Text message' };
export const number = new Intl.NumberFormat('en-US', { maximumFractionDigits: 2 });
export const date = new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'Africa/Dar_es_Salaam' });

export const label = (category: string) => CATEGORY[category]?.[0] ?? category;
export const units = (category: string, quantity: number) => (quantity === 1 ? CATEGORY[category]?.[1] : CATEGORY[category]?.[2]) ?? '';
export const media = (url: string) => `/account/media/${url.split('/').pop()}`;
export const categoryImage = (category: string) => `/images/marketing/${CATEGORY[category]?.[3] ?? 'cattle-herd-v1.webp'}`;
export const tzs = (value: string | number) => `TZS ${number.format(Number(value))}`;
