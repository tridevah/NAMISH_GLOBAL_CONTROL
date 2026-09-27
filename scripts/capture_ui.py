import asyncio
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page = await browser.new_page()
        print('Navigating to Geography page...')
        # Assuming typical geography page URL, try a few paths
        try:
            await page.goto('http://localhost:3000/geography', wait_until='networkidle')
            await page.screenshot(path='D:/NAMISH_GLOBAL_CONTROL/ui_evidence_geography.png', full_page=True)
            print('Screenshot saved to ui_evidence_geography.png')
            
            # Extract basic text info from the page to verify counts
            content = await page.content()
            if '7,912' in content:
                print('Found 7,912 in page content')
            if '784' in content:
                print('Found 784 in page content')
            if '7,092' in content:
                print('Found 7,092 in page content')
                
        except Exception as e:
            print(f'Error navigating to /geography: {e}')
            
        await browser.close()

asyncio.run(main())
