'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const Core = require('./story_core.js');
const { History } = require('./editor_state.js');

test('scene becomes a choice without losing its existing next route', () => {
  const original = {title:'場景', steps:[{op:'say',speaker:'gintoki',text:'您好'}], next:'next_scene'};
  const plan = Core.planSceneType(original, 'choice');
  assert.equal(plan.warning, '');
  assert.equal(Core.sceneType(plan.node), 'choice');
  assert.equal(plan.node.steps[0].text, '您好');
  assert.equal(plan.node.steps[1].options[0].next, 'next_scene');
  assert.equal(plan.node.steps[1].options[1].next, '');
  assert.equal('next' in plan.node, false);
  assert.equal(original.next, 'next_scene', 'planning never mutates the original');
});

test('new choices use distinct ids and preserve previously authored options', () => {
  const node = Core.planSceneType(Core.newNode(), 'choice').node;
  const choice = node.steps.at(-1);
  choice.options.push({id:'opt1',label:'已有',next:'somewhere',extra:true});
  assert.equal(Core.addChoiceOption(choice), '');
  assert.deepEqual(choice.options.at(-1), {id:'opt2',label:'新選項',next:''});
  assert.deepEqual(choice.options.at(-2), {id:'opt1',label:'已有',next:'somewhere',extra:true});
  assert.match(Core.addChoiceOption({op:'choice',options:'invalid'}), /JSON/);
});

test('replacing a real branch warns, does not guess between two routes, and supports undo', () => {
  const node = {title:'選擇', steps:[{op:'say',speaker:'narrator',text:'開始'},
    {op:'choice',prompt:'怎麼辦',options:[{id:'a',label:'A',next:'a'},{id:'b',label:'B',next:'b'}]}]};
  const snapshot = {nodes:{start:node}};
  const history = new History(snapshot);
  const plan = Core.planSceneType(node, 'goto');
  assert.match(plan.warning, /復原/);
  assert.equal(plan.node.steps.at(-1).target, '');
  assert.equal(plan.node.steps[0].text, '開始');
  assert.equal(node.steps.at(-1).options.length, 2);
  history.commit({nodes:{start:plan.node}});
  assert.deepEqual(history.undo(), snapshot);
  assert.equal(history.redo().nodes.start.steps.at(-1).op, 'goto');
});

test('single exit carries over without borrowing a previous investigation route', () => {
  const node = {title:'調查後',steps:[
    {op:'investigate',id:'find',hotspots:[{id:'clue',goto:'clue_response'}]},
    {op:'goto',target:'following'}]};
  const plan = Core.planSceneType(node, 'continue');
  assert.equal(plan.node.next, 'following');
  assert.equal(plan.node.steps[0].hotspots[0].goto, 'clue_response');
  assert.match(plan.warning, /復原/);
});

test('single branch destination transfers to condition and ordinary scenes', () => {
  const node = {steps:[{op:'choice',prompt:'選擇',options:[
    {id:'a',label:'A',next:'same'}, {id:'b',label:'B',next:'same'}]}]};
  const condition = Core.planSceneType(node, 'condition');
  assert.equal(condition.node.steps.at(-1).then, 'same');
  assert.equal(condition.node.steps.at(-1).else, '');
  assert.match(condition.warning, /復原/);
  const continuation = Core.planSceneType(node, 'continue');
  assert.equal(continuation.node.next, 'same');
  assert.equal(continuation.node.steps[0].op, 'say');
  assert.equal(node.steps[0].options.length, 2);
});

test('a step switches between dialogue and narration without losing text or metadata', () => {
  const node = {steps:[{op:'say',speaker:'gintoki',text:'有內容',source_id:'L01',offscreen:true}],next:'next'};
  const plan = Core.planStepType(node, 0, 'narration', 'say');
  assert.deepEqual(plan.node.steps[0], {op:'say',speaker:'narrator',text:'有內容',source_id:'L01'});
  assert.match(plan.warning, /畫外音/);
  assert.equal(node.steps[0].offscreen, true);
  const back = Core.planStepType(plan.node, 0, 'dialogue', 'say', 'shinpachi');
  assert.equal(back.node.steps[0].speaker, 'shinpachi');
  assert.equal(back.node.steps[0].text, '有內容');
});

test('step conversion carries shared text and refuses terminal steps in the middle', () => {
  const node = {steps:[{op:'say',speaker:'gintoki',text:'這句保留'}, {op:'end',text:'結束'}]};
  const comedy = Core.planStepType(node, 0, 'dialogue', 'comedy');
  assert.equal(comedy.node.steps[0].text, '這句保留');
  assert.equal(comedy.node.steps[0].speaker, 'gintoki');
  assert.match(comedy.warning, /復原/);
  assert.match(Core.planStepType(node, 0, 'event', 'choice').error, /最後一步/);
  assert.equal(node.steps[0].op, 'say');
});

test('changing a final step transfers a single next route and shows incomplete edges', () => {
  const node = {title:'start',steps:[{op:'say',speaker:'narrator',text:'改成選項'}],next:'after'};
  const plan = Core.planStepType(node, 0, 'event', 'choice');
  assert.match(plan.warning, /復原/);
  assert.equal(plan.node.steps[0].options[0].next, 'after');
  assert.equal('next' in plan.node, false);
  const story = {entry:'start',nodes:{start:plan.node,after:Core.newNode()}};
  assert.ok(Core.analyze(story).problems.some(p => p.type === 'unconnected'));
});

test('invalid requests and already selected types leave data unchanged', () => {
  const node = Core.newNode();
  assert.equal(Core.planStepType(node, 0, 'narration', 'say').changed, false);
  assert.match(Core.planStepType(node, 5, 'event', 'choice').error, /找不到/);
  assert.match(Core.planStepType(node, 0, 'event', 'fake').error, /不支援/);
  assert.equal(Core.planSceneType(node, 'end').changed, false);
  const malformed = {steps:[{op:'end',text:'done'},{op:'say',speaker:'narrator',text:'ignored'}]};
  assert.match(Core.planSceneType(malformed, 'choice').error, /後面還有步驟/);
});
