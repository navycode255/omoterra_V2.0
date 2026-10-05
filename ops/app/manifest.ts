import type { MetadataRoute } from 'next';

// Makes Omoterra installable to the home screen (Android, desktop Chrome/Edge,
// and iOS via Share → Add to Home Screen).
export default function manifest(): MetadataRoute.Manifest {
  return {
    id: '/',
    name: 'Omoterra · Real Markets for Real People',
    short_name: 'Omoterra',
    description: 'A trusted livestock marketplace connecting Tanzanian farmers, buyers and reliable delivery.',
    start_url: '/',
    scope: '/',
    display: 'standalone',
    orientation: 'portrait-primary',
    background_color: '#ffffff',
    theme_color: '#0e6f50',
    categories: ['business', 'shopping', 'food'],
    icons: [
      { src: '/icons/icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any' },
      { src: '/icons/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any' },
      { src: '/icons/maskable-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
    ],
    shortcuts: [
      { name: 'Log in', url: '/login', icons: [{ src: '/icons/icon-192.png', sizes: '192x192' }] },
      { name: 'Operations', url: '/sign-in', icons: [{ src: '/icons/icon-192.png', sizes: '192x192' }] },
    ],
  };
}
