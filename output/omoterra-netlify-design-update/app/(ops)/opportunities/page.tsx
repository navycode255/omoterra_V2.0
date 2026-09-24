import Link from 'next/link';
import { Empty, Notice, PageHeader, Status } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { date, reference, titleCase } from '@/lib/format';
import type { BusinessOpportunity, BusinessStatus } from '@/lib/types';

export const metadata = { title: 'Business Opportunities · Omoterra Operations' };

const PIPELINE: BusinessStatus[] = [
  'new',
  'contacted',
  'interested',
  'setup_in_progress',
  'converted',
  'closed',
];

function tone(status: BusinessStatus) {
  if (status === 'converted') return 'positive' as const;
  if (status === 'closed') return 'neutral' as const;
  if (status === 'new') return 'warning' as const;
  return 'neutral' as const;
}

export default async function Opportunities() {
  let rows: BusinessOpportunity[];
  try {
    rows = await get<BusinessOpportunity[]>('/ops/business-opportunities');
  } catch (error) {
    return (
      <>
        <div className="topbar">
          <PageHeader title="Business Opportunities" />
        </div>
        <div className="workspace">
          <Notice tone="error">
            {error instanceof ApiError ? error.message : 'Opportunities could not be loaded.'}
          </Notice>
        </div>
      </>
    );
  }

  const counts = Object.fromEntries(
    PIPELINE.map((status) => [status, rows.filter((r) => r.status === status).length]),
  );

  return (
    <>
      <div className="topbar">
        <PageHeader
          title="Business Opportunities"
          subtitle="Setup-plan requests from buyers who want help starting a business."
        />
      </div>
      <div className="workspace">
        <div className="stat-band" style={{ gridTemplateColumns: `repeat(${PIPELINE.length}, minmax(0, 1fr))` }}>
          {PIPELINE.map((status) => (
            <div key={status} className="stat">
              <div className="stat-label">{titleCase(status)}</div>
              <div className="stat-value numeric">{counts[status]}</div>
            </div>
          ))}
        </div>

        <div className="table-wrap">
          {rows.length === 0 ? (
            <Empty>No setup-plan requests yet.</Empty>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>Reference</th>
                  <th>Business type</th>
                  <th>Area</th>
                  <th>Budget</th>
                  <th>Premises</th>
                  <th>Wants stock</th>
                  <th>Target start</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((row) => (
                  <tr key={row.id}>
                    <td>
                      <Link href={`/opportunities/${row.id}`} className="strong">
                        {reference(row.id, 'BO')}
                      </Link>
                    </td>
                    <td>{titleCase(row.business_type)}</td>
                    <td className="small">{row.area}</td>
                    <td className="small">{row.budget_range}</td>
                    <td className="small">{row.has_premises ? 'Yes' : 'No'}</td>
                    <td className="small">{row.wants_stock ? 'Yes' : 'No'}</td>
                    <td className="small">{date(row.target_start_date)}</td>
                    <td>
                      <Status tone={tone(row.status)}>{titleCase(row.status)}</Status>
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
