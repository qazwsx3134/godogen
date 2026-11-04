// 公寓裡的道具（依參考圖一）：沙發、紅毯、三花貓、矮桌與桌上小物、筆電、馬克杯、床、狐狸螢幕、牆上的槍、侍旗幟、藤蔓。
import { type Ctx, PAL, drawSprite, glow, pixelText, px, sprite } from './core'

export function drawSofa(g: Ctx, x: number, y: number, w = 140) {
  // 椅背
  px(g, x + 6, y, PAL.K, w - 12, 12)
  px(g, x + 7, y + 1, PAL.N, w - 14, 10)
  for (let cx = x + 8; cx < x + w - 14; cx += 30) {
    px(g, cx, y + 1, PAL.n, 28, 9) // 椅背靠墊
    px(g, cx, y + 1, '#7c7488', 28, 1)
  }
  // 坐墊
  px(g, x + 4, y + 11, PAL.K, w - 8, 9)
  px(g, x + 5, y + 12, PAL.n, w - 10, 7)
  px(g, x + 5, y + 12, '#7c7488', w - 10, 1)
  // 扶手
  for (const ax of [x, x + w - 10]) {
    px(g, ax, y + 4, PAL.K, 10, 16)
    px(g, ax + 1, y + 5, PAL.N, 8, 14)
    px(g, ax + 1, y + 5, PAL.n, 8, 2)
  }
  // 腳
  px(g, x + 8, y + 20, PAL.K, 3, 2)
  px(g, x + w - 11, y + 20, PAL.K, 3, 2)
}

export function drawCushion(g: Ctx, x: number, y: number) {
  px(g, x, y, PAL.K, 12, 9)
  px(g, x + 1, y + 1, '#4a4054', 10, 7)
  px(g, x + 2, y + 2, '#5c5068', 6, 2)
}

/** 紅色毛毯，青海波紋。 */
export function drawBlanket(g: Ctx, x: number, y: number) {
  px(g, x, y, PAL.R, 22, 16)
  for (let ry = 0; ry < 14; ry += 4)
    for (let rx = (ry / 4) % 2 ? 2 : 0; rx < 22; rx += 4) {
      px(g, x + rx, y + ry + 2, PAL.r, 3, 1)
      px(g, x + rx + 1, y + ry + 1, PAL.r)
    }
  px(g, x, y + 15, PAL.K, 22, 1)
}

export const CAT = sprite([
  '...KK.KK......',
  '...KqKqK......',
  '..KqQQqqKKKK..',
  '.KqQQQQqqQQQK.',
  'KqQQQQQQQQqqqK',
  'KKKKKKKKKKKKKK',
])

export function drawCat(g: Ctx, x: number, y: number, t: number) {
  drawSprite(g, CAT, x, y)
  // 尾巴偶爾甩一下
  const flick = Math.floor(t / 900) % 4 === 0
  px(g, x + 13, y + (flick ? 1 : 3), PAL.q, 2, 1)
  px(g, x + 3, y + 3, PAL.K) // 閉眼
}

export function drawTable(g: Ctx, x: number, y: number, w = 100) {
  px(g, x, y, '#1a1424', w, 4)
  px(g, x, y, PAL.m, w, 1)
  glow(g, x, y, w, 1, PAL.m, 0.12)
  px(g, x + 4, y + 4, PAL.K, 3, 6)
  px(g, x + w - 7, y + 4, PAL.K, 3, 6)
}

export function drawRamen(g: Ctx, x: number, y: number, t: number) {
  // 筷子
  px(g, x + 5, y - 4, '#c8a070', 1, 5)
  px(g, x + 7, y - 5, '#c8a070', 1, 6)
  // 杯子
  px(g, x, y, PAL.w, 9, 7)
  px(g, x, y + 2, PAL.r, 9, 2)
  px(g, x + 1, y, '#f4c070', 7, 1) // 麵
  px(g, x + 8, y, PAL.W, 1, 7)
  // 熱氣
  for (let i = 0; i < 3; i++) {
    const k = (t / 120 + i * 7) % 20
    px(g, x + 2 + i * 2 + Math.round(Math.sin((t / 300 + i) * 2)), y - 2 - k / 2, 'rgba(230,222,240,0.35)')
  }
}

export function drawCan(g: Ctx, x: number, y: number) {
  px(g, x, y, PAL.K, 4, 8)
  px(g, x, y + 2, PAL.m, 4, 3)
  px(g, x + 1, y + 3, PAL.K, 2, 1)
  px(g, x, y, PAL.W, 4, 1)
}

export function drawAshtray(g: Ctx, x: number, y: number) {
  px(g, x, y, '#3a3444', 9, 3)
  px(g, x + 1, y, '#1a1424', 7, 1)
  px(g, x + 3, y - 1, PAL.w, 3, 1)
  px(g, x + 6, y - 1, PAL.o)
}

