/* catalog_editor.js: 素材設定 — edit a catalog file (data/asset_catalog.json or a work's
 * stories/<作品>/catalog.json) in its own form: relative paths stay relative, what it `extends` is
 * shown but not copied in, fields the page does not know are kept. Saving goes through the project
 * service (POST /api/catalog), which checks the catalog and every story that reads it first.
 * editor.js opens it with CatalogEditor.open({...}). */
(function () {
  'use strict';
  const KINDS = [
    { key: 'characters', label: '角色', media: 'image', name: 'name' },
    { key: 'backgrounds', label: '背景', media: 'image', name: 'label' },
    { key: 'items', label: '線索', media: 'image', name: 'name' },
    { key: 'sounds', label: '音效', media: 'audio', name: 'label' },
    { key: 'music', label: '音樂', media: 'audio', name: 'label' },
  ];
  const IMAGE = /\.(png|jpe?g|webp)$/i;
  const AUDIO = /\.(ogg|mp3|wav)$/i;
  const ID = /^[a-z_][a-z0-9_]*$/;
  const isObj = v => v !== null && typeof v === 'object' && !Array.isArray(v);
  const hex = value => {  // <input type=color> needs #rrggbb
    const v = String(value || '');
    return /^#[0-9a-f]{6}$/i.test(v) ? v : /^#[0-9a-f]{3}$/i.test(v) ? '#' + [...v.slice(1)].map(c => c + c).join('') : '#000000';
  };

  let state = null;  // {path, catalog, hash, original, files, inherited, kind, deps, errors, message, saving}

  function open(deps) {
    state = { deps, kind: 'characters', errors: [], message: '', saving: false, opened: new Set(), ...deps.loaded };
    state.original = JSON.stringify(state.catalog);
    render();
  }
  const dirty = () => !!state && JSON.stringify(state.catalog) !== state.original;
  function close() {
    if (dirty() && !confirm('素材設定還沒存，要放棄修改嗎？')) return;
    state = null;
    document.getElementById('catalogPanel')?.remove();
  }
  /** A picture's res:// path for previews: a work's relative paths are under its folder. */
  function resolved(path) {
    if (!path || path.includes('://')) return path;
    return state.path.replace(/[^/]*$/, '') + path;
  }
  function changed() { state.message = ''; render(); }

  // Replacing the page blurs a focused field, whose change handler asks for another render in the
  // middle of this one: that render runs right after, with the change applied.
  let rendering = false, again = false;
  function render() {
    if (!state) return;
    if (rendering) { again = true; return; }
    rendering = true;
    try { build(); } finally { rendering = false; }
    if (again) { again = false; render(); }
  }
  function build() {
    const { el } = state.deps;
    const old = document.getElementById('catalogPanel');
    const scroll = old?.querySelector('.catalog-list')?.scrollTop || 0;
    // Every change re-renders the page; the entries being edited stay open (read from the page
    // itself: a details' toggle event comes too late for a change made right after opening it).
    for (const details of old?.querySelectorAll('details.catalog-entry') || []) {
      if (details.open) state.opened.add(details.dataset.key); else state.opened.delete(details.dataset.key);
    }
    const catalog = state.catalog;
    const kind = KINDS.find(k => k.key === state.kind);
    const entries = isObj(catalog[kind.key]) ? catalog[kind.key] : {};
    const inherited = Object.keys(state.inherited?.[kind.key] || {}).filter(id => !(id in entries));
    const characterIds = [...new Set([...Object.keys(state.inherited?.characters || {}), ...Object.keys(catalog.characters || {})])];
    const backgroundIds = [...new Set([...Object.keys(state.inherited?.backgrounds || {}), ...Object.keys(catalog.backgrounds || {})])];
    const panel = el('div', { id: 'catalogPanel', class: 'catalog-backdrop' },
      el('div', { class: 'catalog-panel' },
        el('div', { class: 'catalog-head' },
          el('strong', {}, `素材設定：${state.path}`),
          el('span', { class: 'catalog-status' }, state.saving ? '驗證中…' : dirty() ? '有未存的修改' : '已存'),
          el('button', { id: 'catalogSave', class: 'primary', disabled: !dirty() || state.saving, onclick: save }, '驗證並存檔'),
          el('button', { id: 'catalogClose', onclick: close }, '關閉')),
        state.message && el('p', { class: 'note info' }, state.message),
        state.errors.length > 0 && el('div', { class: 'note error', id: 'catalogErrors' }, el('strong', {}, '沒有存：'),
          el('ul', {}, state.errors.map(e => el('li', {}, e)))),
        el('div', { class: 'catalog-root' },
          field('預設視角', choose(characterIds, catalog.default_pov, v => setRoot('default_pov', v), '（第一個角色）')),
          field('預設背景', choose(backgroundIds, catalog.default_background, v => setRoot('default_background', v), '（沒有）')),
          catalog.extends && el('span', { class: 'catalog-note' }, `繼承自 ${catalog.extends}：那邊的項目在這裡唯讀，要改請開那份素材設定。`)),
        el('div', { class: 'catalog-tabs' }, KINDS.map(k => el('button', {
          class: k.key === state.kind ? 'active' : '', data: { kind: k.key },
          onclick: () => { state.kind = k.key; render(); } }, `${k.label}（${Object.keys(catalog[k.key] || {}).length}）`)),
          el('button', { id: 'catalogAdd', onclick: () => add(kind) }, `＋新增${kind.label}`)),
        el('div', { class: 'catalog-list' },
          Object.keys(entries).length === 0 && el('p', { class: 'catalog-note' }, `這份設定還沒有自己的${kind.label}。`),
          Object.keys(entries).map(id => entryForm(kind, id, entries[id])),
          inherited.length > 0 && el('p', { class: 'catalog-note' }, `繼承的${kind.label}（唯讀）：${inherited.join('、')}`))));
    if (old) old.replaceWith(panel); else document.body.append(panel);
    panel.querySelector('.catalog-list').scrollTop = scroll;
  }

  function field(label, control, extra) {
    const { el } = state.deps;
    return el('label', { class: 'catalog-field' }, el('span', {}, label), control, extra);
  }
  function choose(options, current, onChange, empty) {
    const { el } = state.deps;
    const list = [...options];
    if (current && !list.includes(current)) list.push(current);
    const control = el('select', {}, empty !== undefined && el('option', { value: '' }, empty), list.map(o => el('option', { value: o }, o)));
    control.value = current || '';
    control.addEventListener('change', () => onChange(control.value));
    return control;
  }
  function text(entry, key, multiline = false) {
    const { el } = state.deps;
    const control = el(multiline ? 'textarea' : 'input', { type: multiline ? undefined : 'text', value: entry[key] ?? '', rows: multiline ? 2 : undefined });
    control.addEventListener('change', () => { if (control.value === '' && key !== 'name' && key !== 'label') delete entry[key]; else entry[key] = control.value; changed(); });
    return control;
  }
  function setRoot(key, value) { if (value) state.catalog[key] = value; else delete state.catalog[key]; changed(); }
  function fileChoice(entry, key, media, empty) {
    const files = state.files.filter(f => (media === 'audio' ? AUDIO : IMAGE).test(f));
    return choose(files, entry[key], v => { if (v) entry[key] = v; else delete entry[key]; changed(); }, empty);
  }
  function preview(path) {
    const { el, projectUrl } = state.deps;
    return path && IMAGE.test(path) ? el('img', { class: 'catalog-preview', src: projectUrl(resolved(path)), alt: path }) : null;
  }

  function entryForm(kind, id, entry) {
    const { el } = state.deps;
    const hasFile = !!entry.path;
    const authors = isObj(entry.license) ? [].concat(entry.license.author || []).filter(Boolean) : [];
    const flags = [kind.key !== 'sounds' && kind.key !== 'music' && kind.key !== 'items' && !hasFile && '還沒有圖',
      hasFile && !authors.length && '缺授權'].filter(Boolean);
    const body = [field(kind.name === 'name' ? '名稱' : '顯示名稱', text(entry, kind.name))];
    if (kind.key === 'characters') {
      body.push(field('名牌顏色', color(entry, 'color')),
        field('預設站位', choose(['left', 'center', 'right'], entry.slot, v => { if (v) entry.slot = v; else delete entry.slot; changed(); })),
        field('打字音高 Hz', number(entry, 'voice_pitch')),
        field('人物檔案', text(entry, 'profile', true)),
        field('立繪（平常表情）', fileChoice(entry, 'path', 'image', '（沒有圖：剪影）'), preview(entry.path)),
        expressions(entry));
    } else if (kind.key === 'backgrounds') {
      body.push(field('漸層上', color(entry, 'top')), field('漸層下', color(entry, 'bottom')),
        field('背景圖', fileChoice(entry, 'path', 'image', '（沒有圖：漸層）'), preview(entry.path)));
    } else if (kind.key === 'items') {
      body.push(field('說明', text(entry, 'description', true)), field('線索圖', fileChoice(entry, 'path', 'image', '（沒有圖：色塊）'), preview(entry.path)));
    } else {
      body.push(field('檔案', fileChoice(entry, 'path', 'audio', kind.key === 'sounds' ? '（沒有：用內建合成音）' : '（沒有檔案）')));
    }
    body.push(license(entry));
    return el('details', { class: 'catalog-entry', data: { id, key: `${kind.key}/${id}` }, open: state.opened.has(`${kind.key}/${id}`) },
      el('summary', {}, el('code', {}, id), ` · ${entry[kind.name] || ''}`, flags.map(f => el('span', { class: 'catalog-flag' }, f))),
      body,
      el('button', { class: 'danger', onclick: () => remove(kind, id) }, `刪除 ${id}`));
  }
  function color(entry, key) {
    const { el } = state.deps;
    const control = el('input', { type: 'color', value: hex(entry[key]) });
    control.addEventListener('change', () => { entry[key] = control.value; changed(); });
    return control;
  }
  function number(entry, key) {
    const { el } = state.deps;
    const control = el('input', { type: 'number', min: 1, value: entry[key] ?? '' });
    control.addEventListener('change', () => { if (control.value === '') delete entry[key]; else entry[key] = Number(control.value); changed(); });
    return control;
  }
  function expressions(entry) {
    const { el, enums } = state.deps;
    const faces = isObj(entry.expressions) ? entry.expressions : {};
    const all = (enums.VALID_EXPRESSIONS || []).filter(e => e !== 'neutral');
    const rows = Object.keys(faces).map(face => el('div', { class: 'catalog-face' },
      el('code', {}, face),
      fileChoice(faces, face, 'image', '（沒有圖）'),
      preview(faces[face]),
      el('button', { onclick: () => { delete faces[face]; if (!Object.keys(faces).length) delete entry.expressions; changed(); } }, '移除')));
    const free = all.filter(e => !(e in faces));
    const adder = choose(free, '', v => {
      if (!v) return;
      const picture = state.files.find(f => IMAGE.test(f));
      if (!picture) { alert('先把表情圖放進作品資料夾（例如 art/），再回來選。'); render(); return; }
      entry.expressions = { ...faces, [v]: picture };  // then pick the right picture in its row
      changed();
    }, '＋加一個表情…');
    return el('div', { class: 'catalog-field' }, el('span', {}, '表情'), el('div', {}, rows, adder));
  }
  function license(entry) {
    const { el } = state.deps;
    const lic = isObj(entry.license) ? entry.license : {};
    const update = (key, value) => {
      const next = { ...lic, [key]: value };
      if (value === '' || value === false || (Array.isArray(value) && !value.length)) delete next[key];
      if (Object.keys(next).length) entry.license = next; else delete entry.license;
      changed();
    };
    const author = el('input', { type: 'text', value: [].concat(lic.author || []).join('、'), placeholder: '多人用頓號或逗號分開' });
    author.addEventListener('change', () => {
      const names = author.value.split(/[、,，]/).map(s => s.trim()).filter(Boolean);
      update('author', names.length > 1 ? names : names[0] || '');
    });
    const plain = key => { const c = el('input', { type: 'text', value: lic[key] ?? '' }); c.addEventListener('change', () => update(key, c.value.trim())); return c; };
    const approved = el('input', { type: 'checkbox', checked: lic.approved === true });
    approved.addEventListener('change', () => update('approved', approved.checked));
    return el('fieldset', { class: 'catalog-license' }, el('legend', {}, '授權（作者會自動進製作名單）'),
      field('作者', author), field('來源', plain('source')), field('授權', plain('license')), field('主編已核准', approved));
  }

  function add(kind) {
    const id = (prompt(`新${kind.label}的 id（英文小寫、數字、底線，例如 ${kind.key === 'characters' ? 'eren' : 'wall'}）`) || '').trim();
    if (!id) return;
    if (!ID.test(id)) { alert('id 只能用英文小寫、數字與底線，且不以數字開頭。'); return; }
    if (id in (state.catalog[kind.key] || {}) || id in (state.inherited?.[kind.key] || {})) { alert(`已經有 ${id}。`); return; }
    const name = (prompt('顯示名稱（中文）', id) || id).trim();
    const fresh = kind.key === 'characters' ? { name, color: '#888888', slot: 'center' }
      : kind.key === 'backgrounds' ? { label: name, top: '#2e2a45', bottom: '#b9794f' }
      : kind.key === 'items' ? { name, description: '' } : { label: name };
    state.catalog[kind.key] = { ...(state.catalog[kind.key] || {}), [id]: fresh };
    state.opened.add(`${kind.key}/${id}`);
    changed();
  }
  function remove(kind, id) {
    if (!confirm(`刪除 ${id}？劇本還在用的話，存檔時會被擋下。`)) return;
    delete state.catalog[kind.key][id];
    changed();
  }

  async function save() {
    if (!dirty() || state.saving) return;
    const sent = JSON.stringify(state.catalog);
    state.saving = true; state.errors = []; render();
    try {
      const response = await state.deps.post('../../api/catalog', { path: state.path, base_hash: state.hash, catalog: JSON.parse(sent) });
      const result = await response.json();
      if (!response.ok || result.ok !== true) { state.errors = [result.error || '儲存失敗', ...(result.errors || [])]; return; }
      state.hash = result.hash;
      state.original = sent;
      state.message = result.message;
      await state.deps.onSaved();
    } catch (err) {
      state.errors = [`無法確認存檔結果：${err.message}`];
    } finally {
      if (state) { state.saving = false; render(); }
    }
  }

  globalThis.CatalogEditor = { open, close, get state() { return state; }, dirty };
})();
