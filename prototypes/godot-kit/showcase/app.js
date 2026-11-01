'use strict';
const $=id=>document.getElementById(id), entries=window.VFX_DATA;
const canvas=$('preview'),ctx=canvas.getContext('2d');
let selected=null,image=null,player=null,token=0,last=0,activeMode='sprite';
const reduced=window.matchMedia('(prefers-reduced-motion: reduce)').matches;
$('sprite-count').textContent=entries.length;
function renderList(){
  const query=$('search').value.toLowerCase().trim();
  const matches=entries.filter(e=>(e.name+' '+e.id).toLowerCase().includes(query));
  $('effect-list').replaceChildren(...matches.map(e=>{
    const button=document.createElement('button');button.className='effect-item';
    button.type='button';button.dataset.id=e.id;button.setAttribute('aria-pressed',String(selected?.id===e.id));
    const title=document.createElement('span');title.textContent=e.name;
    const meta=document.createElement('small');meta.textContent=`${e.size.join(' × ')} · ${e.frames} FRAMES`;
    button.append(title,meta);button.addEventListener('click',()=>select(e));return button;
  }));
  $('results').textContent=matches.length?`${matches.length} 個效果`:'沒有符合的素材，試試另一個名稱。';
}
async function select(entry){
  const request=++token;selected=entry;image=null;
  player=new SpritePlayer(entry.frames,entry.fps,entry.loop);
  $('effect-name').textContent=entry.name;$('loop-mode').textContent=entry.loop?'LOOP':'ONE SHOT';
  $('dimensions').textContent=entry.size.join(' × ')+' PX';$('asset-id').textContent=entry.id;
  $('fps').value=entry.fps;$('fps-label').textContent=entry.fps+' fps';
  $('frame').max=entry.frames-1;$('frame').value=0;
  $('download-png').href=`assets/${entry.id}.png`;
  $('download-recipe').href=`assets/${entry.id}.recipe.json`;
  $('load-error').hidden=true;renderList();sync();
  const next=new Image();
  next.onload=()=>{if(request!==token)return;image=next;if(!reduced)player.play();sync();draw()};
  next.onerror=()=>{if(request!==token)return;$('load-error').textContent='圖片載入失敗，請確認展示包的 assets 資料夾完整。';$('load-error').hidden=false};
  next.src=`assets/${entry.id}.png`;
}
function sync(){
  if(!player)return;
  $('play').textContent=player.playing?'暫停':'播放';$('play').setAttribute('aria-label',player.playing?'暫停動畫':'播放動畫');
  $('frame').value=player.frame;
  $('frame-label').textContent=`${String(player.frame+1).padStart(2,'0')} / ${String(player.count).padStart(2,'0')}`;
}
function draw(){
  const ratio=Math.min(window.devicePixelRatio||1,2),bounds=$('stage').getBoundingClientRect();
  if(bounds.width<=0||bounds.height<=0)return;
  const w=Math.round(bounds.width*ratio),h=Math.round(bounds.height*ratio);
  if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h}
  ctx.setTransform(ratio,0,0,ratio,0,0);ctx.clearRect(0,0,bounds.width,bounds.height);ctx.imageSmoothingEnabled=false;
  if(!image||!selected||!player)return;
  const scale=Number($('scale').value),[fw,fh]=selected.size,[px,py]=selected.pivot;
  const originX=bounds.width/2,originY=bounds.height/2;
  const region=selected.rects[player.frame];
  ctx.drawImage(image,region.x,region.y,region.w,region.h,Math.round(originX-px*fw*scale),Math.round(originY-py*fh*scale),fw*scale,fh*scale);
  if($('anchor').checked){ctx.strokeStyle='#d7f0b7';ctx.lineWidth=1;ctx.beginPath();ctx.moveTo(originX-6,originY);ctx.lineTo(originX+6,originY);ctx.moveTo(originX,originY-6);ctx.lineTo(originX,originY+6);ctx.stroke()}
}
function animate(now){
  const delta=last?Math.min((now-last)/1000,.1):0;last=now;
  if(player&&activeMode==='sprite'&&!document.hidden){player.tick(delta);sync();draw()}
  requestAnimationFrame(animate);
}
$('search').addEventListener('input',renderList);
$('play').onclick=()=>{if(!player)return;if(player.playing)player.playing=false;else player.play();sync()};
$('restart').onclick=()=>{player.seek(0);player.play();sync();draw()};
$('step').onclick=()=>{player.playing=false;player.seek((player.frame+1)%player.count);sync();draw()};
$('frame').oninput=()=>{player.playing=false;player.seek(Number($('frame').value));sync();draw()};
$('fps').oninput=()=>{player.fps=Number($('fps').value);$('fps-label').textContent=player.fps+' fps'};
$('scale').oninput=()=>{$('scale-label').textContent=$('scale').value+'×';draw()};
$('checker').onchange=()=>$('stage').classList.toggle('checker',$('checker').checked);
$('anchor').onchange=draw;
function mode(name){
  activeMode=name;
  for(const id of ['sprite','godot']){const isActive=id===name;$(id+'-tab').setAttribute('aria-selected',String(isActive));$(id+'-tab').tabIndex=isActive?0:-1;$(id+'-panel').hidden=!isActive}
  last=0;draw();
}
for(const id of ['sprite','godot']){$(id+'-tab').onclick=()=>mode(id);$(id+'-tab').onkeydown=e=>{if(['ArrowLeft','ArrowRight','Home','End'].includes(e.key)){e.preventDefault();const next=e.key==='Home'?'sprite':e.key==='End'?'godot':id==='sprite'?'godot':'sprite';mode(next);$(next+'-tab').focus()}}}
$('load-godot').onclick=()=>{
  if(location.protocol==='file:'){$('engine-status').textContent='Godot 需要 HTTP：請執行展示包中的 serve.py，再開啟它印出的網址。';return}
  const frame=$('godot-frame');frame.hidden=false;
  if(!frame.src){frame.src='godot/index.html';$('engine-status').textContent='Godot 正在啟動；載入進度會顯示在下方。'}
  $('load-godot').textContent='重新載入 Godot';
  if(frame.dataset.loaded==='true')frame.src='godot/index.html';
  frame.dataset.loaded='true';
};
new ResizeObserver(draw).observe($('stage'));
document.addEventListener('visibilitychange',()=>{last=0});
renderList();if(entries.length)select(entries.find(e=>e.id==='cinder-explosion')||entries[0]);
requestAnimationFrame(animate);
