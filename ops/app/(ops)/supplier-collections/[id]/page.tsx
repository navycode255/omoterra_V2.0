import Link from 'next/link';
import { notFound } from 'next/navigation';
import { PrintButton } from '@/components/lpo/print-button';
import { Notice, PageHeader, Status } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import type { SupplierCollectionStock } from '@/lib/finance';
import { category, date, quantity, tzs } from '@/lib/format';

export const metadata = { title: 'Supplier delivery note · Omoterra Operations' };

export default async function SupplierDeliveryNote({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  let note: SupplierCollectionStock;
  try { note = await get<SupplierCollectionStock>('/ops/supplier-collections/' + id); }
  catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    return <><div className="topbar"><PageHeader title="Delivery note" /></div><div className="workspace"><Notice tone="error">The delivery note could not be loaded.</Notice></div></>;
  }
  return <>
    <div className="topbar delivery-note-actions"><PageHeader title={note.collection_number} subtitle="Supplier stock collection and acceptance record" /><PrintButton /></div>
    <div className="workspace">
      <article className="delivery-note">
        <header><div><strong>Omoterra</strong><span>SUPPLIER DELIVERY NOTE</span></div><Status tone={note.cancelled_at ? 'warning' : 'positive'}>{note.cancelled_at ? 'Cancelled' : 'Received'}</Status></header>
        <div className="delivery-note-grid">
          <dl><div><dt>Supplier</dt><dd>{note.supplier_name}</dd></div><div><dt>Phone</dt><dd>{note.supplier_phone}</dd></div><div><dt>Batch</dt><dd>{note.batch_id.slice(0, 8)} · {category(note.category)}{note.subtype ? ' · ' + note.subtype : ''}</dd></div></dl>
          <dl><div><dt>Delivery note</dt><dd>{note.collection_number}</dd></div><div><dt>Collection date</dt><dd>{date(note.received_on)}</dd></div><div><dt>Recorded</dt><dd>{date(note.created_at)}</dd></div></dl>
        </div>
        <table><thead><tr><th>Product</th><th>Delivered</th><th>Accepted</th><th>Rejected</th><th>Avg. weight</th><th>Unit cost</th><th>Accepted value</th></tr></thead>
          <tbody><tr><td>{category(note.category)}</td><td>{quantity(note.delivered_quantity)} {note.unit}s</td><td>{quantity(note.accepted_quantity)} {note.unit}s</td><td>{quantity(note.rejected_quantity)} {note.unit}s</td><td>{note.average_weight_kg ? note.average_weight_kg + ' kg' : '—'}</td><td>{tzs(note.unit_cost)}</td><td>{tzs(note.amount)}</td></tr></tbody></table>
        <section><h3>Stock movement</h3><dl className="delivery-note-stock"><div><dt>Accepted into Omoterra stock</dt><dd>{quantity(note.accepted_quantity)}</dd></div><div><dt>Sold</dt><dd>{quantity(note.sold)}</dd></div><div><dt>Currently on hand</dt><dd>{quantity(note.on_hand)}</dd></div></dl></section>
        {note.notes && <section><h3>Comments</h3><p>{note.notes}</p></section>}
        <footer><span>Recorded by Omoterra operations</span><span>Supplier acknowledgement: ____________________</span></footer>
      </article>
      <p className="meta"><Link href={'/suppliers/' + note.supplier_id}>← Back to supplier</Link>{note.debt_id && <> · <Link href={'/finance/debts/' + note.debt_id}>Open supplier invoice</Link></>}</p>
    </div>
  </>;
}
