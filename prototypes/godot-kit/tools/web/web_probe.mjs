// Opens a Godot Web export in headless Chromium (software WebGL) as a desktop and as a phone, and reports load time,
// console errors, failed requests, the canvas size and, if the game has one, the haptics check. Saves a screenshot each.
//
//   npm i --prefix /tmp/pw playwright-core        # once; the browser itself is Playwright's (~/.cache/ms-playwright)
//   python3 -m http.server 8765 --bind 127.0.0.1 --directory <project>/build/web &     # note the PID, kill it afterwards
//   node godot-kit/tools/web/web_probe.mjs --playwright /tmp/pw/node_modules/playwright-core --project <project> \
//        --url http://127.0.0.1:8765/index.html --out /tmp/web_shots --seconds 14
//   node godot-kit/tools/web/web_probe.mjs --self-test
//
// Options: --project <dir>        the Godot project; its addons/proto_kit/haptics.gd (else game/juice.gd) holds
//                                 `const WEB_HAPTICS_PROBE: String = "..."` (the JavaScript the game evaluates to decide whether to
//                                 buzz); without one the haptics check is skipped
//          --haptics-source <f>   read that probe from this file instead; it wins over the project's
//          --chromium <path>      the Chrome binary (default: the newest Playwright one)
//          --tap 0.5,0.76         desktop: mouse click at these canvas fractions (repeatable), e.g. the title's start button
//          --tap-phone 0.5,0.80   phone: a real touch tap (the tall 9:19.5 screen puts bottom-anchored buttons lower)
//          --after-tap 8          seconds to wait after the taps before the screenshot
// Exit code 1 when the page logged an error, a request failed or the haptics check disagrees with the device.
// A web build must be served from localhost or HTTPS: Godot's web engine refuses to start on plain http over a LAN.
import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

export const argValue = (argv, name, fallback) => { const i = argv.indexOf(name); return i >= 0 && i + 1 < argv.length ? argv[i + 1] : fallback; };
export const argValues = (argv, name) => argv.flatMap((a, i) => (a === name && i + 1 < argv.length ? [argv[i + 1]] : []));
export const parseTap = text => text.split(',').map(Number);
/** The JavaScript string a game keeps in `const WEB_HAPTICS_PROBE: String = "..."`, or null. */
export const extractProbe = source => source.match(/const WEB_HAPTICS_PROBE: String = "(.*)"/)?.[1] ?? null;
/** The console lines that count as a problem: errors, page errors, and warnings that sound like a failure. */
export const problemLines = lines => lines.filter(l => /^\[(error|pageerror)\]/.test(l) || /warn.*vibrat|fail|missing|invalid/i.test(l));

function findChromium(argv) {
  if (argValue(argv, '--chromium')) return argValue(argv, '--chromium');
  const base = path.join(os.homedir(), '.cache/ms-playwright');
  const found = fs.existsSync(base) ? fs.readdirSync(base).filter(d => /^chromium-\d+$/.test(d)).sort((a, b) => Number(b.split('-')[1]) - Number(a.split('-')[1])) : [];
  if (!found.length) throw new Error('no Playwright Chromium in ' + base + '; pass --chromium');
  return path.join(base, found[0], 'chrome-linux64/chrome');
}

/** The game's probe: from --haptics-source, else the first of <project>/addons/proto_kit/haptics.gd and <project>/game/juice.gd (the older layout) that holds one. */
function haptics(argv) {
  const [explicit, project] = [argValue(argv, '--haptics-source'), argValue(argv, '--project')];
  const sources = explicit ? [explicit] : project ? ['addons/proto_kit/haptics.gd', 'game/juice.gd'].map(f => path.join(project, f)) : [];
  for (const source of sources) {
    const probe = fs.existsSync(source) ? extractProbe(fs.readFileSync(source, 'utf8')) : null;
    if (probe) return probe;
  }
  return null;
}

