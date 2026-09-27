const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

async function run() {
  const browserURL = 'http://127.0.0.1:9222';
  console.log('Connecting to existing browser over CDP...');
  let browser;
  try {
    browser = await chromium.connectOverCDP(browserURL);
  } catch (err) {
    console.error('Could not connect to CDP:', err.message);
    process.exit(1);
  }

  const defaultContext = browser.contexts()[0];
  const page = await defaultContext.newPage();
  const artifactDir = 'C:\\Users\\Atul1\\.gemini\\antigravity\\brain\\66cbea70-fd6b-47b0-a32c-4681abc67020';

  console.log('Navigating to Dashboard...');
  await page.goto('http://localhost:3000/data-hub');
  await page.waitForTimeout(2000);
  
  // 1. Desktop Dashboard (Groups Collapsed)
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.screenshot({ path: path.join(artifactDir, 'desktop_dashboard.png'), fullPage: true });
  console.log('Desktop dashboard captured.');

  // 2. Mobile Dashboard Closed
  await page.setViewportSize({ width: 375, height: 812 });
  await page.screenshot({ path: path.join(artifactDir, 'mobile_dashboard_closed.png'), fullPage: true });
  console.log('Mobile dashboard closed captured.');

  // 3. Mobile Dashboard Open (Click Hamburger)
  // Assuming the hamburger menu is the button with Lucide "Menu" icon. It should be the first button in header.
  await page.click('button:has(svg.lucide-menu)');
  await page.waitForTimeout(1000);
  await page.screenshot({ path: path.join(artifactDir, 'mobile_dashboard_open.png'), fullPage: true });
  console.log('Mobile dashboard open captured.');
  
  // Close the sidebar by clicking backdrop
  await page.click('div.fixed.inset-0.z-40.bg-black\\/80');
  await page.waitForTimeout(500);

  // 4. Desktop Tax Overview (Tax group Auto-opened)
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.goto('http://localhost:3000/data-hub/tax');
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(artifactDir, 'desktop_tax_overview.png'), fullPage: true });
  console.log('Desktop tax overview captured.');

  // 5. India Geography Units Proof
  const indiaUrl = 'http://localhost:3000/data-hub/geography/units?country=cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d';
  await page.goto(indiaUrl);
  await page.waitForTimeout(3000);
  await page.screenshot({ path: path.join(artifactDir, 'india_units_proof.png'), fullPage: true });
  console.log('India units proof captured.');

  await page.close();
  await browser.close();
}

run().catch(console.error);
