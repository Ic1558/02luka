import puppeteer from 'puppeteer-extra';
import StealthPlugin from 'puppeteer-extra-plugin-stealth';

puppeteer.use(StealthPlugin());

export async function launch({userDataDir, headless = false}) {
  const defaultProfile = `${process.env.HOME}/Library/Application Support/Google/Chrome`;
  const udd = userDataDir || defaultProfile;

  try {
    const browser = await puppeteer.launch({
      headless,
      args: [
        `--user-data-dir=${udd}`,
        '--no-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--disable-blink-features=AutomationControlled',
        '--disable-features=IsolateOrigins,site-per-process',
        '--window-size=1400,900',
        '--no-first-run',
        '--no-default-browser-check'
      ],
      defaultViewport: { width: 1400, height: 900 },
      ignoreDefaultArgs: ['--enable-automation']
    });
    const page = await browser.newPage();
    // ยอมรับ cookie banner บางแบบแบบคร่าวๆ
    page.on('dialog', async d => { try { await d.accept(); } catch {} });
    return { browser, page };
  } catch (err) {
    console.error('❌ Failed to launch with default profile, trying temp profile...');
    console.error(`Error: ${err.message}`);

    // Fallback: use temp profile
    const tmpDir = `/tmp/puppeteer-profile-${Date.now()}`;
    const browser = await puppeteer.launch({
      headless,
      args: [
        `--user-data-dir=${tmpDir}`,
        '--no-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--disable-blink-features=AutomationControlled',
        '--window-size=1400,900'
      ],
      defaultViewport: { width: 1400, height: 900 },
      executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
    });
    console.log(`⚠️  Using temp profile: ${tmpDir} (you'll need to login to GitHub)`);
    const page = await browser.newPage();
    page.on('dialog', async d => { try { await d.accept(); } catch {} });
    return { browser, page };
  }
}

export async function gotoAndWait(page, url) {
  await page.goto(url, { waitUntil: ['networkidle2', 'domcontentloaded'] });
  // รอให้ GitHub โหลดเนื้อหา
  await page.waitForSelector('body', {timeout: 120000});
}
