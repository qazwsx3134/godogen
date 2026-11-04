// 主角「特務」：黑髮綁馬尾、一縷洋紅挑染、黑外套帶洋紅霓虹滾邊、工裝褲、厚底靴（依 art_src/ref）。
// 跑步由「頭＋身體」像素格加上四肢動作表組成；躺姿是獨立的像素格。
import { type Ctx, PAL, drawSprite, line, px, sprite } from './core'

// 朝右。左邊是馬尾，右邊是臉。
export const HEAD = sprite([
  '....hhhhhh..',
  '..hhhhHhhhh.',
  '.hhhHhhhhhhh',
  'hhhhhhhssshh',
  'mhhhhhssssh.',
  '.hhhhhsesss.',
  'hh.hhhsssSs.',
  'h...hhsssS..',
  '.....hhSs...',
  '......ss....',
])

export const TORSO = sprite([
  '....kjjjjk..',
  '...kjjjjjjk.',
  '..kjJjjmjjjk',
  '..kjJjjmjwjk',
  '..kjjjjmjjjk',
  '..kjjjjmjjk.',
  '...kkkkkkk..',
  '...kpppppk..',
  '...kpPpppk..',
])

type P = [number, number]
// 每格：前腳（膝、腳）、後腳（膝、腳）、前手、後手（相對髖部／肩膀），身體上下
const RUN: { fk: P; ff: P; bk: P; bf: P; fa: P; ba: P; bob: number }[] = [
  { fk: [3, 4], ff: [5, 9], bk: [-2, 4], bf: [-4, 8], fa: [-3, 5], ba: [4, 3], bob: 0 },
  { fk: [3, 3], ff: [2, 8], bk: [-1, 4], bf: [-5, 6], fa: [-2, 5], ba: [3, 4], bob: -1 },
  { fk: [1, 4], ff: [0, 9], bk: [2, 2], bf: [0, 6], fa: [0, 6], ba: [0, 6], bob: -1 },
  { fk: [-2, 4], ff: [-4, 8], bk: [3, 4], bf: [5, 9], fa: [4, 3], ba: [-3, 5], bob: 0 },
  { fk: [-1, 4], ff: [-5, 6], bk: [3, 3], bf: [2, 8], fa: [3, 4], ba: [-2, 5], bob: -1 },
  { fk: [2, 2], ff: [0, 6], bk: [1, 4], bf: [0, 9], fa: [0, 6], ba: [0, 6], bob: -1 },
]
export const RUN_FRAMES = RUN.length

function leg(g: Ctx, hx: number, hy: number, k: P, f: P, light: boolean) {
  const c = light ? PAL.P : PAL.p
  line(g, hx, hy, hx + k[0], hy + k[1], c, 2)
  line(g, hx + k[0], hy + k[1], hx + f[0], hy + f[1] - 1, c, 2)
  px(g, hx + f[0] - 1, hy + f[1] - 1, PAL.b, 4, 2) // 靴子
  px(g, hx + f[0] - 1, hy + f[1] + 1, PAL.K, 4, 1)
}

function arm(g: Ctx, sx: number, sy: number, h: P, front: boolean) {
  line(g, sx, sy, sx + h[0], sy + h[1], front ? PAL.J : PAL.j, 2)
  px(g, sx + h[0], sy + h[1] + 1, front ? PAL.s : PAL.S, 2, 1)
  if (front) px(g, sx + h[0], sy + h[1], PAL.m) // 袖口霓虹
}

/** 跑步中的主角，左上角在 (x, y)，大約 14×28。 */
export function drawRunner(g: Ctx, x: number, y: number, frame: number) {
  const r = RUN[((frame % RUN.length) + RUN.length) % RUN.length]
  const by = y + r.bob
  const hx = x + 6
  const hy = by + 18
  arm(g, x + 5, by + 11, r.ba, false)
  leg(g, hx - 1, hy, r.bk, r.bf, false)
  drawSprite(g, TORSO, x, by + 9)
  leg(g, hx + 1, hy, r.fk, r.ff, true)
  drawSprite(g, HEAD, x, by)
  // 馬尾隨步伐擺動
  px(g, x - 1 - (r.bob ? 1 : 0), by + 4, PAL.h, 2, 3)
  arm(g, x + 7, by + 11, r.fa, true)
  // 邊光：背後洋紅、前緣青色，讓暗色衣服在夜景裡看得見
  px(g, x + 2, by + 11, PAL.m, 1, 5)
  px(g, x + 1, by + 1, PAL.m, 1, 3)
  px(g, x + 11, by + 2, PAL.c, 1, 4)
  px(g, x + 10, by + 11, PAL.c, 1, 4)
  px(g, hx + 1 + r.ff[0] - 1, hy + r.ff[1] + 1, PAL.m, 4, 1)
}

