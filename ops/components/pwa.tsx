'use client';

import { useEffect } from 'react';

// Registers the service worker that makes the app installable and shows an
// offline notice. Skipped in development so it never serves stale dev chunks.
export function ServiceWorker() {
  useEffect(() => {
    if (process.env.NODE_ENV !== 'production' || !('serviceWorker' in navigator)) return;
    navigator.serviceWorker.register('/sw.js', { scope: '/', updateViaCache: 'none' }).catch(() => {});
  }, []);
  return null;
}