async function main(argv) {
  const { chromium } = createRequire(import.meta.url)(argValue(argv, '--playwright', 'playwright-core'));
  const url = argValue(argv, '--url', 'http://127.0.0.1:8765/index.html');
  const out = argValue(argv, '--out', '/tmp/web_probe');
  const seconds = Number(argValue(argv, '--seconds', '14'));
  const afterTap = Number(argValue(argv, '--after-tap', '8'));
  const taps = { desktop: argValues(argv, '--tap').map(parseTap), phone: argValues(argv, '--tap-phone').map(parseTap) };
  fs.mkdirSync(out, { recursive: true });
  const probe = haptics(argv);   // the exact string the game evaluates, so the code and the browser cannot drift apart
  if (!probe) console.log('(no WEB_HAPTICS_PROBE found: the haptics check is skipped)');

  const browser = await chromium.launch({ executablePath: findChromium(argv), headless: true,
    args: ['--enable-webgl', '--ignore-gpu-blocklist', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--autoplay-policy=no-user-gesture-required'] });
  const devices = {
    desktop: { viewport: { width: 540, height: 960 }, hasTouch: false, isMobile: false },
    phone: { viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true, deviceScaleFactor: 2,
      userAgent: 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Mobile Safari/537.36' },
  };
  const expectBuzz = { desktop: false, phone: true };
  let bad = 0;
  for (const [name, opts] of Object.entries(devices)) {
    const ctx = await browser.newContext(opts);
    const page = await ctx.newPage();
    const lines = [], failed = [];
    page.on('console', m => lines.push(`[${m.type()}] ${m.text()}`));
    page.on('pageerror', e => lines.push(`[pageerror] ${e.message}`));
    page.on('requestfailed', r => failed.push(`${r.url()} ${r.failure()?.errorText}`));
    const t0 = Date.now();
    await page.goto(url, { waitUntil: 'load', timeout: 60000 });
    await page.waitForSelector('canvas', { timeout: 30000 });
    await page.waitForTimeout(seconds * 1000);
    const box = await page.locator('canvas').boundingBox();
    for (const [fx, fy] of taps[name]) {
      const [x, y] = [box.x + box.width * fx, box.y + box.height * fy];
      if (name === 'phone') await page.touchscreen.tap(x, y); else await page.mouse.click(x, y);
      await page.waitForTimeout(500);
    }
    if (taps[name].length) await page.waitForTimeout(afterTap * 1000);
    const info = await page.evaluate(p => ({
      canvas: (c => c && [c.width, c.height])(document.querySelector('canvas')),
      loaderGone: !document.getElementById('status'),
      vibrate: typeof navigator.vibrate, maxTouchPoints: navigator.maxTouchPoints, coarse: matchMedia('(pointer: coarse)').matches,
      gameWouldBuzz: p ? Boolean(eval(p)) : null,
    }), probe);
    await page.screenshot({ path: path.join(out, `${name}.png`) });
    const errors = problemLines(lines);
    console.log(`== ${name}: ${((Date.now() - t0) / 1000).toFixed(1)} s, ${lines.length} console lines, ${errors.length} problems, ${failed.length} failed requests`);
    console.log('   ' + JSON.stringify(info));
    if (probe && info.gameWouldBuzz !== expectBuzz[name]) { console.log(`   !! the game would ${info.gameWouldBuzz ? '' : 'not '}buzz on ${name}, expected ${expectBuzz[name] ? 'yes' : 'no'}`); bad++; }
    errors.slice(0, 12).forEach(l => console.log('   ' + l.slice(0, 220)));
    failed.slice(0, 5).forEach(l => console.log('   FAILED ' + l));
    bad += errors.length + failed.length;
    await ctx.close();
  }
  await browser.close();
  return bad ? 1 : 0;
}

function selfTest() {
  let ok = true;
  const expect = (condition, label) => { console.log((condition ? 'ok   ' : 'FAIL ') + label); ok = ok && Boolean(condition); };
  const argv = ['node', 'x', '--tap', '0.5,0.76', '--tap', '0.1,0.2', '--url', 'http://h/', '--flag'];
  expect(JSON.stringify(argValues(argv, '--tap').map(parseTap)) === '[[0.5,0.76],[0.1,0.2]]', 'repeated --tap options parse into fractions');
  expect(argValue(argv, '--url', 'd') === 'http://h/' && argValue(argv, '--out', 'd') === 'd', 'an option takes its value, a missing one its fallback');
  expect(argValue(argv, '--flag', 'd') === 'd', 'an option with no value after it falls back instead of reading past the end');
  const sample = 'extends Node\nconst WEB_HAPTICS_PROBE: String = "typeof navigator.vibrate === \'function\' && navigator.maxTouchPoints > 0"\nvar x\n';
  expect(extractProbe(sample) === "typeof navigator.vibrate === 'function' && navigator.maxTouchPoints > 0", 'the haptics probe is read out of a .gd file');
  expect(extractProbe('extends Node\n') === null, 'no probe constant: null (the check is skipped)');
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'web_probe_'));
  fs.mkdirSync(path.join(tmp, 'game'));
  fs.writeFileSync(path.join(tmp, 'game/juice.gd'), sample);
  expect(haptics(['--project', tmp]) === extractProbe(sample), '--project finds game/juice.gd');
  expect(haptics(['--project', path.join(tmp, 'nowhere')]) === null && haptics([]) === null, 'a project without juice.gd, or no project, skips the check');
  // The order is --haptics-source, then addons/proto_kit/haptics.gd, then game/juice.gd; each file gets its own string, so the winner shows.
  const withProbe = text => `extends RefCounted\nconst WEB_HAPTICS_PROBE: String = "${text}"\n`;
  fs.mkdirSync(path.join(tmp, 'addons/proto_kit'), { recursive: true });
  fs.writeFileSync(path.join(tmp, 'addons/proto_kit/haptics.gd'), withProbe('kit'));
  fs.writeFileSync(path.join(tmp, 'explicit.gd'), withProbe('explicit'));
  expect(haptics(['--project', tmp]) === 'kit', '--project prefers addons/proto_kit/haptics.gd over game/juice.gd');
  expect(haptics(['--project', tmp, '--haptics-source', path.join(tmp, 'explicit.gd')]) === 'explicit', '--haptics-source wins over the project');
  fs.writeFileSync(path.join(tmp, 'addons/proto_kit/haptics.gd'), 'extends RefCounted\n');
  expect(haptics(['--project', tmp]) === extractProbe(sample), 'a haptics.gd without a probe falls through to game/juice.gd');
  fs.rmSync(tmp, { recursive: true });
  const lines = ['[log] hello', '[error] boom', '[pageerror] x is undefined', '[warning] navigator.vibrate blocked', '[log] missing glyph', '[info] all good'];
  expect(JSON.stringify(problemLines(lines)) === JSON.stringify(['[error] boom', '[pageerror] x is undefined', '[warning] navigator.vibrate blocked', '[log] missing glyph']),
    'console errors, page errors and failure-sounding warnings count as problems, plain logs do not');
  expect(findChromium(['--chromium', '/x/chrome']) === '/x/chrome', '--chromium wins over the Playwright search');
  console.log('web_probe self-test', ok ? 'PASSED' : 'FAILED');
  return ok ? 0 : 1;
}

process.exit(process.argv.includes('--self-test') ? selfTest() : await main(process.argv));
