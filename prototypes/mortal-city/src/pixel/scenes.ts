// 場景＝把元件擺到位置上。邏輯解析度 192×80。
import { hashSeed } from '../rules/core'
import { drawLying, drawRunner, HEAD, LYING_H, LYING_W, RUN_FRAMES, TORSO } from './character'
import {
  drawDrone,
  drawHologram,
  drawNeonSign,
  drawRail,
  drawRain,
  drawSakura,
  drawSky,
  drawTokyoTower,
  drawTorii,
  drawTrain,
  GUARD,
  skylineLayer,
} from './city'
import { type Ctx, PAL, drawSprite, glow, pixelText, px, type Sprite } from './core'
import {
  CAT,
  drawAshtray,
  drawBanner,
  drawBed,
  drawBlanket,
  drawCan,
  drawCat,
  drawConsole,
  drawCushion,
  drawFoxMonitor,
  drawLaptop,
  drawMug,
  drawPhone,
  drawRamen,
  drawSofa,
  drawTable,
  drawVines,
  drawWallGun,
  GUN,
} from './props'

export const SW = 192
export const SH = 80

interface Layers {
  winFar: HTMLCanvasElement
  winNear: HTMLCanvasElement
  far: HTMLCanvasElement
  mid: HTMLCanvasElement
  front: HTMLCanvasElement
  roof: HTMLCanvasElement
}

let cache: Layers | null = null

/** 需要字型（招牌上的字），所以在字型載入後才建立；結果快取。 */
export function buildLayers(): Layers {
  if (cache) return cache
  const winFar = skylineLayer(hashSeed('wf'), 240, 44, { base: '#1c1230', minH: 14, maxH: 36, lit: [PAL.m, PAL.c, PAL.v], litRate: 0.22 })
  const winNear = skylineLayer(hashSeed('wn'), 240, 44, { base: '#120a20', minH: 6, maxH: 22, lit: [PAL.m, PAL.y, PAL.c], signs: true })
  const far = skylineLayer(hashSeed('sf'), 384, 60, { base: '#1c1230', minH: 16, maxH: 44, lit: [PAL.m, PAL.c, PAL.v], litRate: 0.2 })
  const mid = skylineLayer(hashSeed('sm'), 384, 70, { base: '#24183a', minH: 14, maxH: 40, lit: [PAL.m, PAL.c, PAL.y], signs: true })
  // 中景：企業大樓「神坂」與天橋（參考圖二）
  {
    const g = mid.getContext('2d')!
    px(g, 220, 8, '#1a1030', 60, 62)
    px(g, 222, 22, '#2a3a5a', 56, 30)
    for (let yy = 24; yy < 50; yy += 4) px(g, 222, yy, '#3a4a6a', 56, 1)
    px(g, 262, 26, PAL.m, 4, 20) // 培養槽
    glow(g, 262, 26, 4, 20, PAL.m, 0.25)
    const sign = pixelText('神坂', 8, PAL.m)
    px(g, 228, 10, '#0a0614', sign.width + 4, sign.height + 2)
    g.drawImage(sign, 230, 11)
    // 天橋
    px(g, 0, 52, '#1a1424', 384, 3)
    px(g, 0, 52, PAL.m, 384, 1)
    for (let xx = 4; xx < 384; xx += 12) px(g, xx, 47, '#2a2238', 1, 5)
    px(g, 0, 47, '#2a2238', 384, 1)
    for (let xx = 30; xx < 384; xx += 96) px(g, xx, 46, PAL.r)
    drawSprite(g, GUARD, 238, 44)
    drawSprite(g, GUARD, 252, 44)
  }
  // 前中景：櫻花、鳥居、拉麵招牌
  const front = document.createElement('canvas')
  front.width = 384
  front.height = SH
  {
    const g = front.getContext('2d')!
    drawSakura(g, 20, 52, 3)
    drawTorii(g, 60, 56)
    drawSakura(g, 140, 54, 7)
    drawSakura(g, 300, 50, 11)
    const ramen = pixelText('ラーメン', 7, PAL.m, true)
    px(g, 200, 26, '#0a0614', ramen.width + 2, ramen.height + 2)
    glow(g, 201, 27, ramen.width, ramen.height, PAL.m, 0.25)
    g.drawImage(ramen, 201, 27)
    const izakaya = pixelText('居酒屋', 6, '#ff5c9a', true)
    g.drawImage(izakaya, 330, 36)
    for (const lx of [214, 222, 338]) {
      px(g, lx, 58, PAL.r, 3, 4)
      px(g, lx + 1, 59, '#ff8a8a', 1, 2)
    }
  }
  // 近景：屋頂邊緣、冷氣機、水管、積水倒影
  const roof = document.createElement('canvas')
  roof.width = 384
  roof.height = SH
  {
    const g = roof.getContext('2d')!
    px(g, 0, 67, '#16101f', 384, 13)
    px(g, 0, 67, '#3a2e4c', 384, 1)
    for (let xx = 0; xx < 384; xx += 22) px(g, xx + 8, 70, 'rgba(255,61,240,0.35)', 6, 1) // 積水反光
    for (const ax of [40, 170, 290]) {
      px(g, ax, 56, PAL.K, 16, 11)
      px(g, ax + 1, 57, '#2a2238', 14, 9)
      px(g, ax + 4, 59, '#16101f', 8, 5)
      px(g, ax + 10, 58, PAL.m, 2, 1)
    }
    px(g, 120, 60, '#2a2238', 40, 2)
    px(g, 120, 60, '#4a3a5c', 40, 1)
  }
  cache = { winFar, winNear, far, mid, front, roof }
  return cache
}

