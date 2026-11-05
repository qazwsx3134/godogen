// 像素對齊演算法測試：把隨機小圖放大成「假像素圖」（含偏移與雜訊），看能不能還原。
// 執行：node preview/sprites/snap_test.mjs
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'
const require = createRequire(import.meta.url)
const S = require('./snap.js')

function rnd(seed) {
  return () => ((seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648)
}

function fakePixelArt(srcW, srcH, scale, offset, noise, seed = 7) {
  const r = rnd(seed)
  const pal = [[20, 10, 30], [255, 61, 240], [63, 240, 255], [230, 180, 140], [90, 60, 110]]
  const src = Array.from({ length: srcW * srcH }, () => pal[Math.floor(r() * pal.length)])
  const w = Math.round(srcW * scale + offset + 3)
  const h = Math.round(srcH * scale + offset + 3)
  const data = new Uint8ClampedArray(w * h * 4)
  for (let y = 0; y < h; y++)
    for (let x = 0; x < w; x++) {
      const sx = Math.floor((x - offset) / scale)
      const sy = Math.floor((y - offset) / scale)
      const c = sx >= 0 && sy >= 0 && sx < srcW && sy < srcH ? src[sy * srcW + sx] : [0, 0, 0]
      const i = (y * w + x) * 4
      for (let k = 0; k < 3; k++) data[i + k] = c[k] + (r() - 0.5) * noise
      data[i + 3] = 255
    }
  return { img: { width: w, height: h, data }, src }
}

let pass = 0
for (const [scale, offset] of [[5, 2], [4, 0], [6.5, 3], [8, 5]]) {
  const { img, src } = fakePixelArt(24, 16, scale, offset, 24)
  const g = S.detectGrid(img)
  assert.ok(Math.abs(g.size - scale) < 0.15, `scale ${scale}: detected ${g.size}`)
  const out = S.snap(img, g)
  // 大部分格子應還原成原色：用切點找每格中心，換算回原圖的格子
  let ok = 0
  let total = 0
  for (let y = 0; y < out.height; y++)
    for (let x = 0; x < out.width; x++) {
      const cxp = (out.cols[x] + out.cols[x + 1]) / 2
      const cyp = (out.rows[y] + out.rows[y + 1]) / 2
      const sx = Math.floor((cxp - offset) / scale)
      const sy = Math.floor((cyp - offset) / scale)
      if (sx < 0 || sy < 0 || sx >= 24 || sy >= 16) continue
      const c = src[sy * 24 + sx]
      const i = (y * out.width + x) * 4
      total++
      if (Math.abs(out.data[i] - c[0]) + Math.abs(out.data[i + 1] - c[1]) + Math.abs(out.data[i + 2] - c[2]) < 40) ok++
    }
  assert.ok(total >= 24 * 16 * 0.9, `scale ${scale}: only ${total} cells mapped`)
  // walk 容許格線漂移，非整數格距會有少量格子錯開；要求 90% 以上對上
  assert.ok(ok / total > 0.9, `scale ${scale}: only ${ok}/${total} cells match`)
  pass++
  console.log(`ok scale=${scale} offset=${offset} → detected ${g.size.toFixed(2)} (${g.offsetX},${g.offsetY}) ${out.width}×${out.height}, ${ok}/${total} cells`)
}
const q = S.quantize(S.snap(fakePixelArt(24, 16, 5, 2, 24).img, { size: 5, offsetX: 2, offsetY: 2 }), 3)
assert.ok(new Set(Array.from({ length: q.data.length / 4 }, (_, i) => q.data.slice(i * 4, i * 4 + 3).join())).size <= 3)
console.log(`ok quantize → ≤3 colors`)
// 已經是真像素的圖（每個像素一格）：格距要判成 1，不能被壓小
{
  const { img } = fakePixelArt(40, 30, 1, 0, 0, 3)
  const g = S.detectGrid(img)
  assert.equal(g.size, 1)
  assert.ok(g.alreadyPixel)
  console.log('ok real pixel art → size 1')
}
// 放大回原圖尺寸：寬高不變，每格填滿同色
{
  const { img } = fakePixelArt(24, 16, 5, 2, 24)
  const g = S.detectGrid(img)
  const small = S.snap(img, g)
  const big = S.expand(small, small.cols, small.rows)
  assert.equal(big.width, img.width)
  assert.equal(big.height, img.height)
  const c0 = (y, x) => big.data.slice((y * big.width + x) * 4, (y * big.width + x) * 4 + 4).join()
  assert.equal(c0(small.rows[2] + 1, small.cols[3] + 1), c0(small.rows[3] - 1, small.cols[4] - 1))
  console.log('ok expand keeps original size')
}
// 1×1（照原圖）：輸出和原圖逐像素相同，顏色不被量化
{
  const { img } = fakePixelArt(24, 16, 5, 2, 24)
  const one = S.snap(img, { size: 1, offsetX: 0, offsetY: 0 })
  assert.equal(one.width, img.width)
  assert.deepEqual(Array.from(one.data), Array.from(img.data))
  // 2×2：寬高減半
  const two = S.snap(img, { size: 2, offsetX: 0, offsetY: 0 })
  assert.ok(two.width >= Math.floor(img.width / 2) && two.width <= Math.ceil(img.width / 2), `2×2 width ${two.width}`)
  console.log(`ok 1×1 keeps every pixel; 2×2 → ${two.width}×${two.height}`)
}
console.log(`${pass + 4} passed`)
