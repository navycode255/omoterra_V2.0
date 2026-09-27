'use client';

import { useRouter } from 'next/navigation';
import { useEffect } from 'react';

// Re-reads the page's data every minute while it is on screen, so order and
// payout changes made by Omoterra staff appear without a manual reload.
export function LiveRefresh({ seconds = 60 }: { seconds?: number }) {
  const router = useRouter();
  useEffect(() => {
    const tick = () => { if (document.visibilityState === 'visible') router.refresh(); };
    const timer = window.setInterval(tick, seconds * 1000);
    document.addEventListener('visibilitychange', tick);
    return () => { window.clearInterval(timer); document.removeEventListener('visibilitychange', tick); };
  }, [router, seconds]);
  return null;
}