function scroll(g: Ctx, img: HTMLCanvasElement, off: number, y: number) {
  const o = Math.floor(off) % img.width
  g.drawImage(img, -o, y)
  g.drawImage(img, img.width - o, y)
}

// ---------- 公寓 ----------

const WIN = { x: 52, y: 0, w: 120, h: 44 }

export function drawRoom(g: Ctx, t: number, who: 'sleep' | 'empty') {
  const L = buildLayers()
  px(g, 0, 0, '#120c1c', SW, SH)
  // 左上暖色燈與牆面
  px(g, 6, 2, '#ffd0a0', 24, 2)
  glow(g, 6, 2, 24, 4, '#ffb070', 0.12)
  drawWallGun(g, 4, 12)
  drawBanner(g, 36, 2)
  px(g, 4, 22, '#d8d0c0', 12, 14)
  px(g, 6, 26, '#8a7a6a', 8, 6)

  // 窗外
  g.save()
  g.beginPath()
  g.rect(WIN.x, WIN.y, WIN.w, WIN.h)
  g.clip()
  g.translate(WIN.x, WIN.y)
  drawSky(g, WIN.w, WIN.h)
  scroll(g, L.winFar, t / 900, 0)
  drawTokyoTower(g, 82, 6, 34)
  drawHologram(g, 6, 2, 14, 26, t)
  drawNeonSign(g, '新宿', 23, 5, PAL.m, t, false, 8)
  drawNeonSign(g, '渋谷', 23, 16, PAL.v, t, false, 8)
  drawNeonSign(g, '東京', 97, 1, '#ff5c9a', t, false, 8)
  drawNeonSign(g, '秋葉原', 90, 12, PAL.m, t, false, 8)
  scroll(g, L.winNear, t / 500, 0)
  drawRail(g, WIN.w, 28, 0)
  const tx = ((t / 14) % 420) - 100
  drawTrain(g, tx, 23)
  drawSakura(g, 50, 33, 5)
  drawSakura(g, 62, 35, 9)
  drawTorii(g, 74, 35)
  drawDrone(g, ((t / 40) % 200) - 20, 4, t, false)
  drawRain(g, WIN.w, WIN.h, t, undefined, 40)
  g.restore()
  // 窗框
  px(g, WIN.x - 2, 0, PAL.K, 2, 46)
  px(g, WIN.x + WIN.w, 0, PAL.K, 2, 46)
  px(g, WIN.x + 58, 0, PAL.K, 2, 44)
  px(g, WIN.x - 2, 44, PAL.K, WIN.w + 4, 2)
  drawVines(g, 174, 0, 40, t)

  // 家具
  drawSofa(g, 2, 44, 140)
  drawCushion(g, 10, 48)
  drawBlanket(g, 116, 46)
  drawCat(g, 120, 41, t)
  if (who === 'sleep') drawLying(g, 26, 39, t)
  drawBed(g, 170, 48)
  drawFoxMonitor(g, 172, 28, t)
  px(g, 0, 76, '#07050b', SW, 4)
  drawTable(g, 86, 66, 104)
  drawAshtray(g, 96, 63)
  drawPhone(g, 108, 63, t)
  drawCan(g, 120, 58)
  drawRamen(g, 128, 59, t)
  drawConsole(g, 160, 62)
  px(g, 0, 72, '#1a1424', 30, 4) // 邊桌
  drawLaptop(g, 2, 53, t)
  drawMug(g, 30, 64)
}

// ---------- 任務中：屋頂奔跑 ----------

export function drawStreet(g: Ctx, t: number) {
  const L = buildLayers()
  drawSky(g, SW, SH)
  scroll(g, L.far, t / 200, -2)
  drawTokyoTower(g, 112, 14, 46)
  drawNeonSign(g, '東京', 124, 20, '#ff5c9a', t, false, 8)
  drawDrone(g, SW - ((t / 30) % (SW + 60)), 6, t)
  scroll(g, L.mid, t / 70, -4)
  const tx = ((t / 6) % 700) - 120
  drawRail(g, SW, 62, t / 70)
  drawTrain(g, tx, 57, 5)
  scroll(g, L.front, t / 40, 0)
  scroll(g, L.roof, t / 22, 0)
  drawRunner(g, 46, 39, Math.floor(t / 85))
  drawRain(g, SW, SH, t, undefined, 80)
}

