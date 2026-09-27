const { chromium } = require('playwright');
const path = require('path');

async function run() {
  const browserURL = 'http://127.0.0.1:9222';
  let browser = await chromium.connectOverCDP(browserURL);
  const page = await browser.contexts()[0].newPage();
  const artifactDir = 'C:\\Users\\Atul1\\.gemini\\antigravity\\brain\\66cbea70-fd6b-47b0-a32c-4681abc67020';

  await page.goto('http://localhost:3000/data-hub');
  await page.waitForTimeout(2000);
  
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.screenshot({ path: path.join(artifactDir, 'desktop_dashboard.png'), fullPage: true });

  await page.setViewportSize({ width: 375, height: 812 });
  await page.screenshot({ path: path.join(artifactDir, 'mobile_dashboard_closed.png'), fullPage: true });

  await page.click('button:has(svg.lucide-menu)', { force: true });
  await page.waitForTimeout(1000);
  await page.screenshot({ path: path.join(artifactDir, 'mobile_dashboard_open.png'), fullPage: true });

  await page.setViewportSize({ width: 1280, height: 800 });
  await page.goto('http://localhost:3000/data-hub/tax');
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(artifactDir, 'desktop_tax_overview.png'), fullPage: true });

  const indiaUrl = 'http://localhost:3000/data-hub/geography/units?country=cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d';
  await page.goto(indiaUrl);
  await page.waitForTimeout(3000);
  await page.screenshot({ path: path.join(artifactDir, 'india_units_proof.png'), fullPage: true });

  await page.close();
  await browser.close();
}
run();
