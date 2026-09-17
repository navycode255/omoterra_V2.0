import Link from 'next/link';
import { Empty, Notice, PageHeader } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { titleCase } from '@/lib/format';
import type { BuyerRow } from '@/lib/types';

export const metadata = { title: 'Buyers · Omoterra Operations' };

export default async function Buyers() {
  let buyers: BuyerRow[];
  try {
    buyers = await get<BuyerRow[]>('/ops/buyers');
  } catch (error) {
    return (
      <>
        <div className="topbar">
          <PageHeader title="Buyers" />
        </div>
        <div className="workspace">
          <Notice tone="error">
            {error instanceof ApiError ? error.message : 'Buyers could not be loaded.'}
          </Notice>
        </div>
      </>
    );
  }

  return (
    <>
      <div className="topbar">
        <PageHeader
          title="Buyers"
          subtitle="Buyer records for delivery scheduling and support. Never shared with suppliers."
        />
      </div>
      <div className="workspace">
        <div className="table-wrap">
          {buyers.length === 0 ? (
            <Empty>No buyers registered yet.</Empty>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Phone</th>
                  <th>Type</th>
                  <th>Region</th>
                  <th className="numeric">Orders</th>
                  <th className="numeric">Requests</th>
                </tr>
              </thead>
              <tbody>
                {buyers.map((buyer) => (
                  <tr key={buyer.id}>
                    <td>
                      <Link href={`/buyers/${buyer.id}`} className="strong">
                        {buyer.name || 'Unnamed buyer'}
                      </Link>
                    </td>
                    <td className="small">{buyer.phone}</td>
                    <td className="small">{buyer.buyer_type ? titleCase(buyer.buyer_type) : '—'}</td>
                    <td className="small">{buyer.region || '—'}</td>
                    <td className="numeric">{buyer.order_count}</td>
                    <td className="numeric">{buyer.request_count}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </>
  );
}
