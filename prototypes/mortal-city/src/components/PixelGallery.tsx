import { X } from './icons'
// 像素元件圖鑑：每個元件單獨放大顯示，方便一個一個檢查與修改（src/pixel/）。
import { useEffect, useRef } from 'react'
import { CATALOG, type CatalogItem } from '../pixel/scenes'
import { Panel } from './ui'

function Item({ it }: { it: CatalogItem }) {
  const ref = useRef<HTMLCanvasElement>(null)
  useEffect(() => {
    const g = ref.current!.getContext('2d')!
    let raf = 0
    let alive = true
    const t0 = performance.now()
    const draw = (now: number) => {
      g.clearRect(0, 0, it.w, it.h)
      g.fillStyle = '#1a1226'
      g.fillRect(0, 0, it.w, it.h)
      it.draw(g, now - t0)
      if (alive) raf = requestAnimationFrame(draw)
    }
    ;(document.fonts?.ready ?? Promise.resolve()).then(() => alive && (raf = requestAnimationFrame(draw)))
    return () => {
      alive = false
      cancelAnimationFrame(raf)
    }
  }, [it])
  const scale = Math.max(2, Math.min(6, Math.floor(340 / it.w)))
  return (
    <div className="border-b border-line/40 py-2">
      <div className="mb-1 flex justify-between text-[14px]">
        <b className="text-fg-list">{it.name}</b>
        <span className="tech text-muted">
          {it.w}×{it.h}
        </span>
      </div>
      <canvas ref={ref} width={it.w} height={it.h} style={{ width: it.w * scale, height: it.h * scale, imageRendering: 'pixelated' }} />
    </div>
  )
}

export function PixelGallery({ onClose }: { onClose: () => void }) {
  return (
    <div className="absolute inset-0 z-30 flex flex-col bg-bg/90 p-2" role="dialog" aria-label="像素元件圖鑑">
      <Panel tone="strong" className="min-h-0 flex-1" innerClass="flex h-full flex-col">
        <div className="flex items-center gap-2 border-b border-line/60 px-3 py-1">
          <b className="flex-1 text-heading">像素元件圖鑑（{CATALOG.length}）</b>
          <button onClick={onClose} className="grid min-h-11 min-w-11 place-items-center text-cyan" aria-label="關閉">
            <X size={20} />
          </button>
        </div>
        <div className="min-h-0 flex-1 overflow-y-auto px-3">
          {CATALOG.map((it) => (
            <Item key={it.name} it={it} />
          ))}
        </div>
      </Panel>
    </div>
  )
}
