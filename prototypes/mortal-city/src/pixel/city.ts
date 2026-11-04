// 東京風的城市元件（依參考圖一、二）：天空、天際線、東京鐵塔、高架電車、櫻花、鳥居、全息看板、霓虹招牌、無人機、天橋警衛。
import { rng } from '../rules/core'
import { type Ctx, PAL, drawSprite, glow, pixelText, px, sprite } from './core'

export function drawSky(g: Ctx, w: number, h: number) {
  const s = g.createLinearGradient(0, 0, 0, h)
  s.addColorStop(0, '#0e0820')
  s.addColorStop(0.7, '#2a1244')
  s.addColorStop(1, '#4a1a5a')
  g.fillStyle = s
  g.fillRect(0, 0, w, h)
}

/** 依種子產生一排大樓（可左右無縫拼接），回傳一張畫布。 */
export function skylineLayer(seed: number, width: number, height: number, o: { base: string; minH: number; maxH: number; lit: string[]; signs?: boolean; litRate?: number }) {
  const cv = document.createElement('canvas')
  cv.width = width
  cv.height = height
  const g = cv.getContext('2d')!
  const r = rng(seed)
  let x = 0
  while (x < width) {
    const w = 6 + Math.floor(r() * 14)
    const bh = o.minH + Math.floor(r() * (o.maxH - o.minH))
    const bw = Math.min(w, width - x)
    px(g, x, height - bh, o.base, bw, bh)
    for (let wy = height - bh + 2; wy < height - 1; wy += 2)
      for (let wx = x + 1; wx < x + bw - 1; wx += 2) if (r() < (o.litRate ?? 0.18)) px(g, wx, wy, o.lit[Math.floor(r() * o.lit.length)])
    if (o.signs && r() < 0.55) {
      const sh = 6 + Math.floor(r() * 8)
      const sy = height - bh + 2 + Math.floor(r() * Math.max(1, bh - sh - 3))
      const col = [PAL.m, PAL.c, PAL.v, '#ff5c9a'][Math.floor(r() * 4)]
      px(g, x + bw - 1, sy, PAL.K, 3, sh + 2)
      for (let k = 0; k < sh; k += 2) px(g, x + bw, sy + 1 + k, col, 1, 1)
      glow(g, x + bw, sy + 1, 1, sh, col, 0.2)
    }
    x += w
  }
  return cv
}

export function drawTokyoTower(g: Ctx, x: number, y: number, h = 40) {
  // 兩側斜桿＋每隔幾格的交叉支撐，越往上越窄
  const half = (i: number) => Math.round(((h - i) / h) * (h / 5))
  for (let i = 0; i < h; i++) {
    const w = half(i)
    px(g, x - w, y + i, PAL.o)
    px(g, x + w, y + i, PAL.o)
    if (i % 7 === 3 && w > 1) {
      // 交叉
      for (let k = 1; k < w * 2; k++) px(g, x - w + k, y + i + (k % 2), k % 2 ? '#c86a28' : PAL.o)
    }
  }
  px(g, x, y - 7, '#ffe0a8', 1, 8) // 天線
  const deck = y + Math.round(h * 0.4)
  px(g, x - half(h * 0.4) - 1, deck, '#ffe0a8', half(h * 0.4) * 2 + 3, 2) // 大展望台
  px(g, x - 1, y + Math.round(h * 0.15), '#ffe0a8', 3, 1) // 頂部展望台
  px(g, x - half(h - 1) - 1, y + h - 1, '#ffe0a8', 3, 1)
  px(g, x + half(h - 1) - 1, y + h - 1, '#ffe0a8', 3, 1)
  glow(g, x - 2, y, 5, h, PAL.o, 0.08)
}

/** 高架軌道（橫樑＋橋墩），off 是捲動位移。 */
export function drawRail(g: Ctx, w: number, y: number, off: number, color = '#2a2238') {
  px(g, 0, y, color, w, 2)
  px(g, 0, y, '#4a3a5c', w, 1)
  for (let x = -(off % 24); x < w; x += 24) px(g, x, y + 2, color, 2, 10)
}

/** 列車：x 是車頭位置（往右開）。 */
export function drawTrain(g: Ctx, x: number, y: number, cars = 4) {
  for (let c = 0; c < cars; c++) {
    const cx = x - c * 22
    px(g, cx, y, '#c8d0e0', 21, 5)
    px(g, cx, y + 4, '#3a3a4a', 21, 1)
    for (let k = 2; k < 19; k += 4) px(g, cx + k, y + 1, PAL.c, 3, 2)
    glow(g, cx, y + 1, 21, 2, PAL.c, 0.1)
  }
  px(g, x + 20, y + 1, '#ffe0a8', 1, 2) // 車頭燈
}

