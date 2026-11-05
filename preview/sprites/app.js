'use strict'
// Sprite 檢視器：列出各原型的圖片，放大檢視、播放 sprite sheet／連號序列、像素對齊（snap.js）。

const $ = (id) => document.getElementById(id)
const state = {
  images: [],
  current: null, // { project, path, w, h }
  orig: null, // ImageData
  snapped: null, // ImageData
  grid: null, // 自動偵測的結果（含切點）；手動改格距後清掉
  token: '',
  baseHash: '', // 開檔時的 SHA-256，存檔時給服務端比對
  tool: 'view',
  undo: [],
  dirty: false,
  hit: [], // 每張畫在畫面上的位置，用來把滑鼠座標換成像素
  show: 'orig',
  seq: [], // 連號序列的 Image 物件
  frame: 0,
  playing: false,
  timer: 0,
}
const view = $('view')
const ctx = view.getContext('2d')
const fileUrl = (it) => `/preview/files/${encodeURIComponent(it.project)}/${it.path.split('/').map(encodeURIComponent).join('/')}`
const esc = (t) => String(t).replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`)
const kb = (b) => (b > 1048576 ? `${(b / 1048576).toFixed(1)} MB` : `${Math.round(b / 1024)} KB`)

// ---------- 清單 ----------

async function loadIndex() {
  const res = await fetch('/preview/sprites/index.json', { cache: 'no-store' })
  const json = await res.json()
  state.images = json.images
  state.token = json.token
  const counts = {}
  for (const it of state.images) counts[it.project] = (counts[it.project] || 0) + 1
  const sel = $('project')
  sel.innerHTML = Object.keys(counts)
    .sort()
    .map((p) => `<option value="${esc(p)}">${esc(p)}（${counts[p]}）</option>`)
    .join('')
  const saved = localStorage.getItem('sv-project')
  if (saved && counts[saved]) sel.value = saved
  renderList()
}

function filtered() {
  const p = $('project').value
  const q = $('search').value.trim().toLowerCase()
  return state.images.filter((it) => it.project === p && (!q || it.path.toLowerCase().includes(q)))
}

function renderList() {
  const items = filtered()
  const shown = items.slice(0, 400)
  $('count').textContent = `${items.length} 張${items.length > shown.length ? `（顯示前 ${shown.length} 張，可用搜尋縮小）` : ''}`
  $('files').innerHTML = shown
    .map((it, i) => {
      const name = it.path.split('/').pop()
      const dims = it.w ? `${it.w}×${it.h}・` : ''
      return `<li data-i="${i}" title="${esc(it.path)}"><img loading="lazy" src="${esc(fileUrl(it))}" alt=""><span>${esc(name)}<small>${dims}${kb(it.bytes)}・${esc(it.path)}</small></span></li>`
    })
    .join('')
  $('files').onclick = (e) => {
    const li = e.target.closest('li')
    if (!li) return
    document.querySelectorAll('#files li.on').forEach((n) => n.classList.remove('on'))
    li.classList.add('on')
    openImage(shown[Number(li.dataset.i)])
  }
}

// ---------- 載入圖片 ----------

function loadImg(src) {
  return new Promise((ok, bad) => {
    const im = new Image()
    im.onload = () => ok(im)
    im.onerror = bad
    im.src = src
  })
}

function toData(im) {
  const c = document.createElement('canvas')
  c.width = im.naturalWidth
  c.height = im.naturalHeight
  const g = c.getContext('2d')
  g.drawImage(im, 0, 0)
  return g.getImageData(0, 0, c.width, c.height)
}

async function openImage(it) {
  // 有未存的修改：第一次點只提醒（不用會卡住頁面的 confirm），再點同一張才切換
  if (state.dirty && state.pending !== it) {
    state.pending = it
    $('save-info').textContent = '目前的修改還沒存。要放棄修改並開這張圖，請再點一次。'
    return
  }
  state.pending = null
  stop()
  state.current = it
  state.snapped = null
  state.grid = null
  state.undo = []
  state.dirty = false
  $('download').disabled = true
  $('save').disabled = true
  $('undo').disabled = true
  $('detect-info').textContent = ''
  $('save-info').textContent = ''
  const bytes = await (await fetch(fileUrl(it), { cache: 'no-store' })).arrayBuffer()
  state.baseHash = [...new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))].map((b) => b.toString(16).padStart(2, '0')).join('')
  const im = await loadImg(URL.createObjectURL(new Blob([bytes])))
  state.orig = toData(im)
  $('name').textContent = `${it.project} / ${it.path}`
  $('meta').textContent = `${im.naturalWidth}×${im.naturalHeight}・${kb(it.bytes)}`
  // 檔名像 xxx_03.png：找同資料夾的連號圖片當序列
  const m = it.path.match(/^(.*?)(\d+)(\.\w+)$/)
  state.seq = []
  if (m) {
    const sibs = state.images
      .filter((o) => o.project === it.project && o.path.startsWith(m[1]) && /^\d+\.\w+$/.test(o.path.slice(m[1].length)))
      .sort((a, b) => a.path.localeCompare(b.path, undefined, { numeric: true }))
    if (sibs.length > 1) state.seq = await Promise.all(sibs.map((o) => loadImg(fileUrl(o))))
  }
  $('seq-info').textContent = state.seq.length > 1 ? `找到 ${state.seq.length} 張連號圖片` : '這張圖沒有連號的同系列圖片'
  // 寬是高的整數倍時，猜它是一排的 sprite sheet
  const ratio = im.naturalWidth / im.naturalHeight
  if (Number.isInteger(Math.round(ratio)) && Math.abs(ratio - Math.round(ratio)) < 0.02 && Math.round(ratio) > 1) {
    $('cols').value = $('frames').value = Math.round(ratio)
    $('rows').value = 1
  }
  state.frame = 0
  $('merge').value = '1'
  $('custom-wrap').hidden = true
  $('offx').value = $('offy').value = 0
  updateMergeInfo()
  draw()
}

// ---------- 繪製 ----------

function source() {
  return state.show === 'snap' && state.snapped ? state.snapped : state.orig
}

function frameRect(img) {
  const mode = $('mode').value
  if (mode !== 'sheet') return { x: 0, y: 0, w: img.width, h: img.height }
  const cols = Math.max(1, +$('cols').value)
  const rows = Math.max(1, +$('rows').value)
  const n = Math.max(1, Math.min(cols * rows, +$('frames').value))
  const f = state.frame % n
  const w = Math.floor(img.width / cols)
  const h = Math.floor(img.height / rows)
  return { x: (f % cols) * w, y: Math.floor(f / cols) * h, w, h, n }
}

function frameCount() {
  const mode = $('mode').value
  if (mode === 'seq') return Math.max(1, state.seq.length)
  if (mode === 'sheet') return frameRect(source()).n
  return 1
}

function zoomFor(w, h) {
  const z = $('zoom').value
  if (z !== 'fit') return +z
  const st = $('stage')
  return Math.max(1, Math.floor(Math.min((st.clientWidth - 32) / w, (st.clientHeight - 32) / h)) || 1)
}

function checker(g, w, h) {
  if (!$('checker').checked) {
    g.fillStyle = '#1d221f'
    g.fillRect(0, 0, w, h)
    return
  }
  for (let y = 0; y < h; y += 8)
    for (let x = 0; x < w; x += 8) {
      g.fillStyle = (x / 8 + y / 8) % 2 ? '#3a403b' : '#2c312d'
      g.fillRect(x, y, 8, 8)
    }
}

/** 把 ImageData（或序列的 Image）的一塊畫成放大的畫面。 */
function paint(g, src, r, dx, z) {
  const c = document.createElement('canvas')
  c.width = r.w
  c.height = r.h
  const cg = c.getContext('2d')
  if (src instanceof HTMLImageElement) cg.drawImage(src, 0, 0)
  else cg.putImageData(new ImageData(src.data, src.width, src.height), -r.x, -r.y)
  g.imageSmoothingEnabled = false
  g.drawImage(c, 0, 0, r.w, r.h, dx, 0, r.w * z, r.h * z)
  return c
}

function draw() {
  if (!state.orig) return
  const mode = $('mode').value
  const both = state.show === 'both' && state.snapped
  const srcs = both ? [state.orig, state.snapped] : [source()]
  // 並排時把對齊後的圖放大到和原圖一樣大，方便比對
  const rects = srcs.map((s) => (mode === 'seq' && state.seq.length ? { x: 0, y: 0, w: state.seq[0].naturalWidth, h: state.seq[0].naturalHeight } : frameRect(s)))
  const baseW = rects[0].w
  const baseH = rects[0].h
  const z = zoomFor(baseW * srcs.length, baseH)
  view.width = baseW * z * srcs.length + (srcs.length - 1) * 12
  view.height = baseH * z
  checker(ctx, view.width, view.height)
  state.hit = []
  srcs.forEach((s, k) => {
    const r = rects[k]
    const scale = (z * baseW) / r.w
    const dx = k * (baseW * z + 12)
    const img = mode === 'seq' && state.seq.length ? state.seq[state.frame % state.seq.length] : s
    if ($('onion').checked && frameCount() > 1) {
      ctx.globalAlpha = 0.35
      const prevFrame = state.frame
      state.frame = (state.frame + frameCount() - 1) % frameCount()
      const pr = mode === 'seq' ? r : frameRect(s)
      paint(ctx, mode === 'seq' ? state.seq[state.frame % state.seq.length] : s, pr, dx, scale)
      state.frame = prevFrame
      ctx.globalAlpha = 1
    }
    paint(ctx, img, mode === 'seq' ? r : frameRect(s), dx, scale)
    state.hit.push({ dx, scale, r: mode === 'seq' ? r : frameRect(s) })
    // 偵測到的格線（畫在原圖上）
    if ($('showcuts').checked && s === state.orig && mode === 'still') {
      const g = currentGrid()
      ctx.strokeStyle = 'rgba(255,61,240,0.55)'
      ctx.lineWidth = 1
      ctx.beginPath()
      for (const x of g.cols) ctx.moveTo(dx + x * scale + 0.5, 0), ctx.lineTo(dx + x * scale + 0.5, s.height * scale)
      for (const y of g.rows) ctx.moveTo(dx, y * scale + 0.5), ctx.lineTo(dx + s.width * scale, y * scale + 0.5)
      ctx.stroke()
    }
    if ($('grid').checked && scale >= 4) {
      ctx.strokeStyle = 'rgba(213,237,171,0.18)'
      ctx.lineWidth = 1
      ctx.beginPath()
      for (let x = 0; x <= r.w; x++) ctx.moveTo(dx + x * scale + 0.5, 0), ctx.lineTo(dx + x * scale + 0.5, r.h * scale)
      for (let y = 0; y <= r.h; y++) ctx.moveTo(dx, y * scale + 0.5), ctx.lineTo(dx + r.w * scale, y * scale + 0.5)
      ctx.stroke()
    }
  })
  view.dataset.z = z
  $('frame').textContent = frameCount() > 1 ? `第 ${(state.frame % frameCount()) + 1} / ${frameCount()} 格` : ''
}

// ---------- 動畫 ----------

function stop() {
  state.playing = false
  clearInterval(state.timer)
  $('play').textContent = '▶ 播放'
}

function play() {
  if (state.playing) return stop()
  state.playing = true
  $('play').textContent = '❚❚ 暫停'
  state.timer = setInterval(() => {
    state.frame = (state.frame + 1) % frameCount()
    draw()
  }, 1000 / Math.max(1, +$('fps').value))
}

// ---------- 像素對齊 ----------

function detect() {
  if (!state.orig) return
  const t = performance.now()
  const g = PixelSnap.detectGrid(state.orig)
  state.grid = g
  $('merge').value = 'auto'
  $('custom-wrap').hidden = true
  $('psize').value = g.size.toFixed(2)
  $('offx').value = g.offsetX
  $('offy').value = g.offsetY
  $('showcuts').checked = true
  if (g.alreadyPixel) {
    $('detect-info').textContent = `這張圖已經是真像素（每個像素就是一格，誤差 ${g.err}），不需要對齊；對齊也會保持 ${state.orig.width}×${state.orig.height}。可以直接用下面的編輯工具修像素。`
    return draw()
  }
  $('detect-info').textContent = `偵測到格距約 ${g.size.toFixed(2)} px（x ${g.sizeX.toFixed(2)}、y ${g.sizeY.toFixed(2)}），花了 ${Math.round(performance.now() - t)} ms。合併太多就把「合併大小」改小，例如 2×2 或照原圖。`
  updateMergeInfo()
  draw()
}

/** 目前「合併大小」對應的格子：自動＝偵測結果；數字／自訂＝等距格子加偏移。 */
function currentGrid() {
  const m = $('merge').value
  if (m === 'auto') {
    if (!state.grid && state.orig) state.grid = PixelSnap.detectGrid(state.orig)
    return state.grid
  }
  const size = m === 'custom' ? Math.max(1, +$('psize').value) : +m
  const offsetX = size > 1 ? +$('offx').value % size : 0
  const offsetY = size > 1 ? +$('offy').value % size : 0
  return { size, offsetX, offsetY, cols: PixelSnap.uniformCuts(state.orig.width, size, offsetX), rows: PixelSnap.uniformCuts(state.orig.height, size, offsetY) }
}

function updateMergeInfo() {
  if (!state.orig) return
  const g = currentGrid()
  const n = $('merge').value === 'auto' ? g.size.toFixed(2) : g.size
  $('merge-info').textContent =
    g.size <= 1
      ? `不合併：對齊後還是 ${state.orig.width}×${state.orig.height}，每個像素保持原樣（只會套用色數限制）。`
      : `每 ${n}×${n} 個像素合成 1 格：共 ${g.cols.length - 1}×${g.rows.length - 1} 格（原圖 ${state.orig.width}×${state.orig.height}）。`
}

function runSnap() {
  if (!state.orig) return
  const grid = currentGrid()
  const snapped = PixelSnap.snap(state.orig, grid)
  const small = PixelSnap.quantize(snapped, +$('colors').value)
  // 預設放大回原圖尺寸：像素對齊，但解析度和原圖一樣
  const out = $('outsize').value === 'full' ? PixelSnap.expand(small, snapped.cols, snapped.rows) : small
  state.snapped = new ImageData(out.data, out.width, out.height)
  state.dirty = true
  $('download').disabled = false
  $('save').disabled = false
  $('save-info').textContent = `對齊後 ${out.width}×${out.height}（原圖 ${state.orig.width}×${state.orig.height}）。切到「對齊後」可以繼續修，按「存回原檔」才會寫入。`
  // sprite sheet 的欄列數不變，對齊後也能直接播放
  setShow('both')
}

/** 要下載／存檔的那張：畫面顯示對齊後就存對齊後，否則存（可能編輯過的）原圖。 */
function outputImage() {
  return state.show === 'snap' && state.snapped ? state.snapped : state.show === 'both' && state.snapped ? state.snapped : state.orig
}

function toCanvas(img) {
  const c = document.createElement('canvas')
  c.width = img.width
  c.height = img.height
  c.getContext('2d').putImageData(img, 0, 0)
  return c
}

function download() {
  const a = document.createElement('a')
  a.href = toCanvas(outputImage()).toDataURL('image/png')
  a.download = state.current.path.split('/').pop().replace(/(\.\w+)$/, '_edited.png')
  a.click()
}

async function save() {
  const it = state.current
  if (!it || !/\.png$/i.test(it.path)) return ($('save-info').textContent = '只能存回 PNG；其他格式請用下載。')
  const img = outputImage()
  const blob = await new Promise((ok) => toCanvas(img).toBlob(ok, 'image/png'))
  const png = await new Promise((ok) => {
    const fr = new FileReader()
    fr.onload = () => ok(String(fr.result).split(',')[1])
    fr.readAsDataURL(blob)
  })
  $('save').disabled = true
  const res = await fetch('/preview/sprites/save', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Preview-Token': state.token },
    body: JSON.stringify({ project: it.project, path: it.path, png, base_hash: state.baseHash }),
  })
  const reply = await res.json().catch(() => ({}))
  if (!res.ok) {
    $('save').disabled = false
    return ($('save-info').textContent = `沒有存：${reply.error || res.status}`)
  }
  state.baseHash = reply.hash
  state.orig = new ImageData(new Uint8ClampedArray(img.data), img.width, img.height)
  state.snapped = null
  state.dirty = false
  state.undo = []
  $('undo').disabled = true
  setShow('orig')
  $('save-info').textContent = `已存回 ${it.path}（${img.width}×${img.height}）。舊檔備份在 ${reply.backup}。`
}

// ---------- 編輯像素 ----------

function editTarget() {
  if (state.show === 'both') return null
  return state.show === 'snap' && state.snapped ? 'snapped' : 'orig'
}

/** 滑鼠在畫布上的座標（畫布像素）：用 clientX 減畫布位置，不依賴 offsetX。 */
function canvasPoint(e) {
  const r = view.getBoundingClientRect()
  return { x: ((e.clientX - r.left) * view.width) / r.width, y: ((e.clientY - r.top) * view.height) / r.height }
}

function pixelAt(e) {
  const c = canvasPoint(e)
  for (const h of state.hit) {
    const x = Math.floor((c.x - h.dx) / h.scale)
    const y = Math.floor(c.y / h.scale)
    if (x >= 0 && y >= 0 && x < h.r.w && y < h.r.h) return { h, x: x + h.r.x, y: y + h.r.y }
  }
  return null
}

function hexToRgb(hex) {
  const n = parseInt(hex.slice(1), 16)
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255]
}

let stroke = false
function paintAt(e) {
  const which = editTarget()
  const p = pixelAt(e)
  if (!which || !p) return
  const img = state[which]
  const i = (p.y * img.width + p.x) * 4
  if (state.tool === 'pick') {
    $('color').value = '#' + [0, 1, 2].map((k) => img.data[i + k].toString(16).padStart(2, '0')).join('')
    $('edit-info').textContent = `取到 rgba(${img.data[i]}, ${img.data[i + 1]}, ${img.data[i + 2]}, ${img.data[i + 3]})`
    return
  }
  const [r, g, b] = hexToRgb($('color').value)
  const rgba = state.tool === 'erase' ? [0, 0, 0, 0] : [r, g, b, 255]
  if (rgba.every((v, k) => img.data[i + k] === v)) return
  for (let k = 0; k < 4; k++) img.data[i + k] = rgba[k]
  state.dirty = true
  $('save').disabled = false
  $('download').disabled = false
  draw()
}

view.addEventListener('pointerdown', (e) => {
  if (state.tool === 'view' || !state.orig) return
  const which = editTarget()
  if (!which) return ($('edit-info').textContent = '並排時不能編輯：先切到「原圖」或「對齊後」。')
  if (state.tool !== 'pick') {
    state.undo.push({ which, data: new Uint8ClampedArray(state[which].data) })
    if (state.undo.length > 40) state.undo.shift()
    $('undo').disabled = false
  }
  stroke = true
  try {
    view.setPointerCapture(e.pointerId) // 拖到畫布外也繼續畫；失敗不影響這次上色
  } catch {}
  paintAt(e)
})
view.addEventListener('pointermove', (e) => stroke && state.tool !== 'pick' && paintAt(e))
view.addEventListener('pointerup', () => (stroke = false))

function undo() {
  const u = state.undo.pop()
  if (!u) return
  state[u.which].data.set(u.data)
  $('undo').disabled = !state.undo.length
  draw()
}

function setShow(v) {
  state.show = v
  document.querySelectorAll('[data-show]').forEach((b) => b.classList.toggle('on', b.dataset.show === v))
  draw()
}

// ---------- 事件 ----------

$('project').onchange = () => (localStorage.setItem('sv-project', $('project').value), renderList())
$('search').oninput = renderList
for (const id of ['zoom', 'grid', 'checker', 'cols', 'rows', 'frames', 'onion', 'showcuts']) $(id).addEventListener('input', draw)
for (const id of ['psize', 'offx', 'offy']) $(id).addEventListener('input', () => (updateMergeInfo(), draw()))
$('merge').onchange = () => {
  $('custom-wrap').hidden = $('merge').value !== 'custom'
  updateMergeInfo()
  draw()
}
$('mode').onchange = () => {
  $('sheet-opts').hidden = $('mode').value !== 'sheet'
  $('seq-info').hidden = $('mode').value !== 'seq'
  state.frame = 0
  draw()
}
$('fps').oninput = () => state.playing && (stop(), play())
$('play').onclick = play
$('prev').onclick = () => (stop(), (state.frame = (state.frame + frameCount() - 1) % frameCount()), draw())
$('next').onclick = () => (stop(), (state.frame = (state.frame + 1) % frameCount()), draw())
$('detect').onclick = detect
$('snap').onclick = runSnap
$('download').onclick = download
$('save').onclick = save
$('undo').onclick = undo
document.querySelectorAll('[data-tool]').forEach(
  (b) =>
    (b.onclick = () => {
      state.tool = b.dataset.tool
      document.querySelectorAll('[data-tool]').forEach((o) => o.classList.toggle('on', o === b))
      view.classList.toggle('editing', state.tool !== 'view')
    }),
)
window.addEventListener('keydown', (e) => {
  if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'z') (e.preventDefault(), undo())
})
window.addEventListener('beforeunload', (e) => state.dirty && e.preventDefault())
document.querySelectorAll('[data-show]').forEach((b) => (b.onclick = () => setShow(b.dataset.show)))
window.addEventListener('resize', draw)
view.addEventListener('mousemove', (e) => {
  const src = source()
  if (!src) return
  const p = pixelAt(e)
  if (!p) return
  const { x, y } = p
  const i = (y * src.width + x) * 4
  const d = src.data
  $('cursor').textContent = `x ${x}, y ${y}・rgba(${d[i]}, ${d[i + 1]}, ${d[i + 2]}, ${d[i + 3]})`
})

loadIndex().catch(() => ($('count').textContent = '讀不到圖片清單，請確認預覽服務仍在執行。'))