export function drawPhone(g: Ctx, x: number, y: number, t: number) {
  px(g, x, y, PAL.K, 8, 3)
  px(g, x + 1, y, Math.floor(t / 1500) % 3 ? PAL.c : PAL.m, 6, 2)
  glow(g, x + 1, y, 6, 2, PAL.c, 0.12)
}

export function drawConsole(g: Ctx, x: number, y: number) {
  px(g, x, y, '#3a3444', 14, 4)
  px(g, x + 1, y + 1, PAL.k, 5, 2)
  px(g, x + 10, y + 1, PAL.m, 2, 1)
}

export function drawLaptop(g: Ctx, x: number, y: number, t: number) {
  // 螢幕：人體結構圖
  px(g, x, y, PAL.K, 24, 15)
  px(g, x + 1, y + 1, '#071a24', 22, 13)
  px(g, x + 1, y + 1, PAL.C, 22, 1)
  const bx = x + 6
  px(g, bx + 1, y + 3, PAL.c, 2, 2) // 頭
  px(g, bx + 1, y + 5, PAL.c, 2, 4)
  px(g, bx - 1, y + 5, PAL.C, 1, 4)
  px(g, bx + 3, y + 5, PAL.C, 1, 4)
  px(g, bx, y + 9, PAL.C, 1, 4)
  px(g, bx + 2, y + 9, PAL.C, 1, 4)
  for (let i = 0; i < 4; i++) px(g, x + 12, y + 3 + i * 2, i === Math.floor(t / 400) % 4 ? PAL.m : PAL.C, 9 - i * 2, 1)
  glow(g, x + 1, y + 1, 22, 13, PAL.c, 0.08)
  // 鍵盤底座
  px(g, x - 2, y + 15, '#2a2434', 28, 4)
  px(g, x, y + 16, PAL.k, 24, 1)
  px(g, x + 10, y + 18, PAL.m, 6, 1)
}

export function drawMug(g: Ctx, x: number, y: number) {
  px(g, x, y, '#8a8090', 5, 6)
  px(g, x + 5, y + 1, '#8a8090', 1, 3)
  px(g, x, y, '#2a1810', 5, 1)
}

export function drawBed(g: Ctx, x: number, y: number) {
  px(g, x, y, PAL.K, 20, 26)
  px(g, x + 1, y + 1, '#2a2434', 19, 24)
  px(g, x + 1, y + 2, PAL.w, 19, 8)
  px(g, x + 1, y + 10, PAL.W, 19, 3)
  px(g, x + 4, y + 13, '#d8d0e8', 16, 4)
}

const FOX = sprite([
  'c.......c',
  'cc.....cc',
  'c.ccccc.c',
  'c.c.c.c.c',
  '.c.....c.',
  '..cc.cc..',
  '...ccc...',
])

export function drawFoxMonitor(g: Ctx, x: number, y: number, t: number) {
  px(g, x, y, PAL.K, 20, 14)
  px(g, x + 1, y + 1, '#06141c', 18, 12)
  drawSprite(g, FOX, x + 6, y + 3)
  px(g, x + 1, y + 2 + (Math.floor(t / 150) % 10), 'rgba(63,240,255,0.18)', 18, 1)
  glow(g, x + 1, y + 1, 18, 12, PAL.c, 0.1)
  px(g, x + 9, y + 14, PAL.K, 2, 4)
}

export const GUN = sprite([
  '..KKKKKKKKKKKKKK..',
  'KKkkkkkkkkmmmmkKKK',
  '.KkkkkJJkkkkkkkK..',
  '..KKkKKKKKkK......',
  '...KkK...KkK......',
  '...KKK....KK......',
])

export function drawWallGun(g: Ctx, x: number, y: number) {
  drawSprite(g, GUN, x, y)
  glow(g, x + 10, y + 1, 4, 1, PAL.m, 0.25)
}

export function drawBanner(g: Ctx, x: number, y: number) {
  px(g, x - 1, y, PAL.K, 12, 1)
  px(g, x, y + 1, PAL.R, 10, 26)
  px(g, x, y + 1, PAL.r, 1, 26)
  g.drawImage(pixelText('侍', 8, '#f2eae2'), x + 1, y + 4)
  // 櫻花枝
  for (const [dx, dy] of [[2, 18], [4, 20], [6, 19], [3, 22], [7, 21]]) px(g, x + dx, y + dy, '#ffb0d8')
}

export function drawVines(g: Ctx, x: number, y: number, h: number, t: number) {
  for (let i = 0; i < h; i += 3) {
    const sway = Math.round(Math.sin(t / 900 + i / 4))
    px(g, x + sway + (i % 6 ? 1 : 0), y + i, PAL.G, 1, 3)
    if (i % 6 === 0) px(g, x + sway - 1, y + i + 1, PAL.g, 3, 2)
  }
}
