import { gotoAndWait } from '../lib/browser.mjs';

// ช่วยหา button/by text แบบทนๆ (Puppeteer v23+ compatible)
async function clickByText(page, texts = [], opts={}) {
  for (const t of texts) {
    const clicked = await page.evaluate((text) => {
      const xpath = `//button[normalize-space() = '${text}'] | //span[normalize-space() = '${text}'] | //a[normalize-space() = '${text}']`;
      const result = document.evaluate(xpath, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null);
      if (result.singleNodeValue) {
        result.singleNodeValue.click();
        return true;
      }
      return false;
    }, t);
    if (clicked) return true;
  }
  return false;
}

// Helper สำหรับ XPath click (Puppeteer v23+)
async function clickByXPath(page, xpath) {
  return await page.evaluate((xp) => {
    const result = document.evaluate(xp, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null);
    if (result.singleNodeValue) {
      result.singleNodeValue.click();
      return true;
    }
    return false;
  }, xpath);
}

// เพิ่ม label run-smoke (หรือชื่ออื่น)
export async function addLabel({ page, prUrl, label='run-smoke' }) {
  await gotoAndWait(page, prUrl);
  // เปิดแท็บ Labels (ด้านขวา)
  await page.waitForSelector('[data-test-selector="sidebar-labels-filter"]', {timeout: 60000});
  await page.click('[data-test-selector="sidebar-labels-filter"]'); // เปิดกล่องค้นหา label
  await page.type('[data-test-selector="sidebar-labels-filter"] input', label, {delay: 10});
  // คลิกผลลัพธ์แรก
  await new Promise(resolve => setTimeout(resolve, 500));
  const item = await page.$('label[name="IssueLabelPickerItem"]') || await page.$('[data-test-selector="issue-label-picker-item"]');
  if (item) { await item.click(); }
  // ปิด popover
  await page.keyboard.press('Escape');
}

export async function ensureTitlePrefix({ page, prUrl, prefix='[run-smoke]' }) {
  await gotoAndWait(page, prUrl);
  await page.waitForSelector('span.js-issue-title, [data-test-selector="issue-title"]', {timeout: 60000});
  const titleSel = 'span.js-issue-title';
  const pencil = await page.$('button[aria-label="Edit title"]') || await page.$('svg.octicon-pencil');
  if (pencil) await pencil.click();
  await page.waitForSelector('input[name="issue[title]"]');
  const input = await page.$('input[name="issue[title]"]');
  const curr = await page.evaluate(el => el.value, input);
  if (!curr.startsWith(prefix)) {
    await input.click({ clickCount: 3 });
    await input.type(`${prefix} ${curr}`);
    await clickByText(page, ['Save', 'Save changes']);
  } else {
    // ยกเลิกถ้าไม่ต้องแก้
    await clickByText(page, ['Cancel']);
  }
}

export async function rerunAllChecks({ page, prUrl }) {
  // ไปหน้า "Checks"
  await gotoAndWait(page, prUrl.replace(/\/pull\/(\d+)/, '/pull/$1/checks'));
  // ปุ่ม Re-run
  const tried = await clickByText(page, ['Re-run all jobs', 'Re-run failed jobs', 'Re-run jobs']);
  if (!tried) {
    // เมนูจุดสามจุด
    const menu = await page.$('button[aria-label="More options"]');
    if (menu) { await menu.click(); await clickByText(page, ['Re-run all jobs','Re-run failed jobs']); }
  }
  await new Promise(resolve => setTimeout(resolve, 1000));
}

export async function closePR({ page, prUrl, comment }) {
  await gotoAndWait(page, prUrl);
  if (comment) {
    await page.click('textarea[name="comment[body]"]');
    await page.type('textarea[name="comment[body]"]', comment, {delay: 10});
    await clickByText(page, ['Comment']);
  }
  await clickByText(page, ['Close pull request', 'Close']);
  await new Promise(resolve => setTimeout(resolve, 800));
}

export async function createFromCompare({ page, compareUrl, title, body }) {
  await gotoAndWait(page, compareUrl);
  // ปุ่ม "Create pull request"
  await clickByText(page, ['Create pull request', 'Open pull request']);
  await page.waitForSelector('#pull_request_title', {timeout: 60000});
  if (title) {
    const t = await page.$('#pull_request_title');
    await t.click({ clickCount: 3 }); await t.type(title);
  }
  if (body) {
    const b = await page.$('#pull_request_body');
    if (b) { await b.click({ clickCount: 3 }); await b.type(body); }
  }
  await clickByText(page, ['Create pull request', 'Open pull request']);
}

export async function mergePR({ page, prUrl, mode = 'squash', deleteBranch = true }) {
  await gotoAndWait(page, prUrl);

  // เปิด dropdown เลือกโหมด merge ถ้ามี
  const dropdown = await page.$('summary.btn-group > summary[aria-label="Select merge method"]')
               || await page.$('summary[aria-haspopup="menu"]');
  if (dropdown) {
    await dropdown.click();
    await new Promise(resolve => setTimeout(resolve, 300));
    // เลือกโหมดตามชื่อปุ่มในเมนู
    const labels = {
      squash: ['Squash and merge', 'Squash & merge'],
      merge:  ['Create a merge commit', 'Merge pull request'],
      rebase: ['Rebase and merge', 'Rebase & merge']
    }[mode] || ['Squash and merge'];
    // พยายามคลิกตัวเลือกในเมนู
    let picked = false;
    for (const t of labels) {
      const clicked = await clickByXPath(page, `//button[normalize-space()='${t}'] | //span[normalize-space()='${t}']`);
      if (clicked) { picked = true; break; }
    }
    if (!picked) { await page.keyboard.press('Escape'); }
  }

  // ปุ่ม merge หลัก
  const mainMergeButtons = [
    "//button[normalize-space()='Squash and merge']",
    "//button[normalize-space()='Merge pull request']",
    "//button[normalize-space()='Rebase and merge']",
  ];
  let clicked = false;
  for (const xp of mainMergeButtons) {
    const result = await clickByXPath(page, xp);
    if (result) { clicked = true; break; }
  }
  if (!clicked) {
    // บางหน้าจะมีปุ่มยืนยันรอบเดียว
    const el = await page.$('button.js-merge-box-button') || await page.$('button[data-details-container-group="merge"]');
    if (el) { await el.click(); clicked = true; }
  }

  await new Promise(resolve => setTimeout(resolve, 600));

  // ปุ่มยืนยัน (confirm)
  const confirmButtons = [
    "//button[normalize-space()='Confirm squash and merge']",
    "//button[normalize-space()='Confirm merge']",
    "//button[normalize-space()='Confirm rebase and merge']",
  ];
  for (const xp of confirmButtons) {
    const result = await clickByXPath(page, xp);
    if (result) break;
  }

  await new Promise(resolve => setTimeout(resolve, 800));

  // ลบ branch หลัง merge (ถ้ามีปุ่ม)
  if (deleteBranch) {
    const deleted = await clickByXPath(page, "//button[contains(.,'Delete branch')] | //summary[contains(.,'Delete branch')]");
    if (deleted) { await new Promise(resolve => setTimeout(resolve, 400)); }
  }
}
