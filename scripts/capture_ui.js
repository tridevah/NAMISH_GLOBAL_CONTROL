const { chromium, devices } = require('playwright');
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
  await page.waitForTimeout(2000); // let UI settle
  
  // Desktop
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.screenshot({ path: path.join(artifactDir, 'desktop_dashboard.png'), fullPage: true });
  console.log('Desktop dashboard captured.');

  // Mobile
  await page.setViewportSize({ width: 375, height: 812 });
  await page.screenshot({ path: path.join(artifactDir, 'mobile_dashboard.png'), fullPage: true });
  console.log('Mobile dashboard captured.');

  // Back to Desktop for Geography Units
  await page.setViewportSize({ width: 1280, height: 800 });
  
  // Navigate to India Units
  const indiaUrl = 'http://localhost:3000/data-hub/geography/units?country=cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d';
  console.log('Navigating to India Geography Units...');
  await page.goto(indiaUrl);
  await page.waitForTimeout(3000); // Wait for data to load
  await page.screenshot({ path: path.join(artifactDir, 'india_units_proof.png'), fullPage: true });
  console.log('India units proof captured.');

  await page.close();
  await browser.close();
}

run().catch(console.error);
