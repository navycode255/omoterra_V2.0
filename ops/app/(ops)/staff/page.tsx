import { ActionForm } from '@/components/form';
import { Empty, Notice, PageHeader, Status } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { dateTime, phone } from '@/lib/format';
import { addOperator, updateOperator } from '@/lib/actions';
import { requireAdmin } from '@/lib/session';
import type { Operator } from '@/lib/types';

export const metadata = { title: 'Staff · Omoterra Operations' };

export default async function Staff() {
  const me = await requireAdmin();
  let operators: Operator[];
  try { operators = await get<Operator[]>('/ops/operators'); }
  catch (error) { return <><div className="topbar"><PageHeader title="Staff" /></div><div className="workspace"><Notice tone="error">{error instanceof ApiError ? error.message : 'Staff could not be loaded.'}</Notice></div></>; }
  return <>
    <div className="topbar"><PageHeader title="Staff" subtitle="Everyone who can sign in to operations. Each person signs in with their own phone, and every change they make is recorded under their name." /></div>
    <div className="workspace">
      <div className="grid-2" style={{ alignItems: 'start' }}>
        <div className="table-wrap">{operators.length === 0 ? <Empty>No staff yet.</Empty> : <table>
          <thead><tr><th>Name</th><th>Role</th><th>Last sign-in</th><th>Status</th><th /></tr></thead>
          <tbody>{operators.map((operator) => <tr key={operator.id}>
            <td><span className="strong">{operator.name}{operator.id === me.id ? ' (you)' : ''}</span><div className="meta">{phone(operator.phone)}</div></td>
            <td>{operator.role === 'admin' ? 'Admin' : 'Staff'}</td>
            <td>{operator.last_login_at ? dateTime(operator.last_login_at) : 'Never'}</td>
            <td>{operator.active ? <Status tone="positive">Active</Status> : <Status>Removed</Status>}</td>
            <td><div className="row">
              {operator.active && <ActionForm action={updateOperator} layout="row" variant="secondary"
                label={operator.role === 'admin' ? 'Make staff' : 'Make admin'}
                hidden={{ id: operator.id, role: operator.role === 'admin' ? 'staff' : 'admin' }} />}
              <ActionForm action={updateOperator} layout="row" variant={operator.active ? 'danger' : 'secondary'}
                label={operator.active ? 'Remove' : 'Restore'}
                confirm={operator.active ? `Remove ${operator.name}? They will be signed out immediately.` : undefined}
                hidden={{ id: operator.id, active: operator.active ? 'false' : 'true' }} />
            </div></td>
          </tr>)}</tbody>
        </table>}</div>
        <section className="card"><h3 style={{ marginBottom: 'var(--s4)' }}>Add a staff member</h3>
          <ActionForm action={addOperator} label="Add staff member">
            <div className="field"><label htmlFor="name">Full name</label><input className="input" id="name" name="name" required minLength={2} /></div>
            <div className="field"><label htmlFor="phone">Phone number</label><input className="input" id="phone" name="phone" inputMode="tel" placeholder="0712 345 678" required /></div>
            <div className="field"><label htmlFor="role">Role</label><select className="input" id="role" name="role">
              <option value="staff">Staff: approvals, orders and suppliers</option>
              <option value="admin">Admin: also payouts and staff</option>
            </select></div>
            <p className="meta">They sign in at this dashboard with a code sent to this phone.</p>
          </ActionForm>
        </section>
      </div>
    </div>
  </>;
}
