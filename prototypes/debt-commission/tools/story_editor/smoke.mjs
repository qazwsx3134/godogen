// Browser smoke test of the story editor with real mouse input (Chromium via playwright-core).
//   node tools/story_editor/smoke.mjs --playwright <playwright-core dir> --chromium <chrome-headless-shell> \
//        --out <dir for the screenshot and the exported JSON> [--godot godot] [--port 8879]
// Serves the project root with python3 -m http.server, opens /tools/story_editor/?story=ep00, edits the story
// with the mouse, downloads the result, and (with --godot) runs check_story.gd --write on a copy of it.
// A second page opens index.html from file:// and loads a story through the file picker.
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { spawn, spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { batch1Regression } from './batch1_regression.mjs';
import { sceneRegression } from './scene_regression.mjs';

const require = createRequire(import.meta.url);
const arg = (name, fallback) => { const i = process.argv.indexOf(name); return i >= 0 ? process.argv[i + 1] : fallback; };
const { chromium } = require(arg('--playwright', 'playwright-core'));
const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const out = path.resolve(arg('--out', 'story_editor_smoke'));
const serverPort = Number(arg('--port', '8879'));
fs.mkdirSync(out, { recursive: true });
const log = (...parts) => console.log(...parts);

const server = spawn('python3', ['-m', 'http.server', String(serverPort), '--bind', '127.0.0.1', '-d', project], { stdio: 'ignore' });
const browser = await chromium.launch({ headless: true, executablePath: arg('--chromium', undefined) });
const errors = [];
try {
  for (let tries = 0; ; tries++) {
    try {
      const response = await fetch(`http://127.0.0.1:${serverPort}/tools/story_editor/index.html`);
      if (response.ok && (await response.text()).includes('id="storySelect"')) break;
    } catch (err) { /* not up yet */ }
    assert.ok(server.exitCode === null, `test server exited (port ${serverPort} may be occupied)`);
    assert.ok(tries < 50, 'http server did not start');
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  if (process.argv.includes('--scene-only')) {
    await sceneRegression(browser, `http://127.0.0.1:${serverPort}/tools/story_editor/`, out);
  } else if (process.argv.includes('--batch1-only')) {
    await batch1Regression(browser, `http://127.0.0.1:${serverPort}/tools/story_editor/`, out);
  } else {
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  await page.goto(`http://127.0.0.1:${serverPort}/tools/story_editor/?story=ep00`);
  await page.waitForFunction(() => window.StoryEditor && window.StoryEditor.story, null, { timeout: 15000 }).catch(async err => { console.log('LOAD FAILURE', errors, (await page.content()).slice(0,2000)); throw err; });

  assert.equal(await page.locator('#btnProjectSave').isHidden(), true, 'static server keeps download workflow');
  const original = JSON.parse(fs.readFileSync(path.join(project, 'data', 'ep00_story.json'), 'utf8'));
  const exported = () => page.evaluate(() => JSON.parse(window.StoryEditor.exportText()));
  const state = () => page.evaluate(() => ({ v: { ...window.StoryEditor.state.v }, problems: window.StoryEditor.state.a.problems, sel: window.StoryEditor.state.sel }));
  const cardCount = () => page.locator('.card').count();
  const rect = (selector) => page.evaluate(sel => { const r = document.querySelector(sel).getBoundingClientRect(); return { x: r.x, y: r.y, w: r.width, h: r.height }; }, selector);
  const center = r => ({ x: r.x + r.w / 2, y: r.y + r.h / 2 });
  const portDot = (node, edge) => rect(`.card[data-node="${node}"] .prow[data-edge="${edge}"] .dot`).then(center);
  const head = node => rect(`.card[data-node="${node}"] .head`).then(r => ({ x: r.x + r.w * 0.45, y: r.y + r.h / 2 }));
  const drag = async (from, to) => {
    await page.mouse.move(from.x, from.y);
    await page.mouse.down();
    await page.mouse.move(to.x, to.y, { steps: 24 });
    await page.mouse.up();
  };
  // A point on the empty canvas near `from` (no card, link or scissors under it, inside the view).
  const blankNear = (from, min = 0) => page.evaluate(([x0, y0, minDist]) => {
    const view = document.getElementById('view').getBoundingClientRect();
    const free = (x, y) => x > view.left + 20 && x < view.right - 20 && y > view.top + 20 && y < view.bottom - 20
      && !document.elementsFromPoint(x, y).some(e => e.closest && e.closest('.card, .edge, .cut'));
    for (let r = minDist; r < 600; r += 20) {
      for (let a = 0; a < 360; a += 15) {
        const x = x0 + r * Math.cos(a * Math.PI / 180);
        const y = y0 + r * Math.sin(a * Math.PI / 180);
        if (free(x, y)) return { x, y };
      }
    }
    return null;
  }, [from.x, from.y, min]);
  const show = (node, k = 0.8) => page.evaluate(([n, scale]) => window.StoryEditor.centerOn(n, scale), [node, k]);

  // 1. The page lists every node as a card.
  assert.equal(await cardCount(), Object.keys(original.nodes).length);
  assert.equal(await page.locator('.card.entry').count(), 1);
  assert.equal(await page.locator('.card.ending').count(), 3);
  assert.equal((await state()).problems.length, 0);
  log(`ok  ep00 loaded: ${await cardCount()} cards == ${Object.keys(original.nodes).length} nodes, 1 entry, 3 endings, 0 problems`);
  assert.match(await page.locator('#banner .note.warn').innerText(), /story_src\/ep00\.dialogue/);
  log('ok  generated_from warning shown');

  assert.equal(await page.evaluate(() => window.StoryEditor.exportText()), fs.readFileSync(path.join(project, 'data', 'ep00_story.json'), 'utf8'),
    'an untouched import exports byte for byte');
  log('ok  untouched import -> export is byte-equal to data/ep00_story.json (browser pipeline)');

  // 2. Card and port geometry: the DOM matches the numbers the links are drawn from.
  {
    const bad = await page.evaluate(() => {
      const E = window.StoryEditor;
      const found = [];
      for (const card of document.querySelectorAll('.card')) {
        const id = card.dataset.node;
        const size = E.sizeOf(id);
        if (card.offsetHeight !== Math.round(size.h) || card.scrollHeight > card.offsetHeight) found.push(`${id} height ${card.offsetHeight}/${card.scrollHeight} vs ${size.h}`);
        E.state.a.edges[id].forEach((edge, i) => {
          const dot = card.querySelector(`.prow[data-edge="${CSS.escape(edge.key)}"] .dot`);
          const row = dot.parentElement;
          const o = E.core.portOffset(size, i);
          const cx = row.offsetLeft + dot.offsetLeft + dot.offsetWidth / 2;
          const cy = row.offsetTop + dot.offsetTop + dot.offsetHeight / 2;
          if (Math.abs(cx - o.x) > 0.6 || Math.abs(cy - o.y) > 0.6) found.push(`${id}/${edge.key} dot ${cx},${cy} vs ${o.x},${o.y}`);
        });
      }
      return found;
    });
    assert.deepEqual(bad, []);
    log('ok  every card height and output-port position equals the computed geometry');
  }

  await page.evaluate(() => StoryEditor.convertStory('ep00_smoke_graph'));

  // 3. Wheel zoom keeps the world point under the cursor; dragging the background pans.
  {
    const cursor = { x: 520, y: 420 };
    const at = () => page.evaluate(([x, y]) => { const w = window.StoryEditor.toWorld(x, y); return { ...w, k: window.StoryEditor.state.v.k }; }, [cursor.x, cursor.y]);
    const before = await at();
    await page.mouse.move(cursor.x, cursor.y);
    await page.mouse.wheel(0, -500);
    await page.waitForTimeout(50);
    const after = await at();
    assert.ok(after.k > before.k * 1.3, `zoom in: ${before.k} -> ${after.k}`);
    assert.ok(Math.abs(after.x - before.x) < 0.5 && Math.abs(after.y - before.y) < 0.5, `point under the cursor moved: ${JSON.stringify([before, after])}`);
    await page.mouse.wheel(0, 800);
    await page.waitForTimeout(50);
    const out2 = await at();
    assert.ok(out2.k < after.k && Math.abs(out2.x - before.x) < 0.5, 'zoom out also around the cursor');
    const v0 = (await state()).v;
    const panFrom = await blankNear({ x: 300, y: 760 });
    await drag(panFrom, { x: panFrom.x + 60, y: panFrom.y - 50 });
    const v1 = (await state()).v;
    assert.ok(Math.abs(v1.x - v0.x - 60) < 1 && Math.abs(v1.y - v0.y + 50) < 1 && v1.k === v0.k, `pan: ${JSON.stringify([v0, v1])}`);
    log(`ok  wheel zoom ${before.k.toFixed(2)} -> ${after.k.toFixed(2)} keeps the cursor's world point (${before.x.toFixed(1)}, ${before.y.toFixed(1)}); background drag pans (+60, -50)`);
  }

  // 4. A choice output port dragged onto another card changes that option's `next` (and the old target turns red).
  await show('s02_pov');
  const loudPort = 'steps/0/options/0/next';
  assert.equal((await exported()).nodes.s02_pov.steps[0].options[0].next, 's03_loud');
  await drag(await portDot('s02_pov', loudPort), await head('s03_calm'));
  {
    const story = await exported();
    assert.equal(story.nodes.s02_pov.steps[0].options[0].next, 's03_calm');
    assert.equal(story.nodes.s02_pov.steps[0].options[1].next, 's03_calm');
    assert.equal(story.nodes.s02_pov.steps[0].options[2].next, 's03_tired');
    assert.equal(await page.locator('.card[data-node="s03_loud"].unreachable').count(), 1, 's03_loud turns red');
    assert.equal(await page.locator('.card[data-node="s03_calm"].unreachable').count(), 0);
    const items = await page.locator('#problems li').allInnerTexts();
    assert.ok(items.some(t => t.includes('s03_loud') && t.includes('走不到')), items.join(' | '));
    log(`ok  option pov_loud: next s03_loud -> s03_calm via mouse; s03_loud is red; problem list: ${items.map(t => t.replace(/\s+/g, ' ')).join(' | ')}`);
    await page.locator('#problems li', { hasText: 's03_loud' }).click();
    assert.deepEqual((await state()).sel, { type: 'node', id: 's03_loud' });
    const r = center(await rect('.card[data-node="s03_loud"]'));
    const view = await rect('#view');
    assert.ok(Math.abs(r.x - (view.x + view.w / 2)) < 2 && Math.abs(r.y - (view.y + view.h / 2)) < 2, 'clicking a problem centres its card');
    log('ok  clicking the problem selects and centres the card');
  }

  // 5. Dragging an output port onto empty canvas creates a node and connects it.
  await show('s03_tired', 0.8);
  const before5 = await cardCount();
  {
    const from = await portDot('s03_tired', 'next');
    await drag(from, await blankNear({ x: from.x + 40, y: from.y + 20 }, 40));
    const story = await exported();
    assert.equal(await cardCount(), before5 + 1);
    assert.equal(story.nodes.s03_tired.next, 'node_1');
    assert.deepEqual(story.nodes.node_1.steps.map(s => s.op), ['say', 'end']);
    assert.equal((await state()).sel.id, 'node_1');
    log(`ok  dropped on empty canvas: new node_1 created and s03_tired.next -> node_1 (${before5} -> ${await cardCount()} cards)`);
  }

  // 6. Double-click on empty canvas adds a node; Delete removes the selected node (after the confirm).
  {
    const blank = await blankNear({ x: 700, y: 150 });
    const count = await cardCount();
    await page.mouse.dblclick(blank.x, blank.y);
    assert.equal(await cardCount(), count + 1);
    const created = (await state()).sel.id;
    assert.ok((await state()).problems.some(p => p.type === 'unreachable' && p.node === created));
    page.once('dialog', dialog => dialog.accept());
    await page.keyboard.press('Delete');
    await page.waitForFunction(n => document.querySelectorAll('.card').length === n, count);
    assert.equal((await exported()).nodes[created], undefined);
    log(`ok  double-click created ${created} (flagged unreachable); Delete removed it`);
  }

  // 7. Rename follows every reference, through the sidebar.
  {
    await show('s04_intro', 0.8);
    await page.mouse.click(...Object.values(await head('s04_intro')));
    const idInput = page.locator('#inspector input[type=text]').first();
    assert.equal(await idInput.inputValue(), 's04_intro');
    await idInput.fill('s04_intro_x');
    await idInput.press('Enter');
    const story = await exported();
    assert.ok(story.nodes.s04_intro_x && !story.nodes.s04_intro);
    assert.equal(story.nodes.s03_loud.next, 's04_intro_x');
    assert.equal(story.nodes.s03_calm.next, 's04_intro_x');
    assert.equal(story.nodes.s04_intro_x.next, 's04_room');
    assert.equal((await state()).problems.filter(p => p.type === 'dangling').length, 0);
    log('ok  renamed s04_intro -> s04_intro_x: s03_loud.next, s03_calm.next follow; no dangling');
  }

  // 8. The form edits only what is touched: no empty optional keys, other fields of the step survive.
  {
    await show('s01_open', 0.8);
    await page.mouse.click(...Object.values(await head('s01_open')));
    const step = page.locator('#inspector .step').first();
    const plainSay = s => s.op === 'say' && !('thought' in s) && !('expression' in s) && !('offscreen' in s);
    const sayIndex = (await exported()).nodes.s01_open.steps.findIndex(plainSay);
    assert.ok(sayIndex >= 0, 'ep00 s01_open has a plain say step');
    const sayBefore = (await exported()).nodes.s01_open.steps[sayIndex];
    const box = page.locator(`#inspector .step[data-step="${sayIndex}"]`);
    await box.locator('textarea').first().fill('編輯器改過的台詞');
    await box.locator('details summary').click();
    await box.locator('textarea.json').focus();
    assert.ok((await box.locator('textarea.json').inputValue()).includes('編輯器改過的台詞'), 'the JSON box shows the current step once focused');
    await box.locator('select').nth(1).selectOption('angry');
    let say = (await exported()).nodes.s01_open.steps[sayIndex];
    assert.equal(say.text, '編輯器改過的台詞');
    assert.equal(say.expression, 'angry');
    assert.equal(say.speaker, sayBefore.speaker);
    await box.locator('select').nth(1).selectOption('');
    await box.locator('input[type=checkbox]').check();
    assert.equal((await exported()).nodes.s01_open.steps[sayIndex].thought, true);
    await box.locator('input[type=checkbox]').uncheck();
    say = (await exported()).nodes.s01_open.steps[sayIndex];
    assert.ok(!('expression' in say) && !('thought' in say), `empty optional fields are removed, not written: ${JSON.stringify(say)}`);
    assert.deepEqual({ ...say, text: sayBefore.text }, sayBefore, 'every other field of the step is untouched');
    // JSON box: a broken edit is refused, a good one applies.
    const json = step.locator('textarea.json');
    await step.locator('details summary').click();
    await json.fill('{ not json');
    await json.dispatchEvent('change');
    assert.match(await step.locator('.err').first().innerText(), /沒有改動/);
    assert.deepEqual((await exported()).nodes.s01_open.steps[sayIndex], say);
    await box.locator('textarea').first().fill(sayBefore.text);
    log('ok  say form: text/expression/thought edits leave no empty keys and keep other fields; broken JSON refused, story untouched');
  }

  // 8b. The comedy form: preset list comes from story_runner.gd (emotion_band included), the choice is written as is.
  {
    await show('s03_loud', 0.8);
    await page.mouse.click(...Object.values(await head('s03_loud')));
    const comedyIndex = (await exported()).nodes.s03_loud.steps.findIndex(s => s.op === 'comedy');
    assert.ok(comedyIndex >= 0);
    const box = page.locator(`#inspector .step[data-step="${comedyIndex}"]`);
    const presets = await box.locator('select').first().locator('option').allInnerTexts();
    assert.deepEqual(presets, ['tsukkomi_impact', 'small_reaction', 'full_manga_panel', 'emotion_band']);
    const comedyBefore = (await exported()).nodes.s03_loud.steps[comedyIndex];
    await box.locator('select').first().selectOption('small_reaction');
    const comedyAfter = (await exported()).nodes.s03_loud.steps[comedyIndex];
    assert.deepEqual({ ...comedyAfter, preset: comedyBefore.preset }, comedyBefore);
    assert.equal(comedyAfter.preset, 'small_reaction');
    assert.equal(await box.locator('.field', { hasText: 'color' }).count(), 0, 'color only appears for emotion_band');
    await box.locator('select').first().selectOption('emotion_band');
    const colorBox = box.locator('.field', { hasText: 'color' }).locator('input[type=text]');
    await colorBox.fill('#7ec8ff');
    assert.equal((await exported()).nodes.s03_loud.steps[comedyIndex].color, '#7ec8ff');
    await box.locator('select').first().selectOption('small_reaction');
    assert.ok(!('color' in (await exported()).nodes.s03_loud.steps[comedyIndex]), 'leaving emotion_band removes `color` (the runner rejects it elsewhere)');
    await box.locator('select').first().selectOption('emotion_band');
    const colorField = () => box.locator('.field', { hasText: 'color' });
    await colorField().locator('input[type=text]').fill('#7ec8ff');
    assert.equal(await colorField().locator('input[type=color]').inputValue(), '#7ec8ff', 'the swatch follows the typed colour');
    await colorField().locator('input[type=text]').fill('');
    assert.equal(await colorField().locator('input[type=color]').inputValue(), '#ffd23f', 'an empty box shows the default yellow');
    assert.ok(!('color' in (await exported()).nodes.s03_loud.steps[comedyIndex]), 'an empty colour removes the key, not ""');
    await colorField().locator('input[type=color]').fill('#336699');
    assert.equal((await exported()).nodes.s03_loud.steps[comedyIndex].color, '#336699', 'the colour picker writes #rrggbb');
    await colorField().locator('button', { hasText: '清除' }).click();
    assert.ok(!('color' in (await exported()).nodes.s03_loud.steps[comedyIndex]), '清除 removes the key');
    assert.equal(await colorField().locator('input[type=text]').inputValue(), '', '清除 empties the box');
    assert.equal(await colorField().locator('input[type=color]').inputValue(), '#ffd23f', '清除 puts the swatch back to the default');
    const clearBox = await colorField().locator('button', { hasText: '清除' }).boundingBox();
    assert.ok(clearBox.height < 30, `清除 stays on one line (${clearBox.height}px tall)`);
    await colorField().locator('input[type=text]').fill('#7ec8ff');
    const finalComedy = (await exported()).nodes.s03_loud.steps[comedyIndex];
    assert.deepEqual({ preset: finalComedy.preset, color: finalComedy.color }, { preset: 'emotion_band', color: '#7ec8ff' });
    log(`ok  comedy form: presets ${presets.join(', ')}; ${comedyBefore.preset} -> small_reaction with other fields untouched; emotion_band shows a color field (set, cleared, dropped on leaving); ends as emotion_band #7ec8ff`);
  }

  // 9. Repair: wire s03_calm.next onto s03_loud, so everything is reachable again.
  await show('s03_calm', 0.75);
  {
    const from = await portDot('s03_calm', 'next');
    await drag(from, await head('s03_loud'));
    const story = await exported();
    assert.equal(story.nodes.s03_calm.next, 's03_loud');
    assert.equal(story.nodes.s03_loud.next, 's04_intro_x');
    assert.deepEqual((await state()).problems, []);
    assert.equal(await page.locator('.card.unreachable').count(), 0);
    log('ok  s03_calm.next -> s03_loud: 0 problems, 0 red cards');
  }

  // 10. A link can be cut: the scissors on a selected link, or the sidebar button.
  {
    const before = (await exported()).nodes.s03_tired.next;
    const dot = await portDot('s03_tired', 'next');
    await page.mouse.click(dot.x, dot.y);
    assert.equal((await state()).sel.type, 'edge');
    const scissors = await rect('#edges .cut circle').then(center);
    await page.mouse.click(scissors.x, scissors.y);
    assert.equal('next' in (await exported()).nodes.s03_tired, false, 'optional `next` is removed, not left empty');
    assert.ok((await state()).problems.some(p => p.type === 'unconnected' && p.node === 's03_tired'), 'the node now lacks a continuation');
    await drag(await portDot('s03_tired', 'next'), await head(before));
    assert.equal((await exported()).nodes.s03_tired.next, before);
    await page.mouse.click(...Object.values(await portDot('s03_tired', 'next')));
    await page.locator('#inspector button', { hasText: '斷線' }).click();
    assert.equal('next' in (await exported()).nodes.s03_tired, false);
    await drag(await portDot('s03_tired', 'next'), await head(before));
    assert.equal((await exported()).nodes.s03_tired.next, before);
    assert.deepEqual((await state()).problems, []);
    log(`ok  cut s03_tired.next with the canvas scissors and with the sidebar button (key removed, "no continuation" listed), reconnected to ${before} by dragging the ghost port`);
  }

  // 11. Export through the real download, then the game's own check.
  const downloadPromise = page.waitForEvent('download');
  await page.locator('#btnExport').click();
  const download = await downloadPromise;
  assert.equal(download.suggestedFilename(), 'ep00_smoke_graph_story.json');
  const exportPath = path.join(out, 'editor-export.json');
  await download.saveAs(exportPath);
  const text = fs.readFileSync(exportPath, 'utf8');
  assert.equal(text, await page.evaluate(() => window.StoryEditor.exportText()));
  await page.setInputFiles('#verifySaved', exportPath);
  await page.waitForFunction(() => !window.StoryEditor.state.dirty);
  assert.equal(await page.evaluate(() => window.StoryEditor.state.dirty), false, 'verified download acknowledges saved content');
  const final = JSON.parse(text);
  assert.equal(final.nodes.s02_pov.steps[0].options[0].next, 's03_calm');
  assert.equal(final.nodes.node_1.steps[1].op, 'end');
  assert.equal(final.version, 's-unset', 'an edited story goes out with s-unset: only check_story.gd computes the real version');
  assert.match(await page.locator('#banner').innerText(), /check_story\.gd/);
  log(`ok  downloaded ${download.suggestedFilename()} (${text.length} bytes): option pov_loud.next=${final.nodes.s02_pov.steps[0].options[0].next}, new node node_1 present, version s-unset (edited)`);
  if (arg('--godot')) {
    const copy = path.join(out, 'editor-export.checked.json');
    fs.copyFileSync(exportPath, copy);
    const stale = spawnSync(arg('--godot'), ['--headless', '--path', project, '--script', 'res://tools/story_editor/check_story.gd', '--', copy], { encoding: 'utf8', timeout: 180000 });
    assert.equal(stale.status, 1, 'without --write the unset version is reported');
    log((stale.stdout + stale.stderr).split('\n').filter(l => /^(ERROR|FAILED)/.test(l)).join('\n'));
    const run = spawnSync(arg('--godot'), ['--headless', '--path', project, '--script', 'res://tools/story_editor/check_story.gd', '--', copy, '--write'], { encoding: 'utf8', timeout: 180000 });
    log((run.stdout + run.stderr).split('\n').filter(l => /^(OK|ERROR|FAILED)|nodes,/.test(l)).join('\n'));
    assert.equal(run.status, 0, run.stdout + run.stderr);
    const written = JSON.parse(fs.readFileSync(copy, 'utf8')).version;
    assert.ok(/^s-[0-9a-f]{12}$/.test(written) && written !== original.version, `--write replaced s-unset with the real version (${written})`);
  }

  // 12. The screenshot: the edited area with the new node, the red-free problem list and the sidebar.
  await show('s03_calm', 0.72);
  await page.evaluate(() => window.StoryEditor.select({ type: 'node', id: 'node_1' }));
  await page.screenshot({ path: path.join(out, 'editor-shot.png') });
  log(`ok  screenshot ${path.join(out, 'editor-shot.png')} (1440x900)`);

  // 13. Positions live in localStorage and a <id>.layout.json sidecar, never in the story.
  {
    assert.deepEqual(Object.keys(final).sort(), Object.keys(original).filter(k => k !== 'generated_from').sort(), 'no layout keys at the story root');
    for (const node of Object.values(final.nodes)) assert.ok(Object.keys(node).every(k => ['steps', 'title', 'next'].includes(k)), `unexpected node key in ${Object.keys(node)}`);
    await show('s02_pov', 0.8);
    const layoutOf = () => page.evaluate(() => JSON.parse(JSON.stringify(window.StoryEditor.state.layout)));
    const start = await layoutOf();
    const from = await head('s02_pov');
    await drag(from, { x: from.x + 48, y: from.y + 32 });
    const moved = await layoutOf();
    assert.ok(Math.abs(moved.s02_pov.x - start.s02_pov.x - 60) < 2 && Math.abs(moved.s02_pov.y - start.s02_pov.y - 40) < 2, `node drag at 0.8 zoom moves 48x32 px = 60x40 world: ${JSON.stringify([start.s02_pov, moved.s02_pov])}`);
    await page.reload();
    await page.waitForFunction(() => window.StoryEditor && window.StoryEditor.story);
    await page.setInputFiles('#fileOpen', exportPath);
    await page.waitForFunction(() => StoryEditor.story.id === 'ep00_smoke_graph');
    assert.deepEqual((await layoutOf()).s02_pov, moved.s02_pov, 'reload restores the position from localStorage');
    const layoutDownload = page.waitForEvent('download');
    await page.locator('#btnLayoutExport').click();
    const layoutFile = path.join(out, 'ep00.layout.json');
    const layoutDl = await layoutDownload;
    assert.equal(layoutDl.suggestedFilename(), 'ep00_smoke_graph.layout.json');
    await layoutDl.saveAs(layoutFile);
    const sidecar = JSON.parse(fs.readFileSync(layoutFile, 'utf8'));
    assert.equal(sidecar.story, 'ep00_smoke_graph');
    assert.deepEqual(sidecar.nodes.s02_pov, moved.s02_pov);
    assert.equal(Object.keys(sidecar.nodes).length, Object.keys(final.nodes).length, 'every node has a position');
    await page.locator('#btnLayout').click();
    assert.notDeepEqual((await layoutOf()).s02_pov, moved.s02_pov, 'auto layout moved it back');
    await page.setInputFiles('#layoutOpen', layoutFile);
    await page.waitForFunction(([x, y]) => window.StoryEditor.state.layout.s02_pov.x === x && window.StoryEditor.state.layout.s02_pov.y === y, [moved.s02_pov.x, moved.s02_pov.y]);
    log(`ok  layout: drag moved s02_pov by (60, 40) world px, survives reload (localStorage), sidecar ep00.layout.json exported (${Object.keys(sidecar.nodes).length} nodes) and imported back; story JSON has no coordinates`);
  }

  // 14. A broken story shows what is wrong: red cards, red dangling links, a problem list; check_story.gd refuses it.
  {
    const broken = JSON.parse(JSON.stringify(original));
    broken.nodes.s02_pov.steps[0].options[0].next = 'nowhere';
    broken.nodes.orphan = { title: '沒人連到我', steps: [{ op: 'say', speaker: 'narrator', text: '孤兒節點' }, { op: 'end', text: '' }] };
    const brokenFile = path.join(out, 'broken_story.json');
    fs.writeFileSync(brokenFile, JSON.stringify(broken, null, 2) + '\n');
    await page.setInputFiles('#fileOpen', brokenFile);
    await page.waitForFunction(() => window.StoryEditor.story.nodes.orphan);
    assert.equal(await page.locator('.prow.dangling').count(), 1);
    assert.equal(await page.locator('.edge.bad').count(), 1);
    assert.deepEqual(await page.locator('.card.unreachable').evaluateAll(cards => cards.map(c => c.dataset.node).sort()), ['orphan', 's03_loud']);
    const items = (await page.locator('#problems li').allInnerTexts()).map(t => t.replace(/\s+/g, ' '));
    assert.equal(items.length, 3, items.join(' | '));
    await page.locator('#problems li', { hasText: 'nowhere' }).click();
    assert.equal((await state()).sel.type, 'edge');
    await page.screenshot({ path: path.join(out, 'editor-broken-shot.png') });
    log(`ok  broken story: 1 dangling link, red cards [orphan, s03_loud], problems: ${items.join(' | ')}`);
    if (arg('--godot')) {
      const run = spawnSync(arg('--godot'), ['--headless', '--path', project, '--script', 'res://tools/story_editor/check_story.gd', '--', brokenFile], { encoding: 'utf8', timeout: 180000 });
      const lines = (run.stdout + run.stderr).split('\n').filter(l => /^(OK|ERROR|FAILED)/.test(l));
      assert.equal(run.status, 1);
      assert.ok(lines.some(l => l.includes("StoryRunner rejects it")) && lines.some(l => l.includes('unreachable from')), lines.join('\n'));
      log(lines.join('\n'));
    }
  }

  // 15. file:// : no module scripts, the picker loads a story, no project data means text inputs.
  const filePage = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  const fileErrors = [];
  filePage.on('pageerror', e => fileErrors.push(e.message));
  await filePage.goto('file://' + path.join(project, 'tools', 'story_editor', 'index.html'));
  await filePage.waitForFunction(() => window.StoryEditor);
  await filePage.setInputFiles('#fileOpen', path.join(project, 'data', 'choices_story.json'));
  await filePage.waitForFunction(() => window.StoryEditor.story);
  assert.equal(await filePage.locator('#btnProjectSave').isHidden(), true, 'file URL keeps download workflow');
  const choices = JSON.parse(fs.readFileSync(path.join(project, 'data', 'choices_story.json'), 'utf8'));
  assert.equal(await filePage.locator('.card').count(), Object.keys(choices.nodes).length);
  assert.ok(await filePage.locator('#banner .note.info').count() >= 1, 'offline notice');
  await filePage.locator('.card .head').first().click();
  assert.ok(await filePage.locator('#inspector .step input[type=text]').count() >= 1, 'speaker is a text input without a catalog');
  assert.deepEqual(fileErrors, []);
  log(`ok  file:// page: picker loaded choices_story.json (${await filePage.locator('.card').count()} cards), offline notice shown, speaker is a text input`);

  assert.deepEqual(errors.filter(e => !/favicon/.test(e)), [], 'no page errors');
  await batch1Regression(browser, `http://127.0.0.1:${serverPort}/tools/story_editor/`, out);
  await sceneRegression(browser, `http://127.0.0.1:${serverPort}/tools/story_editor/`, out);
  log('ALL PASSED');
  }
} finally {
  await browser.close();
  server.kill();
}
