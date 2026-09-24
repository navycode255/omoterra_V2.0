'use client';

import { useRouter } from 'next/navigation';

export function RetryButton() {
  const router = useRouter();
  return (
    <button className="error-retry" type="button" onClick={() => router.refresh()}>
      Try again
    </button>
  );
}
