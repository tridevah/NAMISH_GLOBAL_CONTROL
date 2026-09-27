const { chromium } = require('playwright');
const fs = require('fs');

(async () => {
  console.log('Connecting to existing browser over CDP...');
  const browser = await chromium.connectOverCDP('http://localhost:9222');
  const context = browser.contexts()[0] || await browser.newContext();
  const page = await context.newPage();
  page.setDefaultTimeout(3600000);

  const networkLogs = [];
  page.on('response', response => {
    if (response.url().includes('/api/data-hub/countries') || response.url().includes('/api/data-hub/tax/currencies')) {
      networkLogs.push(`URL: ${response.url()} | Status: ${response.status()}`);
    }
  });

  console.log('Navigating to currencies page...');
  await page.goto('http://localhost:3000/data-hub/tax/currencies', { waitUntil: 'domcontentloaded' });

  if (page.url().includes('/login')) {
    console.log('#########################################################');
    console.log('# LOGIN REQUIRED! PLEASE LOG IN VIA THE OPENED BROWSER. #');
    console.log('#########################################################');
    await page.waitForFunction(() => !window.location.href.includes('/login'), { timeout: 3600000 });
    console.log('Login successful! Proceeding...');
    await page.goto('http://localhost:3000/data-hub/tax/currencies', { waitUntil: 'domcontentloaded' });
  }

  console.log('Waiting for options to load...');
  // DataHubShell has the first select. Wait for it to be populated.
  await page.waitForFunction(() => {
    const selects = document.querySelectorAll('select');
    return selects.length > 0 && selects[0].options.length > 10;
  }, { timeout: 60000 });

  console.log('Selecting country in DataHubShell to unhide page content...');
  const shellSelect = 'select:nth-of-type(1)';
  const shellOptions = await page.$$eval(`${shellSelect} option`, opts => opts.map(o => o.value).filter(v => v));
  if (shellOptions.length > 0) {
    await page.selectOption(shellSelect, shellOptions[0]);
    await page.waitForTimeout(1000);
  }

  console.log('Waiting for the specific country select to render...');
  await page.waitForFunction(() => {
    return Array.from(document.querySelectorAll('select')).some(select => 
      Array.from(select.options).some(o => o.value === 'IN')
    );
  }, { timeout: 60000 });

  const selects = page.locator('select');
  const selectsCount = await selects.count();
  let targetSelectIndex = -1;
  for (let i = 0; i < selectsCount; i++) {
    const isCountrySelect = await selects.nth(i).evaluate(el => {
      return Array.from(el.options).some(o => o.value === 'IN');
    });
    if (isCountrySelect) {
      targetSelectIndex = i;
      break;
    }
  }

  if (targetSelectIndex === -1) {
    throw new Error('Country select not found after unhiding page');
  }

  const countryDropdown = selects.nth(targetSelectIndex);

  const tests = [
    { code: 'IN', desc: 'India' },
    { code: 'US', desc: 'USA' },
    { code: 'GB', desc: 'United Kingdom' },
    { code: 'DE', desc: 'Euro-area (Germany)' },
    { code: 'JP', desc: 'Japan' },
    { code: 'AE', desc: 'UAE' },
    { code: 'PS', desc: 'Palestine (Multi-currency)' },
    { code: 'AQ', desc: 'Antarctica (NO_OFFICIAL_CURRENCY)' }
  ];

  for (let t of tests) {
    console.log(`Selecting ${t.desc} (${t.code})...`);
    await countryDropdown.selectOption(t.code);
    await page.waitForTimeout(500); // UI update
    
    const path = `D:/NAMISH_GLOBAL_CONTROL/real_ui_evidence_${t.code}.png`;
    await page.screenshot({ path, fullPage: false });
    console.log(`Saved ${path}`);
  }

  console.log('\n--- Network Logs ---');
  networkLogs.forEach(log => console.log(log));
  console.log('--------------------\n');

  console.log('Verification screenshots captured successfully.');
  await page.close();
})();
