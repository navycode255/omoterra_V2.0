import { Sidebar } from '@/components/sidebar';
import Image from 'next/image';
import { Icons } from '@/components/icons';
import { get } from '@/lib/api';
import { requireSession } from '@/lib/session';
import type { Summary } from '@/lib/types';

export default async function OpsLayout({ children }: { children: React.ReactNode }) {
  await requireSession();
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
        <div className="operator-profile">
          <span className="operator-avatar">AO</span>
          <span><strong>Admin</strong><small>Operations Team</small></span>
          <Icons.chevronDown size={18}/>
        </div>
      </header>
      <Sidebar counts={counts} />
      <div className="main">{children}</div>
    </div>
  );
}
