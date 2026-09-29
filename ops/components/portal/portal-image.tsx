'use client';

import { useState } from 'react';
import { Icon } from './icons';

export function PortalAvatar({ src, alt }: { src: string | null; alt: string }) {
  const [failed, setFailed] = useState(false);
  if (!src || failed) return <Icon name="user" />;
  // eslint-disable-next-line @next/next/no-img-element -- authenticated member media cannot be fetched by the image optimizer
  return <img src={src} alt={alt} onError={() => setFailed(true)} />;
}

export function PortalImage({ src, fallback, alt }: { src: string | null; fallback: string; alt: string }) {
  const [failed, setFailed] = useState(false);
  // eslint-disable-next-line @next/next/no-img-element -- authenticated member media cannot be fetched by the image optimizer
  return <img src={!src || failed ? fallback : src} alt={alt} loading="lazy" onError={() => setFailed(true)} />;
}
