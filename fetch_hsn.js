const { chromium } = require('playwright');
const fs = require('fs');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  
  await page.goto('https://services.gst.gov.in/services/searchhsnsac');
  await page.waitForLoadState('networkidle');
  
  const links = await page.$$eval('a', as => as.map(a => ({ text: a.innerText, href: a.href })));
  
  const hsnLink = links.find(l => 
    (l.text && l.text.toLowerCase().includes('excel')) || 
    (l.href && l.href.toLowerCase().includes('hsn_sac.xlsx'))
  );
  
  if (hsnLink) {
    console.log('Found URL: ' + hsnLink.href);
    console.log('Text: ' + hsnLink.text);
    
    // Download the file
    const https = require('https');
    const file = fs.createWriteStream("HSN_Directory.xlsx");
    https.get(hsnLink.href, function(response) {
      response.pipe(file);
      file.on('finish', function() {
        file.close();
        console.log('Downloaded HSN_Directory.xlsx');
      });
    });
  } else {
    console.log('Could not find HSN Excel link. All links:', links);
  }
  await browser.close();
})();
