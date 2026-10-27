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

// 9. New scenes can become branches without putting an unreachable choice after the placeholder end.
{
  const node = Core.newNode();
  assert.equal(Core.insertIndex(node, 'say'), 1);
  assert.equal(Core.insertIndex(node, 'end'), 2);
  assert.equal(Core.insertIndex({ steps: [] }, 'say'), 0);
  assert.equal(Core.addStep(node, Core.newStep('choice')), '');
  assert.deepEqual(node.steps.map(step => step.op), ['say', 'choice']);
  assert.equal(Core.addStep(node, {op: 'say', speaker: 'narrator', text: '在選項前'}), '');
  assert.deepEqual(node.steps.map(step => step.op), ['say', 'say', 'choice']);
  const before = JSON.stringify(node);
  assert.match(Core.addStep(node, Core.newStep('end')), /已有結尾或分支/);
  assert.equal(JSON.stringify(node), before, 'a real branch is not silently replaced');
  const linked = {steps: [{op: 'say', speaker: 'narrator', text: '有後續'}], next: 'elsewhere'};
  assert.match(Core.addStep(linked, Core.newStep('choice')), /先斷開連線/);
  assert.equal(linked.steps.length, 1);

  const invalid = Core.newStory('terminal_order');
  invalid.nodes.start.steps.push({op: 'say', speaker: 'narrator', text: '永遠不會出現'});
  assert.ok(Core.analyze(invalid).problems.some(problem => problem.type === 'terminal-middle'));
  const file = path.join(out, 'terminal_order_story.json');
  fs.writeFileSync(file, Core.exportText(invalid));
  const result = checkStory(file, '--write');
  assert.equal(result.code, 1, result.text);
  assert.match(result.text, /later steps cannot execute/);
  assert.equal(JSON.parse(fs.readFileSync(file, 'utf8')).version, 's-unset', 'invalid story was not published');
  log('ok  placeholder end is replaced by a branch; authored endings are kept; unreachable steps are rejected');
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
// Scene view contract: shared classification, route joins, fixed points, layout and copies.
{
  for (const group of Core.STEP_GROUPS) for (const op of group.ops) {
    if (op === 'say') continue;
    assert.equal(Core.stepGroup({op}).id, group.id, op);
  }
  assert.equal(Core.stepGroup({op:'say',speaker:'narrator'}).id,'narration');
  assert.equal(Core.stepGroup({op:'say',speaker:''}).id,'narration');
  assert.equal(Core.stepGroup({op:'say',speaker:'gintoki'}).id,'dialogue');
  assert.equal(Core.STEP_GROUPS.slice(0,7).flatMap(g=>g.ops).some(op=>Core.STEP_GROUPS[7].ops.includes(op)),false);
  const node = {steps:[{op:'say',speaker:'a'},{op:'say',speaker:'b'},{op:'bg',id:'room'},{op:'bgm',id:'song'},{op:'end',text:''}]};
  const runs=Core.stepRuns(node);assert.deepEqual(runs.map(r=>r.indices),[[0,1],[2,3],[4]]);
  const layout=JSON.parse(JSON.stringify({x:10,y:20,expanded:{[runs[0].key]:true}}));
  assert.equal(Core.runExpanded(layout,runs[0]),true);assert.equal(Core.runExpanded(layout,runs[1]),false);
  assert.equal(Core.cardSize(node,1,layout).h-Core.cardSize(node,1).h,50);
  const n=(steps,next)=>({steps,...(next?{next}: {})});
  const story={id:'routes',entry:'start',nodes:{
    start:n([{op:'choice',options:[{next:'a'},{next:'b'}]}]),
    a:n([{op:'bg',id:'room'},{op:'bgm',id:'song'}],'join'),
    b:n([{op:'bg',id:'other'},{op:'bgm',id:'song'}],'join'),
    join:n([{op:'say',speaker:'narrator',text:'join'}],'stop'),
    stop:n([{op:'bgm',id:''}],'after'),after:n([{op:'end',text:''}]),
    orphan:n([{op:'goto',target:'orphan'}]),
  }};
  let media=Core.effectiveMedia(story);
  assert.equal(media.join.bg.status,'mixed');assert.equal(media.join.bgm.status,'inherited');assert.equal(media.join.bgm.id,'song');
  story.nodes.b.steps[1].id='other_song';
  assert.equal(Core.effectiveMedia(story).join.bgm.status,'mixed');
  story.nodes.b.steps[1].id='song';
  assert.equal(media.start.bg.status,'none');assert.equal(media.after.bgm.status,'none');assert.equal(media.orphan.bg.status,'none');
  story.nodes.b.steps[0].id='room';media=Core.effectiveMedia(story);assert.equal(media.join.bg.status,'inherited');assert.equal(media.join.bg.id,'room');
  story.nodes.join.next='a';media=Core.effectiveMedia(story);assert.equal(media.join.bg.id,'room'); // converges with cycle
  story.nodes.b.steps= [{op:'goto',target:'join'}];media=Core.effectiveMedia(story);assert.equal(media.join.bg.status,'mixed'); // none is a distinct route
  story.nodes.join.steps.push({op:'bg',id:'explicit'},{op:'bg',id:'last'});assert.equal(Core.effectiveMedia(story).join.bg.id,'last');
  const catalog=JSON.parse(fs.readFileSync(path.join(project,'data','asset_catalog.json'),'utf8'));
  assert.ok(Core.availableExpressions(catalog,'gintoki').includes('angry'));
  assert.ok(!Core.availableExpressions(catalog,'gintoki').includes('cry'));
  assert.deepEqual(Core.availableExpressions(catalog,'missing'),[]);
  const source=JSON.parse(read('ep00_story.json')), before=JSON.stringify(source);
  const registry={metadata:'preserved',stories:[{id:'ep00',path:'res://data/ep00_story.json',authoring:'dialogue'}]};
  const copy=Core.graphCopy(source,'ep00_graph',registry);
  assert.equal(copy.story.id,'ep00_graph');assert.equal(copy.story.generated_from,undefined);assert.equal(copy.story.version,'s-unset');
  assert.equal(copy.registry.stories.at(-1).authoring,'graph');assert.equal(copy.registry.metadata,'preserved');
  assert.equal(JSON.stringify(source),before);assert.equal(registry.stories.length,1);
  assert.throws(()=>Core.graphCopy(source,'ep00',registry));assert.throws(()=>Core.graphCopy(source,'../bad',registry));
  const dense=Core.newStory('dense');dense.nodes={};dense.entry='n0';
  for(let i=0;i<240;i++)dense.nodes['n'+i]=n([{op:'say',speaker:'narrator',text:'dense'},...(i===239?[{op:'end',text:''}]:[])],i===239?null:'n'+(i+1));
  assert.equal(Core.analyze(dense).unreachable.length,0);assert.equal(Object.keys(Core.autoLayout(dense)).length,240);
  const copyFile=path.join(out,'ep00_graph.json');fs.writeFileSync(copyFile,Core.exportText(copy.story));
  assert.equal(checkStory(copyFile,'--write').code,0);
  log('ok  scene classification, joins/none/cycles/last explicit media, collapse geometry, expressions, graph conversion and 240 nodes');
}

{
  const source = JSON.parse(read('ep00_story.json'));
  source.default_pov = 'gintoki';
  source.credits = [{ role: '劇本', names: ['作者'] }, { role: '繪', names: ['畫師'], extra: { names: ['甲', '乙'] } }];
  assert.deepEqual(JSON.parse(Core.exportText(source)), source);
  const registry = {stories:[{id:source.id,skin:'plain',cover:'res://assets/image/cover.png',future:{names:['keep']}}]};
  const copy = Core.graphCopy(source, 'credits_graph',registry);
  assert.equal(copy.story.default_pov,'gintoki');
  assert.equal(copy.registry.stories.at(-1).skin,'plain');
  assert.equal(copy.registry.stories.at(-1).cover,'res://assets/image/cover.png');
  assert.deepEqual(copy.registry.stories.at(-1).future,{names:['keep']});
  assert.deepEqual(copy.story.credits, source.credits);
  copy.story.credits[1].extra.names.push('丙');
  assert.deepEqual(source.credits[1].extra.names, ['甲', '乙']);
  assert.equal(Core.stepLabel({op:'say',speaker:'narrator'}), '旁白');
  assert.equal(Core.stepLabel({op:'char'}), '角色登場／表情');
  log('ok  root credits round trip and graph conversion preserve unknown nested fields, copy isolation; Chinese labels');
}
{
  // 故事包: rows and catalogs as story_library.gd / StoryRunner.read_catalog read them (titan test work).
  const read = rel => JSON.parse(fs.readFileSync(path.join(project, rel), 'utf8'));
  const pack = read('tests/fixtures/packs/titan/pack.json');
  const rows = Core.packEntries(pack, 'titan');
  assert.deepEqual(rows.map(e => [e.id, e.kind, e.path, e.save, e.work, e.work_title]), [
    ['titan_ch1', 'chapter', 'res://stories/titan/ch1_story.json', 'user://pack_titan_titan_ch1.save', 'titan', '測試作品：城牆'],
    ['titan_ch2', 'chapter', 'res://stories/titan/ch2_story.json', 'user://pack_titan_titan_ch2.save', 'titan', '測試作品：城牆']]);
  assert.equal(rows[0].cover, undefined, "a row keeps only its own cover; the pack's is the default");
  const base = read('data/asset_catalog.json');
  const own = { extends: 'res://data/asset_catalog.json', characters: { eren: { name: '艾連', path: 'art/eren.png', expressions: { angry: 'art/eren_angry.png', calm: 'res://x.png' } } },
    backgrounds: { wall: { top: '#000', bottom: '#111', path: 'art/wall.png' } } };
  const catalog = Core.resolveCatalog(own, 'res://stories/titan', base);
  assert.equal(catalog.characters.eren.path, 'res://stories/titan/art/eren.png');
  assert.deepEqual(catalog.characters.eren.expressions, { angry: 'res://stories/titan/art/eren_angry.png', calm: 'res://x.png' });
  assert.ok(catalog.characters.shinpachi && catalog.backgrounds.yorozuya_living_room && catalog.backgrounds.wall, 'extends lays the base under it');
  assert.equal(catalog.extends, undefined); assert.equal(base.characters.eren, undefined, 'the base is not changed');
  assert.equal(Core.resolveCatalog(read('tests/fixtures/packs/titan/catalog.json'), 'res://tests/fixtures/packs/titan').backgrounds.wall.path,
    'res://tests/fixtures/packs/titan/art/wall.png');
  const copy = Core.graphCopy({ id: 'titan_ch1', nodes: {}, generated_from: 'x' }, 'titan_ch1_graph', { stories: rows }, rows[0]);
  assert.deepEqual(copy.registry.stories.at(-1), { ...rows[0], id: 'titan_ch1_graph', path: 'res://stories/titan/titan_ch1_graph_story.json',
    save: 'user://pack_titan_titan_ch1_graph.save', authoring: 'graph' });
  log('ok  story packs: rows with res:// paths and per-work saves; catalogs resolve relative art and extends; a work copy stays in its folder');
}
{
  // 美術待辦: the same answers as scripts/asset_usage.gd + tools/art_check (tests/test_art_check.gd pins both).
  const read = rel => JSON.parse(fs.readFileSync(path.join(project, rel), 'utf8'));
  const catalog = Core.resolveCatalog(read('tests/fixtures/art_check/shapes/catalog.json'), 'res://tests/fixtures/art_check/shapes');
  const byNode = Core.missingArt(read('tests/fixtures/art_check/shapes/ch1_story.json'), catalog);
  const todo = new Set(Object.values(byNode).flat().map(m => [m.kind, m.id, m.face || ''].join(':')));
  assert.deepEqual([...todo].sort(), ['background:dusk:', 'character:shadow:', 'face:hero:angry'], 'the art check fixture work\'s three to-dos (not the flat black)');
  assert.deepEqual(Object.keys(byNode).sort(), ['hall', 'start']);
  const small = { backgrounds: { room: {}, yard: {} }, characters: { a: {}, b: {} }, items: { key: {} }, sounds: {}, music: { song: {} } };
  const story = { nodes: {
    n1: { steps: [{ op: 'investigate', places: [{ bg: 'yard', hotspots: [{ item: 'key', character: 'b' }] }] },
      { op: 'say', speaker: 'a+b', text: '', expression: 'smile' }, { op: 'bgm', id: 'song' },
      { op: 'say', speaker: 'nobody', text: '' }, { op: 'bg', id: 'room' }] },
    n2: { steps: [{ op: 'boke_round', lines: [{ speaker: 'b', text: '' }] },
      { op: 'choice', options: [{ text: 'x', require: 'key', next: 'n1' }] }] } } };
  const used = Core.usedAssets(story, small, 'a');
  assert.deepEqual(used.backgrounds, { room: ['n1'], yard: ['n1'] }); assert.deepEqual(used.investigation, { yard: true });
  assert.deepEqual(used.items, { key: ['n1', 'n2'] }); assert.deepEqual(used.music, { song: ['n1'] });
  assert.deepEqual(used.characters.a.expressions, { smile: ['n1'], thinking: ['（選項時）'] });
  assert.deepEqual(used.characters.b.expressions, { neutral: ['n1'], smile: ['n1'], annoyed: ['n2'] });
  assert.equal(used.characters.nobody, undefined);
  log('ok  missing-art marks: same to-dos as the GDScript art check; same usage (rounds annoyed, POV thinking) as asset_usage.gd');
}
log('ALL PASSED');
