'use client';

import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import { useEffect, useRef, useState, useTransition } from 'react';
import { Icons } from '@/components/icons';

// Dates are plain calendar days (YYYY-MM-DD) in Tanzanian time; the backend
// interprets them the same way.
function iso(day: Date) {
  return `${day.getFullYear()}-${String(day.getMonth() + 1).padStart(2, '0')}-${String(day.getDate()).padStart(2, '0')}`;
}

function parse(value: string) {
  const [year, month, day] = value.split('-').map(Number);
  return new Date(year, month - 1, day);
}

function presets(today: Date) {
  const shift = (days: number) => new Date(today.getFullYear(), today.getMonth(), today.getDate() - days);
  return [
    { label: 'Today', start: today, end: today },
    { label: 'Last 7 days', start: shift(6), end: today },
    { label: 'This month', start: new Date(today.getFullYear(), today.getMonth(), 1), end: today },
    { label: 'Last month', start: new Date(today.getFullYear(), today.getMonth() - 1, 1), end: new Date(today.getFullYear(), today.getMonth(), 0) },
    { label: 'Last 30 days', start: shift(29), end: today },
    { label: 'This year', start: new Date(today.getFullYear(), 0, 1), end: today },
  ];
}

export function rangeLabel(start: string, end: string) {
  const a = parse(start);
  const b = parse(end);
  const day = (d: Date) => d.getDate();
  const month = (d: Date) => d.toLocaleDateString('en-GB', { month: 'short' });
  if (start === end) return `${day(a)} ${month(a)} ${a.getFullYear()}`;
  if (a.getFullYear() !== b.getFullYear()) return `${day(a)} ${month(a)} ${a.getFullYear()} – ${day(b)} ${month(b)} ${b.getFullYear()}`;
  if (a.getMonth() !== b.getMonth()) return `${day(a)} ${month(a)} – ${day(b)} ${month(b)} ${b.getFullYear()}`;
  return `${day(a)} – ${day(b)} ${month(b)} ${b.getFullYear()}`;
}

// The range picker and year select each change one part of the query. A change
// made while another is still loading must build on it, not on the URL the
// page was rendered with, so the latest requested query is kept here until
// the page has caught up with it.
let requested: string | null = null;

function useQueryUpdate() {
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();
  const [pending, startTransition] = useTransition();
  const current = params.toString();
  useEffect(() => { if (requested === current) requested = null; }, [current]);
  const update = (values: Record<string, string>) => {
    const next = new URLSearchParams(requested ?? current);
    for (const [key, value] of Object.entries(values)) next.set(key, value);
    requested = next.toString();
    startTransition(() => router.replace(`${pathname}?${requested}`, { scroll: false }));
  };
  return { update, pending };
}

export function DateRangePicker({ start, end, today }: { start: string; end: string; today: string }) {
  const [open, setOpen] = useState(false);
  const [from, setFrom] = useState(start);
  const [to, setTo] = useState(end);
  const box = useRef<HTMLDivElement>(null);
  const { update, pending } = useQueryUpdate();

  useEffect(() => {
    if (!open) return;
    const close = (event: MouseEvent | KeyboardEvent) => {
      if (event instanceof KeyboardEvent ? event.key === 'Escape' : !box.current?.contains(event.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', close);
    document.addEventListener('keydown', close);
    return () => { document.removeEventListener('mousedown', close); document.removeEventListener('keydown', close); };
  }, [open]);

  const choose = (a: string, b: string) => { setOpen(false); update({ from: a, to: b }); };
  const toggle = () => { setFrom(start); setTo(end); setOpen((value) => !value); };

  return <div className="range-picker" ref={box}>
    <button type="button" className="range-button" aria-haspopup="dialog" aria-expanded={open} onClick={toggle} data-pending={pending}>
      <Icons.calendar size={18}/><span>{rangeLabel(start, end)}</span><Icons.chevronDown size={18}/>
    </button>
    {open && <div className="range-popover" role="dialog" aria-label="Choose a date range">
      <div className="range-presets">{presets(parse(today)).map((preset) => {
        const a = iso(preset.start);
        const b = iso(preset.end);
        return <button key={preset.label} type="button" data-active={a === start && b === end} onClick={() => choose(a, b)}>{preset.label}</button>;
      })}</div>
      <form className="range-custom" onSubmit={(event) => { event.preventDefault(); if (from && to && from <= to) choose(from, to); }}>
        <label>From<input type="date" value={from} max={to || today} onChange={(event) => setFrom(event.target.value)} required/></label>
        <label>To<input type="date" value={to} min={from} max={today} onChange={(event) => setTo(event.target.value)} required/></label>
        <button type="submit" className="button">Apply</button>
      </form>
    </div>}
  </div>;
}

export function YearSelect({ year, years }: { year: number; years: number[] }) {
  const { update, pending } = useQueryUpdate();
  const current = years[0];
  return <label className="year-select" data-pending={pending}>
    <span className="sr-only">Supply trend year</span>
    <select value={year} onChange={(event) => update({ year: event.target.value })}>
      {years.map((option) => <option key={option} value={option}>{option === current ? 'This year' : option === current - 1 ? 'Last year' : option}</option>)}
    </select>
    <Icons.chevronDown size={16}/>
  </label>;
}