// 躺在沙發上、雙手枕在頭後、一腳屈膝（依參考圖一）。頭在左邊、臉朝上，約 58×19。
export const LYING_HEAD = sprite([
  '...hhhhh...',
  '.hhhhHhhhh.',
  'hhhHhhhhhhh',
  'mhhhhsssshh',
  'hhhhssessh.',
  'hhhhsssSsh.',
  '.hhhhsSss..',
  '..hh.sss...',
])
export const LYING_W = 58
export const LYING_H = 19

/** 躺姿：由手、頭、身體、兩條腿組成；胸口隨呼吸起伏，偶爾冒出 zZ。 */
export function drawLying(g: Ctx, x: number, y: number, t: number) {
  const up = Math.floor(t / 1100) % 2
  // 枕在頭後的手（手肘朝上）
  line(g, x + 14, y + 9, x + 7, y + 1, PAL.K, 3)
  line(g, x + 14, y + 9, x + 7, y + 1, PAL.j, 2)
  line(g, x + 7, y + 1, x + 4, y + 6, PAL.j, 2)
  px(g, x + 7, y + 1, PAL.m)
  // 伸直的那條腿（在後面）
  px(g, x + 34, y + 12, PAL.K, 20, 6)
  px(g, x + 35, y + 13, PAL.p, 18, 4)
  px(g, x + 35, y + 13, PAL.P, 18, 1)
  px(g, x + 42, y + 14, PAL.K, 3, 2) // 口袋
  px(g, x + 52, y + 11, PAL.K, 6, 7)
  px(g, x + 53, y + 12, PAL.b, 4, 5)
  px(g, x + 53, y + 14, PAL.m, 4, 1)
  // 身體（外套）
  px(g, x + 11, y + 8 - up, PAL.K, 25, 10 + up)
  px(g, x + 12, y + 9 - up, PAL.j, 23, 8 + up)
  px(g, x + 12, y + 9 - up, PAL.J, 23, 1)
  px(g, x + 12, y + 16, PAL.m, 23, 1) // 下擺霓虹滾邊
  px(g, x + 20, y + 10 - up, PAL.m, 1, 6 + up) // 拉鍊
  px(g, x + 15, y + 11, PAL.w, 3, 2) // 「特務」臂章
  px(g, x + 24, y + 13, PAL.k, 6, 3) // 腰包
  px(g, x + 32, y + 9, PAL.K, 3, 9) // 腰帶
  px(g, x + 33, y + 11, PAL.W, 1, 2)
  // 屈膝的那條腿（在前面）
  line(g, x + 35, y + 12, x + 44, y + 4, PAL.K, 4)
  line(g, x + 35, y + 12, x + 44, y + 4, PAL.P, 3)
  line(g, x + 44, y + 4, x + 49, y + 12, PAL.K, 4)
  line(g, x + 44, y + 4, x + 49, y + 12, PAL.p, 3)
  px(g, x + 39, y + 8, PAL.m, 2, 1) // 綁帶
  px(g, x + 46, y + 11, PAL.K, 7, 5)
  px(g, x + 47, y + 12, PAL.b, 5, 3)
  px(g, x + 47, y + 13, PAL.B, 5, 1)
  // 頭（臉朝上）與另一隻手
  drawSprite(g, LYING_HEAD, x + 2, y + 4)
  line(g, x + 15, y + 9, x + 10, y + 0, PAL.J, 2)
  line(g, x + 10, y + 0, x + 6, y + 3, PAL.J, 2)
  // zZ
  const k = (t / 70) % 36
  if (k < 26) {
    const zx = x + 10 + Math.floor(k / 5)
    const zy = y - 2 - Math.floor(k / 3)
    px(g, zx, zy, PAL.c, 3, 1)
    px(g, zx + 1, zy + 1, PAL.c)
    px(g, zx, zy + 2, PAL.c, 3, 1)
  }
}
