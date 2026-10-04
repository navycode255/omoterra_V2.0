'use server';

import { randomUUID } from 'node:crypto';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { ApiError, del, post, postFile, put } from './api';
import type { ActionResult } from './actions';
import type { Debt, SaleDetail } from './finance';
import { tanzanianMobile } from './phone';
import { requireSession } from './session';

// Same contract as lib/actions.ts: every action re-checks the session, and
// the backend owns the rules (balances, no overpayment, idempotency).
async function run(work: () => Promise<unknown>, paths: string[]): Promise<ActionResult> {
  await requireSession();
  try {
    await work();
  } catch (error) {
    if (error instanceof ApiError) return { ok: false, error: error.message };
    throw error;
  }
  for (const path of paths) revalidatePath(path, 'layout');
  return { ok: true };
}

const text = (formData: FormData, key: string) => String(formData.get(key) ?? '').trim();

// The form renders one key; a double click or a retry after a lost answer
// then records the payment once. A refused attempt stores nothing, so the
// same key can be sent again once the input is fixed.
function key(formData: FormData) {
  return text(formData, 'idempotency_key') || randomUUID();
}

const FINANCE = ['/finance', '/sales'];

function supplierReceiptSmsBody(formData: FormData) {
  return {
    send_receipt_sms: text(formData, 'send_receipt_sms') === 'true',
    receipt_language: text(formData, 'receipt_language') || 'en',
    include_thank_you: text(formData, 'include_thank_you') === 'true',
  };
}

type SupplierPaymentResult = {
  id: string;
  amount: string;
  receipt_sms_status: 'queued' | 'sent' | 'failed' | 'skipped';
};

/** The sale form posts its whole order as JSON; on success, open the sale. */
export async function createSale(_: ActionResult | null, formData: FormData): Promise<ActionResult> {
  await requireSession();
  let sale: SaleDetail;
  try {
    sale = await post<SaleDetail>('/ops/sales', JSON.parse(text(formData, 'payload')), key(formData));
  } catch (error) {
    if (error instanceof ApiError) return { ok: false, error: error.message };
    if (error instanceof SyntaxError) return { ok: false, error: 'The order could not be read. Reload the page and try again.' };
    throw error;
  }
  for (const path of [...FINANCE, '/buyers']) revalidatePath(path, 'layout');
  redirect(`/sales/${sale.id}?created=1`);
}

/** Correct sale details while the backend preserves all recorded payments. */
export async function updateSale(_: ActionResult | null, formData: FormData): Promise<ActionResult> {
  await requireSession();
  const id = text(formData, 'sale_id');
  let sale: SaleDetail;
  try {
    sale = await put<SaleDetail>(`/ops/sales/${id}`, JSON.parse(text(formData, 'payload')));
  } catch (error) {
    if (error instanceof ApiError) return { ok: false, error: error.message };
    if (error instanceof SyntaxError) return { ok: false, error: 'The sale could not be read. Reload the page and try again.' };
    throw error;
  }
  for (const path of [...FINANCE, '/buyers', `/sales/${id}`]) revalidatePath(path, 'layout');
  redirect(`/sales/${sale.id}?updated=1`);
}

function paymentBody(formData: FormData) {
  return {
    amount: text(formData, 'amount').replace(/,/g, ''),
    paid_on: text(formData, 'paid_on'),
    method: text(formData, 'method'),
    reference: text(formData, 'reference'),
    note: text(formData, 'note'),
  };
}

export async function recordLedgerPayment(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'debt_id');
  const sale = text(formData, 'sale_id');
  return run(() => post(`/ops/ledger/debts/${id}/payments`, paymentBody(formData), key(formData)),
    [...FINANCE, `/finance/debts/${id}`, ...(sale ? [`/sales/${sale}`] : [])]);
}

/** The dedicated supplier-payment screen returns to a clean, refreshed list. */
export async function recordSupplierPayment(_: ActionResult | null, formData: FormData): Promise<ActionResult> {
  const result = await recordLedgerPayment(null, formData);
  if (!result.ok) return result;
  redirect('/finance/supplier-payments?paid=1');
}

