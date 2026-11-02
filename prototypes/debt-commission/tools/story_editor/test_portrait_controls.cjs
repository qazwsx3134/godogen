const {test} = require('node:test');
const assert = require('node:assert/strict');
const Core = require('./story_core.js');

test('entrance, exit and lighting have separate templates and labels', () => {
  assert.equal(Core.newStep('char').enter, true);
  for (const [op,label] of [['portrait_exit','角色退場'],['portrait_lighting','立繪明暗']]) {
    const step = Core.newStep(op);
    assert.equal(Core.stepGroup(step).id, 'character');
    assert.equal(Core.stepLabel(step), label);
    assert.equal(step.id, '');
  }
  const old = {op:'char',id:'shinpachi',visible:false,transition:'slide_right',source_id:'L01'};
  const original = structuredClone(old);
  assert.equal(Core.stepType(old), 'portrait_exit');
  assert.equal(Core.stepLabel(old), '角色退場');
  assert.deepEqual(old, original, 'displaying old exits never rewrites authored data');
});

test('switching portrait commands retains the character and compatible transition', () => {
  const node = {steps:[{op:'char',id:'shinpachi',visible:false,transition:'slide_right'}]};
  const enter = Core.planStepType(node, 0, 'character', 'char');
  assert.equal(enter.node.steps[0].enter, true);
  assert.equal(enter.node.steps[0].id, 'shinpachi');
  assert.equal(enter.node.steps[0].transition, 'slide_right');
  assert.equal('visible' in enter.node.steps[0], false);
  const exit = Core.planStepType(enter.node, 0, 'character', 'portrait_exit');
  assert.equal(exit.node.steps[0].op, 'portrait_exit');
  assert.equal(exit.node.steps[0].id, 'shinpachi');
  assert.equal(exit.node.steps[0].transition, 'slide_right');
  const light = Core.planStepType(exit.node, 0, 'character', 'portrait_lighting');
  assert.deepEqual(light.node.steps[0], {op:'portrait_lighting',id:'shinpachi',mode:'dim'});
  assert.equal(node.steps[0].visible, false);
});

test('portrait commands participate in asset usage and inserted steps', () => {
  const story = Core.newStory('portrait_controls');
  for (const op of ['portrait_exit', 'portrait_lighting', 'portrait_effect']) {
    const step = {...Core.newStep(op),id:'shinpachi'};
    assert.equal(Core.addStep(story.nodes.start, step, 0), '');
  }
  const used = Core.usedAssets(story, {characters:{shinpachi:{}}});
  assert.deepEqual(used.characters.shinpachi.nodes, ['start']);
  assert.equal(story.nodes.start.steps.at(-1).op, 'end');
});
