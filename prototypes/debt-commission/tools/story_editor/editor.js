/* editor.js: the story node editor page. The graph rules live in story_core.js; this file draws
 * cards and links, handles the mouse, and edits the story object in place (only the fields the
 * author touches, so everything else in a step survives).
 *
 * Opened from file:// it reads/writes files through the pickers; served from the project root
 * (python3 -m http.server -d <project>) it also lists data/stories.json and reads the asset
 * catalog and story_runner.gd's constant lists for the dropdowns. */
(function () {
  'use strict';
  const Core = globalThis.StoryCore;
  const { GEOM } = Core;
  const Authoring = globalThis.EditorState;
  const DRAFT_KEY = 'debtStoryEditor.draft.';
  const LAST_DRAFT = 'debtStoryEditor.lastDraft';
  const SVG_NS = 'http://www.w3.org/2000/svg';
  const LAYOUT_KEY = 'debtStoryEditor.layout.';
  const DASHED = new Set(['spot', 'talk', 'round', 'over']);
  const PROBLEM_ICON = { unreachable: '🔴', dangling: '🔴', entry: '🔴', unconnected: '🟠', 'terminal-next': '🟠', 'terminal-middle': '🔴', node: '🟠' };

  const $ = id => document.getElementById(id);
  const view = $('view');
  const world = $('world');
  const edgesSvg = $('edges');
  const cardsEl = $('cards');
  const clamp = (value, lo, hi) => Math.min(hi, Math.max(lo, value));
  const isObj = value => value !== null && typeof value === 'object' && !Array.isArray(value);

  function el(tag, props = {}, ...kids) {
    const node = document.createElement(tag);
    for (const [key, value] of Object.entries(props)) {
      if (value === undefined || value === null || value === false) continue;
      if (key === 'class') node.className = value;
      else if (key === 'style') for (const [name, v] of Object.entries(value)) name.startsWith('--') ? node.style.setProperty(name, v) : (node.style[name] = v);
      else if (key === 'data') Object.assign(node.dataset, value);
      else if (key.startsWith('on')) node.addEventListener(key.slice(2), value);
      else if (key in node) node[key] = value;
      else node.setAttribute(key, value);
    }
    for (const kid of kids.flat()) if (kid !== false && kid !== null && kid !== undefined) node.append(kid instanceof Node ? kid : document.createTextNode(String(kid)));
    return node;
  }
  function svg(tag, attrs = {}, label) {
    const node = document.createElementNS(SVG_NS, tag);
    for (const [key, value] of Object.entries(attrs)) node.setAttribute(key, value);
    if (label !== undefined) node.textContent = label;
    return node;
  }

  const S = {
    story: null, name: '', layout: {}, v: { x: 0, y: 0, k: 1 }, sel: null, a: null, dirty: false, modified: false, notice: '', error: '',
    catalog: null, online: false, stories: [], enums: JSON.parse(JSON.stringify(Core.FALLBACK_ENUMS)),
    baseCatalog: null, packs: [], packCatalogs: {},
  };
  const nodeIds = () => Object.keys(S.story.nodes).sort();
  const snapshot = () => ({ story: S.story, layout: S.layout, sel: S.sel, conversionRegistry });
  let history = null;
  let originalStory = '';
  let confirmedText = null;
  let draftKey = '';
  let draftRaw = null;
  let pendingDraft = null;
  let draftBlocked = false;
  let pendingExport = null;
  let storageError = '';
  let loadTicket = 0;
  let fieldSession = 0;

  let projectSource = { path: '', hash: null, ready: true };
  let projectSaving = false;
  let previewStarting = false;
  let saveIssues = [];
  const registryText = value => JSON.stringify(value || {stories:[]}, null, 2) + '\n';
  let confirmedRegistryText = '';
  let registryBaseHash = null;
  // A story's registry is data/stories.json, or for stories/<作品>/ that work's pack.json (shown with
  // res:// paths, as story_library.gd reads it; the service writes the pack's own form).
  const workOf = path => /^stories\/([A-Za-z_][A-Za-z0-9_]*)\//.exec(path || '')?.[1] || null;
  const packOf = work => S.packs.find(p => p.id === work) || null;
  function ownerRegistry() {
    const pack = packOf(workOf(projectSource.path));
    return pack ? {stories: Core.packEntries(pack.pack, pack.id)} : (S.registry || {stories: []});
  }
  const ownerHash = () => packOf(workOf(projectSource.path))?.hash ?? (S.registryHash || null);
  function rebuildStories() {
    S.stories = [...(S.registry?.stories || []), ...S.packs.flatMap(p => Core.packEntries(p.pack, p.id))];
    const picker = $('storySelect');
    picker.hidden = !S.stories.length;
    const option = e => el('option', { value: e.id }, `${e.id}（${e.kind}）`);
    picker.replaceChildren(el('option', { value: '' }, '從專案開啟…'), ...(S.registry?.stories || []).map(option),
      ...S.packs.map(p => el('optgroup', { label: `作品：${p.title}` }, ...Core.packEntries(p.pack, p.id).map(option))));
    picker.value = S.stories.find(e => e.path === 'res://' + projectSource.path)?.id || '';
  }
  /** The open story's catalog: its work's catalog.json, else data/asset_catalog.json. */
  function useCatalog() {
    const work = workOf(projectSource.path);
    S.catalog = (work && S.packCatalogs[work]) || S.baseCatalog;
  }
  async function loadCatalog(resPath, depth = 0) {
    if (resPath === 'res://data/asset_catalog.json' && S.baseCatalog) return S.baseCatalog;
    const own = await getJson(Core.projectUrl(resPath));
    const base = typeof own.extends === 'string' && depth < 4 ? await loadCatalog(own.extends, depth + 1) : null;
    return Core.resolveCatalog(own, resPath.replace(/\/[^/]*$/, ''), base);
  }
  async function loadPackCatalog(work) {
    try { S.packCatalogs[work] = await loadCatalog(`res://stories/${work}/catalog.json`); }
    catch { delete S.packCatalogs[work]; }  // no catalog.json: the game's catalog
  }
  function currentRegistryEntry() {
    const work = workOf(projectSource.path), pack = packOf(work);
    return (conversionRegistry || ownerRegistry())?.stories?.find(e => e.path === 'res://' + projectSource.path) ||
      (pack ? {id:S.story.id,kind:'chapter',path:'res://' + projectSource.path,save:`user://pack_${work}_${S.story.id}.save`,
        work,work_title:String(pack.pack.title || work),authoring:'graph'}
        : {id:S.story.id,kind:'sample',path:'res://' + projectSource.path,save:`user://${S.story.id}.save`,authoring:isReadOnly()?'dialogue':'graph'});
  }
  const registryDirty = () => !!conversionRegistry && registryText(conversionRegistry) !== confirmedRegistryText;
  const registryChanged = () => !!conversionRegistry && registryText(conversionRegistry) !== registryText(ownerRegistry());
  function editRegistry(key, value) {
    if (!conversionRegistry) conversionRegistry = JSON.parse(JSON.stringify(ownerRegistry()));
    let entry = conversionRegistry.stories.find(e => e.path === 'res://' + projectSource.path);
    if (!entry) { entry = {...currentRegistryEntry()}; conversionRegistry.stories.push(entry); }
    if (value === '') delete entry[key]; else entry[key] = value;
    history.commit(snapshot()); refreshDirty(); saveDraft(); renderBanner(); renderStatus(); renderHistory();
    if (key === 'cover') renderInfo();
    applyReadOnly();
  }
  async function loadSkins() {
    if (S.service?.skins?.length) return S.service.skins;
    const ids = [...new Set(['gintama', ...[...S.stories, ...S.packs.map(p=>p.pack)].map(e=>e.skin).filter(id=>typeof id==='string' && /^[A-Za-z0-9_-]+$/.test(id))])];
    return Promise.all(ids.map(async id => {
      if (location.protocol !== 'file:') try {
        const value = await getJson(`../../skins/${id}/skin.json`);
        return {id,name:value.name || id};
      } catch { /* Keep registry-used ids selectable even if their manifest is unavailable. */ }
      return {id,name:id==='gintama'?'銀魂和紙':'名稱未載入'};
    }));
  }
  function registryControls() {
    const entry = currentRegistryEntry();
    const pack = packOf(workOf(projectSource.path))?.pack;
    const skin = select2((S.skins || []).map(s=>({value:s.id,label:`${s.id} · ${s.name}`})),entry.skin,value=>editRegistry('skin',value),
      `預設：${pack?.skin || 'gintama'}${pack ? '（作品）' : ''}`);
    skin.id='storySkin'; skin.dataset.registryField='true';
    const covers = Object.values(S.catalog?.backgrounds || {}).filter(bg=>bg.path).map(bg=>({value:bg.path,label:bg.label || bg.path}));
    const cover = select2(covers,entry.cover,value=>editRegistry('cover',value),pack?.cover ? '預設：作品封面' : '自動：故事第一張背景');
    cover.id='storyCover'; cover.dataset.registryField='true';
    return [field('外觀包',skin),field('章節封面',cover,
      entry.cover && el('img',{class:'cover-preview',src:Core.projectUrl(entry.cover),alt:'章節封面預覽'}))];
  }
  function voicePitch(step) {
    const id=step.id || step.speaker;
    const value=S.catalog?.characters?.[id]?.voice_pitch;
    return field('打字音高',el('code',{class:'voice-pitch'},id==='narrator'?'旁白（無打字音）':Number.isFinite(value)?`${value} Hz`:'未設定（用預設音高）'));
  }
  function exportRegistry() {
    if (workOf(projectSource.path)) { failure(`作品的登記在 stories/${workOf(projectSource.path)}/pack.json，請用「驗證並存檔」存回。`); return; }
    const text = registryText(conversionRegistry || S.registry);
    download('stories.json',text);
    pendingExport={text,key:draftKey,kind:'registry'};
    S.notice='已下載故事登記。請選回檔案確認內容；下載不會自動合併進專案。';
    saveDraft();renderBanner();renderStatus();
  }

  async function textHash(text) {
    const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
    return [...new Uint8Array(bytes)].map(byte => byte.toString(16).padStart(2, '0')).join('');
  }
  function resetProjectSource(story, name, rawText, path = null) {
    projectSource = { path: path || `data/${/^[A-Za-z0-9_]+_story\.json$/.test(name) ? name : story.id + '_story.json'}`, hash: null, ready: rawText === null };
    projectSaving = false; saveIssues = [];
    useCatalog();
    confirmedRegistryText=registryText(ownerRegistry());registryBaseHash=ownerHash();
    if (rawText !== null && location.protocol !== 'file:') {
      const source = projectSource;
      textHash(rawText).then(hash => {
        if (projectSource !== source) return;
        source.hash = hash; source.ready = true;
        renderProjectSave(); if (S.dirty) saveDraft();
      }).catch(err => { if (projectSource === source) failure(`無法建立存檔基底：${err.message}。請先匯出。`); });
    }
  }
  function renderProjectSave() {
    const control = $('btnProjectSave');
    control.hidden = !S.service;
    control.disabled = !S.story || projectSaving || !projectSource.ready || (isReadOnly() && !registryChanged());
    control.textContent = projectSaving ? '存檔中…' : isReadOnly() && registryChanged() ? '存回外觀設定' : '驗證並存檔';
  }
  async function saveProject() {
    const metadataOnly=isReadOnly();
    if (!S.service || !S.story || projectSaving || !projectSource.ready || (metadataOnly && !registryChanged())) return;
    const source=projectSource, sentText=storyText(), sentRegistry=registryText(conversionRegistry || ownerRegistry());
    const request={path:source.path,base_hash:source.hash,story:JSON.parse(sentText),
      registry_entry:JSON.parse(JSON.stringify(currentRegistryEntry())),registry_hash:registryBaseHash,update_registry:registryChanged()};
    projectSaving=true;saveIssues=[];S.error='';S.notice='';
    renderBanner();renderProjectSave();renderProblems();renderStatus();
    try {
      const response=await fetch(metadataOnly?'../../api/registry':'../../api/save',{method:'POST',
        headers:{'Content-Type':'application/json','X-Story-Editor-Token':S.service.token},body:JSON.stringify(request)});
      const result=await response.json();
      if(projectSource!==source)return;
      if(!response.ok || result.ok!==true){
        const errors=[result.error || '儲存失敗',...(result.errors || [])];
        saveIssues=errors.map(message=>({type:'validation',message}));
        failure(errors[0]);saveDraft();renderProblems();renderStatus();return;
      }
      const unchanged=storyText()===sentText;
      const registryUnchanged=registryText(conversionRegistry || ownerRegistry())===sentRegistry;
      const latestEntry=JSON.parse(JSON.stringify(currentRegistryEntry()));
      if(!metadataOnly){
        source.hash=result.hash;
        const saved=JSON.parse(result.text);
        if(unchanged)S.story=saved;else S.story.version=saved.version;
        originalStory=JSON.stringify(saved);confirmedText=Core.exportText(saved);
      }
      if(result.registry || result.pack){
        if(result.pack){  // only that work's pack.json changed
          const work=workOf(source.path), known=packOf(work);
          if(known){known.pack=result.pack;known.hash=result.pack_hash;}
          else S.packs.push({id:work,title:String(result.pack.title || work),path:result.owner,hash:result.pack_hash,pack:result.pack});
          registryBaseHash=result.pack_hash;
        } else {S.registry=result.registry;S.registryHash=result.registry_hash;registryBaseHash=result.registry_hash;}
        confirmedRegistryText=registryText(ownerRegistry());
        conversionRegistry=null;
        if(!registryUnchanged){
          conversionRegistry=JSON.parse(JSON.stringify(ownerRegistry()));
          const entry=conversionRegistry.stories.find(e=>e.path==='res://'+source.path);
          if(entry)for(const key of ['skin','cover']){if(key in latestEntry)entry[key]=latestEntry[key];else delete entry[key];}
        }
        rebuildStories();
      }
      pendingExport=null;S.error='';refreshDirty();
      S.notice=S.dirty?'已存回送出的版本；此頁另有後續修改，請再次存檔。':metadataOnly?'外觀設定已存回專案。':'驗證通過，已存回專案。';
      recompute();ensureLayout();if(unchanged && registryUnchanged)history.replaceCurrent(snapshot());
      saveDraft();renderAll();
    } catch(err){if(projectSource===source)failure(`無法確認存檔結果：${err.message}。修改仍保留，請先匯出；重試若提示衝突，請重開專案版本比較。`);}
    finally{if(projectSource===source){projectSaving=false;renderProjectSave();}}
  }
  async function detectService() {
    if (!/^https?:$/.test(location.protocol)) return null;
    const response = await fetch('../../data/stories.json', {method:'HEAD'});
    if (response.headers.get('X-Story-Editor-Service') !== 'debt-story-editor-v1') return null;
    const service = await getJson('../../api/capabilities');
    return service.service === 'debt-story-editor-v1' ? service : null;
  }

  function failure(message) { S.error = message; renderBanner(); }
  function storageFailure(err) {
    storageError = `瀏覽器儲存失敗：${err.message}。修改仍在此頁，請立即匯出；草稿／座標尚未備份。`;
    renderBanner();
  }
  function refreshDirty() {
    S.modified = JSON.stringify(S.story) !== originalStory;
    S.dirty = confirmedText === null || storyText() !== confirmedText || registryDirty();
  }
  function renderHistory() {
    $('btnUndo').disabled = !history?.canUndo;
    $('btnRedo').disabled = !history?.canRedo;
  }
  function saveDraft() {
    if (!S.story || pendingDraft || draftBlocked) return;
    try {
      const actual = localStorage.getItem(draftKey);
      if (actual !== draftRaw) throw new Error('另一個分頁已變更此草稿，為避免覆蓋已停止備份；請先匯出目前版本');
      if (!S.dirty) {
        localStorage.removeItem(draftKey); draftRaw = null;
        if (localStorage.getItem(LAST_DRAFT) === draftKey) localStorage.removeItem(LAST_DRAFT);
        storageError = ''; renderBanner(); return;
      }
      const record = { format: 1, name: S.name, base: JSON.parse(originalStory),
        confirmedText, confirmedRegistryText, registryBaseHash, ...snapshot(), projectSource, updatedAt: new Date().toISOString() };
      const raw = JSON.stringify(record);
      localStorage.setItem(draftKey, raw);
      draftRaw = raw;
      localStorage.setItem(LAST_DRAFT, draftKey);
      storageError = '';
    } catch (err) { storageFailure(err); }
    renderBanner();
  }
  function validDraft(raw) {
    const record = JSON.parse(raw);
    if (!isObj(record) || record.format !== 1 || !isObj(record.base) || shapeError(record.base)
        || !isObj(record.story) || shapeError(record.story) || !isObj(record.layout)
        || typeof record.name !== 'string' || !(record.confirmedText === null || typeof record.confirmedText === 'string')) throw new Error('草稿格式損壞，原紀錄已保留，請先匯出目前故事');
    return record;
  }
  function readDraft() {
    pendingDraft = null;
    draftBlocked = false;
    draftRaw = null;
    try {
      draftRaw = localStorage.getItem(draftKey);
      if (draftRaw) pendingDraft = validDraft(draftRaw);
    } catch (err) { draftBlocked = true; storageFailure(err); }
  }
  function restoreDraft() {
    if (!pendingDraft) return;
    if (S.dirty && !confirm('復原草稿會取代此頁尚未儲存的修改，繼續嗎？')) return;
    ++loadTicket;
    pendingExport = null;
    const record = pendingDraft;
    pendingDraft = null;
    S.story = record.story;
    if (record.projectSource?.path && (record.projectSource.hash === null || /^[0-9a-f]{64}$/.test(record.projectSource.hash))) projectSource = { ...record.projectSource, ready: true };
    saveIssues = [];
    conversionRegistry = record.conversionRegistry || null;
    S.name = record.name;
    S.layout = cleanLayout(record.layout);
    S.sel = null;
    confirmedText = record.confirmedText;
    useCatalog();
    confirmedRegistryText=record.confirmedRegistryText ?? registryText(ownerRegistry());
    registryBaseHash=record.registryBaseHash ?? registryBaseHash;
    recompute(); ensureLayout(); refreshDirty();
    history.reset(snapshot());
    S.notice = '已復原草稿。請匯出並選回下載檔案確認儲存；草稿不會自動覆寫專案。';
    renderAll(); fit();
  }
  function discardDraft() {
    if ((!pendingDraft && !draftBlocked) || !confirm('確定刪除此瀏覽器草稿？已開啟的故事不會改動。')) return;
    try {
      if (localStorage.getItem(draftKey) !== draftRaw) throw new Error('草稿已被另一分頁更新，請重新開啟後再決定');
      localStorage.removeItem(draftKey);
      draftRaw = null; pendingDraft = null; draftBlocked = false; storageError = '';
      if (localStorage.getItem(LAST_DRAFT) === draftKey) localStorage.removeItem(LAST_DRAFT);
      if (S.dirty) saveDraft();
    } catch (err) { storageFailure(err); }
    renderBanner();
  }
  function restoreHistory(value) {
    if (!value) return;
    ++loadTicket;
    drag = null;
    S.story = value.story; S.layout = value.layout; S.sel = value.sel; conversionRegistry = value.conversionRegistry || null;
    recompute(); ensureLayout(); refreshDirty();
    saveLayout(); saveDraft(); renderAll();
  }
  function cleanLayout(layout) {
    return Object.fromEntries(Object.entries(layout).filter(([id, p]) => id in S.story.nodes && isObj(p) && Number.isFinite(p.x) && Number.isFinite(p.y)).map(([id,p]) => [id, {x:p.x, y:p.y, ...(isObj(p.expanded) ? {expanded: Object.fromEntries(Object.entries(p.expanded).filter(([k,v]) => /^\d+:[a-z]+$/.test(k) && typeof v === 'boolean'))} : {})}]));
  }


  // ---------------------------------------------------------------- state

  let foldShapes = {};
  function recompute(resetExpanded = false) {
    const shapes = Object.fromEntries(Object.entries(S.story.nodes).map(([id, node]) => [id, Core.foldShape(node)]));
    if (resetExpanded) for (const id of Object.keys(shapes)) {
      if (foldShapes[id] && shapes[id] !== foldShapes[id] && S.layout[id]) delete S.layout[id].expanded;
    }
    foldShapes = shapes;
    S.a = Core.analyze(S.story);
    S.media = Core.effectiveMedia(S.story, S.a);
    S.missingArt = S.catalog ? Core.missingArt(S.story, S.catalog) : {};
    if (S.sel && S.sel.type === 'node' && !(S.sel.id in S.story.nodes)) S.sel = null;
    if (S.sel && S.sel.type === 'edge') {
      const edges = S.a.edges[S.sel.node];
      if (!edges || !edges.some(edge => edge.key === S.sel.key)) S.sel = S.sel.node in S.story.nodes ? { type: 'node', id: S.sel.node } : null;
    }
  }

  const sizeOf = id => Core.cardSize(S.story.nodes[id], S.a.edges[id].length, S.layout[id]);

  function ensureLayout() {
    const missing = Object.keys(S.story.nodes).filter(id => !S.layout[id]);
    if (!missing.length) return;
    const auto = Core.autoLayout(S.story, S.a, S.layout);
    for (const id of missing) S.layout[id] = auto[id];
  }

  function readLayout(storyId) {
    try {
      const saved = JSON.parse(localStorage.getItem(LAYOUT_KEY + storyId));
      if (isObj(saved)) return cleanLayout(saved);
    } catch (err) { storageFailure(err); }
    return {};
  }
  function saveLayout() {
    try { localStorage.setItem(LAYOUT_KEY + S.story.id, JSON.stringify(S.layout)); } catch (err) { storageFailure(err); }
  }

  function loadStory(story, name, key = null, rawText = null, path = null) {
    ++loadTicket;
    drag = null;
    stopAudio(); conversionRegistry = null;
    S.story = story;
    S.name = name || `${story.id}_story.json`;
    resetProjectSource(story, S.name, rawText, path);
    S.sel = null;
    S.dirty = false;
    S.modified = false;
    S.notice = '';
    S.error = '';
    originalStory = JSON.stringify(story);
    confirmedText = Core.exportText(story);
    pendingExport = null;
    draftKey = key || DRAFT_KEY + JSON.stringify([S.name, story.id]);
    recompute();
    S.layout = readLayout(story.id);
    ensureLayout();
    history = new Authoring.History(snapshot());
    readDraft();
    renderAll();
    fit();
  }

  /** Call after every change to S.story. opts.inspector rebuilds the sidebar editor (not while typing in it). */
  function touch(opts = {}) {
    recompute(true);
    ensureLayout();
    history.commit(snapshot(), opts.merge || null);
    refreshDirty();
    renderHistory();
    renderSearch();
    renderCanvas();
    renderProblems();
    if (opts.inspector) renderInspector();
    applyReadOnly();
    renderStatus();
    renderVersionHint();
    saveLayout();
    saveDraft();
  }

  /**
   * The file's text. `version` hashes the save positions, which only check_story.gd may compute; a story edited
   * here goes out as s-unset, so a forgotten check_story run shows up as a rejected old save, never as a save
   * restored onto the wrong steps. An untouched story is written back unchanged.
   */
  const storyText = () => Core.exportText(S.modified ? { ...S.story, version: 's-unset' } : S.story);

  function select(sel) {
    S.sel = sel;
    cardsEl.querySelectorAll('.card.selected, .prow.selected').forEach(node => node.classList.remove('selected'));
    if (sel && sel.type === 'node') cardEl(sel.id)?.classList.add('selected');
    if (sel && sel.type === 'edge') cardEl(sel.node)?.querySelector(`.prow[data-edge="${CSS.escape(sel.key)}"]`)?.classList.add('selected');
    drawEdges();
    renderInspector(); applyReadOnly();
  }

  // ---------------------------------------------------------------- view

  function applyView() {
    const { x, y, k } = S.v;
    world.style.transform = `translate(${x}px, ${y}px) scale(${k})`;
    const major = 100 * k;
    const minor = 20 * k;
    view.style.backgroundSize = `${major}px ${major}px, ${major}px ${major}px, ${minor}px ${minor}px, ${minor}px ${minor}px`;
    view.style.backgroundPosition = `${x}px ${y}px`;
    view.style.setProperty('--grid-minor', k < 0.45 ? 'transparent' : 'rgba(255, 255, 255, .035)');
  }
  function toWorld(clientX, clientY) {
    const r = view.getBoundingClientRect();
    return { x: (clientX - r.left - S.v.x) / S.v.k, y: (clientY - r.top - S.v.y) / S.v.k };
  }
  function zoomAt(clientX, clientY, factor) {
    const r = view.getBoundingClientRect();
    const px = clientX - r.left;
    const py = clientY - r.top;
    const k = clamp(S.v.k * factor, 0.08, 2.5);
    const wx = (px - S.v.x) / S.v.k;
    const wy = (py - S.v.y) / S.v.k;
    S.v = { k, x: px - wx * k, y: py - wy * k };
    applyView();
  }
  function fit(maxK = 1) {
    const ids = Object.keys(S.story.nodes);
    if (!ids.length) { S.v = { x: 40, y: 40, k: 1 }; applyView(); return; }
    let x0 = Infinity; let y0 = Infinity; let x1 = -Infinity; let y1 = -Infinity;
    for (const id of ids) {
      const p = S.layout[id];
      const s = sizeOf(id);
      x0 = Math.min(x0, p.x); y0 = Math.min(y0, p.y); x1 = Math.max(x1, p.x + s.w); y1 = Math.max(y1, p.y + s.h);
    }
    const r = view.getBoundingClientRect();
    const pad = 40;
    const k = clamp(Math.min((r.width - 2 * pad) / (x1 - x0), (r.height - 2 * pad) / (y1 - y0)), 0.08, maxK);
    S.v = { k, x: (r.width - (x1 - x0) * k) / 2 - x0 * k, y: (r.height - (y1 - y0) * k) / 2 - y0 * k };
    applyView();
  }
  function centerOn(id, k = Math.max(S.v.k, 0.7)) {
    const p = S.layout[id];
    const s = sizeOf(id);
    const r = view.getBoundingClientRect();
    S.v = { k, x: r.width / 2 - (p.x + s.w / 2) * k, y: r.height / 2 - (p.y + s.h / 2) * k };
    applyView();
  }

  // ---------------------------------------------------------------- canvas

  const cardEl = id => (id ? cardsEl.querySelector(`.card[data-node="${CSS.escape(id)}"]`) : null);

  function portRow(id, edge) {
    const unconnected = !edge.target;
    const dangling = !unconnected && !(edge.target in S.story.nodes);
    const selected = S.sel && S.sel.type === 'edge' && S.sel.node === id && S.sel.key === edge.key;
    return el('div', {
      class: `prow kind-${edge.kind}${unconnected ? ' unconnected' : ''}${dangling ? ' dangling' : ''}${selected ? ' selected' : ''}`,
      data: { edge: edge.key }, title: `${edge.label} → ${edge.target || '（未連線）'}`,
    }, el('span', { class: 'plabel' }, edge.label), el('span', { class: 'dot' }));
  }

  const mediaLabels = { explicit: '', inherited: '沿用', mixed: '依路線不同', none: '無' };
  let audition = null;
  let auditionId = '';
  function stopAudio() {
    audition?.pause(); audition = null; auditionId = '';
    document.querySelectorAll('[data-audition]').forEach(b => { b.textContent = '▶ 試聽'; b.setAttribute('aria-pressed', 'false'); });
  }
  function audioButton(id) {
    const asset = S.catalog?.music?.[id];
    if (!id) return el('span', { class: 'muted' }, '無');
    if (!asset?.path) return el('span', { class: 'muted' }, '佔位（無音檔）');
    const b = button(auditionId === id ? '■ 停止' : '▶ 試聽', async () => {
      const stopping = auditionId === id; stopAudio(); if (stopping) return;
      const player = new Audio(Core.projectUrl(asset.path)); audition = player; auditionId = id;
      document.querySelectorAll('[data-audition]').forEach(x => { if (x.dataset.audition === id) { x.textContent = '■ 停止'; x.setAttribute('aria-pressed', 'true'); } });
      player.addEventListener('ended', () => { if (audition === player) stopAudio(); });
      try { await player.play(); } catch (err) { if (audition === player) { stopAudio(); failure(`試聽失敗：${err.message}`); } }
    }, 'small audition');
    b.dataset.audition = id; b.setAttribute('aria-pressed', String(auditionId === id)); return b;
  }
  function thumbnail(id) {
    const asset = S.catalog?.backgrounds?.[id];
    if (!asset) return el('span', { class: 'bg-thumb empty', title: id || '無背景' }, id ? '?' : '—');
    const box = el('span', { class: 'bg-thumb', title: asset.label || id });
    if (asset.path) box.append(el('img', { src: Core.projectUrl(asset.path), alt: asset.label || id, loading: 'lazy', onerror: () => { box.textContent = '缺圖'; } }));
    else if (/^#[0-9a-f]{3,8}$/i.test(asset.top || '') && /^#[0-9a-f]{3,8}$/i.test(asset.bottom || '')) box.style.background = `linear-gradient(${asset.top}, ${asset.bottom})`;
    return box;
  }
  function sceneMedia(id) {
    const { bg, bgm } = S.media[id];
    const label = (kind, value) => `${kind}：${mediaLabels[value.status]}${value.id ? ` ${S.catalog?.[kind === '背景' ? 'backgrounds' : 'music']?.[value.id]?.label || value.id}` : ''}`;
    return el('div', { class: 'scene-media' }, thumbnail(bg.id),
      el('div', {}, el('div', { class: 'media-label', title: label('背景', bg) }, label('背景', bg)),
        el('div', { class: 'media-label', title: label('BGM', bgm) }, label('BGM', bgm))),
      bgm.status !== 'mixed' && audioButton(bgm.id));
  }
  function openStep(id, index) {
    select({ type: 'node', id, step: index });
    const target = $('inspector').querySelector(`[data-step="${index}"]`);
    if (target) { target.scrollIntoView({ block: 'nearest' }); target.classList.add('search-hit'); target.querySelector('textarea,input,select')?.focus({ preventScroll: true }); }
  }
  function flowNodes(id) {
    const node = S.story.nodes[id];
    const nodes = [];
    const stepButton = (index, group) => {
      const step = node.steps[index];
      const detail = step.text || step.prompt || step.id || step.key || step.target || '';
      const name = Core.stepLabel(step);
      const b = button(`${index + 1} · ${name}${detail ? ` · ${detail}` : ''}`, () => openStep(id, index), `flow-node group-${group.id}`);
      b.title = `${step.op} · ${detail}`; b.dataset.step = index; return b;
    };
    for (const run of Core.stepRuns(node)) {
      if (run.indices.length === 1) { nodes.push(stepButton(run.indices[0], run.group)); continue; }
      const expanded = Core.runExpanded(S.layout[id], run);
      const characters = run.group.id === 'character' ? [...new Set(run.indices.map(i => S.catalog?.characters?.[node.steps[i].id]?.name || node.steps[i].id).filter(Boolean))] : [];
      const b = button(`${expanded ? '▾' : '▸'} ${run.group.label} ×${run.indices.length}${characters.length ? '：' + characters.join('、') : ''}`, () => {
        (S.layout[id].expanded ||= {})[run.key] = !expanded;
        history.commit(snapshot()); saveLayout(); saveDraft(); renderHistory(); renderCanvas();
      }, `flow-node flow-group group-${run.group.id}`);
      b.setAttribute('aria-expanded', String(expanded)); b.dataset.run = run.key; nodes.push(b);
      if (expanded) nodes.push(...run.indices.map(index => stepButton(index, run.group)));
    }
    return nodes;
  }
  function isReadOnly() {
    return !!S.story && (!!S.story.generated_from || S.stories.some(e => e.path === 'res://' + projectSource.path && e.authoring === 'dialogue'));
  }
  let conversionRegistry = null;
  function convertStory(id) {
    if (S.stories.some(e => e.id === id)) throw new Error('請使用未存在的新故事 id（英文、數字、底線）');
    const result = Core.graphCopy(S.story,id,conversionRegistry || ownerRegistry(),currentRegistryEntry());
    const layout = JSON.parse(JSON.stringify(S.layout));
    loadStory(result.story, `${id}_story.json`, null, null, result.registry.stories.at(-1).path.replace(/^res:\/\//, ''));
    S.layout = layout; conversionRegistry = result.registry;
    confirmedText = null; history.reset(snapshot()); refreshDirty(); saveDraft(); saveLayout();
    S.notice = '圖編輯副本已建立。匯出故事後跑 check_story；下載 stories.json 並合併登記，讓遊戲讀到新故事。原始故事保留。';
    renderAll(); fit();
    return result;
  }

  function buildCard(id) {
    const node = S.story.nodes[id];
    const edges = S.a.edges[id];
    const size = sizeOf(id);
    const summary = Core.summaryOf(node);
    const pos = S.layout[id];
    const ending = Core.isEnding(node);
    const lost = S.a.unreachable.includes(id);
    const selected = S.sel && S.sel.type === 'node' && S.sel.id === id;
    const rows = summary.rows.length + (summary.chips.length ? 1 : 0);
    return el('div', {
      class: ['card', id === S.story.entry && 'entry', ending && 'ending', lost && 'unreachable', selected && 'selected'].filter(Boolean).join(' '),
      data: { node: id },
      style: { left: pos.x + 'px', top: pos.y + 'px', width: size.w + 'px', height: size.h + 'px', '--rows': rows },
    },
    el('div', { class: 'head' },
      el('span', { class: 'dot' }),
      el('span', { class: 'title', title: node.title }, node.title || '（無標題）'),
      id === S.story.entry && el('span', { class: 'badge entry' }, 'ENTRY'),
      ending && el('span', { class: 'badge end' }, '結局'),
      lost && el('span', { class: 'badge lost' }, '到不了'),
      S.missingArt?.[id]?.length > 0 && el('span', { class: 'badge missing-art', title: S.missingArt[id].map(m => m.text).join('\n') },
        `缺圖 ${S.missingArt[id].length}`),
      el('span', { class: 'nid' }, id)),
    el('div', { class: 'scene-body', style: { height: (size.body + 16) + 'px' } }, sceneMedia(id), el('div', { class: 'flow' }, flowNodes(id))),
    el('div', { class: 'ports' }, edges.map(edge => portRow(id, edge))));
  }

  const cardCache = new Map();
  function renderCanvas() {
    const alive = new Set(Object.keys(S.story.nodes));
    for (const [id, cached] of cardCache) if (!alive.has(id)) { cached.el.remove(); cardCache.delete(id); }
    for (const id of alive) {
      const signature = JSON.stringify([S.story.nodes[id], S.layout[id], S.media[id], S.catalogVersion || 0, S.missingArt?.[id] || null, id === S.story.entry, S.a.unreachable.includes(id), S.sel?.type === 'node' && S.sel.id === id, S.sel?.type === 'edge' && S.sel.node === id ? S.sel.key : null, auditionId]);
      const cached = cardCache.get(id);
      if (cached?.signature === signature && cached.el.parentNode === cardsEl) continue;
      const node = buildCard(id);
      if (cached?.el.parentNode === cardsEl) cached.el.replaceWith(node); else cardsEl.append(node);
      cardCache.set(id, { signature, el: node });
    }
    drawEdges();
  }

  const anchorOut = (id, index) => {
    const o = Core.portOffset(sizeOf(id), index);
    return { x: S.layout[id].x + o.x, y: S.layout[id].y + o.y };
  };
  const anchorIn = id => {
    const o = Core.inPortOffset();
    return { x: S.layout[id].x + o.x, y: S.layout[id].y + o.y };
  };
  const curve = (a, b) => {
    const d = Math.max(50, Math.abs(b.x - a.x) * 0.5);
    return `M${a.x} ${a.y} C${a.x + d} ${a.y} ${b.x - d} ${b.y} ${b.x} ${b.y}`;
  };

  function drawEdges() {
    edgesSvg.replaceChildren();
    const picked = S.sel && S.sel.type === 'edge' ? S.sel : null;
    let cut = null;
    for (const id of Object.keys(S.story.nodes)) {
      S.a.edges[id].forEach((edge, index) => {
        if (!edge.target) return;
        const from = anchorOut(id, index);
        const exists = edge.target in S.story.nodes;
        const selected = picked && picked.node === id && picked.key === edge.key;
        const g = svg('g', { class: `edge kind-${edge.kind}${DASHED.has(edge.kind) ? ' dashed' : ''}${exists ? '' : ' bad'}${selected ? ' selected' : ''}` });
        g.dataset.node = id;
        g.dataset.edge = edge.key;
        let d;
        let mid;
        if (exists) {
          const to = anchorIn(edge.target);
          d = curve(from, to);
          mid = { x: (from.x + to.x) / 2, y: (from.y + to.y) / 2 };
        } else {
          d = `M${from.x} ${from.y} h44`;
          mid = { x: from.x + 44, y: from.y };
          g.append(svg('text', { class: 'stub', x: from.x + 50, y: from.y + 4 }, `✕ ${edge.target}`));
        }
        g.prepend(svg('path', { class: 'hit', d }), svg('path', { class: 'line', d }));
        edgesSvg.append(g);
        if (selected) cut = mid;
      });
    }
    if (cut) {
      const scissors = svg('g', { class: 'cut', transform: `translate(${cut.x} ${cut.y})` });
      scissors.append(svg('circle', { r: 11 }), svg('text', {}, '✂'));
      edgesSvg.append(scissors);
    }
  }

  // ---------------------------------------------------------------- sidebar

  function renderBanner() {
    const box = $('banner');
    box.replaceChildren();
    renderProjectSave();
    if (storageError) box.append(el('p', { class: 'note error', role: 'alert', id: 'storageError' }, storageError));
    if (pendingDraft) {
      const changed = JSON.stringify(pendingDraft.base) !== originalStory;
      box.append(el('div', { class: 'note warn', id: 'draftRecovery' },
        `找到 ${pendingDraft.updatedAt || ''} 的草稿。${changed ? '來源檔已變動；復原前請確認版本。' : ''}請先決定復原／刪除；此頁的新修改不會覆蓋待處理草稿，可先匯出目前版本。`,
        el('div', { class: 'actions' }, button('復原草稿', restoreDraft), button('刪除草稿', discardDraft))));
    }
    if (draftBlocked) box.append(button('刪除損壞草稿（需確認）', discardDraft, 'danger'));
    if (pendingExport) box.append(el('p', { class: 'note warn', id: 'exportPending' }, '已送出下載，尚未確認儲存。請按「確認下載檔…」選回剛才的 JSON；比對成功才解除離頁提醒。'));
    if (S.error) box.append(el('p', { class: 'note error' }, S.error));
    $('btnAddNode').disabled = isReadOnly();
    $('btnConvert').hidden = !isReadOnly();
    $('btnRegistry').hidden = !conversionRegistry;
    if (isReadOnly()) {
      box.append(el('p', { class: 'note warn' }, `此故事為唯讀，來源：${S.story.generated_from || "dialogue"}。請改來源檔，或「轉成圖編輯來源」建立新故事。`));
    }
    if (!S.online) {
      box.append(el('p', { class: 'note info' }, '沒有連到專案資料：角色與素材的下拉改為文字輸入，列表用內建清單。要有下拉請在專案根目錄跑 python3 -m http.server，再開 /tools/story_editor/。'));
    }
    if (S.notice) box.append(el('p', { class: 'note info' }, S.notice));
  }

  function renderStatus() {
    if (!S.story) { $('status').textContent = '開啟一個 *_story.json，或按「新故事」'; return; }
    const count = Object.keys(S.story.nodes).length;
    $('status').textContent = `${S.name}${S.dirty ? ' ●未確認儲存' : ''} · ${count} 節點 · ${S.a.problems.length + saveIssues.length} 個問題`;
    document.title = `${S.dirty ? '● ' : ''}${S.story.id} · 劇本節點編輯器`;
  }

  function jumpTo(problem) {
    if (problem.node && problem.node in S.story.nodes) {
      centerOn(problem.node);
      select(problem.edge ? { type: 'edge', node: problem.node, key: problem.edge } : { type: 'node', id: problem.node });
      if (Number.isInteger(problem.step)) {
        const target = $('inspector').querySelector(`[data-step="${problem.step}"]`);
        if (target) { target.scrollIntoView({block: 'nearest'}); target.classList.add('search-hit'); }
      }
    } else {
      $('info').querySelector('select')?.focus();
    }
  }

  function renderSearch() {
    const results = Authoring.search(S.story, $('searchInput').value);
    $('searchCount').textContent = results.length ? `${results.length} 筆結果${results.length > 100 ? '（先顯示 100 筆）' : ''}` : ($('searchInput').value.trim() ? '沒有符合的結果' : '搜尋節點 ID、標題、台詞、角色與其他文字');
    $('searchResults').replaceChildren(...results.slice(0, 100).map(result => el('li', {},
      button(`${result.node} · ${result.path}：${result.text.slice(0, 180)}`, () => {
        centerOn(result.node); select({ type: 'node', id: result.node });
        const index = /^steps\.(\d+)/.exec(result.path)?.[1];
        const target = index !== undefined && $('inspector').querySelector(`[data-step="${index}"]`);
        if (target) { target.scrollIntoView({ block: 'nearest' }); target.classList.add('search-hit'); }
      }))));
  }

  function renderProblems() {
    const list = $('problems');
    const problems = [...S.a.problems, ...saveIssues];
    $('problemTitle').textContent = `問題清單（${problems.length}）`;
    list.replaceChildren(...(problems.length
      ? problems.map(problem => el('li', { data: { type: problem.type, node: problem.node || '' }, onclick: () => jumpTo(problem) },
        el('span', {}, PROBLEM_ICON[problem.type] || '⚠'), el('span', {}, el('b', {}, problem.node || (problem.type === 'validation' ? '驗證' : 'entry')), '　', problem.message)))
      : [el('li', { class: 'ok' }, '✓ 沒有發現問題')]));
  }

  const field = (label, ...controls) => el('div', { class: 'field' }, el('label', {}, label), el('div', {}, controls));
  const button = (label, onclick, cls = '') => el('button', { class: cls, onclick, type: 'button' }, label);

  function bindText(control, obj, key, optional, eventName = 'input') {
    let merge = null;
    control.addEventListener('focus', () => { merge = ++fieldSession; history?.breakMerge(); });
    control.addEventListener('blur', () => { merge = null; history?.breakMerge(); });
    control.addEventListener(eventName, () => {
      if (optional && control.value === '') delete obj[key];
      else obj[key] = control.value;
      touch({ merge });
    });
    return control;
  }
  const textInput = (obj, key, optional = false, placeholder = '') => bindText(el('input', { type: 'text', value: obj[key] ?? '', placeholder }), obj, key, optional);
  const textArea = (obj, key, optional = false, rows = 3) => bindText(el('textarea', { rows, value: obj[key] ?? '' }), obj, key, optional);

  /** A <select>; a current value the list does not know stays selectable, so editing another field never swaps it. */
  function select2(options, current, onChange, empty) {
    const list = options.map(o => (typeof o === 'string' ? { value: o, label: o } : o));
    if (current !== undefined && current !== '' && !list.some(o => o.value === current)) list.push({ value: current, label: `${current}（目前的值）` });
    const control = el('select', {}, empty !== undefined && el('option', { value: '' }, empty), list.map(o => el('option', { value: o.value }, o.label)));
    control.value = current ?? '';
    control.addEventListener('change', () => onChange(control.value));
    return control;
  }
  const nodeSelect = (current, onChange, empty = '— 未連線 —') =>
    select2(nodeIds().map(id => ({ value: id, label: `${id}　${S.story.nodes[id].title || ''}` })), current, onChange, empty);

  function speakerControl(obj, key, narrator = true) {
    if (!S.catalog) return textInput(obj, key, false, 'catalog 角色 id');
    const options = [...(narrator ? [{ value: 'narrator', label: 'narrator（旁白）' }] : []),
      ...Object.entries(S.catalog.characters || {}).map(([id, c]) => ({ value: id, label: `${id}（${(c && c.name) || id}）` }))];
    return select2(options, obj[key], v => { obj[key] = v; touch({inspector:true}); });
  }
  const expressionControl = step => select2(S.catalog ? Core.availableExpressions(S.catalog, step.id || step.speaker) : S.enums.VALID_EXPRESSIONS, step.expression, v => {
    if (v === '') delete step.expression; else step.expression = v;
    touch({inspector:true});
  }, '（預設）');
  /** `color` of an emotion_band: "#rrggbb" typed or picked; 清除 (or an empty box) removes the key, so the scene's own yellow shows. */
  const BAND_DEFAULT_COLOR = '#ffd23f';  // the CutInPanel StyleBox in scenes/comedy/emotion_band.tscn
  const HEX6 = /^#[0-9a-f]{6}$/i;
  function colorControl(step) {
    const hex = el('input', { type: 'text', value: step.color ?? '', placeholder: '#rrggbb（空白＝預設色）' });
    const picker = el('input', { type: 'color', value: HEX6.test(step.color || '') ? step.color : BAND_DEFAULT_COLOR, style: { width: '38px', flex: 'none' } });
    bindText(hex, step, 'color', true);
    hex.addEventListener('input', () => { picker.value = HEX6.test(hex.value) ? hex.value : BAND_DEFAULT_COLOR; });  // the swatch follows the box
    picker.addEventListener('input', () => { hex.value = picker.value; hex.dispatchEvent(new Event('input')); });
    const clear = button('清除', () => { hex.value = ''; hex.dispatchEvent(new Event('input')); }, 'small');
    return el('div', { style: { display: 'flex', gap: '4px' } }, hex, picker, clear);
  }
  const checkbox = (obj, key, label) => el('label', {}, el('input', {
    type: 'checkbox', checked: obj[key] === true,
    onchange: ev => { if (ev.target.checked) obj[key] = true; else delete obj[key]; touch(); },
  }), ' ' + label);

  const move = (array, from, to) => { const [item] = array.splice(from, 1); array.splice(to, 0, item); };
  const rowButtons = (array, index) => [
    index > 0 && button('↑', () => { move(array, index, index - 1); touch({ inspector: true }); }, 'small'),
    index < array.length - 1 && button('↓', () => { move(array, index, index + 1); touch({ inspector: true }); }, 'small'),
    button('✕', () => { array.splice(index, 1); touch({ inspector: true }); }, 'small danger'),
  ];

  function assetSelect(section, step, key = 'id', empty) {
    if (!S.catalog) return textInput(step, key);
    return select2(Object.entries(S.catalog[section] || {}).map(([id, a]) => ({ value: id, label: `${a.label || a.name || id} · ${id}` })), step[key], v => {
      step[key] = v; stopAudio(); touch({ inspector: true });
    }, empty);
  }
  /** A visual editor for the runner's existing left/center/right stage positions. */
  function characterPositionEditor(step) {
    const character = S.catalog?.characters?.[step.id];
    const places = ['left', 'center', 'right'];
    const labels = {left: '左側', center: '中央', right: '右側'};
    const selected = places.includes(step.position) ? step.position : places.includes(character?.slot) ? character.slot : 'center';
    const fraction = place => ({left: 1 / 6, center: 1 / 2, right: 5 / 6})[place];
    const picture = character?.expressions?.[step.expression] || character?.path;
    const actor = el('div', {class: 'stage-position-actor', style: {left: `${fraction(selected) * 100}%`},
      title: '拖曳角色到左、中或右站位'},
      picture ? el('img', {class: 'character-preview', src: Core.projectUrl(picture), alt: `${character?.name || step.id} ${step.expression || 'neutral'}`, draggable: false})
        : el('span', {class: 'stage-position-placeholder'}, character?.name || step.id || '角色'));
    const stage = el('div', {class: 'stage-position-preview', 'aria-label': '角色站位示意'},
      ...places.map(place => el('span', {class: `stage-position-guide ${place === selected ? 'selected' : ''}`}, labels[place])), actor);
    let dragging = false;
    const point = event => clamp((event.clientX - stage.getBoundingClientRect().left) / stage.getBoundingClientRect().width, 0, 1);
    const choose = place => {
      if (isReadOnly()) return;
      step.position = place;
      touch({inspector: true});
    };
    actor.addEventListener('pointerdown', event => {
      if (isReadOnly() || event.button !== 0) return;
      dragging = true; actor.setPointerCapture(event.pointerId); event.preventDefault();
      actor.classList.add('dragging');
    });
    actor.addEventListener('pointermove', event => { if (dragging) actor.style.left = `${point(event) * 100}%`; });
    actor.addEventListener('pointerup', event => {
      if (!dragging) return;
      dragging = false; actor.classList.remove('dragging');
      const x = point(event);
      choose(x < 1 / 3 ? 'left' : x < 2 / 3 ? 'center' : 'right');
    });
    actor.addEventListener('pointercancel', () => { dragging = false; actor.classList.remove('dragging'); actor.style.left = `${fraction(selected) * 100}%`; });
    const buttons = places.map(place => el('button', {type: 'button', class: place === selected ? 'selected' : '',
      'aria-pressed': String(place === selected), onclick: () => choose(place)}, labels[place]));
    return el('div', {class: 'stage-position-editor'}, stage,
      el('div', {class: 'stage-position-actions'}, ...buttons),
      el('p', {class: 'note'}, '拖曳立繪或按按鈕切換站位。位置與大小的精調在 Godot 的舞台和角色場景。'));
  }
  function scalarControl(obj, key, numberOnly = false) {
    const input = el('input', { type: 'text', value: JSON.stringify(obj[key] ?? (numberOnly ? 1 : true)), 'aria-label': key });
    const error = el('div', { class: 'err', role: 'alert' });
    input.addEventListener('change', () => {
      try {
        const value = JSON.parse(input.value);
        if (!(typeof value === 'string' || typeof value === 'boolean' || typeof value === 'number' && Number.isFinite(value))) throw new Error('請填 JSON 純量（文字加雙引號）');
        if (numberOnly && !Number.isInteger(value)) throw new Error('增減值必須是整數');
        obj[key] = value; error.textContent = ''; touch();
      } catch (err) { error.textContent = err.message; }
    });
    return el('div', {}, input, error);
  }
  function flagSelect(obj, key) {
    return select2(Object.keys(S.story.initial_flags || {}), obj[key], v => { obj[key] = v; touch(); }, '選擇旗標');
  }
  function testForm(test, replace) {
    if (!isObj(test) || (test.all && !Array.isArray(test.all)) || (test.any && !Array.isArray(test.any))) return [el('p', {class:'note warn'}, '條件格式無法顯示；請用 JSON 修正並跑 check_story。')];
    const kind = test.all ? 'all' : test.any ? 'any' : test.not ? 'not' : 'has' in test ? 'has' : 'flag';
    const kinds = [{ value: 'flag', label: '旗標比較' }, { value: 'has', label: '持有道具' }, { value: 'all', label: '全部成立 AND' }, { value: 'any', label: '任一成立 OR' }, { value: 'not', label: '反轉 NOT' }];
    const seed = () => ({ flag: Object.keys(S.story.initial_flags || {})[0] || '', cmp: '==', value: true });
    const parts = [field('條件種類', select2(kinds, kind, v => {
      replace(v === 'all' || v === 'any' ? { [v]: [seed()] } : v === 'not' ? { not: seed() } : v === 'has' ? { has: '' } : seed());
      touch({ inspector: true });
    }))];
    if (kind === 'all' || kind === 'any') {
      parts.push(...test[kind].map((child, i) => el('div', { class: 'condition-child' }, ...testForm(child, v => { test[kind][i] = v; }),
        test[kind].length > 1 && button('刪除此條件', () => { test[kind].splice(i, 1); touch({ inspector: true }); }, 'small'))));
      parts.push(button('＋條件', () => { test[kind].push(seed()); touch({ inspector: true }); }, 'small'));
    } else if (kind === 'not') parts.push(el('div', { class: 'condition-child' }, ...testForm(test.not, v => { test.not = v; })));
    else if (kind === 'has') parts.push(field('道具', assetSelect('items', test, 'has')));
    else parts.push(field('旗標', flagSelect(test, 'flag')), field('比較', select2(['==', '!=', '<', '<=', '>', '>='], test.cmp, v => { test.cmp = v; touch(); })), field('值 JSON', scalarControl(test, 'value')));
    return parts;
  }

  const FORMS = {
    bg: step => [field('背景', assetSelect('backgrounds', step)), field('預覽', thumbnail(step.id))],
    bgm: step => [field('BGM', assetSelect('music', step, 'id', '無（停止音樂）')), field('試聽', audioButton(step.id))],
    se: step => [field('音效', assetSelect('sounds', step))],
    char: step => [field('角色', assetSelect('characters', step)), field('表情', expressionControl(step)), voicePitch(step),
      field('站位', select2(['left', 'center', 'right'], step.position, v => { if (v) step.position = v; else delete step.position; touch({inspector: true}); }, '（角色預設）')),
      field('舞台', characterPositionEditor(step)),
      field('顯示', select2([{value:'default',label:'預設'},{value:'true',label:'顯示'},{value:'false',label:'隱藏'}], step.visible === undefined ? 'default' : String(step.visible), v => { if(v === 'default') delete step.visible; else step.visible = v === 'true'; touch(); })), field('', checkbox(step, 'enter', '登場'))],
    profile: step => [field('角色檔案', assetSelect('characters', step))],
    item: step => [field('取得道具', assetSelect('items', step))],
    flag: step => [field('旗標', flagSelect(step, 'key')), field('操作', select2([{value:'value',label:'設定值'},{value:'add',label:'加減整數'}], 'add' in step ? 'add' : 'value', v => { delete step.value; delete step.add; step[v] = v === 'add' ? 1 : true; touch({inspector:true}); })), field('值 JSON', scalarControl(step, 'add' in step ? 'add' : 'value', 'add' in step))],
    condition: step => [field('條件模式', select2([{value:'simple',label:'單一旗標等於'},{value:'tree',label:'複合條件'}], 'test' in step ? 'tree' : 'simple', v => {
      if(v === 'tree') { step.test = {flag:step.flag || '',cmp:'==',value:step.equals ?? true}; delete step.flag; delete step.equals; }
      else { delete step.test; step.flag = ''; step.equals = true; }
      touch({inspector:true});
    })), ...('test' in step ? testForm(step.test, v => {step.test=v;}) : [field('旗標', flagSelect(step,'flag')), field('等於 JSON', scalarControl(step,'equals'))]),
      field('成立 then', nodeSelect(step.then, v => {step.then=v;touch();})), field('否則 else', nodeSelect(step.else,v => {step.else=v;touch();}))],

    say: step => [field('speaker', speakerControl(step, 'speaker')), field('text', textArea(step, 'text')),
      field('expression', expressionControl(step)), voicePitch(step), field('', checkbox(step, 'thought', '心聲（thought）'))],
    goto: step => [field('target', nodeSelect(step.target, v => { step.target = v; touch(); }))],
    end: step => [field('text', textArea(step, 'text', false, 2))],
    comedy: step => [
      field('preset', select2(S.enums.VALID_COMEDY_PRESETS, step.preset, v => {
        step.preset = v;
        if (v !== 'emotion_band') delete step.color;  // story_runner.gd accepts `color` on emotion_band only
        touch({ inspector: true });
      })),
      field('speaker', speakerControl(step, 'speaker', false)), field('text', textArea(step, 'text')), field('expression', expressionControl(step)), voicePitch(step),
      step.preset === 'emotion_band' && field('color', colorControl(step))],
    choice: step => {
      const options = Array.isArray(step.options) ? step.options : [];
      return [field('prompt', textInput(step, 'prompt')),
        ...options.map((option, j) => isObj(option) && el('div', { class: 'opt' },
          textInput(option, 'id', false, 'id'), textInput(option, 'label', false, '選項文字'),
          el('div', { class: 'wide' }, nodeSelect(option.next, v => { option.next = v; touch(); }), rowButtons(options, j)))),
        button('＋選項', () => {
          if (!Array.isArray(step.options)) step.options = [];
          let n = step.options.length + 1;
          while (step.options.some(o => o.id === 'opt' + n)) n++;
          step.options.push({ id: 'opt' + n, label: '新選項', next: '' });
          touch({ inspector: true });
        }, 'small')];
    },
  };

  function applyJson(step, text) {
    let value;
    try { value = JSON.parse(text); } catch (err) { return `JSON 解析失敗，沒有改動：${err.message}`; }
    if (!isObj(value) || typeof value.op !== 'string' || !value.op) return '必須是帶有 op 的物件，沒有改動';
    for (const key of Object.keys(step)) delete step[key];
    Object.assign(step, value);
    return '';
  }

  function stepBox(node, step, index) {
    const form = FORMS[step.op];
    const json = el('textarea', { class: 'json', value: Core.stringify(step), spellcheck: false });
    const err = el('div', { class: 'err' });
    json.addEventListener('focus', () => { json.value = Core.stringify(step); });  // the form may have changed the step since this was drawn
    json.addEventListener('change', () => {
      err.textContent = applyJson(step, json.value);
      if (!err.textContent) touch({ inspector: true });
    });
    return el('div', { class: 'step', data: { step: index } },
      el('div', { class: 'step-head' }, el('span', {}, `#${index}`), el('span', { class: 'op', title: step.op }, `${Core.icon(step.op)} ${Core.stepLabel(step)}`, el('small', {class:'op-code'}, step.op)), rowButtons(node.steps, index)),
      el('div', { class: 'step-body' }, form ? form(step) : [], el('details', { open: !form }, el('summary', {}, 'JSON（所有欄位）'), json, err)));
  }

  function renderInfo() {
    const box = $('info');
    const story = S.story;
    if (!story) { box.replaceChildren(); return; }
    const flags = el('textarea', { rows: 3, value: Core.stringify(story.initial_flags || {}), spellcheck: false });
    const flagsErr = el('div', { class: 'err' });
    flags.addEventListener('change', () => {
      try {
        const value = JSON.parse(flags.value);
        if (!isObj(value)) throw new Error('必須是物件');
        story.initial_flags = value;
        flagsErr.textContent = '';
        touch();
      } catch (err) { flagsErr.textContent = `沒有改動：${err.message}`; }
    });
    box.replaceChildren(
      field('id', bindText(el('input', { type: 'text', value: story.id }), story, 'id', false, 'change')),
      field('title', textInput(story, 'title')),
      field('entry', select2(nodeIds(), story.entry, v => { story.entry = v; touch(); })),
      field('version', el('code', {}, story.version ?? '（無）'), el('div', { id: 'versionHint', class: 'err', style: { color: 'var(--muted)' } })),
      field('flags', flags, flagsErr),
      ...registryControls(),
      field('預設視角',select2(Object.entries(S.catalog?.characters || {}).map(([id,c])=>({value:id,label:`${c.name || id} · ${id}`})),story.default_pov,v=>{if(v)story.default_pov=v;else delete story.default_pov;touch();},`用 catalog 預設（${S.catalog?.default_pov || '未設定'}）`)));
  }

  function renderVersionHint() {
    const hint = $('versionHint');
    if (hint) hint.textContent = S.modified ? '已修改：匯出時 version 寫成 s-unset，要跑 check_story.gd --write 才會算出正確值' : '沒改過：匯出會原樣寫回';
  }

  function applyReadOnly() {
    for (const area of [$('info'), $('inspector')]) area.querySelectorAll('input,textarea,select,button').forEach(c => {
      c.disabled = (isReadOnly() && !c.hasAttribute('data-audition') && !c.dataset.registryField) || (c.id === 'previewStart' && previewStarting);
    });
  }

  function renderInspector() {
    const box = $('inspector');
    box.replaceChildren();
    const sel = S.sel;
    if (!S.story) return;
    if (!sel) { box.append(el('p', { class: 'note info' }, '點一張卡片編輯節點；點一條線可以斷線；雙擊空白處新增節點。')); return; }
    if (sel.type === 'edge') {
      const edge = S.a.edges[sel.node].find(e => e.key === sel.key);
      if (!edge) return;
      box.append(el('h3', {}, '出線'),
        field('來源', `${sel.node} · ${edge.label}`),
        field('目標', nodeSelect(edge.target, v => { if (v) Core.setEdge(S.story, sel.node, edge, v); else Core.clearEdge(S.story, sel.node, edge); touch({ inspector: true }); })),
        el('div', { class: 'actions' },
          button('✂ 斷線', () => disconnect(sel.node, edge), 'danger'),
          button('到來源', () => { centerOn(sel.node); select({ type: 'node', id: sel.node }); }),
          edge.target && edge.target in S.story.nodes && button('到目標', () => { centerOn(edge.target); select({ type: 'node', id: edge.target }); })));
      return;
    }
    const id = sel.id;
    const node = S.story.nodes[id];
    const idErr = el('div', { class: 'err' });
    const idInput = el('input', { type: 'text', value: id });
    idInput.addEventListener('change', () => {
      const next = idInput.value.trim();
      const message = Core.renameNode(S.story, id, next);
      if (message) { idErr.textContent = message; idInput.value = id; return; }
      if (next !== id) {
        S.layout[next] = S.layout[id];
        delete S.layout[id];
        S.sel = { type: 'node', id: next };
        renderInfo();
        touch({ inspector: true });
      }
    });
    box.append(el('h3', {}, '節點'),
      field('id', idInput, idErr, el('div', { class: 'err', style: { color: 'var(--muted)' } }, '改名會同步所有指向它的出線與 entry')),
      field('title', textInput(node, 'title')));
    const nextEdge = S.a.edges[id].find(e => e.key === 'next');
    if (nextEdge) {
      box.append(field('next', nodeSelect(nextEdge.target, v => {
        if (v) Core.setEdge(S.story, id, nextEdge, v); else Core.clearEdge(S.story, id, nextEdge);
        touch({ inspector: true });
      }, '— 無 —')));
    }
    box.append(el('div', { class: 'actions' },
      button(id === S.story.entry ? '✓ 這是 entry' : '設為 entry', () => { S.story.entry = id; renderInfo(); touch({ inspector: true }); }),
      button('刪除節點', () => removeNode(id), 'danger')));
    if (S.service) box.append(previewControls(id));
    box.append(el('h3', {}, `步驟（${node.steps.length}）`), ...node.steps.map((step, index) => stepBox(node, step, index)));
    const op = el('select', { id: 'addStepOp', size: 16, 'aria-label': '新增步驟分類' }, Core.STEP_GROUPS.slice(0, 7).map(group => el('optgroup', {label: group.label}, group.ops.map(name => el('option', {value: `${group.id}:${name}`}, `${Core.icon(name)} ${Core.stepLabel({op:name,speaker:group.id === 'narration' ? 'narrator' : 'speaker'})}（${name}）`)))));
    op.value = 'dialogue:say';
    box.append(el('details', {id: 'addStepPicker', class: 'step-picker'}, el('summary', {}, '選擇步驟類型（七類）'), op));
    const addStepError = el('div', {class: 'err', role: 'alert'});
    box.append(addStepError);
    box.append(el('div', { class: 'actions' }, button('＋ 新增步驟', () => {
      const [category, name] = op.value.split(':');
      const step = Core.newStep(name);
      if (name === 'say') step.speaker = category === 'narration' ? 'narrator' : Object.keys(S.catalog?.characters || {})[0] || 'speaker';
      const error = Core.addStep(node, step);
      if (error) { addStepError.textContent = error; return; }
      touch({ inspector: true });
    })));
  }

  function previewControls(id) {
    const flagInputs = new Map(), itemInputs = new Map();
    const flagRows = Object.entries(S.story.initial_flags || {}).map(([key, value]) => {
      let input;
      if (typeof value === 'boolean') {
        input = el('select', {'data-audition': 'true'},
          el('option', {value: 'true'}, '是'), el('option', {value: 'false'}, '否'));
        input.value = String(value);
      } else {
        input = el('input', {type: typeof value === 'number' ? 'number' : 'text',
          value: String(value), 'data-audition': 'true'});
        if (typeof value === 'number') input.step = 'any';
      }
      flagInputs.set(key, {input, type: typeof value});
      return field(key, input);
    });
    const itemRows = Object.entries(S.catalog?.items || {}).map(([key, value]) => {
      const input = el('input', {type: 'checkbox', 'data-audition': 'true'});
      itemInputs.set(key, input);
      return el('label', {class: 'preview-item'}, input, `${value.name || key}（${key}）`);
    });
    const start = el('button', {id: 'previewStart', class: 'primary', 'data-audition': 'true', disabled: previewStarting}, '從這裡試玩');
    start.addEventListener('click', async () => {
      if (previewStarting) return;
      const flags = {};
      for (const [key, {input, type}] of flagInputs) {
        if (type === 'number' && (!input.value.trim() || !Number.isFinite(Number(input.value)))) {
          failure(`旗標 ${key} 請填入數字。`); return;
        }
        flags[key] = type === 'boolean' ? input.value === 'true' : type === 'number' ? Number(input.value) : input.value;
      }
      const source = projectSource, submitted = storyText();
      const work = packOf(workOf(source.path));
      const payload = {path: source.path, story: JSON.parse(submitted), node: id, flags,
        items: [...itemInputs].filter(([, input]) => input.checked).map(([key]) => key),
        skin: currentRegistryEntry().skin || work?.pack.skin || ''};
      previewStarting = true; start.disabled = true; start.textContent = '正在啟動…';
      S.error = ''; S.notice = ''; saveIssues = []; renderBanner(); renderProblems(); renderStatus();
      try {
        const response = await fetch('../../api/preview', {method: 'POST',
          headers: {'Content-Type': 'application/json', 'X-Story-Editor-Token': S.service.token}, body: JSON.stringify(payload)});
        const result = await response.json();
        if (projectSource !== source) return;
        if (!response.ok || result.ok !== true) {
          const errors = [result.error || '試玩未能啟動', ...(result.errors || [])];
          saveIssues = errors.map(message => ({type: 'validation', message}));
          failure(errors[0]); renderProblems(); return;
        }
        S.notice = storyText() === submitted ? result.message : '試玩已開啟，內容是按下按鈕時的版本；後續修改仍在編輯器。';
        renderBanner(); renderStatus();
      } catch (err) {
        if (projectSource === source) failure(`無法啟動試玩：${err.message}。修改仍在編輯器。`);
      } finally {
        previewStarting = false;
        const current = $('previewStart');
        if (current) { current.disabled = false; current.textContent = '從這裡試玩'; }
      }
    });
    return el('details', {id: 'previewConfig', class: 'preview-config'},
      el('summary', {}, '試玩這個場景'),
      el('p', {class: 'note'}, '可調整本次旗標與線索；背景、角色與音樂從這個場景開始，不會自動重播前面的劇情。'),
      flagRows.length ? el('div', {class: 'preview-section'}, el('strong', {}, '旗標'), ...flagRows) : null,
      itemRows.length ? el('div', {class: 'preview-section'}, el('strong', {}, '已取得的線索'), ...itemRows) : null,
      el('div', {class: 'actions'}, start));
  }

  function renderAll() {
    renderBanner();
    renderInfo();
    renderCanvas();
    renderProblems();
    renderInspector();
    renderStatus();
    renderVersionHint();
    applyReadOnly();
    renderHistory();
    renderSearch();
  }

  // ---------------------------------------------------------------- editing actions

  function addNode(pos, connect) {
    if (isReadOnly()) return;
    const id = Core.uniqueId(S.story, 'node');
    S.story.nodes[id] = Core.newNode();
    S.layout[id] = { x: Math.round(pos.x), y: Math.round(pos.y) };
    if (connect) Core.setEdge(S.story, connect.node, connect.edge, id);
    S.sel = { type: 'node', id };
    renderInfo();
    touch({ inspector: true });
    return id;
  }
  function removeNode(id) {
    if (isReadOnly()) return;
    if (!confirm(`刪除節點「${id}」？指向它的出線會留著並標成紅色，之後可以重新連。`)) return;
    Core.deleteNode(S.story, id);
    delete S.layout[id];
    S.sel = null;
    renderInfo();
    touch({ inspector: true });
  }
  function disconnect(nodeId, edge) {
    if (isReadOnly()) return;
    Core.clearEdge(S.story, nodeId, edge);
    touch({ inspector: true });
  }

  // ---------------------------------------------------------------- mouse

  let drag = null;

  function cardAt(x, y) {
    for (const node of document.elementsFromPoint(x, y)) {
      const card = node.closest && node.closest('.card');
      if (card) return card.dataset.node;
    }
    return null;
  }
  function insideView(x, y) {
    const r = view.getBoundingClientRect();
    return x >= r.left && x <= r.right && y >= r.top && y <= r.bottom;
  }

  view.addEventListener('pointerdown', ev => {
    if (ev.button !== 0 || ev.target.closest('button,input,select')) return;
    const t = ev.target;
    if (t.closest('.cut')) { disconnectSelected(); return; }
    const row = t.closest('.prow');
    const card = t.closest('.card');
    const edgeHit = t.closest('.edge');
    if (row && card && !isReadOnly()) {
      const id = card.dataset.node;
      const edge = S.a.edges[id].find(e => e.key === row.dataset.edge);
      drag = { type: 'link', id, edge, index: S.a.edges[id].indexOf(edge), sx: ev.clientX, sy: ev.clientY, moved: false, hover: null };
    } else if (card) {
      const id = card.dataset.node;
      const w = toWorld(ev.clientX, ev.clientY);
      history.breakMerge();
      drag = { type: 'node', before: JSON.parse(JSON.stringify(S.layout[id])), id, ox: w.x - S.layout[id].x, oy: w.y - S.layout[id].y, sx: ev.clientX, sy: ev.clientY, moved: false };
      select({ type: 'node', id });
    } else if (edgeHit) {
      select({ type: 'edge', node: edgeHit.dataset.node, key: edgeHit.dataset.edge });
      return;
    } else {
      drag = { type: 'pan', sx: ev.clientX, sy: ev.clientY, vx: S.v.x, vy: S.v.y, moved: false };
      view.classList.add('panning');
    }
    view.setPointerCapture(ev.pointerId);
  });

  view.addEventListener('pointermove', ev => {
    if (!drag) return;
    const dx = ev.clientX - drag.sx;
    const dy = ev.clientY - drag.sy;
    if (!drag.moved && Math.hypot(dx, dy) < (drag.type === 'link' ? 24 : 3)) return;
    drag.moved = true;
    if (drag.type === 'pan') {
      S.v.x = drag.vx + dx;
      S.v.y = drag.vy + dy;
      applyView();
    } else if (drag.type === 'node') {
      const w = toWorld(ev.clientX, ev.clientY);
      S.layout[drag.id] = { ...S.layout[drag.id], x: Math.round(w.x - drag.ox), y: Math.round(w.y - drag.oy) };
      const card = cardEl(drag.id);
      card.style.left = S.layout[drag.id].x + 'px';
      card.style.top = S.layout[drag.id].y + 'px';
      drawEdges();
    } else {
      let tmp = edgesSvg.querySelector('.tmp');
      if (!tmp) { tmp = svg('path', { class: 'tmp' }); edgesSvg.append(tmp); }
      tmp.setAttribute('d', curve(anchorOut(drag.id, drag.index), toWorld(ev.clientX, ev.clientY)));
      const hover = cardAt(ev.clientX, ev.clientY);
      if (hover !== drag.hover) {
        cardEl(drag.hover)?.classList.remove('drop');
        cardEl(hover)?.classList.add('drop');
        drag.hover = hover;
      }
    }
  });

  function endDrag(ev, cancelled) {
    if (!drag) return;
    const d = drag;
    drag = null;
    view.classList.remove('panning');
    try { view.releasePointerCapture(ev.pointerId); } catch (err) { /* already released */ }
    if (d.type === 'link') {
      cardEl(d.hover)?.classList.remove('drop');
      edgesSvg.querySelector('.tmp')?.remove();
      if (cancelled) return;
      if (!d.moved) { select({ type: 'edge', node: d.id, key: d.edge.key }); return; }
      const target = cardAt(ev.clientX, ev.clientY);
      if (target) {
        Core.setEdge(S.story, d.id, d.edge, target);
        touch({ inspector: true });
      } else if (insideView(ev.clientX, ev.clientY)) {
        const w = toWorld(ev.clientX, ev.clientY);
        addNode({ x: w.x + 8, y: w.y - GEOM.header / 2 }, { node: d.id, edge: d.edge });
      }
    } else if (d.type === 'node') {
      if (cancelled) { S.layout[d.id] = d.before; renderCanvas(); }
      else if (d.moved) { history.commit(snapshot()); saveLayout(); saveDraft(); renderHistory(); }
    } else if (!d.moved && !cancelled) {
      select(null);
    }
  }
  view.addEventListener('pointerup', ev => endDrag(ev, false));
  view.addEventListener('pointercancel', ev => endDrag(ev, true));

  view.addEventListener('dblclick', ev => {
    if (!S.story || ev.target.closest('.card, .edge, .cut')) return;
    const w = toWorld(ev.clientX, ev.clientY);
    addNode({ x: w.x - GEOM.width / 2, y: w.y - GEOM.header / 2 });
  });

  view.addEventListener('wheel', ev => {
    ev.preventDefault();
    zoomAt(ev.clientX, ev.clientY, Math.exp(-ev.deltaY * 0.0015));
  }, { passive: false });

  function disconnectSelected() {
    if (!S.sel || S.sel.type !== 'edge') return;
    const edge = S.a.edges[S.sel.node].find(e => e.key === S.sel.key);
    if (edge) disconnect(S.sel.node, edge);
  }

  document.addEventListener('keydown', ev => {
    if ((ev.ctrlKey || ev.metaKey) && ev.key.toLowerCase() === 'f') {
      ev.preventDefault(); $('searchInput').focus(); $('searchInput').select(); return;
    }
    if ((ev.ctrlKey || ev.metaKey) && !ev.isComposing && ['z', 'y'].includes(ev.key.toLowerCase()) && S.story) {
      if (ev.target.classList?.contains('json')) return; // Uncommitted JSON keeps native textarea undo.
      ev.preventDefault();
      restoreHistory(ev.shiftKey || ev.key.toLowerCase() === 'y' ? history.redo() : history.undo()); return;
    }
    if (/^(INPUT|TEXTAREA|SELECT)$/.test(ev.target.tagName) || !S.story) return;
    if ((ev.key === 'Delete' || ev.key === 'Backspace') && S.sel) {
      ev.preventDefault();
      if (isReadOnly()) return;
      if (S.sel.type === 'node') removeNode(S.sel.id); else disconnectSelected();
    } else if (ev.key === 'Escape') {
      select(null);
    }
  });

  // ---------------------------------------------------------------- files

  function download(name, text) {
    const url = URL.createObjectURL(new Blob([text], { type: 'application/json' }));
    const link = el('a', { href: url, download: name });
    document.body.append(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 2000);
  }

  function shapeError(story) {
    if (!isObj(story) || !isObj(story.nodes) || typeof story.entry !== 'string') return '不像劇本：需要 nodes（物件）與 entry（字串）';
    for (const [id, node] of Object.entries(story.nodes)) {
      if (!isObj(node) || !Array.isArray(node.steps)) return `節點「${id}」必須是帶有 steps 陣列的物件`;
      const bad = node.steps.findIndex(step => !isObj(step) || typeof step.op !== 'string');
      if (bad >= 0) return `節點「${id}」第 ${bad} 步必須是帶有 op 的物件`;
    }
    return '';
  }

  function openText(text, name, path = null) {
    if (S.dirty && !confirm('目前的修改還沒確認儲存，要放棄嗎？')) return;
    let story;
    try { story = JSON.parse(text); } catch (err) { S.error = `${name}：不是合法的 JSON（${err.message}）`; renderBanner(); return; }
    const problem = shapeError(story);
    if (problem) { S.error = `${name}：${problem}`; renderBanner(); return; }
    loadStory(story, name, null, text, path);
  }

  function exportStory() {
    if (!S.story) return;
    try {
      const text = storyText();
      download(S.name, text);
      pendingExport = { text, key: draftKey };
      S.error = '';
      S.notice = `匯出 ${S.name}${S.modified ? '（version 是 s-unset）' : ''}。放進專案後跑 check_story.gd --write 重算 version 並驗證。`;
      saveDraft(); renderBanner(); renderStatus();
    } catch (err) { failure(`下載失敗：${err.message}。修改仍保留，請重試。`); }
  }
  async function verifyDownload(file) {
    const pending = pendingExport;
    if (!pending) { failure('請先匯出，再選回下載的 JSON 檔案確認。'); return; }
    try {
      const text = await file.text();
      if (pending !== pendingExport || pending.key !== draftKey) return;
      if (text !== pending.text) throw new Error('檔案內容與這次匯出不同，尚未確認儲存');
      if(pending.kind==='registry')confirmedRegistryText=pending.text;else confirmedText=pending.text;
      S.error = '';
      pendingExport = null;
      refreshDirty();
      S.notice = S.dirty ? '下載檔已比對成功，但頁面另有後續修改，請再次匯出。' : '下載檔內容比對成功。修改過的劇本仍須跑 check_story.gd --write。';
      saveDraft(); renderBanner(); renderStatus();
    } catch (err) { failure(`確認下載失敗：${err.message}。未儲存提醒仍保留。`); }
  }

  function exportLayout() {
    if (!S.story) return;
    const nodes = {};
    for (const id of nodeIds()) nodes[id] = JSON.parse(JSON.stringify(S.layout[id]));
    download(`${S.story.id}.layout.json`, JSON.stringify({ story: S.story.id, nodes }, null, 2) + '\n');
  }
  function importLayout(text) {
    let data;
    try { data = JSON.parse(text); } catch (err) { S.error = `座標檔不是合法的 JSON（${err.message}）`; renderBanner(); return; }
    if (!isObj(data) || !isObj(data.nodes)) { S.error = '座標檔需要 nodes：{id: {x, y}}'; renderBanner(); return; }
    S.error = data.story && data.story !== S.story.id ? `注意：這份座標是給「${data.story}」的，套用到「${S.story.id}」。` : '';
    for (const id of Object.keys(S.story.nodes)) {
      const p = data.nodes[id];
      if (isObj(p) && Number.isFinite(p.x) && Number.isFinite(p.y)) S.layout[id] = cleanLayout({ [id]: p })[id];
    }
    ensureLayout();
    history.commit(snapshot());
    renderBanner();
    renderCanvas();
    saveLayout(); saveDraft(); renderHistory();
    fit();
  }

  async function readStoryFile(file) {
    const ticket = ++loadTicket;
    try {
      const text = await file.text();
      if (ticket === loadTicket) openText(text, file.name);
    } catch (err) { if (ticket === loadTicket) failure(`讀檔失敗：${err.message}。目前故事沒有改動。`); }
  }
  $('fileOpen').addEventListener('change', ev => {
    const file = ev.target.files[0]; ev.target.value = '';
    if (file) readStoryFile(file);
  });
  $('verifySaved').addEventListener('change', ev => {
    const file = ev.target.files[0]; ev.target.value = '';
    if (file) verifyDownload(file);
  });
  $('layoutOpen').addEventListener('change', async ev => {
    const file = ev.target.files[0]; ev.target.value = '';
    const story = S.story;
    const ticket = loadTicket;
    try {
      if (file && story) {
        const text = await file.text();
        if (ticket === loadTicket && S.story === story) importLayout(text);
      }
    } catch (err) { if (ticket === loadTicket && S.story === story) failure(`座標讀檔失敗：${err.message}。目前座標沒有改動。`); }
  });
  $('storySelect').addEventListener('change', async ev => {
    const entry = S.stories.find(s => s.id === ev.target.value);
    const ticket = ++loadTicket;
    if (!entry) return;
    try {
      const response = await fetch(Core.projectUrl(entry.path));
      if (!response.ok) throw new Error(response.status);
      const text = await response.text();
      if (ticket === loadTicket) openText(text, entry.path.split('/').pop(), entry.path.replace(/^res:\/\//, ''));
    } catch (err) { if (ticket === loadTicket) failure(`讀不到 ${entry.path}（${err.message}）`); }
  });
  /** A blank story at data/<id>_story.json, or in a work's folder (registered in its pack.json on save). */
  function startNewStory(id, work = null) {
    loadStory(Core.newStory(id), `${id}_story.json`, null, null, work ? `stories/${work}/${id}_story.json` : null);
    confirmedText = null;
    refreshDirty(); saveDraft();
    renderStatus();
    renderVersionHint();
  }
  $('btnNewStory').addEventListener('click', () => {
    if (S.dirty && !confirm('目前的修改還沒確認儲存，要放棄嗎？')) return;
    let work = null;
    if (S.packs.length) {
      work = (prompt(`放在哪個作品？填作品 id；留空＝本作（data/）。\n${S.packs.map(p => `${p.id}：${p.title}`).join('\n')}`,
        workOf(projectSource.path) || '') || '').trim() || null;
      if (work && !packOf(work)) { failure(`沒有 ${work} 這個作品。`); return; }
    }
    const id = (prompt('新故事的 id（英文、數字、底線）', work ? `${work}_ch${Core.packEntries(packOf(work).pack, work).length + 1}` : 'my_story') || '').trim();
    if (!/^[A-Za-z0-9_]+$/.test(id)) return;
    if (S.stories.some(e => e.id === id)) { failure(`已經有 ${id} 這個故事。`); return; }
    startNewStory(id, work);
  });
  /** 素材設定 of the open story's catalog file: its work's catalog.json, else data/asset_catalog.json. */
  async function openCatalog() {
    if (!S.service) return;
    const work = workOf(projectSource.path);
    const path = work ? `stories/${work}/catalog.json` : 'data/asset_catalog.json';
    try {
      const loaded = await getJson(`../../api/catalog?path=${encodeURIComponent(path)}`);
      globalThis.CatalogEditor.open({
        el, enums: S.enums, projectUrl: Core.projectUrl,
        loaded: { ...loaded, inherited: work && loaded.catalog.extends ? S.baseCatalog : null },
        post: (url, body) => fetch(url, {method:'POST', headers:{'Content-Type':'application/json','X-Story-Editor-Token':S.service.token}, body:JSON.stringify(body)}),
        onSaved: reloadCatalogs,
      });
    } catch (err) { failure(`素材設定打不開：${err.message}`); }
  }
  /** After 素材設定 saves: the game's catalog and every work's again (a work may extend the game's). */
  async function reloadCatalogs() {
    S.baseCatalog = await getJson('../../data/asset_catalog.json');
    await Promise.all(S.packs.map(p => loadPackCatalog(p.id)));
    useCatalog();
    S.catalogVersion = (S.catalogVersion || 0) + 1;
    if (S.story) { recompute(); renderAll(); }
  }
  $('btnCatalog').addEventListener('click', openCatalog);
  $('btnNewWork').addEventListener('click', async () => {
    if (!S.service || (S.dirty && !confirm('目前的修改還沒確認儲存，要放棄嗎？'))) return;
    const id = (prompt('作品 id（英文小寫、數字、底線，例如 titan）') || '').trim();
    if (!id) return;
    const title = (prompt('作品名稱（章節選擇裡的標題）', id) || '').trim();
    if (!title) return;
    try {
      const response = await fetch('../../api/work', {method:'POST',
        headers:{'Content-Type':'application/json','X-Story-Editor-Token':S.service.token},body:JSON.stringify({id,title})});
      const result = await response.json();
      if (!response.ok || result.ok !== true) { failure(result.error || '建立作品失敗'); return; }
      S.packs = result.packs;
      await loadPackCatalog(id);
      rebuildStories();
      startNewStory(`${id}_ch1`, id);
      S.notice = `${result.message} 第一章已開好，按「驗證並存檔」後它會登記進 pack.json。`;
      renderBanner();
    } catch (err) { failure(`建立作品失敗：${err.message}`); }
  });
  $('btnConvert').addEventListener('click', () => {
    const id = prompt('新故事 id（原故事保留）', `${S.story.id}_graph`);
    if (id === null) return;
    try { convertStory(id.trim()); } catch (err) { failure(err.message); }
  });
  $('btnRegistry').addEventListener('click', exportRegistry);
  $('btnProjectSave').addEventListener('click', saveProject);
  $('btnExport').addEventListener('click', exportStory);
  $('btnUndo').addEventListener('click', () => restoreHistory(history?.undo()));
  $('btnRedo').addEventListener('click', () => restoreHistory(history?.redo()));
  $('searchInput').addEventListener('input', renderSearch);
  $('btnAddNode').addEventListener('click', () => {
    if (!S.story) return;
    const r = view.getBoundingClientRect();
    const c = toWorld(r.left + r.width / 2, r.top + r.height / 2);
    addNode({ x: c.x - GEOM.width / 2, y: c.y - GEOM.header / 2 });
  });
  $('btnLayout').addEventListener('click', () => {
    if (!S.story) return;
    const positions = Core.autoLayout(S.story, S.a, S.layout);
    for (const id of Object.keys(positions)) positions[id].expanded = S.layout[id]?.expanded || {};
    S.layout = positions;
    history.commit(snapshot());
    renderCanvas();
    saveLayout(); saveDraft(); renderHistory();
    fit();
  });
  $('btnFit').addEventListener('click', () => S.story && fit());
  $('btnLayoutExport').addEventListener('click', exportLayout);
  window.addEventListener('beforeunload', ev => { if (S.dirty) { ev.preventDefault(); ev.returnValue = ''; } });

  // ---------------------------------------------------------------- project data (only when served over http)

  async function getJson(url) {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`${url}: ${response.status}`);
    return response.json();
  }

  async function loadProject() {
    const [stories, catalog, runner, service] = await Promise.allSettled([
      getJson('../../data/stories.json'), getJson('../../data/asset_catalog.json'),
      fetch('../../scripts/story_runner.gd').then(r => (r.ok ? r.text() : Promise.reject(new Error(r.status)))),
      detectService(),
    ]);
    if (service.status === 'fulfilled') S.service = service.value;
    const registry=S.service?.registry || (stories.status==='fulfilled'?stories.value:null);
    if(registry)S.registry=registry;
    S.registryHash=S.service?.registry_hash || null;
    S.packs=S.service?.packs || [];  // works are listed by the service (a static server lists no folders)
    if (catalog.status === 'fulfilled' && isObj(catalog.value.characters)) S.baseCatalog = catalog.value;
    await Promise.all(S.packs.map(p => loadPackCatalog(p.id)));
    useCatalog();
    rebuildStories();  // the skin list includes the ids the stories use
    S.skins=await loadSkins();
    if (runner.status === 'fulfilled') {
      for (const name of Object.keys(S.enums)) {
        const list = Core.parseGdStrings(runner.value, name);
        if (list && list.length) S.enums[name] = list;
      }
    }
    S.online = stories.status === 'fulfilled' && catalog.status === 'fulfilled';
    const picker = $('storySelect');
    $('btnNewWork').hidden = !S.service;
    $('btnCatalog').hidden = !S.service;
    const wanted = new URLSearchParams(location.search).get('story');
    const entry = S.stories.find(s => s.id === wanted);
    if (entry && !S.story && loadTicket === 0) {
      picker.value = entry.id;
      picker.dispatchEvent(new Event('change'));
    } else if (!wanted && !S.story && loadTicket === 0) {
      try {
        const key = localStorage.getItem(LAST_DRAFT);
        const raw = key?.startsWith(DRAFT_KEY) && localStorage.getItem(key);
        if (raw) { const record = validDraft(raw); loadStory(record.base, record.name, key, null, record.projectSource?.path || null); }
      } catch (err) { storageFailure(err); }
    }
  }

  applyView();
  renderStatus();
  renderBanner();
  renderHistory();
  const ready = loadProject().then(() => { renderBanner(); }).catch(err => failure(`專案載入失敗：${err.message}`));
  window.addEventListener('storage', ev => {
    if (ev.key === draftKey && ev.newValue !== draftRaw) storageFailure(new Error('另一個分頁已變更此草稿，請先匯出目前版本'));
  });

  window.StoryEditor = {
    state: S, core: Core, ready,
    get story() { return S.story; },
    exportText: storyText,
    loadStory, fit, centerOn, select, readStoryFile, verifyDownload,
    setView(v) { S.v = { ...S.v, ...v }; applyView(); },
    saveProject,
    get projectSource() { return projectSource; },
    anchorOut, anchorIn, toWorld, sizeOf, convertStory, isReadOnly, stopAudio,
    get conversionRegistry() { return conversionRegistry; },
    openCatalog,
  };
})();
