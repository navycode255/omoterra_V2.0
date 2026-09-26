// How a supplier can be paid (backend contracts.PayoutMethod). Only the
// choice is collected; account numbers are asked for when a payout is due.
export const PAYOUT_METHODS = [
  ['mpesa', 'M-Pesa'], ['mixx_by_yas', 'Mixx by Yas'], ['airtel_money', 'Airtel Money'],
  ['halopesa', 'HaloPesa'], ['bank_transfer', 'Bank transfer'],
] as const;

export const payoutLabel = (key: string) => PAYOUT_METHODS.find(([value]) => value === key)?.[1] ?? key;
