// 像素元件的共用工具。每個元件都是「像素格字串」或一個小繪圖函式，場景只負責擺位置。
// 美術參考：art_src/ref/（使用者提供的非像素參考圖），色調是深紫＋洋紅霓虹＋少量青色。

export type Ctx = CanvasRenderingContext2D

/** 參考圖取出的調色盤；像素格字串用單一字元對應顏色，'.' 是透明。 */
export const PAL: Record<string, string> = {
  K: '#0a0710', // 最深的輪廓
  k: '#17111f',
  j: '#251c31', // 外套
  J: '#3a2e4c', // 外套亮面
  m: '#ff3df0', // 洋紅霓虹
  M: '#a62aa6',
  c: '#3ff0ff', // 青色
  C: '#1b8d9c',
  h: '#0f0b16', // 黑髮
  H: '#2c2540',
  s: '#e9b391', // 皮膚
  S: '#b67f68',
  e: '#b46cff', // 紫色眼睛
  b: '#07050b', // 靴子
  B: '#2a2233',
  p: '#211b2c', // 褲子
  P: '#342a44',
  w: '#e6def0',
  W: '#a89cb8',
  r: '#d42c48',
  R: '#7c1830',
  o: '#ff9a3c',
  y: '#ffd84a',
  g: '#5aa05a',
  G: '#2c5a3c',
  n: '#6c6478', // 沙發
  N: '#4a4258',
  q: '#b07a52', // 貓（三花）
  Q: '#f2eae2',
  x: '#2a2a30',
  v: '#6a3cff', // 紫色招牌
}

export interface Sprite {
  w: number
  h: number
  rows: string[]
}

export function sprite(rows: string[]): Sprite {
  const w = Math.max(...rows.map((r) => r.length))
  return { w, h: rows.length, rows }
}

export function drawSprite(g: Ctx, s: Sprite, x: number, y: number, flip = false, pal = PAL) {
  for (let r = 0; r < s.h; r++) {
    const row = s.rows[r]
    for (let i = 0; i < row.length; i++) {
      const ch = row[i]
      if (ch === '.' || ch === ' ') continue
      const col = pal[ch]
      if (!col) continue
      g.fillStyle = col
      g.fillRect(Math.round(x + (flip ? s.w - 1 - i : i)), Math.round(y + r), 1, 1)
    }
  }
}

export function px(g: Ctx, x: number, y: number, c: string, w = 1, h = 1) {
  g.fillStyle = c
  g.fillRect(Math.round(x), Math.round(y), w, h)
}

export function line(g: Ctx, x0: number, y0: number, x1: number, y1: number, c: string, w = 1) {
  const n = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0), 1)
  for (let i = 0; i <= n; i++) px(g, x0 + ((x1 - x0) * i) / n, y0 + ((y1 - y0) * i) / n, c, w, w)
}

/** 霓虹光暈：在像素周圍加一圈半透明色，讓招牌像在發光。 */
export function glow(g: Ctx, x: number, y: number, w: number, h: number, c: string, a = 0.18) {
  g.save()
  g.globalAlpha = a
  g.fillStyle = c
  g.fillRect(Math.round(x - 1), Math.round(y - 1), w + 2, h + 2)
  g.globalAlpha = a / 2
  g.fillRect(Math.round(x - 2), Math.round(y - 2), w + 4, h + 4)
  g.restore()
}

const textCache = new Map<string, HTMLCanvasElement>()

/**
 * 把小字（招牌上的「新宿」「ラーメン」）畫成像素：先用字型畫在小畫布，再依透明度門檻轉成純色像素。
 * vertical 為真時一字一行（直式招牌）。
 */
export function pixelText(text: string, size: number, color: string, vertical = false): HTMLCanvasElement {
  const key = `${text}|${size}|${color}|${vertical}`
  const hit = textCache.get(key)
  if (hit) return hit
  const chars = [...text]
  const cw = size + 1
  const cv = document.createElement('canvas')
  cv.width = vertical ? cw : cw * chars.length
  cv.height = vertical ? cw * chars.length : cw
  const g = cv.getContext('2d')!
  g.font = `700 ${size}px "Noto Sans TC", sans-serif`
  g.textBaseline = 'top'
  g.fillStyle = '#fff'
  chars.forEach((ch, i) => g.fillText(ch, vertical ? 0 : i * cw, vertical ? i * cw : 0))
  const img = g.getImageData(0, 0, cv.width, cv.height)
  const out = g.createImageData(cv.width, cv.height)
  const [r, gg, b] = [1, 3, 5].map((o) => parseInt(color.slice(o, o + 2), 16))
  for (let i = 0; i < img.data.length; i += 4) {
    if (img.data[i + 3] > 150) {
      out.data[i] = r
      out.data[i + 1] = gg
      out.data[i + 2] = b
      out.data[i + 3] = 255
    }
  }
  g.clearRect(0, 0, cv.width, cv.height)
  g.putImageData(out, 0, 0)
  // 字型還沒載入時先不要快取，等載入後重畫
  if (document.fonts?.check?.(`700 ${size}px "Noto Sans TC"`)) textCache.set(key, cv)
  return cv
}
