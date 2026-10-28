// Usage: node tools/web_m3_check.mjs --playwright /path/to/playwright-core --chromium /path/to/chrome
//        --url http://127.0.0.1:8795/index.html --out /tmp/seal-web-m3
// Uses an isolated browser context; never touches the player's browser storage.
import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const option = (name, fallback) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : fallback;
};
const require = createRequire(import.meta.url);
const { chromium } = require(option('--playwright', 'playwright-core'));
const executablePath = option('--chromium', undefined);
const url = option('--url', 'http://127.0.0.1:8795/index.html');
const out = option('--out', '/tmp/seal-web-m3');
fs.mkdirSync(out, { recursive: true });

const checks = [];
const errors = [];
const check = (name, ok) => { checks.push({ name, ok: Boolean(ok) }); if (!ok) console.error('FAIL:', name); };

async function saveRecord(page) {
  return page.evaluate(async () => {
    const db = await new Promise((resolve, reject) => {
      const request = indexedDB.open('/userfs');
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    const store = db.transaction('FILE_DATA', 'readonly').objectStore('FILE_DATA');
    const keys = await new Promise((resolve, reject) => {
      const request = store.getAllKeys(); request.onsuccess = () => resolve(request.result); request.onerror = () => reject(request.error);
    });
    const key = keys.find(k => String(k).endsWith('/seal_meadow/save.json'));
    if (!key) { db.close(); return null; }
    const record = await new Promise((resolve, reject) => {
      const request = db.transaction('FILE_DATA', 'readonly').objectStore('FILE_DATA').get(key);
      request.onsuccess = () => resolve(request.result); request.onerror = () => reject(request.error);
    });
    db.close();
    return { key, data: JSON.parse(new TextDecoder().decode(record.contents)) };
  });
}

async function waitSave(page, predicate) {
  for (let i = 0; i < 30; i++) {
    const record = await saveRecord(page);
    if (record && predicate(record.data)) return record;
    await page.waitForTimeout(300);
  }
  throw new Error('Timed out waiting for the expected IndexedDB save');
}

async function loaded(page) {
  await page.waitForFunction(() => !document.getElementById('status'), null, { timeout: 60000 });
  await page.waitForTimeout(800);
}

async function seedSave(page, key, save) {
  await page.evaluate(async ({ key, save }) => {
    const db = await new Promise((resolve, reject) => {
      const request = indexedDB.open('/userfs'); request.onsuccess = () => resolve(request.result); request.onerror = () => reject(request.error);
    });
    const tx = db.transaction('FILE_DATA', 'readwrite');
    const store = tx.objectStore('FILE_DATA');
    const record = await new Promise((resolve, reject) => {
      const request = store.get(key); request.onsuccess = () => resolve(request.result); request.onerror = () => reject(request.error);
    });
    record.contents = new TextEncoder().encode(JSON.stringify(save));
    record.timestamp = new Date(Date.now() + 1000);
    store.put(record, key);
    await new Promise((resolve, reject) => { tx.oncomplete = resolve; tx.onerror = () => reject(tx.error); });
    db.close();
  }, { key, save });
}

let browser;
try {
  browser = await chromium.launch({ executablePath, headless: true, args: [
    '--no-sandbox', '--enable-webgl', '--ignore-gpu-blocklist', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
    '--autoplay-policy=no-user-gesture-required',
  ] });
  const context = await browser.newContext({ viewport: { width: 844, height: 390 }, hasTouch: true, isMobile: true, deviceScaleFactor: 1 });
  const page = await context.newPage();
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('requestfailed', r => errors.push(`${r.url()}: ${r.failure()?.errorText}`));
  await page.goto(url, { waitUntil: 'load', timeout: 60000 });
  await loaded(page);
  check('mobile canvas loaded', Boolean(await page.locator('canvas').boundingBox()));
  await page.screenshot({ path: path.join(out, 'start.png') });

  await page.touchscreen.tap(47, 242); // settings
  await page.touchscreen.tap(220, 165); // sound off
  const off = await waitSave(page, s => s.data?.settings?.sound === false);
  check('sound setting saved to IndexedDB', off.data.data.settings.sound === false);
  await page.screenshot({ path: path.join(out, 'settings.png') });
  await page.reload({ waitUntil: 'load', timeout: 60000 });
  await loaded(page);
  await page.touchscreen.tap(47, 242);
  await page.touchscreen.tap(220, 165); // persisted off -> on
  const on = await waitSave(page, s => s.data?.settings?.sound === true);
  check('setting restored and toggled after reload', on.data.data.settings.sound === true);
  await page.touchscreen.tap(620, 76); // close settings
  await page.touchscreen.tap(132, 242); // collection
  await page.waitForTimeout(500);
  await page.screenshot({ path: path.join(out, 'collection.png') });

  // Leave the game before changing its isolated database, so page shutdown cannot overwrite the fixture.
  // A same-origin HTML fixture with its own icon avoids the browser's unrelated /favicon.ico request; no
  // console errors or failed game requests are filtered out of the report.
  const fixtureUrl = new URL('__seal_storage_fixture__.html', url).href;
  await page.route(fixtureUrl, route => route.fulfill({
    status: 200, contentType: 'text/html', body: '<!doctype html><link rel="icon" href="data:,">',
  }));
  await page.goto(fixtureUrl, { waitUntil: 'load' });
  await page.waitForTimeout(700);
  await seedSave(page, on.key, { version: 4, data: {
    level: 3, xp: 7, x: 0, z: 4, gold: 100,
    bag: [{ id: 'iron_sword', count: 1 }, { id: 'crystal', count: 2 }],
    equipped: { weapon: 'iron_sword', body: '' }, refine: { iron_sword: 2 },
  } });
  await page.goto(url, { waitUntil: 'load', timeout: 60000 });
  await loaded(page);
  await page.touchscreen.tap(47, 242);
  await page.touchscreen.tap(220, 165); // trigger a v6 checkpoint after migration
  const migrated = await waitSave(page, s => s.version === 6 && s.data?.settings?.sound === false);
  const worn = migrated.data.data.equipped.weapon;
  const bag = migrated.data.data.bag.find(item => item.id === 'iron_sword');
  check('v4 equipment migrated in Web', worn?.refine === 2 && bag?.refine === 2 && Boolean(worn.uid) && Boolean(bag.uid) && worn.uid !== bag.uid);
  check('legacy level and currency retained', migrated.data.data.level === 3 && migrated.data.data.gold === 100);
  await page.screenshot({ path: path.join(out, 'migrated.png') });

  await page.touchscreen.tap(620, 76); // close settings
  await page.touchscreen.tap(785, 25); // bag
  await page.touchscreen.tap(783, 98); // refine tab
  await page.waitForTimeout(400);
  await page.screenshot({ path: path.join(out, 'refine.png') });
  await page.touchscreen.tap(810, 187); // first press arms the equipped sword
  await page.waitForTimeout(300);
  const armed = await saveRecord(page);
  check('first refine press spends nothing', armed.data.data.equipped.weapon.refine === 2
    && armed.data.data.bag.find(item => item.id === 'crystal')?.count === 2);
  await page.touchscreen.tap(810, 187); // second press commits
  const refined = await waitSave(page, s => s.data?.equipped?.weapon?.refine === 3);
  check('second refine press saves the upgraded item and one crystal',
    refined.data.data.bag.find(item => item.id === 'crystal')?.count === 1
      && refined.data.data.equipped.weapon.uid === worn.uid);

  // Reopen a genuine v5-shaped snapshot with the achievements already claimed.
  const v5 = JSON.parse(JSON.stringify(refined.data));
  v5.version = 5;
  delete v5.data.appearance;
  v5.data.collection = { kills: { slime: 1 }, claimed: ['first_slime', 'first_quest'] };
  await page.goto(fixtureUrl, { waitUntil: 'load' });
  await page.waitForTimeout(500);
  await seedSave(page, on.key, v5);
  await page.goto(url, { waitUntil: 'load', timeout: 60000 });
  await loaded(page);
  await page.touchscreen.tap(47, 242);
  await page.touchscreen.tap(220, 165);
  const migratedV5 = await waitSave(page, s => s.version === 6 && s.data?.settings?.sound === true);
  check('v5 appearance migration preserves achievements', migratedV5.data.data.appearance?.outfit === ''
    && migratedV5.data.data.collection.claimed.includes('first_quest'));
  await page.touchscreen.tap(620, 76); // close settings
  await page.touchscreen.tap(216, 242); // wardrobe
  await page.touchscreen.tap(225, 138); // outfit preview
  await page.touchscreen.tap(225, 209); // aura preview
  await page.waitForTimeout(300);
  await page.screenshot({ path: path.join(out, 'wardrobe.png') });
  const preview = await saveRecord(page);
  check('wardrobe preview does not alter saved appearance', preview.data.data.appearance.outfit === ''
    && preview.data.data.appearance.aura === '');
  await page.touchscreen.tap(150, 345); // apply both choices
  const dressed = await waitSave(page, s => s.data?.appearance?.outfit === 'meadow_tunic'
    && s.data?.appearance?.aura === 'meadow_ring');
  check('wardrobe apply persists both unlocked choices', dressed.data.data.gold === 100);
  await page.reload({ waitUntil: 'load', timeout: 60000 });
  await loaded(page);
  const restored = await saveRecord(page);
  check('wardrobe choices survive Web reload', restored.data.data.appearance.outfit === 'meadow_tunic'
    && restored.data.data.appearance.aura === 'meadow_ring');
  await page.screenshot({ path: path.join(out, 'wardrobe-restored.png') });
  check('no browser errors or failed requests', errors.length === 0);
  await context.close();
} catch (error) {
  errors.push(String(error));
  check('browser run completed', false);
} finally {
  if (browser) await browser.close();
  const report = { checks, errors };
  fs.writeFileSync(path.join(out, 'report.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 2));
  if (errors.length || checks.some(c => !c.ok)) process.exitCode = 1;
}
