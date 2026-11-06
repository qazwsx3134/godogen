// 城市新聞跑馬燈、故障轉場、打字機文字。
import { useEffect, useState } from 'react'
import type { News, NewsTag } from '../content/news'

const TAG_COLOR: Record<NewsTag, string> = {
  MPD: 'text-red',
  神坂: 'text-[#c58cff]',
  'FM104.9': 'text-cyan',
  AD: 'text-warning',
  港務部: 'text-positive',
  傳說: 'text-heading',
}

/** 狀態列下方的新聞跑馬燈；速度依字數固定（約每秒 60px）。 */
export function NewsTicker({ items }: { items: News[] }) {
  const line = items.map((n) => `${n.tag}|${n.text}`).join('◆')
  const seconds = Math.max(30, line.length * 0.32)
  const row = (k: string) => (
    <span key={k} className="flex shrink-0 items-center gap-6 pr-6">
      {items.map((n, i) => (
        <span key={i} className="whitespace-nowrap">
          <b className={`tech mr-1.5 ${TAG_COLOR[n.tag]}`}>[{n.tag}]</b>
          {n.text}
        </span>
      ))}
    </span>
  )
  return (
    <div className="news-ticker" aria-label="城市新聞">
      <span className="news-live tech">LIVE</span>
      <div className="min-w-0 flex-1 overflow-hidden">
        <div className="news-track" style={{ animationDuration: `${seconds}s` }}>
          {row('a')}
          {row('b')}
        </div>
      </div>
    </div>
  )
}

/** 換頁、進節點時閃一下的畫面撕裂（約 0.22 秒）；key 一變就重播。 */
export function GlitchFlash() {
  return (
    <div className="glitch-tx" aria-hidden>
      <i />
      <i />
      <i />
    </div>
  )
}

/** 一個字一個字打出來，後面跟著游標；打完游標消失。 */
export function TypeLine({ text, cps = 45 }: { text: string; cps?: number }) {
  const [n, setN] = useState(0)
  useEffect(() => {
    setN(0)
    const t0 = performance.now()
    const id = setInterval(() => {
      const k = Math.min(text.length, Math.floor(((performance.now() - t0) / 1000) * cps))
      setN(k)
      if (k >= text.length) clearInterval(id)
    }, 30)
    return () => clearInterval(id)
  }, [text, cps])
  return (
    <>
      {text.slice(0, n)}
      {n < text.length && <span className="type-cursor" aria-hidden />}
      <span className="sr-only">{text.slice(n)}</span>
    </>
  )
}
