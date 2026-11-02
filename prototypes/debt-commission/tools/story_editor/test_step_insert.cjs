'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const Core = require('./story_core.js');
const { History } = require('./editor_state.js');

test('insert at the beginning, middle and before the ending preserves authored data and routes', () => {
  for (const index of [0, 40, 80]) {
    const lines = Array.from({length:80}, (_, i) => ({op:'say',speaker:'gintoki',text:`台詞 ${i}`,source_id:`L${i}`,offscreen:true}));
    const choice = {op:'choice',prompt:'往哪裡？',options:[{id:'a',label:'A',next:'after',require:{flag:true}}]};
    const node = {steps:[...structuredClone(lines), structuredClone(choice)],custom:'keep'};
    const step = {op:'say',speaker:'narrator',text:'插入'};
    assert.equal(Core.addStep(node, step, index), '');
    assert.equal(node.steps[index], step);
    assert.deepEqual(node.steps.filter(item => item !== step), [...lines,choice]);
    assert.equal(node.custom, 'keep');
  }
  const linked = {steps:[],next:'following'};
  assert.equal(Core.addStep(linked, Core.newStep('bg'), 0), '');
  assert.equal(Core.addStep(linked, Core.newStep('say'), 1), '');
  assert.equal(linked.next, 'following');
});

test('invalid positions and insertion around terminal steps reject without mutation', () => {
  for (const op of Core.NEEDS_NO_NEXT) {
    const node = {steps:[{op:'say',speaker:'narrator',text:'before'},Core.newStep(op)]};
    const original = structuredClone(node);
    assert.match(Core.addStep(node, Core.newStep('say'), 2), /之後/);
    assert.deepEqual(node, original);
    assert.equal(Core.addStep(node, Core.newStep('say'), 1), '');
    assert.equal(node.steps.at(-1).op, op);
  }
  for (const index of [-1, 3, 0.5, NaN, '1', null]) {
    const node = Core.newNode(), original = structuredClone(node);
    assert.match(Core.addStep(node, Core.newStep('say'), index), /位置/);
    assert.deepEqual(node, original);
  }
  const node = Core.newNode(), original = structuredClone(node);
  assert.match(Core.addStep(node, Core.newStep('choice'), 1), /最後一步/);
  assert.deepEqual(node, original, 'inserting never replaces the placeholder ending');
  const malformed = {steps:[{op:'end',text:'done'}, {op:'say',text:'unreachable'}]};
  const before = structuredClone(malformed);
  assert.match(Core.addStep(malformed, Core.newStep('say'), 0), /後面還有步驟/);
  assert.deepEqual(malformed, before);
});

test('insertion supports undo/redo and existing append behavior stays available', () => {
  const node = Core.newNode(), original = structuredClone(node);
  const history = new History({node});
  assert.equal(Core.addStep(node, {op:'say',speaker:'narrator',text:'new'}, 0), '');
  history.commit({node});
  assert.deepEqual(history.undo().node, original);
  assert.equal(history.redo().node.steps[0].text, 'new');
  assert.equal(Core.addStep(node, Core.newStep('bg')), '');
  assert.deepEqual(node.steps.map(s => s.op), ['say','say','bg','end']);
  assert.equal(Core.addStep(node, Core.newStep('choice')), '');
  const before = structuredClone(node);
  assert.match(Core.addStep(node, Core.newStep('end')), /已有結尾或分支/);
  assert.deepEqual(node, before);
});
