'use client';
import { useActionState } from 'react';
import { useFormStatus } from 'react-dom';
import { cancelMarketReservation } from '@/lib/market-portal-actions';
function Button() { const { pending } = useFormStatus(); return <button type="submit" className="market-cancel-button" disabled={pending}>{pending ? 'Cancelling…' : 'Cancel reservation'}</button>; }
export function MarketCancel({ id }: { id: string }) { const [state, action] = useActionState(cancelMarketReservation, null); return <form action={action}><input type="hidden" name="id" value={id} /><Button />{state && !state.ok && <p className="portal-form-error">{state.error}</p>}</form>; }
