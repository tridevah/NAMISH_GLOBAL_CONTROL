const { chromium } = require('playwright');
const fs = require('fs');

(async () => {
  console.log('Connecting to existing browser over CDP...');
  const browser = await chromium.connectOverCDP('http://localhost:9222');
  const context = browser.contexts()[0] || await browser.newContext();
  const page = await context.newPage();
  page.setDefaultTimeout(60000);

  try {
    // 1. Geography Levels - India
    console.log('Navigating to Geography Levels (India)...');
    await page.goto('http://localhost:3000/data-hub/geography/levels?country=cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(2000);
    await page.screenshot({ path: 'D:/NAMISH_GLOBAL_CONTROL/real_ui_india_levels.png', fullPage: true });

    // 2. Geography Units - India (Total)
    console.log('Navigating to Geography Units (India)...');
    await page.goto('http://localhost:3000/data-hub/geography/units?country=cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(3000);
    await page.screenshot({ path: 'D:/NAMISH_GLOBAL_CONTROL/real_ui_india_units_total.png', fullPage: true });

    // Filter by District (level_number = 2)
    console.log('Filtering District...');
    await page.evaluate(() => {
      const selects = Array.from(document.querySelectorAll('select'));
      const levelSelect = selects.find(s => s.options[0] && s.options[0].text === 'All Levels');
      if (levelSelect && levelSelect.options.length > 2) {
        levelSelect.selectedIndex = 2; // District
        levelSelect.dispatchEvent(new Event('change', { bubbles: true }));
      }
    });
    // Wait for network/UI
    await page.waitForTimeout(3000);
    await page.screenshot({ path: 'D:/NAMISH_GLOBAL_CONTROL/real_ui_india_units_district.png', fullPage: true });

    // Filter by Sub-District (level_number = 3)
    console.log('Filtering Sub-District...');
    await page.evaluate(() => {
      const selects = Array.from(document.querySelectorAll('select'));
      const levelSelect = selects.find(s => s.options[0] && s.options[0].text === 'All Levels');
      if (levelSelect && levelSelect.options.length > 3) {
        levelSelect.selectedIndex = 3; // Sub-District
        levelSelect.dispatchEvent(new Event('change', { bubbles: true }));
      }
    });
    await page.waitForTimeout(3000);
    await page.screenshot({ path: 'D:/NAMISH_GLOBAL_CONTROL/real_ui_india_units_subdistrict.png', fullPage: true });

    // 3. Geography Units - Afghanistan
    console.log('Navigating to Geography Units (Afghanistan)...');
    await page.goto('http://localhost:3000/data-hub/geography/units?country=d2347500-7f09-469e-a020-adfa369e173a', { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(3000);
    await page.screenshot({ path: 'D:/NAMISH_GLOBAL_CONTROL/real_ui_afghanistan_units.png', fullPage: true });

    console.log('Verification screenshots captured successfully.');
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await page.close();
  }
})();
