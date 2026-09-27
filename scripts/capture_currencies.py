import asyncio
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page = await browser.new_page()
        print('Navigating to Currencies page...')
        try:
            await page.goto('http://localhost:3000/data-hub/tax/currencies', wait_until='networkidle')
            await page.screenshot(path='D:/NAMISH_GLOBAL_CONTROL/ui_evidence_currencies.png', full_page=True)
            print('Screenshot saved to ui_evidence_currencies.png')
            
            # Extract basic text info from the page to verify
            content = await page.content()
            if 'Currencies Master' in content:
                print('Found Currencies Master in page content')
            if '₹' in content and 'INR' in content:
                print('Found INR ₹ verification card')
            if '$' in content and 'USD' in content:
                print('Found USD $ verification card')
                
        except Exception as e:
            print(f'Error navigating to /data-hub/tax/currencies: {e}')
            
        await browser.close()

asyncio.run(main())
