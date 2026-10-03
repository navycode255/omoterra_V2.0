'use client';

import { useEffect } from 'react';

const PHONE = '(max-width: 720px)';

// On phones every operations table shows a row number, an expand button and
// two columns: the first two, or the ones a table names in
// data-phone-show="1 3" (1-based); the button opens the rest of that row as a list of
// labelled values (styles: "Tables on phones" in globals.css). Tables with
// form fields in their rows keep sideways scrolling so the fields stay usable.
// Only attributes are added here, never elements, so React's own rendering
// of the tables is left alone.
export function MobileTables() {
  useEffect(() => {
    const phone = window.matchMedia(PHONE);
    let frame = 0;

    function prepare() {
      frame = 0;
      const query = new URLSearchParams(location.search);
      const page = Math.max(1, Number(query.get('page')) || 1);
      const perPage = Number(query.get('page_size')) || 10;
      for (const table of document.querySelectorAll<HTMLTableElement>('.shell table:not([data-phone-native])')) {
        const heads = [...table.querySelectorAll('thead th')].map((th) => th.textContent?.trim() ?? '');
        const body = table.tBodies[0];
        if (!body || heads.length < 3 || body.querySelector('input, select, textarea')) continue;
        // A table whose own styles already turn rows into cards on phones
        // (expenses) is left as it is.
        if (!table.hasAttribute('data-phone-table') && phone.matches && body.rows[0]
          && getComputedStyle(body.rows[0]).display !== 'table-row') continue;
        if (!table.hasAttribute('data-phone-table')) table.setAttribute('data-phone-table', '');
        const show = (table.dataset.phoneShow ?? '1 2').split(/\s+/).map(Number);
        const mark = (cells: HTMLCollectionOf<HTMLTableCellElement>) => [...cells].forEach((cell, index) => {
          const hidden = !show.includes(index + 1);
          if (cell.hasAttribute('data-phone-hidden') !== hidden) cell.toggleAttribute('data-phone-hidden', hidden);
        });
        for (const head of table.tHead?.rows ?? []) {
          mark(head.cells);
          [...head.cells].forEach((cell, index) => cell.toggleAttribute('data-phone-first', index === show[0] - 1));
        }
        // Numbering continues across pages (page 2 starts at 11).
        body.style.counterReset = `phone-row ${(page - 1) * perPage}`;
        for (const row of body.rows) {
          if (row.cells.length < 3) continue;
          [...row.cells].forEach((cell, index) => {
            if (heads[index] && cell.getAttribute('data-label') !== heads[index]) cell.setAttribute('data-label', heads[index]);
          });
          mark(row.cells);
          // The expand button sits in the first shown cell.
          const first = row.cells[show[0] - 1] ?? row.cells[0];
          if (!first.hasAttribute('data-phone-toggle')) {
            first.setAttribute('data-phone-toggle', '');
            first.setAttribute('aria-expanded', row.hasAttribute('data-open') ? 'true' : 'false');
          }
        }
      }
    }
    const schedule = () => { if (!frame) frame = requestAnimationFrame(prepare); };

    // The expand button is drawn in the first cell's left gutter.
    function toggle(event: MouseEvent) {
      if (!phone.matches) return;
      const cell = (event.target as Element).closest?.('[data-phone-table] td[data-phone-toggle]');
      if (!cell || (event.target as Element).closest('a, button, summary')) return;
      if (event.clientX - cell.getBoundingClientRect().left > 56) return;
      const row = cell.parentElement!;
      const open = !row.hasAttribute('data-open');
      row.toggleAttribute('data-open', open);
      cell.setAttribute('aria-expanded', String(open));
    }

    prepare();
    const watcher = new MutationObserver(schedule);
    watcher.observe(document.body, { childList: true, subtree: true });
    document.addEventListener('click', toggle);
    return () => { watcher.disconnect(); document.removeEventListener('click', toggle); cancelAnimationFrame(frame); };
  }, []);
  return null;
}
