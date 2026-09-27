const { chromium } = require('playwright');
const path = require('path');

async function run() {
  const browserURL = 'http://127.0.0.1:9222';
  let browser = await chromium.connectOverCDP(browserURL);
  const page = await browser.contexts()[0].newPage();
  const artifactDir = 'C:\\Users\\Atul1\\.gemini\\antigravity\\brain\\66cbea70-fd6b-47b0-a32c-4681abc67020';

  const INDIA = 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d';
  const AFGHANISTAN = 'e57726de-3796-cfbf-94e0-798888dddd5e';
  const INVALID = '00000000-0000-0000-0000-000000000000';

  await page.setViewportSize({ width: 1280, height: 800 });

  // 1. Missing Country
  await page.goto('http://localhost:3000/data-hub');
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(artifactDir, 'dashboard_missing_fallback.png'), fullPage: true });

  // 2. Invalid Country
  await page.goto(`http://localhost:3000/data-hub?country=${INVALID}`);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(artifactDir, 'dashboard_invalid_fallback.png'), fullPage: true });

  // 3. India
  await page.goto(`http://localhost:3000/data-hub?country=${INDIA}`);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(artifactDir, 'dashboard_india.png'), fullPage: true });

  // 4. Afghanistan
  await page.goto(`http://localhost:3000/data-hub?country=${AFGHANISTAN}`);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(artifactDir, 'dashboard_afghanistan.png'), fullPage: true });

  // Verify Placeholder page
  await page.goto(`http://localhost:3000/data-hub/tax/coverage`);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(artifactDir, 'placeholder_not_configured.png'), fullPage: true });

  await page.close();
  await browser.close();
}
run();
