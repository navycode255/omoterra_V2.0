import { existsSync } from 'node:fs';
import path from 'node:path';
import { defineConfig, devices } from '@playwright/test';

// The e2e suite (ops/e2e, see e2e/README.md) runs the real backend against a
// fresh local database and a production build of this dashboard.
const apiPort = process.env.OMOTERRA_E2E_API_PORT ?? '18765';
const webPort = process.env.OMOTERRA_E2E_WEB_PORT ?? '13765';
const opsToken = process.env.OMOTERRA_E2E_OPS_TOKEN ?? 'e2e-operations-token';
const venvPython = path.join(__dirname, '..', 'backend', '.venv', 'bin', 'python');
export const python = process.env.OMOTERRA_E2E_PYTHON ?? (existsSync(venvPython) ? venvPython : 'python3');
const apiUrl = `http://127.0.0.1:${apiPort}/api/v1`;
// OMOTERRA_E2E_SKIP_BUILD=1 reuses the last `next build` (faster reruns).
const build = process.env.OMOTERRA_E2E_SKIP_BUILD ? '' : 'npx next build && ';

process.env.OMOTERRA_E2E_API_URL = apiUrl;
process.env.OMOTERRA_E2E_OPS_TOKEN = opsToken;
process.env.OMOTERRA_E2E_PYTHON = python;

export default defineConfig({
  testDir: './e2e',
  // Every test empties the shared database first, so they run one at a time.
  workers: 1,
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: 0,
  timeout: 90_000,
  reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : 'list',
  use: {
    baseURL: `http://127.0.0.1:${webPort}`,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: [
    {
      name: 'backend',
      command: `"${python}" e2e/harness.py serve`,
      url: `http://127.0.0.1:${apiPort}/health`,
      env: { OMOTERRA_E2E_API_PORT: apiPort, OMOTERRA_E2E_OPS_TOKEN: opsToken },
      reuseExistingServer: false,
      timeout: 120_000,
      stdout: 'pipe',
    },
    {
      name: 'ops',
      command: `${build}npx next start -p ${webPort} -H 127.0.0.1`,
      url: `http://127.0.0.1:${webPort}/sign-in`,
      // Set here, so they win over anything in .env.local (a real backend).
      env: { OMOTERRA_API_URL: apiUrl, OMOTERRA_OPS_TOKEN: opsToken, NEXT_TELEMETRY_DISABLED: '1' },
      reuseExistingServer: false,
      timeout: 600_000,
    },
  ],
});
