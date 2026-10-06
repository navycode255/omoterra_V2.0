'use server';
import { revalidatePath } from 'next/cache';
import { post, put, ApiError } from './api';
import { requireSession } from './session';
import type { ActionResult } from './actions';
const text = (form: FormData, name: string) => String(form.get(name) ?? '').trim();
export async function saveLocationForm(kind: string, id: string, data: FormData): Promise<ActionResult> {
  await requireSession();
  const t = (name: string) => text(data,name);
  const key = t('idempotency_key');
  let body: Record<string, unknown>; let path: string;
  switch(kind) {
    case 'location': case 'settings':
      body = {name:t('name'),address:t('address'),notes:t('notes'),daily_target:t('daily_target') || '0',active:kind==='location'||t('active')==='true'};
      path = kind==='location' ? '/ops/locations' : `/ops/locations/${id}`; break;
    case 'asset':
      body = {name:t('name'),purchased_on:t('purchased_on'),cost:t('cost'),residual_value:t('residual_value')||'0',useful_months:Number(t('useful_months')),depreciation_start:t('depreciation_start'),notes:t('notes')};
      path=`/ops/locations/${id}/assets`;break;
    case 'investment':
      body={invested_on:t('invested_on'),description:t('description'),amount:t('amount')};path=`/ops/locations/${id}/investments`;break;
    case 'allocation': {
      const source=t('source');const [kind,sourceId]=source.split(':');
      body={allocated_on:t('allocated_on'),quantity:t('quantity'),notes:t('notes'),
        ...(source==='opening' ? {category:t('category'),unit:t('unit'),unit_cost:t('unit_cost'),description:t('description')} : kind==='lpo' ? {lpo_line_id:sourceId} : kind==='returned' ? {opening_source_id:sourceId} : {supplier_collection_id:sourceId})};
      path=`/ops/locations/${id}/allocations`;break;
    }
    case 'sale': {
      const amount = t('payment_amount');
      body={allocation_id:t('allocation_id'),sold_on:t('sold_on'),quantity:t('quantity'),unit_price:t('unit_price'),notes:t('notes'),payment:Number(amount)>0 ? {amount,paid_on:t('sold_on'),method:t('method'),reference:t('reference'),money_account_id:t('money_account_id')||null} : null};
      path=`/ops/locations/${id}/sales`;break;
    }
    case 'stock-event':
      body={occurred_on:t('occurred_on'),kind:t('event_kind'),quantity:t('quantity'),note:t('note')};
      path=`/ops/locations/${id}/stock-events?allocation_id=${encodeURIComponent(t('allocation_id'))}`;break;
    case 'retire':
      body={retired_on:t('retired_on'),reason:t('reason')};path=`/ops/assets/${t('asset_id')}/retire`;break;
    default:return {ok:false,error:'Unknown form.'};
  }
  try { if(kind==='settings') await put(path,body); else await post(path,body,key); }
  catch(error) { if(error instanceof ApiError)return {ok:false,error:error.message};throw error; }
  for(const path of ['/locations','/sales','/finance']) revalidatePath(path,'layout');
  return {ok:true};
}
