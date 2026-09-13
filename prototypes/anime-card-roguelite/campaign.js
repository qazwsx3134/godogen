import { CHARACTERS, CARDS, RELICS, ARCHETYPES, isBasicCard } from './data.js';
import { assertInvariants, createRun } from './engine.js';
export const CAMPAIGN_KEY = 'rift-cards.campaign.v1';
export const ACHIEVEMENTS = [
  {id:'first_run',name:'踏入裂界',text:'開始第一次冒險。',icon:'◇'},
  {id:'first_battle',name:'初戰告捷',text:'贏得一場戰鬥。',icon:'⚔'},
  {id:'relay',name:'跨界接力',text:'在一局中完成3次跨宇宙接力。',icon:'✦'},
  {id:'empower',name:'共鳴覺醒',text:'成功使用一次共鳴強化。',icon:'◈'},
  {id:'collector',name:'異界藏家',text:'收藏20種卡牌。',icon:'▣'},
  {id:'victory',name:'登塔者',text:'完成一次七層登塔。',icon:'♜'},
  ...CHARACTERS.map(c=>({id:`win_${c.id}`,name:`${c.name}的傳說`,text:`使用${c.name}完成登塔。`,icon:'★'})),
];
const clone = value => JSON.parse(JSON.stringify(value));
const integer = (v,min=0) => Number.isSafeInteger(v) && v>=min;
const active = run => run && !['won','lost'].includes(run.phase);
export function freshCampaign(stats={}) { return {version:1,run:null,runId:null,savedAt:null,achievements:[],completed:[],stats:{runs:stats.runs||0,wins:stats.wins||0}}; }
function validateRun(run) {
  assertInvariants(run);
  if(!integer(run._rng)||run._rng>0xffffffff||!integer(run._nextUid,1)||!integer(run._nextPotionUid,1)||!integer(run.turn)||typeof run.seed!=='string'||run.seed.length>200) throw Error('無效亂數或回合狀態');
  const template=createRun({deck:CHARACTERS.find(c=>c.id===run.characterId).deck,seed:'validate',characterId:run.characterId});
  if(!run.metrics||Object.keys(template.metrics).some(k=>!integer(run.metrics[k]))) throw Error('無效冒險紀錄');
  if(!run._turn||Object.keys(template._turn).some(k=>typeof run._turn[k]!==typeof template._turn[k])) throw Error('無效回合特性');
  if(!Array.isArray(run.log)||run.log.some(x=>typeof x!=='string')||run.resolving.length) throw Error('無效結算狀態');
  if(!Array.isArray(run.excludedBuilds||[])||(run.excludedBuilds||[]).some(id=>!ARCHETYPES[id])) throw Error('無效流派');
  if(!Array.isArray(run.excludedRelics||[])||(run.excludedRelics||[]).some(id=>!RELICS.some(r=>r.id===id))) throw Error('無效遺物排除');
  if(run.map.some((row,i)=>row.length!==template.map[i].length||row.some((node,j)=>node.id!==template.map[i][j].id||node.kind!==template.map[i][j].kind))) throw Error('無效路線');
  if(run.currentNode) run.currentNode=run.map.flat().find(n=>n.id===run.currentNode.id);
  return run;
}
function decode(raw) {
  if(!raw || raw.length>2_000_000) throw Error('存檔不存在或過大');
  const value=JSON.parse(raw);
  if(value?.buildExcludedCards!==undefined&&(!Array.isArray(value.buildExcludedCards)||value.buildExcludedCards.some(id=>!CARDS.some(card=>card.id===id)))) throw Error('無效流派卡牌紀錄');
  if(value.version!==1||!Array.isArray(value.achievements)||value.achievements.some(id=>!ACHIEVEMENTS.some(a=>a.id===id))||!Array.isArray(value.completed)||value.completed.some(id=>typeof id!=='string')||!integer(value.stats?.runs)||!integer(value.stats?.wins)||value.stats.wins>value.stats.runs) throw Error('存檔格式不相容');
  if(value.run) { if(typeof value.runId!=='string'||!value.runId||!Number.isFinite(Date.parse(value.savedAt))) throw Error('存檔資訊不完整'); validateRun(value.run); }
  return value;
}
export function loadCampaign(storage,stats) {
  let found=false;
  for(const key of [CAMPAIGN_KEY,`${CAMPAIGN_KEY}.bak`]) {
    try { const raw=storage.getItem(key); if(!raw) continue; found=true; return {campaign:decode(raw),notice:key.endsWith('.bak')?'主要存檔無法讀取，已恢復上一份備份。':''}; } catch { found=true; }
  }
  return {campaign:freshCampaign(stats),notice:found?'存檔無法讀取；可開始新冒險，收藏仍保留。':''};
}
export function saveCampaign(storage,campaign) {
  try {
    const data=JSON.stringify(campaign); decode(data);
    const old=storage.getItem(CAMPAIGN_KEY);
    if(old) { try { decode(old); storage.setItem(`${CAMPAIGN_KEY}.bak`,old); } catch {} }
    storage.setItem(CAMPAIGN_KEY,data);
    // Terminal writes also retire the active backup, preventing a finished run resurrecting.
    if(!campaign.run) { try {storage.setItem(`${CAMPAIGN_KEY}.bak`,data);} catch {} }
    return true;
  } catch { return false; }
}
export function checkpoint(campaign,run,runId,profile) {
  const next=clone(campaign), unlocked=new Set(next.achievements);
  if(run) {
    validateRun(clone(run));
    unlocked.add('first_run');
    if(run.metrics.battlesWon>0) unlocked.add('first_battle');
    if(run.metrics.relays>=3) unlocked.add('relay');
    if(run.metrics.empowered>0) unlocked.add('empower');
    if(run.phase==='won') {unlocked.add('victory');unlocked.add(`win_${run.characterId}`);}
    if(!active(run)&&!next.completed.includes(runId)) { next.completed.push(runId);next.stats.runs++;if(run.phase==='won')next.stats.wins++; }
  }
  if(Object.values(profile.collection).filter(n=>n>0).length>=20) unlocked.add('collector');
  if(profile.stats.wins>0) unlocked.add('victory');
  next.achievements=[...unlocked]; next.run=active(run)?clone(run):null; next.runId=active(run)?runId:null; next.savedAt=new Date().toISOString();
  return next;
}
export function buildExclusions(builds,characterId) {
  const character=CHARACTERS.find(c=>c.id===characterId);
  if(!character||!Array.isArray(builds)||builds.some(id=>!ARCHETYPES[id])) throw Error('無效流派設定');
  const matches=item=>(item.tags||[]).some(tag=>builds.includes(tag));
  const protectedCards=CARDS.filter(c=>character.fixedCards.includes(c.id)&&matches(c)).map(c=>c.id);
  return {excludedCards:CARDS.filter(c=>!isBasicCard(c.id)&&!character.fixedCards.includes(c.id)&&matches(c)).map(c=>c.id),excludedRelics:RELICS.filter(matches).map(r=>r.id),protectedCards};
}
export function configuredDeck(profile,builds) {
  const c=CHARACTERS.find(c=>c.id===profile.characterId), filters=buildExclusions(builds,c.id);
  const excludedCards=[...new Set([...(profile.excludedCards||[]),...filters.excludedCards])].filter(id=>!c.fixedCards.includes(id));
  const deck=profile.deck.filter(id=>!excludedCards.includes(id));
  for(const fixed of c.fixedCards) if(!deck.includes(fixed)) deck.unshift(fixed);
  for(const id of ['strike','defend',...Object.keys(profile.collection)]) while(deck.length<10&&!excludedCards.includes(id)&&deck.filter(x=>x===id).length<Math.min(profile.collection[id]||0,isBasicCard(id)?5:2)) deck.push(id);
  return {...filters,excludedCards,deck};
}
