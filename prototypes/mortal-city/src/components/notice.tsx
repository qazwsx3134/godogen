// 「發生了什麼」的小通知：挑卡、挑道具、加屬性之後在畫面下方出現約 3 秒（不擋操作）。
import { useEffect, useState } from 'react'

export interface Notice {
  title: string
  lines: string[]
}

let push: ((n: Notice) => void) | null = null
export const notify = (n: Notice) => push?.(n)

export function Notices() {
  const [list, setList] = useState<(Notice & { id: number })[]>([])
  useEffect(() => {
    let seq = 0
    push = (n) => {
      const id = ++seq
      setList((l) => [...l.slice(-1), { ...n, id }])
      setTimeout(() => setList((l) => l.filter((x) => x.id !== id)), 3200)
    }
    return () => {
      push = null
    }
  }, [])
  if (!list.length) return null
  return (
    <div className="pointer-events-none absolute inset-x-3 bottom-[calc(76px+env(safe-area-inset-bottom))] z-40 space-y-2" aria-live="polite" data-testid="notice">
      {list.map((n) => (
        <div key={n.id} className="notice cut cut-sm">
          <div className="cut-in px-3 py-2">
            <b className="text-[15px] text-heading">{n.title}</b>
            {n.lines.length > 0 && <div className="text-[13px] text-cyan">{n.lines.join('・')}</div>}
          </div>
        </div>
      ))}
    </div>
  )
}
