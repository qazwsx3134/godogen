// 城市分頁的橫向像素欄：休息時躺在公寓沙發上，出任務時在東京風的屋頂上奔跑（參考 taskbar-hero 的行軍橫幅）。
// 畫面由 src/pixel/ 的元件拼成；邏輯解析度 192×80，CSS 放大並保持像素銳利。
import { useEffect, useRef } from 'react'
import { SH, SW, drawRoom, drawStatic, drawStreet } from '../pixel/scenes'

export type StripMode = 'rest' | 'run' | 'dead'

export function CityStrip({ mode, label, sub }: { mode: StripMode; label: string; sub?: string }) {
  const ref = useRef<HTMLCanvasElement>(null)
  const modeRef = useRef(mode)
  modeRef.current = mode

  useEffect(() => {
    const g = ref.current!.getContext('2d')!
    g.imageSmoothingEnabled = false
    const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches
    let raf = 0
    let alive = true
    const t0 = performance.now()
    const draw = (now: number) => {
      const t = reduce ? 0 : now - t0
      const m = modeRef.current
      g.clearRect(0, 0, SW, SH)
      if (m === 'run') drawStreet(g, t)
      else drawRoom(g, t, m === 'rest' ? 'sleep' : 'empty')
      if (m === 'dead') drawStatic(g, t)
      if (!reduce && alive) raf = requestAnimationFrame(draw)
    }
    // 招牌上的字需要字型，等字型載入後再開始畫
    ;(document.fonts?.ready ?? Promise.resolve()).then(() => alive && (raf = requestAnimationFrame(draw)))
    return () => {
      alive = false
      cancelAnimationFrame(raf)
    }
  }, [mode]) // 減少動態模式只畫一格，所以切換狀態時要重畫

  return (
    <div className="cut cut-strong">
      <div className="cut-in relative overflow-hidden">
        <canvas
          ref={ref}
          width={SW}
          height={SH}
          className="block h-auto w-full"
          style={{ imageRendering: 'pixelated', aspectRatio: `${SW} / ${SH}` }}
          role="img"
          aria-label={label}
        />
        <div className="pointer-events-none absolute inset-x-0 top-0 flex items-start justify-between gap-2 bg-gradient-to-b from-bg/85 to-transparent px-2 pt-1 pb-3">
          <span className={`text-[13px] font-bold ${mode === 'dead' ? 'text-red' : mode === 'run' ? 'text-cyan' : 'text-heading'}`}>{label}</span>
          {sub && <span className="tech text-[13px] text-heading">{sub}</span>}
        </div>
      </div>
    </div>
  )
}
