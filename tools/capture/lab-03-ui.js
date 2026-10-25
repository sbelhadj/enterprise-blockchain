// Author's tool: screenshots the Lab 3 history page (Figure L3.2) with Playwright.
//   node lab-03-ui.js URL KEY SERIAL OUT.png
const {chromium} = require('playwright');
(async () => {
    const [url, key, serial, out] = process.argv.slice(2);
    const browser = await chromium.launch();
    const page = await browser.newPage({viewport: {width: 1000, height: 400},
        deviceScaleFactor: 2});
    await page.goto(url);
    await page.fill('#key', key);
    await page.fill('#serial', serial);
    await page.click('button');
    await page.waitForSelector('table');
    await page.screenshot({path: out, fullPage: true});
    await browser.close();
})();
