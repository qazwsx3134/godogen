// 用多張 sprite 圖片組裝場景：每張圖依版面資料放在 384×160 的像素座標上，放大顯示並保持像素銳利。
// 動畫只用 CSS（styles.css 的 mc-* keyframes），減少動態設定下全部停止。
import type { CSSProperties } from 'react'

export const SCENE_W = 384
export const SCENE_H = 160

/**
 * anim：
 * - scroll:秒      圖層向左無限捲動（圖片要左右可無縫接）
 * - bob:秒:幅度%   上下浮動（幅度是自身高度的百分比）
 * - breathe:秒     由下往上微微伸縮（呼吸）
 * - cross:秒       從場景右邊外面橫越到左邊外面
 * - flicker:秒     偶爾閃一下（霓虹、螢幕）
 * - frames:格數:fps 播放橫排的 sprite strip（w 是單格寬）
 */
export interface SpritePlacement {
  id: string
  src: string // public/ 下的路徑
  x: number
  y: number
  w: number // sprite 原始像素尺寸
  h: number
  anim?: string
}

/** 不是圖片的小特效：雨、熱氣、zZ。 */
export interface SceneFx {
  fx: 'rain' | 'steam' | 'zz'
  x: number
  y: number
  w: number
  h: number
}

const pct = (v: number, of: number) => `${(v / of) * 100}%`

function box(x: number, y: number, w: number, h: number): CSSProperties {
  return { left: pct(x, SCENE_W), top: pct(y, SCENE_H), width: pct(w, SCENE_W), height: pct(h, SCENE_H) }
}

const pixel: CSSProperties = { imageRendering: 'pixelated' }

function Layer({ l }: { l: SpritePlacement }) {
  const [kind, a, b] = (l.anim ?? '').split(':')
  const sec = Number(a) || 1
  if (kind === 'frames') {
    const n = Number(a) || 1
    const fps = Number(b) || 10
    return (
      <div
        className="absolute"
        style={{
          ...box(l.x, l.y, l.w, l.h),
          ...pixel,
          backgroundImage: `url(${l.src})`,
          backgroundSize: `${n * 100}% 100%`,
          animation: `mc-frames ${n / fps}s steps(${n}) infinite`,
          // 背景圖是 n 倍寬時，background-position 100% 只移動 n−1 格；終點設 n/(n−1) 才會每步剛好一格
          ['--end' as string]: `${n > 1 ? (n / (n - 1)) * 100 : 0}%`,
        }}
      />
    )
  }
  if (kind === 'scroll') {
    // 兩張並排，整條往左移動一張的寬度後回到原位
    return (
      <div className="absolute flex" style={{ ...box(l.x, l.y, l.w * 2, l.h), animation: `mc-scroll ${sec}s linear infinite` }}>
        <img src={l.src} alt="" draggable={false} className="h-full w-1/2 select-none" style={pixel} />
        <img src={l.src} alt="" draggable={false} className="h-full w-1/2 select-none" style={pixel} />
      </div>
    )
  }
  const style: CSSProperties = { ...box(l.x, l.y, l.w, l.h), ...pixel }
  if (kind === 'bob') Object.assign(style, { animation: `mc-bob ${sec}s ease-in-out infinite`, ['--bob' as string]: `-${Number(b) || 3}%` })
  if (kind === 'breathe') Object.assign(style, { animation: `mc-breathe ${sec}s ease-in-out infinite`, transformOrigin: '50% 100%' })
  if (kind === 'flicker') Object.assign(style, { animation: `mc-flicker ${sec}s steps(1) infinite` })
  if (kind === 'cross')
    Object.assign(style, {
      left: pct(SCENE_W, SCENE_W),
      animation: `mc-cross ${sec}s linear infinite`,
      ['--dist' as string]: `-${((SCENE_W + l.w) / l.w) * 100}%`,
    })
  return <img src={l.src} alt="" draggable={false} className="absolute select-none" style={style} />
}

function Fx({ f }: { f: SceneFx }) {
  const style = box(f.x, f.y, f.w, f.h)
  if (f.fx === 'rain') return <div className="mc-rain pointer-events-none absolute" style={style} />
  if (f.fx === 'steam')
    return (
      <div className="pointer-events-none absolute" style={style}>
        {[0, 1, 2].map((i) => (
          <span key={i} className="mc-steam" style={{ left: `${20 + i * 25}%`, animationDelay: `${i * 0.6}s` }} />
        ))}
      </div>
    )
  return (
    <div className="pointer-events-none absolute" style={style}>
      {[0, 1].map((i) => (
        <span key={i} className="mc-zz tech" style={{ animationDelay: `${i * 1.4}s` }}>
          z
        </span>
      ))}
    </div>
  )
}

export function SpriteScene({ layers, fx = [], label }: { layers: SpritePlacement[]; fx?: SceneFx[]; label: string }) {
  return (
    <div className="relative w-full overflow-hidden bg-bg" style={{ aspectRatio: `${SCENE_W} / ${SCENE_H}` }} role="img" aria-label={label}>
      {layers.map((l) => (
        <Layer key={l.id} l={l} />
      ))}
      {fx.map((f, i) => (
        <Fx key={i} f={f} />
      ))}
    </div>
  )
}