export function drawSakura(g: Ctx, x: number, y: number, seed = 1) {
  const r = rng(seed)
  px(g, x + 4, y + 6, '#3a2430', 2, 6)
  for (let i = 0; i < 26; i++) {
    const dx = Math.floor(r() * 11)
    const dy = Math.floor(r() * 7)
    px(g, x + dx, y + dy, r() < 0.5 ? '#ff9ed0' : '#ffc8e6')
  }
}

export const TORII = sprite([
  'rrrrrrrrrrrr',
  '.RrrrrrrrrR.',
  '..r......r..',
  'rrrrrrrrrrrr',
  '..r......r..',
  '..r......r..',
  '..r......r..',
  '..R......R..',
])

export function drawTorii(g: Ctx, x: number, y: number) {
  drawSprite(g, TORII, x, y)
  glow(g, x, y, 12, 1, PAL.r, 0.15)
}

/** 全息看板：側臉剪影＋櫻花，偶爾閃一下。 */
export function drawHologram(g: Ctx, x: number, y: number, w: number, h: number, t: number) {
  const flick = Math.floor(t / 90) % 31 === 0
  g.save()
  g.globalAlpha = flick ? 0.35 : 0.7
  const grad = g.createLinearGradient(x, y, x, y + h)
  grad.addColorStop(0, '#3a2a8a')
  grad.addColorStop(1, '#6a3cff')
  g.fillStyle = grad
  g.fillRect(x, y, w, h)
  // 側臉剪影
  const fx = x + Math.round(w * 0.35)
  px(g, fx, y + 6, '#7ad8ff', 5, 10)
  px(g, fx - 2, y + 4, '#2a1a5a', 7, 4) // 頭髮
  px(g, fx + 5, y + 10, '#7ad8ff', 1, 2) // 鼻
  px(g, fx - 1, y + 16, '#7ad8ff', 7, h - 16) // 肩
  for (const [dx, dy] of [[2, 3], [4, 2], [3, 5], [w - 4, 4], [w - 3, 7]]) px(g, x + dx, y + dy, PAL.m)
  for (let sy = 0; sy < h; sy += 2) px(g, x, y + sy, 'rgba(0,0,0,0.25)', w, 1)
  g.restore()
}

export function drawNeonSign(g: Ctx, text: string, x: number, y: number, color: string, t: number, vertical = false, size = 7) {
  const img = pixelText(text, size, color, vertical)
  const on = Math.floor(t / 110 + x) % 37 !== 0
  px(g, x - 1, y - 1, '#0a0614', img.width + 2, img.height + 2)
  if (!on) return
  glow(g, x, y, img.width, img.height, color, 0.22)
  g.drawImage(img, x, y)
}

export const DRONE = sprite(['K.KKK.K', 'KKxxxKK', '..KmK..'])

export function drawDrone(g: Ctx, x: number, y: number, t: number, beam = true) {
  drawSprite(g, DRONE, x, y)
  if (Math.floor(t / 300) % 2) px(g, x + 3, y + 2, PAL.r)
  if (!beam) return
  g.save()
  g.globalAlpha = 0.12
  g.fillStyle = '#e6def0'
  g.beginPath()
  g.moveTo(x + 3, y + 3)
  g.lineTo(x - 6, y + 30)
  g.lineTo(x + 12, y + 30)
  g.closePath()
  g.fill()
  g.restore()
}

export const GUARD = sprite(['.KK.', 'KrrK', '.KK.', 'KxxK', 'KxxK', '.KK.', '.KK.', 'K..K'])

export function drawRain(g: Ctx, w: number, h: number, t: number, clip?: [number, number, number, number], n = 60) {
  g.fillStyle = 'rgba(200,180,255,0.35)'
  for (let i = 0; i < n; i++) {
    const x = ((i * 37) % w) - ((t / 30) % w) + w
    const y = ((i * 53) % h) + t / 9
    const xx = Math.round(x % w)
    const yy = Math.round(y % h)
    if (clip && (xx < clip[0] || xx > clip[0] + clip[2] || yy < clip[1] || yy > clip[1] + clip[3])) continue
    g.fillRect(xx, yy, 1, 2)
  }
}
