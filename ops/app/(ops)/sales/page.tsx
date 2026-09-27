import Link from 'next/link';
import { Empty, Notice, PageHeader, Status } from '@/components/ui';
import { ListControls } from '@/components/list-controls';
import { ApiError, get } from '@/lib/api';
import { day, type Sale } from '@/lib/finance';
import { phone, tzs } from '@/lib/format';
import { listPath, type ListParams, type Page } from '@/lib/paging';

export const metadata = { title: 'Sales · Omoterra Operations' };

const TABS = [
  { key: '', label: 'All' },
  { key: 'unpaid', label: 'Buyer still owes' },
  { key: 'paid', label: 'Fully paid' },
  { key: 'cancelled', label: 'Cancelled' },
];

export default async function Sales({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  let data: Page<Sale>;
  try {
    data = await get<Page<Sale>>(listPath('/ops/sales', params));
  } catch (error) {
    return <><div className="topbar"><PageHeader title="Sales" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'Sales could not be loaded.'}</Notice></div></>;
  }
  return (
    <>
      <div className="topbar">
        <PageHeader title="Sales" subtitle="Orders staff recorded directly: phone, market and walk-in sales, with what each buyer still owes."
          info="Each sale opens a debt for the buyer and, for stock bought from a supplier, a debt to that supplier. Installments are recorded on the sale." />
        <Link href="/sales/new" className="button">+ New sale</Link>
      </div>
      <div className="workspace">
        <ListControls path="/sales" params={params} data={data} tabs={TABS} noun={['sale', 'sales']}
          placeholder="Search sale number, buyer, phone or product">
          <div className="table-wrap">
            {data.items.length === 0 ? <Empty>No sales in this view. <Link href="/sales/new">Record a sale</Link>.</Empty> : (
              <table>
                <thead>
                  <tr>
                    <th>Sale</th><th>Buyer</th><th className="numeric">Total</th><th className="numeric">Received</th>
                    <th className="numeric">Buyer owes</th><th className="numeric">I owe suppliers</th><th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {data.items.map((sale) => (
                    <tr key={sale.id}>
                      <td><Link href={`/sales/${sale.id}`} className="strong">{sale.sale_number}</Link><div className="meta">{day(sale.sold_on)}</div></td>
                      <td>{sale.buyer_name}<div className="meta">{phone(sale.buyer_phone)}</div></td>
                      <td className="numeric money">{tzs(sale.total_amount)}</td>
                      <td className="numeric">{tzs(sale.received_amount)}</td>
                      <td className="numeric money">{tzs(sale.balance)}</td>
                      <td className="numeric">{tzs(sale.supplier_balance)}</td>
                      <td>
                        {sale.status === 'cancelled' ? <Status>Cancelled</Status>
                          : Number(sale.balance) > 0 ? <Status tone="warning">Owes</Status> : <Status tone="positive">Paid</Status>}
                      </td>
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
