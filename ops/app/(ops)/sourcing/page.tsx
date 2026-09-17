import Link from 'next/link';
import { Empty, Notice, PageHeader, Status } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { category, date, quantity, reference, titleCase } from '@/lib/format';
import type { SourcingRequest } from '@/lib/types';

export const metadata = { title: 'Sourcing · Omoterra Operations' };

function tone(status: string) {
  if (status === 'converted' || status === 'confirmed') return 'positive' as const;
  if (status === 'cancelled') return 'error' as const;
  if (status === 'submitted') return 'warning' as const;
  return 'neutral' as const;
}

export default async function Sourcing() {
  let requests: SourcingRequest[];
  try {
    requests = await get<SourcingRequest[]>('/ops/requests');
  } catch (error) {
    return (
      <>
        <div className="topbar">
          <PageHeader title="Sourcing" />
        </div>
        <div className="workspace">
          <Notice tone="error">
            {error instanceof ApiError ? error.message : 'Sourcing requests could not be loaded.'}
          </Notice>
        </div>
      </>
    );
  }

  return (
    <>
      <div className="topbar">
        <PageHeader
          title="Sourcing"
          subtitle="Buyer requests for supply we do not currently hold. Matching is coordinated manually."
        />
      </div>
      <div className="workspace">
        <div className="table-wrap">
          {requests.length === 0 ? (
            <Empty>No sourcing requests yet.</Empty>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>Reference</th>
                  <th>Requested</th>
                  <th className="numeric">Quantity</th>
                  <th className="numeric">Secured</th>
                  <th>Needed by</th>
                  <th>Area</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {requests.map((request) => (
                  <tr key={request.id}>
                    <td>
                      <Link href={`/sourcing/${request.id}`} className="strong">
                        {reference(request.id, 'SR')}
                      </Link>
                      <div className="meta">{date(request.created_at)}</div>
                    </td>
                    <td>
                      {category(request.category)}
                      {request.weight_or_size_requirement && (
                        <div className="meta">{request.weight_or_size_requirement}</div>
                      )}
                    </td>
                    <td className="numeric">
                      {quantity(request.quantity)} {request.unit_type}
                    </td>
                    <td className="numeric">{quantity(request.quantity_secured)}</td>
                    <td className="small">{date(request.needed_by_date)}</td>
                    <td className="small">{request.delivery_area}</td>
                    <td>
                      <Status tone={tone(request.status)}>{titleCase(request.status)}</Status>
                    </td>
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
