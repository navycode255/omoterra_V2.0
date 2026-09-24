import { Sidebar } from '@/components/sidebar';
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
      <Sidebar counts={counts} />
      <div className="main">{children}</div>
    </div>
  );
}
