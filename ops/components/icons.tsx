import type { SVGProps } from 'react';

type IconProps = SVGProps<SVGSVGElement> & { size?: number };

export function Icon({ size = 20, children, ...props }: IconProps) {
  return <svg viewBox="0 0 24 24" width={size} height={size} fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" {...props}>{children}</svg>;
}

export const Icons = {
  home: (props: IconProps) => <Icon {...props}><path d="m3 11 9-8 9 8"/><path d="M5 10v11h14V10M9 21v-7h6v7"/></Icon>,
  box: (props: IconProps) => <Icon {...props}><path d="m12 3 8 4.5v9L12 21l-8-4.5v-9Z"/><path d="m4.5 7.7 7.5 4.2 7.5-4.2M12 12v9"/></Icon>,
  file: (props: IconProps) => <Icon {...props}><path d="M6 2h8l4 4v16H6z"/><path d="M14 2v5h5M9 12h6M9 16h6"/></Icon>,
  calendar: (props: IconProps) => <Icon {...props}><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M8 3v4M16 3v4M3 10h18M7 14h2M11 14h2M15 14h2M7 18h2M11 18h2"/></Icon>,
  card: (props: IconProps) => <Icon {...props}><rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 9h18M7 15h3"/></Icon>,
  clock: (props: IconProps) => <Icon {...props}><circle cx="12" cy="12" r="9"/><path d="M12 7v6l4 2"/></Icon>,
  chart: (props: IconProps) => <Icon {...props}><path d="M4 20V9M9 17V5M14 20v-8M19 16V3M3 20h18"/></Icon>,
  users: (props: IconProps) => <Icon {...props}><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/></Icon>,
  logout: (props: IconProps) => <Icon {...props}><path d="M10 17l5-5-5-5M15 12H3M14 3h5a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-5"/></Icon>,
  plus: (props: IconProps) => <Icon {...props}><path d="M12 5v14M5 12h14"/></Icon>,
  search: (props: IconProps) => <Icon {...props}><circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/></Icon>,
  checkCircle: (props: IconProps) => <Icon {...props}><circle cx="12" cy="12" r="9"/><path d="m8 12 2.7 2.7L16.5 9"/></Icon>,
  chevron: (props: IconProps) => <Icon {...props}><path d="m9 6 6 6-6 6"/></Icon>,
  chevronDown: (props: IconProps) => <Icon {...props}><path d="m7 9 5 5 5-5"/></Icon>,
  more: (props: IconProps) => <Icon {...props}><circle cx="12" cy="5" r="1" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1" fill="currentColor" stroke="none"/><circle cx="12" cy="19" r="1" fill="currentColor" stroke="none"/></Icon>,
  edit: (props: IconProps) => <Icon {...props}><path d="M12 20h9M16.5 3.5a2.1 2.1 0 0 1 3 3L8 18l-4 1 1-4Z"/></Icon>,
  clipboard: (props: IconProps) => <Icon {...props}><rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4V2h6v2M9 9h6M9 13h6M9 17h4"/></Icon>,
  sprout: (props: IconProps) => <Icon {...props}><path d="M12 21v-9M12 15c-4 0-7-2-7-6 4 0 7 2 7 6ZM12 12c0-4 3-7 7-7 0 4-3 7-7 7Z"/></Icon>,
  pin: (props: IconProps) => <Icon {...props}><path d="M20 10c0 5-8 12-8 12S4 15 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/></Icon>,
  shield: (props: IconProps) => <Icon {...props}><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/><path d="m9 12 2 2 4-4"/></Icon>,
  image: (props: IconProps) => <Icon {...props}><rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="9" r="2"/><path d="m3 17 5-5 4 4 3-3 6 6"/></Icon>,
  cubes: (props: IconProps) => <Icon {...props}><path d="m8 3 4 2-4 2-4-2ZM16 8l4 2-4 2-4-2ZM8 13l4 2-4 2-4-2ZM4 5v5l4 2 4-2V5M12 10v5l4 2 4-2v-5M4 15v4l4 2 4-2v-4"/></Icon>,
  camera: (props: IconProps) => <Icon {...props}><path d="M4 7h4l2-3h4l2 3h4v13H4z"/><circle cx="12" cy="13" r="4"/></Icon>,
};
