// Headless checks for story_core.js against the real data and against Godot.
//   node tools/story_editor/test_core.mjs [--out <scratch dir>] [--godot godot]
// Needs Godot for the reachability and rename checks (check_story.gd). Exits 1 on the first failure.
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const require = createRequire(import.meta.url);
const Core = require('./story_core.js');
const Authoring = require('./editor_state.js');
const arg = (name, fallback) => { const i = process.argv.indexOf(name); return i >= 0 ? process.argv[i + 1] : fallback; };
const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const godot = arg('--godot', 'godot');
const out = path.resolve(arg('--out', path.join(os.tmpdir(), 'story_editor_test')));
fs.mkdirSync(out, { recursive: true });

const files = fs.readdirSync(path.join(project, 'data')).filter(name => name.endsWith('_story.json')).sort();
const read = name => fs.readFileSync(path.join(project, 'data', name), 'utf8');
const log = (...parts) => console.log(...parts);

function checkStory(file, ...flags) {
  const run = spawnSync(godot, ['--headless', '--path', project, '--script', 'res://tools/story_editor/check_story.gd', '--', file, ...flags],
    { encoding: 'utf8', timeout: 180000 });
  return { code: run.status, stdout: run.stdout, stderr: run.stderr, text: run.stdout + run.stderr };
}
const okLine = run => run.stdout.split('\n').find(l => l.startsWith('OK ')) || run.text.trim();
function reachTable(file) {
  const run = checkStory(file, '--reach-all');
  const line = run.stdout.split('\n').find(l => l.startsWith('REACHALL '));
  assert.ok(line, `no REACHALL line from Godot for ${file}:\n${run.text}`);
  return JSON.parse(line.slice('REACHALL '.length));
}

// 1. The fallback lists in story_core.js are the runner's (the page reads the real file when it can).
{
  const runner = fs.readFileSync(path.join(project, 'scripts', 'story_runner.gd'), 'utf8');
  for (const [name, fallback] of Object.entries(Core.FALLBACK_ENUMS)) {
    assert.deepEqual(Core.parseGdStrings(runner, name), fallback, `${name} in story_core.js differs from story_runner.gd`);
  }
  log('ok  FALLBACK_ENUMS equal the lists in story_runner.gd');
}

// 2. Import -> export of every data file. Build output must come back byte for byte; hand-formatted files
//    (inline step objects) can only match as data, and the export is then the build's standard format.
for (const name of files) {
  const original = read(name);
  const story = JSON.parse(original);
  const exported = Core.exportText(story);
  assert.deepEqual(JSON.parse(exported), story, `${name}: export differs as data`);
  const same = exported === original;
  if (story.generated_from) assert.ok(same, `${name}: built by ${story.generated_from}, must export byte-equal`);
  log(`ok  ${name.padEnd(26)} deep-equal${same ? ' + byte-equal' : ' only (hand-formatted original)'}`);
}

// 3. Nothing dangling or unconnected in the shipped stories, so every reference kind is a real node.
const jsReach = {};
for (const name of files) {
  const story = JSON.parse(read(name));
  const analysis = Core.analyze(story);
  const bad = analysis.problems.filter(p => p.type !== 'unreachable');
  assert.deepEqual(bad, [], `${name}: ${JSON.stringify(bad)}`);
  assert.deepEqual(analysis.unreachable, [], `${name}: unreachable ${analysis.unreachable}`);
  jsReach[name] = story;
  const edges = Object.values(analysis.edges).flat();
  log(`ok  ${name.padEnd(26)} ${Object.keys(story.nodes).length} nodes, ${edges.length} edges, 0 unreachable, 0 dangling`);
}

// 4. Reachability from EVERY node as the start == Godot's story_builder.gd::_unreachable, for each data file.
{
  const kinds = new Set();
  for (const name of files) {
    const story = jsReach[name];
    const analysis = Core.analyze(story);
    for (const edge of Object.values(analysis.edges).flat()) kinds.add(edge.path.filter(p => typeof p === 'string').join('.'));
    const godotTable = reachTable(path.join(project, 'data', name));
    const ids = Object.keys(story.nodes);
    assert.deepEqual(Object.keys(godotTable).sort(), [...ids].sort());
    let differing = 0;
    for (const start of ids) {
      const reached = Core.reachableFrom(start, story.nodes, analysis.edges);
      const js = ids.filter(id => !reached.has(id)).sort();
      const gd = [...godotTable[start]].sort();
      assert.deepEqual(js, gd, `${name}: from '${start}' the editor and Godot disagree`);
      if (js.length) differing++;
    }
    log(`ok  ${name.padEnd(26)} ${ids.length} starts agree with Godot (${differing} starts miss some node)`);
  }
  log(`    edge shapes seen in the data: ${[...kinds].sort().join(' | ')}`);
}

