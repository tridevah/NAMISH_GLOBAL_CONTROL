const { chromium } = require('playwright');

(async () => {
  try {
    console.log('Connecting to existing browser over CDP...');
    const browser = await chromium.connectOverCDP('http://localhost:9222');
    const defaultContext = browser.contexts()[0];
    const page = await defaultContext.newPage();
    
    console.log('Navigating to Tax Authorities...');
    await page.goto('http://localhost:3000/data-hub/tax/authorities', { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(3000);
    
    await page.screenshot({ path: 'D:/NAMISH_GLOBAL_CONTROL/real_ui_tax_authorities.png', fullPage: true });
    console.log('Verification screenshot captured successfully.');
    
    await page.close();
    await browser.close();
  } catch (error) {
    console.error('Verification failed:', error);
    process.exit(1);
  }
})();