export function drawStatic(g: Ctx, t: number) {
  g.save()
  g.globalAlpha = 0.55
  px(g, 0, 0, '#05030a', SW, SH)
  g.restore()
  for (let i = 0; i < 360; i++) {
    const k = (Math.floor(t / 70) * 7919 + i * 104729) % 15360
    px(g, k % SW, Math.floor(k / SW) % SH, i % 3 ? '#3a2e4c' : PAL.M)
  }
}

// ---------- 元件圖鑑 ----------

export interface CatalogItem {
  name: string
  w: number
  h: number
  draw: (g: Ctx, t: number) => void
}

const sp = (s: Sprite) => ({ w: s.w + 2, h: s.h + 2 })

export const CATALOG: CatalogItem[] = [
  { name: '主角・跑步（6 格）', w: 20, h: 32, draw: (g, t) => drawRunner(g, 3, 2, Math.floor(t / 120) % RUN_FRAMES) },
  { name: '主角・頭', ...sp(HEAD), draw: (g) => drawSprite(g, HEAD, 1, 1) },
  { name: '主角・身體', ...sp(TORSO), draw: (g) => drawSprite(g, TORSO, 1, 1) },
  { name: '主角・躺在沙發', w: LYING_W + 4, h: LYING_H + 8, draw: (g, t) => drawLying(g, 2, 7, t) },
  { name: '沙發', w: 144, h: 24, draw: (g) => drawSofa(g, 2, 1, 140) },
  { name: '坐墊', w: 14, h: 11, draw: (g) => drawCushion(g, 1, 1) },
  { name: '紅毯（青海波）', w: 24, h: 18, draw: (g) => drawBlanket(g, 1, 1) },
  { name: '三花貓', w: CAT.w + 4, h: CAT.h + 2, draw: (g, t) => drawCat(g, 1, 1, t) },
  { name: '矮桌', w: 60, h: 12, draw: (g) => drawTable(g, 1, 1, 56) },
  { name: '泡麵', w: 12, h: 18, draw: (g, t) => drawRamen(g, 1, 10, t) },
  { name: '罐裝飲料', w: 6, h: 10, draw: (g) => drawCan(g, 1, 1) },
  { name: '菸灰缸', w: 11, h: 6, draw: (g) => drawAshtray(g, 1, 2) },
  { name: '手機', w: 12, h: 7, draw: (g, t) => drawPhone(g, 2, 2, t) },
  { name: '遊戲機', w: 16, h: 6, draw: (g) => drawConsole(g, 1, 1) },
  { name: '筆電', w: 30, h: 21, draw: (g, t) => drawLaptop(g, 3, 1, t) },
  { name: '馬克杯', w: 8, h: 8, draw: (g) => drawMug(g, 1, 1) },
  { name: '床', w: 22, h: 28, draw: (g) => drawBed(g, 1, 1) },
  { name: '狐狸螢幕', w: 22, h: 20, draw: (g, t) => drawFoxMonitor(g, 1, 1, t) },
  { name: '牆上的槍', ...sp(GUN), draw: (g) => drawWallGun(g, 1, 1) },
  { name: '侍旗幟', w: 14, h: 30, draw: (g) => drawBanner(g, 2, 1) },
  { name: '藤蔓', w: 8, h: 42, draw: (g, t) => drawVines(g, 3, 1, 40, t) },
  { name: '東京鐵塔', w: 20, h: 50, draw: (g) => drawTokyoTower(g, 10, 8, 40) },
  { name: '高架電車', w: 92, h: 16, draw: (g) => (drawRail(g, 92, 8, 0), drawTrain(g, 88, 3, 4)) },
  { name: '櫻花', w: 14, h: 14, draw: (g) => drawSakura(g, 1, 1, 5) },
  { name: '鳥居', w: 14, h: 10, draw: (g) => drawTorii(g, 1, 1) },
  { name: '全息看板', w: 18, h: 30, draw: (g, t) => drawHologram(g, 2, 2, 14, 26, t) },
  { name: '霓虹招牌', w: 40, h: 12, draw: (g, t) => (drawNeonSign(g, '新宿', 3, 2, PAL.m, t), drawNeonSign(g, '渋谷', 22, 2, PAL.v, t)) },
  { name: '直式招牌', w: 12, h: 40, draw: (g, t) => drawNeonSign(g, 'ラーメン', 3, 2, PAL.m, t, true) },
  { name: '無人機（探照燈）', w: 24, h: 34, draw: (g, t) => drawDrone(g, 8, 2, t) },
  { name: 'MPD 警衛', ...sp(GUARD), draw: (g) => drawSprite(g, GUARD, 1, 1) },
]
