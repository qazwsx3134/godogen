import assert from 'node:assert/strict';
import fs from 'node:fs';
export async function sceneRegression(browser, base, out) {
  const context = await browser.newContext({viewport:{width:1600,height:1000},acceptDownloads:true});
  const page = await context.newPage(); const errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  page.on('dialog',d=>d.accept());
  try {
    await page.goto(base+'?story=chapter1');
    await page.waitForFunction(()=>window.StoryEditor?.story);
    assert.equal(await page.locator('.card').count(),96);
    await page.evaluate(()=>{StoryEditor.fit(.1);});
    await page.screenshot({path:out+'/chapter1-full.png'});
    const original=await page.evaluate(()=>JSON.stringify(StoryEditor.story));
    await page.evaluate(()=>{const E=StoryEditor;E.centerOn(E.story.entry,1);E.select({type:'node',id:E.story.entry});});
    assert.equal(await page.locator('#btnAddNode').isDisabled(),true);
    assert.equal(await page.locator('#inspector textarea').first().isDisabled(),true);
    const card=page.locator('.card.entry');
    assert.ok(await card.locator('.bg-thumb img').count());
    await page.evaluate(async()=>{await Promise.all([...document.images].map(i=>i.decode().catch(()=>{})));});
    assert.ok(await card.locator('.bg-thumb img').evaluate(i=>i.naturalWidth>0));
    const group=card.locator('.flow-group.group-dialogue').first();
    const key=await group.getAttribute('data-run');
    const beforeText=await page.evaluate(()=>StoryEditor.exportText());
    await group.click(); assert.equal(await group.getAttribute('aria-expanded'),'true');
    assert.equal(await page.evaluate(()=>StoryEditor.exportText()),beforeText,'collapse does not edit story');
    await card.locator('.flow-node.group-dialogue[data-step]').first().click();
    assert.ok(await page.locator('#inspector .search-hit').count());
    await page.screenshot({path:out+'/chapter1-expanded.png'});
    const dl=page.waitForEvent('download');await page.locator('#btnLayoutExport').click();
    const sidecar=await dl;await sidecar.saveAs(out+'/chapter1.layout.json');
    const exported=JSON.parse(fs.readFileSync(out+'/chapter1.layout.json'));
    assert.equal(exported.nodes[await card.getAttribute('data-node')].expanded[key],true);
    await group.click();assert.equal(await group.getAttribute('aria-expanded'),'false');
    await page.setInputFiles('#layoutOpen',out+'/chapter1.layout.json');
    await page.waitForFunction(key=>[...document.querySelectorAll('.card.entry .flow-group')].some(b=>b.dataset.run===key && b.getAttribute('aria-expanded')==='true'),key);
    assert.equal(await group.getAttribute('aria-expanded'),'true');
    await page.reload();await page.waitForFunction(()=>window.StoryEditor?.story);
    assert.equal(await page.locator('.card.entry .flow-group.group-dialogue').first().getAttribute('aria-expanded'),'true');
    assert.equal(await page.evaluate(()=>JSON.stringify(StoryEditor.story)),original);
    // Convert with the real UI, then alter a line and download the graph source.
    page.removeAllListeners('dialog');
    page.once('dialog',d=>d.accept('chapter1_scene_graph'));
    await page.locator('#btnConvert').click();
    page.on('dialog',d=>d.accept());
    assert.equal(await page.evaluate(()=>StoryEditor.isReadOnly()),false);
    assert.equal(await page.locator('#btnAddNode').isDisabled(),false);
    assert.equal(await page.evaluate(()=>StoryEditor.story.generated_from),undefined);
    assert.equal(await page.evaluate(()=>StoryEditor.conversionRegistry.stories.at(-1).authoring),'graph');
    await page.evaluate(()=>{const E=StoryEditor;E.centerOn(E.story.entry,.85);E.select({type:'node',id:E.story.entry});});
    const foldBefore = await page.evaluate(()=>structuredClone(StoryEditor.state.layout[StoryEditor.story.entry].expanded));
    await page.locator('#addStepPicker summary').click();
    await page.locator('#addStepOp').selectOption('narration:say');
    await page.getByRole('button',{name:'＋ 新增步驟',exact:true}).click();
    assert.equal(await page.evaluate(()=>StoryEditor.state.layout[StoryEditor.story.entry].expanded),undefined);
    await page.locator('#btnUndo').click();
    assert.deepEqual(await page.evaluate(()=>StoryEditor.state.layout[StoryEditor.story.entry].expanded),foldBefore);
    await page.evaluate(()=>StoryEditor.select({type:'node',id:StoryEditor.story.entry}));
    const say=await page.evaluate(()=>StoryEditor.story.nodes[StoryEditor.story.entry].steps.findIndex(s=>s.op==='say'));
    const text=page.locator(`#inspector [data-step="${say}"] textarea`).first();
    await text.fill('編輯器轉出的測試台詞。');
    const download=page.waitForEvent('download');await page.locator('#btnExport').click();
    await (await download).saveAs(out+'/scene-graph-export.json');
    const graph=JSON.parse(fs.readFileSync(out+'/scene-graph-export.json'));
    assert.equal(graph.nodes[graph.entry].steps[say].text,'編輯器轉出的測試台詞。');
    const registryDownload=page.waitForEvent('download');await page.locator('#btnRegistry').click();await (await registryDownload).saveAs(out+'/scene-registry.json');
    assert.equal(JSON.parse(fs.readFileSync(out+'/scene-registry.json')).stories.at(-1).authoring,'graph');
    await page.locator('#addStepPicker summary').click();
    await page.locator('#addStepPicker').scrollIntoViewIfNeeded();
    assert.deepEqual(await page.locator('#addStepOp optgroup').evaluateAll(g=>g.map(x=>x.label)),['對話','旁白','立繪','背景・音樂','音效','事件','效果']);
    const values=await page.locator('#addStepOp option').evaluateAll(o=>o.map(x=>x.value));
    assert.ok(!values.some(v=>/legacy|:show$|:set_flag$/.test(v)));
    await page.screenshot({path:out+'/add-step-menu.png'});
    // Reload recovers graph copy and registry via its draft, source remains untouched.
    await page.goto(base);await page.waitForFunction(()=>window.StoryEditor?.story);
    await page.getByRole('button',{name:'復原草稿',exact:true}).click();
    assert.equal(await page.evaluate(()=>StoryEditor.story.id),'chapter1_scene_graph');
    assert.equal(await page.locator('#btnRegistry').isVisible(),true);
    console.log('ok  scene cards: 96 nodes, image decode, read-only source, collapse sidecar/localStorage, copy/edit/export/draft registry');

    await page.goto(base+'?story=phase3');await page.waitForFunction(()=>window.StoryEditor?.story);
    await page.evaluate(()=>{ const s=structuredClone(StoryEditor.story); s.id='phase3_scene_graph'; delete s.generated_from; StoryEditor.loadStory(s,'phase3_scene_graph.json'); });
    const node=await page.evaluate(()=>Object.entries(StoryEditor.story.nodes).find(([id,n])=>n.steps.some(s=>s.op==='bg')&&n.steps.some(s=>s.op==='bgm'))?.[0] || StoryEditor.story.entry);
    await page.evaluate(id=>{StoryEditor.centerOn(id,.9);StoryEditor.select({type:'node',id});},node);
    await page.locator('#addStepPicker summary').click();
    await page.locator('#addStepOp').selectOption('scene:bgm');
    await page.getByRole('button',{name:'＋ 新增步驟',exact:true}).click();
    for(let index=await page.evaluate(id=>StoryEditor.story.nodes[id].steps.findIndex(s=>s.op==='bgm'),node);index>1;index--) {
      await page.locator(`#inspector [data-step="${index}"]`).getByRole('button',{name:'↑',exact:true}).click();
    }
    await page.evaluate(()=>{for(const id of ['infoBox','problemBox','searchBox'])document.getElementById(id).open=false;});
    const bgIndex=await page.evaluate(id=>StoryEditor.story.nodes[id].steps.findIndex(s=>s.op==='bg'),node);
    const bgmIndex=await page.evaluate(id=>StoryEditor.story.nodes[id].steps.findIndex(s=>s.op==='bgm'),node);
    await page.locator(`#inspector [data-step="${bgIndex}"]`).scrollIntoViewIfNeeded();
    const bg=page.locator(`#inspector [data-step="${bgIndex}"] select`);
    await bg.selectOption('black');assert.equal(await page.locator(`#inspector [data-step="${bgIndex}"] .bg-thumb img`).count(),0);
    await bg.selectOption('yorozuya_living_room');
    const music=page.locator(`#inspector [data-step="${bgmIndex}"] select`);
    await music.selectOption('bgm_daily');
    await page.locator(`#inspector [data-step="${bgIndex}"]`).scrollIntoViewIfNeeded();
    await page.screenshot({path:out+'/phase3-bg-bgm.png'});
    // Mock just browser Audio to assert exclusive player lifecycle without depending on an output device.
    await page.evaluate(()=>{window.audioEvents=[];window.Audio=class{constructor(src){this.src=src;} play(){audioEvents.push(['play',this.src]);return Promise.resolve();} pause(){audioEvents.push(['pause',this.src]);}addEventListener(){}};});
    await page.locator(`#inspector [data-step="${bgmIndex}"] [data-audition]`).click();
    await page.evaluate(()=>{StoryEditor.state.catalog.music.bgm_meeting.path='res://assets/audio/music/gintama_01.ogg';});
    await music.selectOption('bgm_meeting');
    await page.locator(`#inspector [data-step="${bgmIndex}"] [data-audition]`).click();
    await page.locator(`#inspector [data-step="${bgmIndex}"] [data-audition]`).click();
    assert.deepEqual(await page.evaluate(()=>audioEvents.map(x=>x[0])),['play','pause','play','pause']);
    await music.selectOption('');assert.equal(await page.evaluate(([id,i])=>StoryEditor.story.nodes[id].steps[i].id,[node,bgmIndex]),'');
    // Exercise the new structured forms through UI events, including typed values and field preservation.
    await page.evaluate(()=>StoryEditor.loadStory({id:'forms_graph',version:'s-unset',title:'forms',entry:'start',initial_flags:{met:false,trust:0},nodes:{
      start:{steps:[{op:'char',id:'gintoki',expression:'cry',custom:'keep'},{op:'item',id:'milk_bottle'},{op:'se',id:'crow'},{op:'flag',key:'trust',value:0},{op:'condition',flag:'met',equals:true,then:'end',else:'end'}]},end:{steps:[{op:'end',text:''}]}
    }},'forms_graph.json'));
    await page.evaluate(()=>StoryEditor.select({type:'node',id:'start'}));
    const char=page.locator('#inspector [data-step="0"]');
    const expressions=await char.locator('select').nth(1).locator('option').evaluateAll(o=>o.map(x=>({value:x.value,label:x.label})));
    assert.ok(expressions.some(x=>x.value==='angry'));
    assert.ok(expressions.some(x=>x.value==='cry'&&x.label.includes('目前的值')));
    assert.ok(!expressions.some(x=>x.value==='smile'));
    await char.locator('select').nth(1).selectOption('angry');
    assert.equal(await page.evaluate(()=>StoryEditor.story.nodes.start.steps[0].custom),'keep');
    await page.locator('#inspector [data-step="1"] select').selectOption('salary_envelope');
    await page.locator('#inspector [data-step="2"] select').selectOption('glass_crack');
    const flag=page.locator('#inspector [data-step="3"]');
    await flag.locator('select').nth(1).selectOption('add');
    await flag.locator('input').fill('-2');await flag.locator('input').dispatchEvent('change');
    assert.equal(await page.evaluate(()=>StoryEditor.story.nodes.start.steps[3].add),-2);
    assert.equal(await page.evaluate(()=>'value' in StoryEditor.story.nodes.start.steps[3]),false);
    await flag.locator('input').fill('1.5');await flag.locator('input').dispatchEvent('change');
    assert.equal(await page.evaluate(()=>StoryEditor.story.nodes.start.steps[3].add),-2,'invalid fractional add does not replace value');
    const condition=page.locator('#inspector [data-step="4"]');
    await condition.locator('select').first().selectOption('tree');
    await condition.locator('select').nth(1).selectOption('all');
    await condition.getByRole('button',{name:'＋條件',exact:true}).click();
    await condition.locator('.condition-child').nth(1).locator('select').first().selectOption('has');
    await condition.locator('.condition-child').nth(1).locator('select').nth(1).selectOption('salary_envelope');
    const forms=await page.evaluate(()=>StoryEditor.story.nodes.start.steps);
    assert.equal(forms[1].id,'salary_envelope');assert.equal(forms[2].id,'glass_crack');
    assert.equal(forms[4].test.all[1].has,'salary_envelope');assert.equal('flag' in forms[4],false);
    assert.equal(forms[4].then,'end');assert.equal(forms[4].else,'end');
    console.log('ok  char expression filtering/current value, item/se, integer flag add and recursive condition forms');

    // Dense graph checks actual browser rendering, edit locality and no unintended mutation.
    await page.evaluate(()=>{const s=StoryCore.newStory('dense_browser');s.nodes={};s.entry='n0';for(let i=0;i<240;i++)s.nodes['n'+i]={title:'密集'+i,steps:[{op:'say',speaker:'narrator',text:'台詞'},...(i===239?[{op:'end',text:''}]:[])],...(i<239?{next:'n'+(i+1)}:{})};StoryEditor.loadStory(s,'dense_browser.json');StoryEditor.select({type:'node',id:'n0'});window.untouchedCard=document.querySelector('.card[data-node=n200]');});
    await page.locator('#inspector > .field').nth(1).locator('input').fill('修改標題');
    assert.equal(await page.evaluate(()=>untouchedCard===document.querySelector('.card[data-node=n200]')),true,'unmodified card DOM reused');
    assert.equal(await page.locator('.card').count(),240);
    assert.equal(await page.evaluate(()=>StoryEditor.state.a.problems.length),0);
    assert.deepEqual(errors,[]);
    console.log('SCENE REGRESSIONS PASSED');
  } catch(err) {await page.screenshot({path:out+'/scene-failure.png'});throw err;}
  finally{await context.close();}
}