/** One real supplier transfer, allocated over all or selected open invoices. */
export async function recordSupplierBatchPayment(_: ActionResult | null, formData: FormData): Promise<ActionResult> {
  await requireSession();
  const supplier = text(formData, 'supplier_id');
  const receipt = formData.get('receipt');
  const reference = text(formData, 'reference');
  const sms = text(formData, 'sms_text');
  if (!supplier) return { ok: false, error: 'Choose the supplier you paid.' };
  const creditOnly = Number(text(formData, 'use_credit') || 0) > 0 && Number(text(formData, 'amount').replace(/,/g, '') || 0) <= 0;
  // No invoices picked: the backend pays the supplier's oldest invoices first.
  if (!creditOnly && !reference && !sms && (!(receipt instanceof File) || receipt.size === 0)) {
    return { ok: false, error: 'Add a receipt number, payment SMS, or receipt image.' };
  }
  if (receipt instanceof File && receipt.size > 10 * 1024 * 1024) {
    return { ok: false, error: 'Choose a receipt image smaller than 10 MB.' };
  }
  try {
    let receiptMediaId: string | null = null;
    if (receipt instanceof File && receipt.size) {
      const saved = await postFile<{ id: string }>('/ops/ledger/supplier-payment-receipts', receipt, randomUUID());
      receiptMediaId = saved.id;
    }
    const credit = Number(text(formData, 'use_credit') || 0);
    const amount = Number(text(formData, 'amount').replace(/,/g, '') || 0);
    if (credit > 0 && amount <= 0) {
      // The supplier's credit covers it: no new money, so no transfer.
      await post(`/ops/ledger/suppliers/${encodeURIComponent(supplier)}/credit/apply`, {
        amount: String(credit), debt_ids: formData.getAll('debt_ids').map(String), note: text(formData, 'note'),
      }, key(formData));
    } else {
      await post<SupplierPaymentResult>(`/ops/ledger/suppliers/${encodeURIComponent(supplier)}/payments`, {
        ...paymentBody(formData),
        debt_ids: formData.getAll('debt_ids').map(String),
        sms_text: sms,
        receipt_media_id: receiptMediaId,
        use_credit: credit > 0 ? String(credit) : '0',
        ...supplierReceiptSmsBody(formData),
      }, key(formData));
    }
  } catch (error) {
    if (error instanceof ApiError) return { ok: false, error: error.message };
    throw error;
  }
  for (const path of [...FINANCE, '/finance/supplier-payments']) revalidatePath(path, 'layout');
  const smsRequested = text(formData, 'send_receipt_sms') === 'true';
  redirect(`/finance/supplier-payments?paid=1${smsRequested ? '&sms=queued' : ''}`);
}

/** Record a supplier payment whose original stock cost was never entered. */
export async function recordUnlistedSupplierPayment(_: ActionResult | null, formData: FormData): Promise<ActionResult> {
  await requireSession();
  const receipt = formData.get('receipt');
  const reference = text(formData, 'reference');
  const sms = text(formData, 'sms_text');
  if (!reference && !sms && (!(receipt instanceof File) || receipt.size === 0)) {
    return { ok: false, error: 'Add a receipt number, payment SMS, or receipt image.' };
  }
  if (receipt instanceof File && receipt.size > 10 * 1024 * 1024) {
    return { ok: false, error: 'Choose a receipt image smaller than 10 MB.' };
  }
  let debt: Debt;
  try {
    debt = await post<Debt>('/ops/ledger/debts', {
      direction: 'payable',
      party_kind: 'supplier',
      supplier_id: text(formData, 'supplier_id'),
      party_name: '',
      party_phone: '',
      description: text(formData, 'description'),
      amount: text(formData, 'amount').replace(/,/g, ''),
      incurred_on: text(formData, 'paid_on'),
      due_on: null,
    }, key(formData));
    let receiptMediaId: string | null = null;
    if (receipt instanceof File && receipt.size) {
      const saved = await postFile<{ id: string }>('/ops/ledger/supplier-payment-receipts', receipt, randomUUID());
      receiptMediaId = saved.id;
    }
    await post<SupplierPaymentResult>(`/ops/ledger/suppliers/${encodeURIComponent(text(formData, 'supplier_id'))}/payments`, {
      ...paymentBody(formData), debt_ids: [debt.id], sms_text: sms, receipt_media_id: receiptMediaId,
      ...supplierReceiptSmsBody(formData),
    }, text(formData, 'payment_key') || randomUUID());
  } catch (error) {
    if (error instanceof ApiError) return { ok: false, error: error.message };
    throw error;
  }
  for (const path of FINANCE) revalidatePath(path, 'layout');
  const smsRequested = text(formData, 'send_receipt_sms') === 'true';
  redirect(`/finance/supplier-payments?paid=1${smsRequested ? '&sms=queued' : ''}`);
}

