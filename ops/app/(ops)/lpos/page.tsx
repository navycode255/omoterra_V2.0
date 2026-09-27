import Link from 'next/link';
import { Card, Empty, Notice, PageHeader, Status } from '@/components/ui';
import { ListControls } from '@/components/list-controls';
import { ApiError, get } from '@/lib/api';
import { day } from '@/lib/finance';
import { LPO_STATUS, lpoTone, type DemandRow, type Lpo } from '@/lib/lpo';
import { category, quantity, tzs, type Tone } from '@/lib/format';
import { listPath, type ListParams, type Page } from '@/lib/paging';

export const metadata = { title: 'LPOs · Omoterra Operations' };

const TABS = [
  { key: '', label: 'All' },
  { key: 'draft', label: 'Drafts' },
  { key: 'active', label: 'Open' },
  { key: 'closed', label: 'Closed' },
  { key: 'cancelled', label: 'Cancelled' },
];
const URGENCY: Record<DemandRow['urgency'], [Tone, string]> = {
  overdue: ['error', 'Overdue'], urgent: ['error', 'Urgent'], soon: ['warning', 'This week'], planned: ['neutral', 'Planned'],
};

export default async function Lpos({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  let data: Page<Lpo>;
  let demand: DemandRow[];
  try {
    [data, demand] = await Promise.all([get<Page<Lpo>>(listPath('/ops/lpos', params)), get<DemandRow[]>('/ops/lpos/demand')]);
  } catch (error) {
    return <><div className="topbar"><PageHeader title="LPOs" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'LPOs could not be loaded.'}</Notice></div></>;
  }
  return (
    <>
      <div className="topbar">
        <PageHeader title="Purchase orders (LPOs)" subtitle="What we have ordered from suppliers, what arrived, and what we owe for it."
          info="Staff draft LPOs; an admin issues them with their signature and the company stamp. Each batch received creates the supplier payment due." />
        <div className="row">
          <Link href="/lpos/marks" className="button" data-variant="secondary">Stamp and signature</Link>
          <Link href="/lpos/new" className="button">+ New LPO</Link>
        </div>
      </div>
      <div className="workspace">
        <Card title={`Supply most needed (${demand.length})`}>
          {demand.length === 0 ? <Empty>No open buyer demand is short of supply.</Empty> : (
            <div className="table-wrap">
              <table>
                <thead><tr><th>Needed</th><th>Demand</th><th className="numeric">Short</th><th>Best suppliers</th><th /></tr></thead>
                <tbody>
                  {demand.slice(0, 12).map((row) => (
                    <tr key={row.id}>
                      <td><Status tone={URGENCY[row.urgency][0]}>{URGENCY[row.urgency][1]}</Status>
                        <div className="meta">{day(row.needed_by_date)}{row.days_left !== null ? ` · ${row.days_left < 0 ? `${-row.days_left} days late` : `${row.days_left} days left`}` : ''}</div></td>
                      <td><Link href={`/sourcing/${row.id}`} className="strong">{category(row.category)}{row.product_subtype ? ` · ${row.product_subtype}` : ''}</Link>
                        <div className="meta">{row.requirement_number} · {row.buyer_name || 'Buyer'} · {[row.delivery_area, row.delivery_region].filter(Boolean).join(', ')}</div></td>
                      <td className="numeric money">{quantity(row.short)}<div className="meta">of {quantity(row.quantity)}{Number(row.on_lpo) ? ` · ${quantity(row.on_lpo)} on LPO` : ''}</div></td>
                      <td className="small">{row.suppliers.length === 0 ? <span className="muted">No approved supplier for this product yet</span>
                        : row.suppliers.slice(0, 3).map((s) => (
                          <div key={s.supplier_id}><Link href={`/lpos/new?demand=${row.id}&supplier=${s.supplier_id}`}>{s.name}</Link>
                            <span className="meta"> · {s.reasons.join('; ')}</span></div>))}</td>
                      <td><Link href={`/lpos/new?demand=${row.id}`} className="button" data-variant="secondary">Create LPO</Link></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Card>

        <ListControls path="/lpos" params={params} data={data} tabs={TABS} noun={['LPO', 'LPOs']} actionLabel="open"
          placeholder="Search LPO number or supplier">
          <div className="table-wrap">
            {data.items.length === 0 ? <Empty>No LPOs in this view.</Empty> : (
              <table>
                <thead><tr><th>LPO</th><th>Supplier</th><th>Items</th><th>Delivery</th><th className="numeric">Received</th><th className="numeric">I owe</th><th>Status</th></tr></thead>
                <tbody>
                  {data.items.map((lpo) => (
                    <tr key={lpo.id}>
                      <td><Link href={`/lpos/${lpo.id}`} className="strong">{lpo.status === 'draft' ? 'Draft' : lpo.lpo_number}</Link>
                        <div className="meta">{day(lpo.lpo_date)}</div></td>
                      <td>{lpo.supplier_snapshot.name}<div className="meta">{lpo.supplier_snapshot.phone}</div></td>
                      <td className="small">{lpo.lines.map((l) => `${l.item} @ ${tzs(l.unit_price)}`).join(', ')}</td>
                      <td className="small">{day(lpo.delivery_start)} – {day(lpo.delivery_end)}</td>
                      <td className="numeric">{tzs(lpo.received_value)}</td>
                      <td className="numeric money">{tzs(lpo.owed_value)}</td>
                      <td><Status tone={lpoTone(lpo.display_status)}>{LPO_STATUS[lpo.display_status]}</Status></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </ListControls>
      </div>
    </>
  );
}
