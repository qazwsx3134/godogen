// 對話一則一則浮現：從已讀的地方接著播，每播一則就回報（存檔），回來不重播。
// 父元件每秒會因時鐘重新渲染，callback 每次都是新函式；放進 ref 才不會一直重設計時器。
import { useEffect, useRef, useState } from 'react'

const reducedMotion = () => typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches

/** 對方打字的時間：看字數，0.6～1.6 秒。你自己的回覆幾乎立刻出現。 */
export function typingMs(text: string, mine = false) {
  return mine ? 150 : Math.max(600, Math.min(1600, 400 + text.length * 35))
}

export function useReveal(total: number, seen: number, delay: (i: number) => number, onSeen: (n: number) => void) {
  const [n, setN] = useState(() => (reducedMotion() ? total : Math.min(seen, total)))
  const cb = useRef({ delay, onSeen })
  cb.current = { delay, onSeen }
  useEffect(() => {
    if (n > total) setN(total) // 舊訊息被丟掉
    else if (n < total && reducedMotion()) {
      setN(total)
      cb.current.onSeen(total)
    }
  }, [n, total])
  useEffect(() => {
    if (n >= total || reducedMotion()) return
    const id = setTimeout(() => {
      setN(n + 1)
      cb.current.onSeen(n + 1)
    }, cb.current.delay(n))
    return () => clearTimeout(id)
  }, [n, total])
  return {
    n: Math.min(n, total),
    typing: n < total,
    skip: () => {
      setN(total)
      cb.current.onSeen(total)
    },
  }
}

export function TypingLine({ who }: { who: string }) {
  return (
    <div className="flex items-center gap-2 text-[13px] text-muted" aria-live="polite">
      <span className="typing-dots" aria-hidden>
        <i />
        <i />
        <i />
      </span>
      {who} 正在輸入…
    </div>
  )
}