export async function reverseLedgerPayment(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'payment_id');
  return run(() => post(`/ops/ledger/payments/${id}/reverse`, { reason: text(formData, 'reason') }, key(formData)),
    [...FINANCE, '/suppliers', '/account']);
}

/** Put a supplier's credit (money they already hold) on their open invoices. No money moves. */
export async function applySupplierCredit(_: ActionResult | null, formData: FormData) {
  const supplier = text(formData, 'supplier_id');
  const debts = formData.getAll('debt_ids').map(String).filter(Boolean);
  return run(() => post(`/ops/ledger/suppliers/${encodeURIComponent(supplier)}/credit/apply`, {
    amount: text(formData, 'amount').replace(/,/g, ''), debt_ids: debts, note: text(formData, 'note'),
  }, key(formData)), [...FINANCE, '/suppliers', '/account']);
}

/** Money a supplier actually sent back from their credit (admin, with evidence). */
export async function recordTransferRefund(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'transfer_id');
  return run(() => post(`/ops/ledger/transfers/${encodeURIComponent(id)}/refunds`, {
    amount: text(formData, 'amount').replace(/,/g, ''), received_on: text(formData, 'received_on'),
    method: text(formData, 'method'), reference: text(formData, 'reference'), evidence: text(formData, 'evidence'),
    note: text(formData, 'note'),
  }, key(formData)), [...FINANCE, '/suppliers', '/account']);
}

/** Part of a transfer that never left the account (admin, with reason and evidence). */
export async function correctTransferEntry(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'transfer_id');
  return run(() => post(`/ops/ledger/transfers/${encodeURIComponent(id)}/entry-error`, {
    amount: text(formData, 'amount').replace(/,/g, ''), reason: text(formData, 'reason'), evidence: text(formData, 'evidence'),
  }, key(formData)), [...FINANCE, '/suppliers', '/account']);
}

export async function cancelSale(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'sale_id');
  // Received goods (delivery note or LPO): staff say what happened to them (rule R2).
  const goods = text(formData, 'goods');
  return run(() => post(`/ops/sales/${id}/cancel`, {
    reason: text(formData, 'reason'),
    ...(goods ? { goods, goods_note: text(formData, 'goods_note') } : {}),
  }, key(formData)), [...FINANCE, `/sales/${id}`, '/suppliers', '/supplier-collections']);
}

export async function cancelDebt(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'debt_id');
  const sale = text(formData, 'sale_id');
  return run(() => post(`/ops/ledger/debts/${id}/cancel`, { reason: text(formData, 'reason') }, key(formData)),
    [...FINANCE, '/finance/supplier-payments', '/account', `/finance/debts/${id}`, ...(sale ? [`/sales/${sale}`] : [])]);
}

/**
 * Correct a supplier debt opened by a sale, for one of four reasons
 * (POST /ops/ledger/debts/{id}/corrections, admins only). Money already paid
 * stays with the supplier who received it, as credit or unresolved.
 */