// 5. Every reference kind, including the ones no shipped story uses, plus decoys that are not references.
{
  const leaf = id => [id, { title: id, steps: [{ op: 'end', text: '' }] }];
  const t = n => 't' + String(n).padStart(2, '0');
  const hub = {
    title: 'hub',
    steps: [
      { op: 'goto', target: t(1) },
      { op: 'condition', flag: 'f', equals: true, then: t(2), else: t(3) },
      { op: 'choice', prompt: 'p', options: [{ id: 'a', label: 'A', next: t(4) }, { id: 'b', label: 'B', next: t(5) }] },
      {
        op: 'investigate', id: 'inv', prompt: 'p',
        hotspots: [{ id: 'h1', label: 'H1', pos: [0.5, 0.5], goto: t(6) }, { id: 'h2', label: 'H2', pos: [0.5, 0.5], lines: [t(7), t(8)] }],
        talk: [{ id: 'k1', label: 'K1', goto: t(9) }],
        places: [{ id: 'p1', bg: 'black', hotspots: [{ id: 'h3', label: 'H3', goto: t(10) }, { id: 'h4', label: 'H4', lines: [t(11)] }], talk: [{ id: 'k2', label: 'K2', goto: t(12) }] }],
      },
      {
        op: 'boke_round', id: 'r1', speaker: 'gintoki', timer_seconds: 8, game_over: t(15), retry: t(16),
        lines: [{ id: 'a', text: 'x', listen: 'dec1' }],
        tsukkomi: { options: [{ id: 'o1', label: 'O1', result: 'perfect', goto: t(13) }], timeout: { result: 'fail', goto: t(14) } },
      },
      {
        op: 'boke_round', mode: 'testimony', id: 'r2', speaker: 'kagura', timer_seconds: 8, clear: t(17), game_over: t(18), retry: t(19),
        rules: { super: t(20), combo_bonus: t(21), combo_break: t(22) },
        lines: [
          { id: 'l1', text: 'x', listen: t(23), whiff: t(24), hint: t(25),
            slot: { timeout: t(26), options: [{ id: 'a', label: 'A', result: 'perfect', goto: t(27), when: [{ require_caught: ['l1'], result: 'hidden', goto: t(28) }] }], censor: { hidden: 'h', goto: t(29) } } },
          { id: 'l2', text: 'y', slot: { timeout: t(30), options: [{ id: 'a', label: 'A', result: 'perfect', goto: t(31) }], placard: { text: 'p', goto: t(32) } } },
          { id: 'l3', text: 'z', slot: { qte: { duration: 1, window: 0.1, late_after: 1, perfect: t(33), early: t(34), late: t(35) } } },
        ],
      },
      { op: 'result', title: 'T', lines: { S: { speaker: 'narrator', text: 'dec2' } } },
      { op: 'se', id: 'dec3' },
      { op: 'say', speaker: 'narrator', text: 'dec4' },
    ],
    next: t(36),
  };
  const story = { id: 'fixture', version: 'x', title: 'x', entry: 'hub', initial_flags: {}, nodes: Object.fromEntries([['hub', hub], ...Array.from({ length: 36 }, (_, i) => leaf(t(i + 1))), leaf('dec1'), leaf('dec2'), leaf('dec3'), leaf('dec4')]) };
  const analysis = Core.analyze(story);
  assert.deepEqual(analysis.unreachable, ['dec1', 'dec2', 'dec3', 'dec4'], 'JS: only the decoys are unreachable');
  assert.equal(analysis.edges.hub.length, 36, 'one edge per leaf');
  const file = path.join(out, 'fixture_story.json');
  fs.writeFileSync(file, Core.exportText(story));
  const gd = reachTable(file).hub;
  assert.deepEqual([...gd].sort(), ['dec1', 'dec2', 'dec3', 'dec4'], 'Godot: only the decoys are unreachable from hub');
  const camera = Core.edgesOf({ steps: [{ op: 'camera', target: 'center' }, { op: 'move', target: 'door' }], next: 'x' });
  assert.deepEqual(camera.map(e => e.key), ['next'], 'camera/move targets are stage marks, not nodes');
  log('ok  fixture: 36 reference kinds reached in both, decoys (v1 listen, result.lines, se id, say text) in neither');
}

