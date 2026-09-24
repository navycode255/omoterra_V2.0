import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ActionForm } from '@/components/form';
import { Card, Definition, PageHeader, Status } from '@/components/ui';
import { updateOpportunity } from '@/lib/actions';
import { get } from '@/lib/api';
import { date, reference, titleCase } from '@/lib/format';
import type { BusinessOpportunity, BuyerDetail, BusinessStatus } from '@/lib/types';

const PIPELINE: BusinessStatus[] = [
  'new',
  'contacted',
  'interested',
  'setup_in_progress',
  'converted',
  'closed',
];

export default async function OpportunityDetail({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const rows = await get<BusinessOpportunity[]>('/ops/business-opportunities');
  const opportunity = rows.find((row) => row.id === id);
  if (!opportunity) notFound();

  const buyer = await get<BuyerDetail>(`/ops/buyers/${opportunity.buyer_id}`);

  return (
    <>
      <div className="topbar">
        <PageHeader
          title={`${titleCase(opportunity.business_type)} · ${reference(opportunity.id, 'BO')}`}
          subtitle={`${opportunity.area} · target start ${date(opportunity.target_start_date)}`}
        />
        <Status tone={opportunity.status === 'converted' ? 'positive' : 'neutral'}>
          {titleCase(opportunity.status)}
        </Status>
      </div>
      <div className="workspace">
        <div className="grid-2" style={{ alignItems: 'start' }}>
          <div className="stack">
            <Card title="Request">
              <Definition
                items={[
                  ['Business type', titleCase(opportunity.business_type)],
                  ['Area', opportunity.area],
                  ['Budget range', opportunity.budget_range],
                  ['Has premises', opportunity.has_premises ? 'Yes' : 'No'],
                  ['Wants stock', opportunity.wants_stock ? 'Yes' : 'No'],
                  ['Target start', date(opportunity.target_start_date)],
                ]}
              />
            </Card>

            <Card title="Buyer">
              <Definition
                items={[
                  ['Name', buyer.name || '—'],
                  ['Phone', buyer.phone],
                  ['Type', buyer.buyer_type ? titleCase(buyer.buyer_type) : '—'],
                  ['Region', buyer.region || '—'],
                  ['Orders placed', String(buyer.orders.length)],
                ]}
              />
              <Link href={`/buyers/${buyer.id}`} className="small" style={{ color: 'var(--forest)' }}>
                View buyer →
              </Link>
            </Card>
          </div>

          <Card title="Follow-up">
            <ActionForm action={updateOpportunity} label="Save" hidden={{ id: opportunity.id }}>
              <div className="field">
                <label htmlFor="status">Status</label>
                <select id="status" name="status" className="input" defaultValue={opportunity.status}>
                  {PIPELINE.map((status) => (
                    <option key={status} value={status}>
                      {titleCase(status)}
                    </option>
                  ))}
                </select>
              </div>
              <div className="field">
                <label htmlFor="internal_notes">Internal notes</label>
                <textarea
                  id="internal_notes"
                  name="internal_notes"
                  className="input"
                  rows={8}
                  defaultValue={opportunity.internal_notes}
                  placeholder="Call outcomes, next steps, who is following up…"
                />
              </div>
            </ActionForm>
          </Card>
        </div>
      </div>
    </>
  );
}