export async function correctDebt(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'debt_id');
  const sale = text(formData, 'sale_id');
  const kind = text(formData, 'kind');
  const supplier = text(formData, 'supplier_id');
  const body = {
    kind,
    reason: text(formData, 'reason'),
    ...(kind === 'wrong_supplier' ? supplier ? { supplier_id: supplier } : { supplier_name: text(formData, 'supplier_name') } : {}),
    ...(kind === 'duplicate_liability' ? { duplicate_of: text(formData, 'duplicate_of') } : {}),
    ...(text(formData, 'payments') ? { payments: text(formData, 'payments') } : {}),
  };
  return run(() => post(`/ops/ledger/debts/${id}/corrections`, body, key(formData)),
    [...FINANCE, '/finance/supplier-payments', '/suppliers', '/account', `/finance/debts/${id}`, ...(sale ? [`/sales/${sale}`] : [])]);
}

export async function createDebt(_: ActionResult | null, formData: FormData) {
  const party = text(formData, 'party');  // 'buyer:<id>', 'supplier:<id>' or '' for a typed name
  const [kind, id] = party.includes(':') ? party.split(':') : ['other', ''];
  const phone = text(formData, 'party_phone');
  const due = text(formData, 'due_on');
  // Debts keep one description: an optional reference and note ride along.
  const reference = text(formData, 'reference');
  const note = text(formData, 'note');
  const description = [text(formData, 'description'), reference && `Ref ${reference}`, note].filter(Boolean).join(' · ').slice(0, 500);
  const body = {
    direction: text(formData, 'direction'),
    party_kind: kind,
    ...(kind === 'buyer' ? { buyer_profile_id: id } : {}),
    ...(kind === 'supplier' ? { supplier_id: id } : {}),
    party_name: kind === 'other' ? text(formData, 'party_name') : '',
    party_phone: phone ? tanzanianMobile(phone) ?? phone : '',
    description,
    amount: text(formData, 'amount').replace(/,/g, ''),
    incurred_on: text(formData, 'incurred_on'),
    due_on: due || null,
  };
  return run(() => post('/ops/ledger/debts', body, key(formData)), [...FINANCE]);
}

export async function createExpense(_: ActionResult | null, formData: FormData) {
  const paidNow = text(formData, 'paid_now');  // 'full', 'part' or 'none'
  const amount = text(formData, 'amount').replace(/,/g, '');
  const paidAmount = paidNow === 'full' ? amount : paidNow === 'part' ? text(formData, 'paid_amount').replace(/,/g, '') : '';
  const phone = text(formData, 'paid_to_phone');
  const sale = text(formData, 'sale_id');
  const body = {
    spent_on: text(formData, 'spent_on'),
    location_id: text(formData, 'location_id') || null,
    category: text(formData, 'category'),
    description: text(formData, 'description'),
    amount,
    paid_to: text(formData, 'paid_to'),
    paid_to_phone: phone ? tanzanianMobile(phone) ?? phone : '',
    sale_id: sale || null,
    due_on: text(formData, 'due_on') || null,
    payment: paidAmount ? {
      amount: paidAmount, paid_on: text(formData, 'spent_on'), method: text(formData, 'method'),
      reference: text(formData, 'reference'), note: '',
    } : null,
  };
  return run(() => post('/ops/expenses', body, key(formData)),
    [...FINANCE, '/locations', '/finance/expenses', '/finance/profit', ...(sale ? [`/sales/${sale}`] : [])]);
}

export async function sendPromotion(_: ActionResult | null, formData: FormData) {
  const channels = formData.getAll('channel').map(String);
  return run(() => post('/ops/promotions', {
    audience: text(formData, 'audience'),
    title: text(formData, 'title'),
    message: text(formData, 'message'),
    send_sms: channels.includes('sms'),
    send_in_app: channels.includes('in_app'),
  }, key(formData)), ['/promotions']);
}

export async function retryPromotion(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'promotion_id');
  return run(() => post(`/ops/promotions/${id}/retry`, {}), ['/promotions', `/promotions/${id}`]);
}

export async function addOptOut(_: ActionResult | null, formData: FormData) {
  const phone = text(formData, 'phone');
  return run(() => post('/ops/promotions/opt-outs', { phone: tanzanianMobile(phone) ?? phone, note: text(formData, 'note') }),
    ['/promotions']);
}

export async function removeOptOut(_: ActionResult | null, formData: FormData) {
  return run(() => del(`/ops/promotions/opt-outs/${encodeURIComponent(text(formData, 'phone'))}`), ['/promotions']);
}
