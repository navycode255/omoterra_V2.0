import { Empty, Notice, PageHeader } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { dateTime } from '@/lib/format';
import { requireAdmin } from '@/lib/session';
import type { AuditEntry } from '@/lib/types';

export const metadata = { title: 'Activity · Omoterra Operations' };

// Turns the recorded request into a readable action, e.g.
// "PATCH /ops/suppliers/<id>/status" → "Changed supplier status".
const VERBS: [RegExp, string][] = [
  [/^\/ops\/listings\/[^/]+\/approve$/, 'Approved stock'],
  [/^\/ops\/listings\/[^/]+\/status$/, 'Paused or rejected stock'],
  [/^\/ops\/orders\/[^/]+\/progress$/, 'Moved an order forward'],
  [/^\/ops\/orders\/[^/]+\/reconcile$/, 'Recorded a buyer payment'],
  [/^\/ops\/orders\/[^/]+\/photos$/, 'Added a collection photo'],
  [/^\/ops\/settlements\/[^/]+\/pay$/, 'Paid a supplier'],
  [/^\/ops\/suppliers\/[^/]+\/status$/, 'Changed supplier status'],
  [/^\/ops\/suppliers\/[^/]+\/verification$/, 'Updated supplier verification'],
  [/^\/ops\/suppliers\/[^/]+\/(photos|video)/, 'Changed supplier media'],
  [/^\/ops\/suppliers(\/[^/]+)?$/, 'Added or edited a supplier'],
  [/^\/ops\/offers\/[^/]+\/review$/, 'Reviewed a supply offer'],
  [/^\/ops\/requirements/, 'Worked on a buyer requirement'],
  [/^\/ops\/allocations/, 'Changed a supply allocation'],
  [/^\/ops\/requests/, 'Worked on a supply request'],
  [/^\/ops\/batches\/[^/]+\/verify$/, 'Verified a production batch'],
  [/^\/ops\/buyer-crm/, 'Edited a buyer record'],
  [/^\/ops\/business-opportunities/, 'Updated a business opportunity'],
  [/^\/ops\/operators/, 'Changed staff'],
  [/^\/ops\/auth\/logout$/, 'Signed out'],
];

function describe(entry: AuditEntry) {
  return VERBS.find(([pattern]) => pattern.test(entry.path))?.[1] ?? `${entry.method} ${entry.path}`;
}

export default async function Activity() {
  await requireAdmin();
  let entries: AuditEntry[];
  try { entries = await get<AuditEntry[]>('/ops/audit?limit=200'); }
  catch (error) { return <><div className="topbar"><PageHeader title="Activity" /></div><div className="workspace"><Notice tone="error">{error instanceof ApiError ? error.message : 'Activity could not be loaded.'}</Notice></div></>; }
  return <>
    <div className="topbar"><PageHeader title="Activity" subtitle="Every change made in operations, newest first, with who made it." /></div>
    <div className="workspace">
      <div className="table-wrap">{entries.length === 0 ? <Empty>No changes recorded yet.</Empty> : <table>
        <thead><tr><th>When</th><th>Who</th><th>What</th><th>Record</th></tr></thead>
        <tbody>{entries.map((entry) => <tr key={entry.id}>
          <td>{dateTime(entry.at)}</td>
          <td className="strong">{entry.operator_name}</td>
          <td>{describe(entry)}</td>
          <td className="meta">{entry.path}</td>
        </tr>)}</tbody>
      </table>}</div>
    </div>
  </>;
}
