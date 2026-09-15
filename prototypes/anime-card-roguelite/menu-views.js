import { ARCHETYPES, CHARACTERS, CARDS } from './data.js';
import { ACHIEVEMENTS, buildExclusions } from './campaign.js';
import { BATTLE_ASSETS } from './battle-art.js';
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const menuIcon=(name,className='')=>{
  const paths={
    play:'<path d="m9 6 9 6-9 6V6Z"></path>',
    achievement:'<path d="M7 4h10v5a5 5 0 0 1-10 0V4Z"></path><path d="M7 6H4v2a4 4 0 0 0 4 4M17 6h3v2a4 4 0 0 1-4 4M12 14v5M8 20h8"></path>',
    collection:'<path d="M7 5h11v14H7z"></path><path d="M4 8v11h11M10 9h5M10 13h5"></path>',
    tutorial:'<circle cx="12" cy="12" r="8.5"></circle><path d="M9.5 9a2.6 2.6 0 1 1 4.4 1.9c-1.2 1-1.9 1.3-1.9 2.8M12 17v.2"></path>',
    continue:'<path d="M5 6v12l12-6L5 6Z"></path><path d="M19 6v12"></path>',
    new:'<path d="M12 4v16M4 12h16"></path>',
    back:'<path d="M19 12H5M11 6l-6 6 6 6"></path>',
    next:'<path d="M5 12h14M13 6l6 6-6 6"></path>',
    reset:'<path d="M5 8a8 8 0 1 1 1 8"></path><path d="M5 4v4h4"></path>',
    medal:'<circle cx="12" cy="14" r="5.5"></circle><path d="m9 9-2-5 5 2 5-2-2 5M10 14l1.4 1.4L14.5 12"></path>',
    sword:'<path d="m6 18 9-9M13 5l6 6M5 19l3-1-2-2-1 3Z"></path>',
    ring:'<circle cx="12" cy="12" r="6"></circle><circle cx="12" cy="12" r="2"></circle>',
    spark:'<path d="m12 3 1.7 5.3H19l-4.3 3.2 1.6 5.2-4.3-3.1-4.3 3.1 1.6-5.2L5 8.3h5.3L12 3Z"></path>',
    shield:'<path d="M12 3 19 6v5c0 4-2.8 7.2-7 9-4.2-1.8-7-5-7-9V6l7-3Z"></path><path d="m9 12 2 2 4-4"></path>',
    leaf:'<path d="M19 5C10 5 5 9 5 16c0 2 1 3 3 3 7 0 11-5 11-14Z"></path><path d="M5 19c2-4 5-6 9-8"></path>',
    rift:'<path d="M12 3 6 12l6 9 6-9-6-9Z"></path><path d="M9 12h6"></path>',
  };
  return `<svg class="menu-icon ${className}" viewBox="0 0 24 24" aria-hidden="true" focusable="false">${paths[name]||paths.spark}</svg>`;
};
const button=(id,label,description='',extra='',iconName=id)=>`<button data-menu="${id}" ${extra}><span class="menu-button-label">${menuIcon(iconName)}<span>${label}</span></span>${description?`<small>${description}</small>`:''}</button>`;
const back=()=>button('back','返回','','class="menu-back"','back');
const buildIcon=id=>({combo:'sword',poison:'ring',charge:'spark',guard:'shield',exhaust:'leaf',relay:'rift'}[id]||'spark');
const achievementIcon=id=>id==='first_battle'?'sword':id==='collector'?'collection':id==='victory'?'achievement':id==='empower'?'spark':id==='relay'?'rift':'medal';
const date=value=>value?new Date(value).toLocaleString('zh-TW',{month:'short',day:'numeric',hour:'2-digit',minute:'2-digit'}):'';
export function menuView({screen,campaign,profile,builds,notice,feedback,seed}) {
  const message=`<p class="menu-feedback" role="status">${esc(notice||feedback)}</p>`;
  if(screen==='title') return `<section class="title-scene" aria-label="主選單"><div class="title-content"><p class="menu-kicker">RIFTBOUND · 跨宇宙卡牌冒險</p><h1>裂界牌局</h1><p class="title-tagline">一副牌，穿越無數世界。</p><nav class="title-options" aria-label="遊戲選單">${button('play','進入遊戲','CONTINUE THE JOURNEY','class="title-primary"','play')}${button('achievements','查看成就',`${campaign.achievements.length} / ${ACHIEVEMENTS.length} 已解鎖`,'','achievement')}${button('collection','卡牌收藏',`${Object.values(profile.collection).filter(n=>n>0).length} 種已收藏`,'','collection')}<button data-tutorial-open><span class="menu-button-label">${menuIcon('tutorial')}<span>玩法教學</span></span><small>共鳴 · 蓄氣 · 跨界接力</small></button></nav>${message}</div><footer class="title-footer"><span>七層裂界 · 三名旅人 · 無限構築</span><span>本機自動存檔 · 原型 v0.3</span></footer></section>`;
  const heading={play:['選擇冒險','你的下一段旅程'],setup:['新的遊戲','01 / 冒險設定'],achievements:['旅人成就','每一次冒險，都留下痕跡'],replace:['開始新的旅程？','目前進度將被替換']}[screen];
  let content='';
  if(screen==='play') {
    const run=campaign.run, character=run&&CHARACTERS.find(c=>c.id===run.characterId);
    content=`<div class="journey-options"><button class="journey-card continue-card" data-menu="continue" ${run?'':'disabled'}><span class="journey-icon">${menuIcon('continue')}</span><strong>繼續上次進度</strong>${run?`<span class="save-portrait sprite-sheet" style="--sprite-image:url('${BATTLE_ASSETS.heroes[character.id]}')" aria-hidden="true"></span><span>${esc(character.name)} · 第 ${run.step+1} / 7 層 · ${esc({map:'選擇路線',battle:`戰鬥・回合 ${run.turn}`,reward:'挑選戰利品',shop:'商店',event:'事件',camp:'營火'}[run.phase])}</span><small>生命 ${run.player.hp}/${run.player.maxHp} · ${run.deck.length} 張牌<br>存檔時間 ${date(campaign.savedAt)}</small>`:'<span>尚無進行中的冒險</span><small>從新的遊戲展開第一段旅程。</small>'}</button><button class="journey-card new-card" data-menu="new"><span class="journey-icon">${menuIcon('new')}</span><strong>新的遊戲</strong><span>設定流派，再選擇旅人</span><small>決定這一局會遇見的卡牌與遺物。</small></button></div>`;
  }
  if(screen==='setup') {
    const candidates=CHARACTERS.map(c=>({c,...buildExclusions(builds,c.id)}));
    const viable=candidates.some(c=>CARDS.filter(card=>!['strike','defend'].includes(card.id)&&!c.excludedCards.includes(card.id)).length>=3);
    content=`<div class="setup-layout"><section><h2>選擇要排除的流派</h2><p class="menu-help">預設全部開放。排除後，相關卡牌與遺物不會出現在本局；混合流派只要命中任一排除項目也會移除。</p><div class="build-options">${Object.entries(ARCHETYPES).map(([id,b])=>`<button data-build="${id}" aria-pressed="${builds.includes(id)}" class="build-option ${builds.includes(id)?'excluded':''}"><span class="build-sigil">${menuIcon(buildIcon(id))}</span><span><strong>${b.name}</strong><small>${b.description}</small></span><b class="build-state">${builds.includes(id)?'已排除':'開放'}</b></button>`).join('')}</div><button data-menu="reset-builds" class="menu-secondary">${menuIcon('reset')}<span>恢復全部流派</span></button></section><aside class="setup-summary"><p class="menu-kicker">本局設定</p><h2>${builds.length?`排除 ${builds.length} 種流派`:'完整跨界體驗'}</h2><p>${builds.length?builds.map(id=>ARCHETYPES[id].name).join('、'):'所有流派皆可出現。推薦第一次遊玩使用。'}</p><div class="fixed-rule"><b>角色固定牌永遠保留</b><p>下一步選角色後，會列出保留的固定牌；其他起始牌自動補足十張，仍可手動調整。</p></div><label class="field">冒險種子<input id="seed" value="${esc(seed)}" maxlength="48" autocomplete="off"></label>${campaign.run?'<p class="menu-help">目前存檔會保留到你確認開始新冒險。</p>':''}${button('choose-character','下一步：選擇角色','02 / 決定你的職業',`class="primary" ${viable?'':'disabled'}`,'next')}${!viable?'<p class="menu-error">排除過多，請至少保留3種非基礎卡候選。</p>':''}</aside></div>`;
  }
  if(screen==='achievements') content=`<div class="achievement-overview"><span><b>${campaign.achievements.length}</b> / ${ACHIEVEMENTS.length} 成就</span><span>完成冒險 <b>${campaign.stats.runs}</b> 次</span><span>登塔成功 <b>${campaign.stats.wins}</b> 次</span></div><div class="achievement-grid">${ACHIEVEMENTS.map(a=>`<article class="achievement ${campaign.achievements.includes(a.id)?'unlocked':'locked'}" data-achievement="${a.id}"><span class="achievement-medal">${menuIcon(achievementIcon(a.id))}</span><div><small>${campaign.achievements.includes(a.id)?'已解鎖':'尚未解鎖'}</small><h2>${a.name}</h2><p>${a.text}</p></div></article>`).join('')}</div>`;
  if(screen==='replace') content=`<section class="replace-panel"><p>開始新的冒險後，將取代目前的${esc(CHARACTERS.find(c=>c.id===campaign.run?.characterId)?.name||'旅人')}第 ${(campaign.run?.step||0)+1} 層存檔。</p><p>卡牌收藏與已解鎖成就會保留。</p><div>${button('cancel-replace','返回角色選擇')}${button('confirm-replace','開始新的冒險','','class="primary"')}</div></section>`;
  return `<section class="menu-page menu-${screen}"><header class="menu-page-header">${back()}<span>裂界牌局</span></header><div class="menu-page-body"><p class="menu-kicker">${heading[1]}</p><h1>${heading[0]}</h1>${message}${content}</div></section>`;
}
