import { Sidebar } from '@/components/sidebar';
import { OpsAlerts } from '@/components/ops-alerts';
import Image from 'next/image';
import { Icons } from '@/components/icons';
import { get } from '@/lib/api';
import { requireSession } from '@/lib/session';
import type { Summary } from '@/lib/types';

export default async function OpsLayout({ children }: { children: React.ReactNode }) {
  const operator = await requireSession();
  const initials = operator.name.split(/\s+/).filter(Boolean).slice(0, 2).map((word) => word[0]!.toUpperCase()).join('');
  let counts: Record<string, number> = {};
  try {
    counts = (await get<Summary>('/ops/summary')).attention;
  } catch {
    // The sidebar badges are advisory. A backend outage is surfaced by the page
    // itself rather than blocking navigation entirely.
  }
  return (
    <div className="shell">
      <header className="ops-header">
        <Image src="/images/marketing/logo.png" width={204} height={61} alt="Omoterra" priority />
        <div className="ops-header-right">
        <OpsAlerts />
        <div className="operator-profile">
          <span className="operator-avatar">{initials}</span>
          <span><strong>{operator.name}</strong><small>{operator.role === 'admin' ? 'Admin' : 'Operations staff'}</small></span>
          <Icons.chevronDown size={18}/>
        </div>
        </div>
      </header>
      <Sidebar counts={counts} admin={operator.role === 'admin'} />
      <div className="main">{children}</div>
    </div>
  );
}
