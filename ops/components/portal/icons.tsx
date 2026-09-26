const stroke = { fill: 'none', stroke: 'currentColor', strokeWidth: 1.8, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const };

const paths = {
  home: <><path {...stroke} d="M3.5 10.5 12 3.8l8.5 6.7V20a.5.5 0 0 1-.5.5h-5v-6h-6v6H4a.5.5 0 0 1-.5-.5z" /></>,
  user: <><circle {...stroke} cx="12" cy="8" r="3.6" /><path {...stroke} d="M4.8 20.2a7.2 7.2 0 0 1 14.4 0" /></>,
  box: <><path {...stroke} d="m12 3 8 4.2v9.6L12 21l-8-4.2V7.2z" /><path {...stroke} d="m4.3 7.3 7.7 4.2 7.7-4.2M12 11.5V21" /></>,
  cart: <><path {...stroke} d="M2.5 3.5h2.2l2.4 11h11.2l2.2-7.8H6.1" /><circle {...stroke} cx="9" cy="19" r="1.5" /><circle {...stroke} cx="17.5" cy="19" r="1.5" /></>,
  orders: <><path {...stroke} d="M6.5 4.5h11v16h-11z" /><path {...stroke} d="M9.5 3h5v3h-5zM9 10h6M9 13.5h6M9 17h4" /></>,
  coins: <><ellipse {...stroke} cx="10" cy="6.5" rx="6" ry="2.7" /><path {...stroke} d="M4 6.5v4c0 1.5 2.7 2.7 6 2.7s6-1.2 6-2.7v-4M4 10.5v4c0 1.5 2.7 2.7 6 2.7M16.5 12.4c2.1.3 3.5 1.1 3.5 2.1v3.5c0 1.5-2.7 2.7-6 2.7-2 0-3.8-.5-4.9-1.2" /></>,
  help: <><circle {...stroke} cx="12" cy="12" r="8.5" /><path {...stroke} d="M9.6 9.4a2.5 2.5 0 1 1 3.4 2.3c-.6.3-1 .8-1 1.5v.4M12 16.8h.01" /></>,
  bell: <><path {...stroke} d="M6 16.5V11a6 6 0 0 1 12 0v5.5l1.5 1.8h-15z" /><path {...stroke} d="M10 20.5a2.2 2.2 0 0 0 4 0" /></>,
  chevron: <><path {...stroke} d="m7 10 5 5 5-5" /></>,
  clock: <><circle {...stroke} cx="12" cy="12" r="8.5" /><path {...stroke} d="M12 7.5V12l3 2" /></>,
  check: <><path {...stroke} d="m6 12.5 4 4 8-9" /></>,
  alert: <><circle {...stroke} cx="12" cy="12" r="8.5" /><path {...stroke} d="M12 7.5v5.5M12 16.5h.01" /></>,
  lock: <><rect {...stroke} x="5.5" y="10.5" width="13" height="9.5" rx="2" /><path {...stroke} d="M8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5" /></>,
  pin: <><path {...stroke} d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11z" /><circle {...stroke} cx="12" cy="10" r="2.4" /></>,
  farm: <><path {...stroke} d="M3.5 20.5V9.8L12 3.5l8.5 6.3v10.7z" /><path {...stroke} d="M8 20.5v-6.8h8v6.8M8 13.7l8 6.8M16 13.7l-8 6.8" /></>,
  leaf: <><path {...stroke} d="M20.5 3.5C11 3.5 5 5.8 5 12.1c0 3 2.1 5.2 5.1 5.2 6.2 0 8.1-7.2 10.4-13.8Z" /><path {...stroke} d="M3 21c3-5.4 7.3-8.6 13.2-11.4" /></>,
  phone: <><path {...stroke} d="M5 4h3.5l1.7 4.3-2.2 1.4a11 11 0 0 0 6.3 6.3l1.4-2.2L20 15.5V19a1 1 0 0 1-1 1A16 16 0 0 1 4 5a1 1 0 0 1 1-1z" /></>,
  chat: <><path {...stroke} d="M4 5.5h16v11H9l-5 4z" /></>,
};

export type IconName = keyof typeof paths;

export function Icon({ name }: { name: IconName }) {
  return <svg viewBox="0 0 24 24" aria-hidden="true" className="portal-icon">{paths[name]}</svg>;
}
