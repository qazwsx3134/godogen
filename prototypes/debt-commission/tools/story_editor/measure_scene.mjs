import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
const require=createRequire(import.meta.url);
const arg=(n,d)=>process.argv.includes(n)?process.argv[process.argv.indexOf(n)+1]:d;
const {chromium}=require(arg('--playwright','playwright-core'));
const root=path.resolve(arg('--root',path.resolve(import.meta.dirname,'../..')));
const out=arg('--out','/tmp/debt-scene-before.json');
const server=spawn('python3',['-m','http.server','8767','--bind','127.0.0.1','-d',root],{stdio:'ignore'});
let browser;
try {
 for(let i=0;i<50;i++){try{if((await fetch('http://127.0.0.1:8767/data/stories.json')).ok)break;}catch{}await new Promise(r=>setTimeout(r,100));}
 browser=await chromium.launch({executablePath:arg('--chromium',undefined),headless:true});
 const page=await browser.newPage({viewport:{width:1600,height:1000}});
 const start=performance.now();
 await page.goto('http://127.0.0.1:8767/tools/story_editor/?story=chapter1');
 await page.waitForFunction(()=>window.StoryEditor?.story?.generated_from==='story_src/chapter1.dialogue');
 const open=performance.now()-start;
 const metrics=await page.evaluate(async()=>{
  const E=StoryEditor;const source=JSON.parse(JSON.stringify(E.story));delete source.generated_from;source.id='measure_copy';
  E.loadStory(source,'measure_copy.json');
  E.centerOn(E.story.entry,.8);E.select({type:'node',id:E.story.entry});
  const input=document.querySelector('#inspector .field:nth-of-type(2) input');
  const card=document.querySelector(`.card[data-node="${E.story.entry}"]`);
  const t=performance.now();input.value+=' measured';input.dispatchEvent(new Event('input'));const field=performance.now()-t;
  await new Promise(requestAnimationFrame);
  const r=card.getBoundingClientRect();
  return{nodes:Object.keys(source.nodes).length,field_ms:field,head:{x:r.x+90,y:r.y+17}};
 });
 const t=performance.now();await page.mouse.move(metrics.head.x,metrics.head.y);await page.mouse.down();await page.mouse.move(metrics.head.x+100,metrics.head.y+80,{steps:20});await page.mouse.up();const drag=performance.now()-t;
 const result={open_ms:open,drag_ms:drag,...metrics,method:'1600x1000 Chromium; cold page open includes fetch; drag 20 Playwright input steps; synchronous title field input includes analysis/history/render/storage; temporary graph copy'};delete result.head;
 fs.writeFileSync(out,JSON.stringify(result,null,2));console.log(result);
}finally{await browser?.close();server.kill();}