// 6. The analysis is not vacuous: it reports what is broken.
{
  const story = JSON.parse(read('ep00_story.json'));
  const orphan = Core.newNode();
  story.nodes.orphan = orphan;
  story.nodes.s02_pov.steps[0].options[0].next = 'nowhere';
  Core.clearEdge(story, 's02_pov', Core.edgesOf(story.nodes.s02_pov)[1]);
  const problems = Core.analyze(story).problems;
  const has = (type, node) => problems.some(p => p.type === type && p.node === node);
  assert.ok(has('unreachable', 'orphan'), 'orphan is unreachable');
  assert.ok(has('dangling', 's02_pov'), 'nowhere is dangling');
  assert.ok(has('unconnected', 's02_pov'), 'the cleared option is unconnected');
  assert.ok(has('unreachable', 's03_loud') && has('unreachable', 's03_calm'), 'targets that lost their only route are unreachable');
  log(`ok  broken ep00 copy reports: ${problems.map(p => p.type + ':' + p.node).join(', ')}`);
}

// 7. Rename keeps every reference (and the entry); the renamed file still loads in the game.
{
  const story = JSON.parse(read('chapter1_story.json'));
  const before = Core.analyze(story);
  const incoming = {};
  for (const edge of Object.values(before.edges).flat()) incoming[edge.target] = (incoming[edge.target] || 0) + 1;
  const busiest = Object.entries(incoming).sort((a, b) => b[1] - a[1]).find(([id]) => id !== story.entry)[0];
  assert.equal(Core.renameNode(story, busiest, Object.keys(story.nodes)[1]), `已經有節點叫「${Object.keys(story.nodes)[1]}」`);
  assert.equal(Core.renameNode(story, busiest, 'renamed_busiest'), '');
  assert.equal(Core.renameNode(story, story.entry, 'renamed_entry'), '');
  const after = Core.analyze(story);
  assert.deepEqual(after.problems, [], 'rename leaves nothing dangling');
  assert.equal(story.entry, 'renamed_entry');
  const file = path.join(out, 'chapter1_renamed.json');
  fs.writeFileSync(file, Core.exportText(story));
  const run = checkStory(file, '--write');
  assert.equal(run.code, 0, run.text);
  log(`ok  chapter1: '${busiest}' (${incoming[busiest]} references) and the entry renamed -> ${okLine(run)}`);
}

// 8. A story made with the editor's own newStory/newNode loads once check_story.gd --write has set `version`.
{
  const story = Core.newStory('editor_demo');
  const a = Core.newNode();
  const b = Core.newNode();
  story.nodes.a = a;
  story.nodes.b = b;
  story.nodes.start.steps = [Core.newStep('say'), Core.newStep('choice')];
  story.nodes.start.steps[1].options[0].next = 'a';
  story.nodes.start.steps[1].options[1].next = 'b';
  assert.deepEqual(Core.analyze(story).problems, []);
  const file = path.join(out, 'editor_demo_story.json');
  fs.writeFileSync(file, Core.exportText(story));
  const stale = checkStory(file);
  assert.equal(stale.code, 1);
  assert.match(stale.text, /version is 's-unset'/);
  const fixed = checkStory(file, '--write');
  assert.equal(fixed.code, 0, fixed.text);
  assert.equal(checkStory(file).code, 0);
  log(`ok  new story: stale version reported, then ${okLine(fixed)}`);
}

// 9. insertIndex keeps new lines ahead of the closing step.
{
  const node = Core.newNode();
  assert.equal(Core.insertIndex(node, 'say'), 1);
  assert.equal(Core.insertIndex(node, 'end'), 2);
  assert.equal(Core.insertIndex({ steps: [] }, 'say'), 0);
  log('ok  insertIndex');
}
// 10. History branching, bounded snapshots and recursive literal search.
{
  const h = new Authoring.History({ text: '' }, 3);
  h.commit({ text: 'a' }, 'field'); h.commit({ text: 'ab' }, 'field');
  assert.deepEqual(h.undo(), { text: '' });
  assert.deepEqual(h.redo(), { text: 'ab' });
  h.undo(); h.commit({ text: 'new' }); assert.equal(h.canRedo, false);
  const detached = h.current; detached.text = 'mutated'; assert.equal(h.current.text, 'new');
  h.commit({ text: 'next' }); h.commit({ text: 'last' });
  assert.equal(h.entries.length, 3); assert.deepEqual(h.undo(), { text: 'next' });
  h.reset({ text: 'other document' }); assert.equal(h.canUndo, false);
  const story = { nodes: { cafe: { title: 'Café', steps: [{ op: 'say', speaker: 'gintoki', text: '[.*] 台詞', nested: { text: '分支文字' } }] } } };
  assert.equal(Authoring.search(story, '[.*]')[0].path, 'steps.0.text');
  assert.equal(Authoring.search(story, 'GINTOKI')[0].node, 'cafe');
  assert.equal(Authoring.search(story, 'Cafe\u0301')[0].path, 'title');
  assert.equal(Authoring.search(story, '分支')[0].path, 'steps.0.nested.text');
  assert.equal(Authoring.search(story, '  ').length, 0);
  log('ok  authoring history: coalescing, branching, limit, clone isolation, reset; recursive Unicode literal search');
}
log('ALL PASSED');
