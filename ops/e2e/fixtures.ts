import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import path from 'node:path';
import { test as base, expect, type BrowserContext } from '@playwright/test';

// Shared helpers for the e2e suite. The database is emptied and an admin
// operator signed in by e2e/harness.py; data the screens show is recorded
// through the real backend API, the same way the dashboard does.

const harness = path.join(__dirname, 'harness.py');
const apiUrl = () => process.env.OMOTERRA_E2E_API_URL!;
const opsToken = () => process.env.OMOTERRA_E2E_OPS_TOKEN!;

function runHarness(...args: string[]) {
  const output = execFileSync(process.env.OMOTERRA_E2E_PYTHON!, [harness, ...args], { encoding: 'utf8' });
  return JSON.parse(output.trim().split('\n').pop()!);
}

export type Seeded = { operator_id: string; operator_token: string; debts?: { name: string; status: string }[] };

/** Empty every table and sign in one admin operator (plus the scenario's rows). */
export function seed(scenario: 'operator' | 'debts'): Seeded {
  return runHarness('seed', scenario);
}

/** A supplier-portal session token for an existing user. */
export function memberSession(userId: string): string {
  return runHarness('member', userId).member_token;
}

/** Calls the backend's /ops API as the seeded operator. */
export function opsApi(operatorToken: string) {
  async function call<T>(method: string, route: string, body?: unknown): Promise<T> {
    const response = await fetch(apiUrl() + route, {
      method,
      headers: {
        'X-Ops-Token': opsToken(), 'X-Operator-Session': operatorToken,
        'Idempotency-Key': randomUUID(), 'Content-Type': 'application/json',
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await response.text();
    if (!response.ok) throw new Error(`${method} ${route} -> ${response.status}: ${text}`);
    return JSON.parse(text) as T;
  }
  return {
    get: <T>(route: string) => call<T>('GET', route),
    post: <T>(route: string, body: unknown) => call<T>('POST', route, body),
  };
}

async function setCookie(context: BrowserContext, name: string, value: string) {
  const { baseURL } = test.info().project.use;
  await context.addCookies([{ name, value, url: baseURL!, httpOnly: true, sameSite: 'Lax' }]);
}

export const signInOperator = (context: BrowserContext, token: string) => setCookie(context, 'omoterra_operator', token);
export const signInMember = (context: BrowserContext, token: string) => setCookie(context, 'omoterra_member', token);

/** Today on Omoterra's clock (EAT), as the backend validates dates. */
export function businessToday() {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Dar_es_Salaam' }).format(new Date());
}

/** "TZS 1,234" the way lib/format.ts shows whole amounts. */
export function tzs(amount: number) {
  return `TZS ${amount.toLocaleString('en-US', { maximumFractionDigits: 2 })}`;
}

export const test = base;
export { expect };
