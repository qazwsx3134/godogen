// 委託結案的演出：右上角 toast（任務完成）→ 結算畫面：印章砸下、閃光與火花、報酬一列一列跳出 → 繼續（之後才挑三選一）。
import { useEffect, useRef, useState } from 'react'
import { CheckCircle2, XCircle } from 'lucide-react'
import { ActionButton, Panel } from '../components/ui'
import type { Claim, useGame } from '../game/state'
import { buzz } from '../components/haptics'
import { sfx } from '../components/sfx'

type G = ReturnType<typeof useGame>

const STAMP: Record<Claim['tone'], { label: string; sub: string; color: string }> = {
  success: { label: '完成', sub: 'MISSION COMPLETE', color: 'var(--color-cyan)' },
  partial: { label: '部分完成', sub: 'PARTIAL', color: 'var(--color-warning)' },
  rescued: { label: '生還', sub: 'RESCUED', color: 'var(--color-positive)' },
  fail: { label: '失敗', sub: 'FAILED', color: 'var(--color-red)' },
}

/** 信用點那一列的數字從 0 跳到最後的值。 */
function CountUp({ value }: { value: string }) {
  const m = value.match(/^([+−-]?¢)(\d+)(.*)$/)
  const target = m ? Number(m[2]) : 0
  const [n, setN] = useState(0)
  useEffect(() => {
    if (!m) return
    const t0 = performance.now()
    const id = setInterval(() => {
      const k = Math.min(1, (performance.now() - t0) / 700)
      setN(Math.round(target * (1 - (1 - k) ** 3)))
      if (k >= 1) clearInterval(id)
    }, 30)
    return () => clearInterval(id)
  }, [target])
  return <>{m ? `${m[1]}${n}${m[3]}` : value}</>
}

const TOAST_MS = 1400

/** 結案：右上角先跳 toast（任務完成／失敗），約 1.4 秒後（或點一下）打開結算畫面，印章自動砸下、報酬逐列出現。 */
export function CompleteDialog({ game }: { game: G }) {
  const { g, act } = game
  const claim = g.run.claim!
  const st = STAMP[claim.tone]
  const won = claim.tone !== 'fail'
  const [sheet, setSheet] = useState(false)
  const picks = g.character.picks.length

  const opened = useRef(false)
  const open = () => {
    if (opened.current) return
    opened.current = true
    setSheet(true)
    ;(won ? sfx.success : sfx.fail)()
  }
  useEffect(() => {
    buzz(won ? [30, 40, 60] : 80)
    sfx.toast()
    const id = setTimeout(open, TOAST_MS)
    return () => clearTimeout(id)
  }, [won]) // open 只看 ref，不需要放進依賴

  if (!sheet)
    return (
      <button onClick={open} className="claim-toast absolute top-[max(10px,env(safe-area-inset-top))] right-3 z-40 block w-64 text-left cut cut-sm" style={{ ['--edge' as string]: st.color }} aria-live="polite">
        <span className="cut-in flex items-center gap-3 px-3 py-2.5">
          {won ? <CheckCircle2 size={22} style={{ color: st.color }} className="shrink-0" /> : <XCircle size={22} className="shrink-0 text-red" />}
          <span className="min-w-0 flex-1">
            <span className="block text-[15px] font-bold" style={{ color: st.color }}>
              {won ? (claim.tone === 'success' ? '任務完成' : st.label) : '委託失敗'}
            </span>
            <span className="block truncate text-[13px] text-fg-list">{claim.title}</span>
          </span>
          <span className="tech text-[11px] text-muted">{st.sub}</span>
        </span>
        <span className="claim-toast-bar" style={{ background: st.color, animationDuration: `${TOAST_MS}ms` }} aria-hidden />
      </button>
    )

  return (
    <div className="absolute inset-0 z-40 overflow-y-auto bg-bg/92 p-3" role="dialog" aria-label="委託結案">
      {won && <div className="claim-flash" aria-hidden />}
      <Panel tone={won ? 'strong' : 'red'} className="relative mt-[8dvh]" innerClass="relative overflow-hidden p-4 space-y-3">
        <div className="tech text-[12px] text-muted">CASE FILE・委託結案</div>
        <h2 className="m-0 text-[22px] leading-snug font-bold text-heading">{claim.title}</h2>
        <p className="m-0 text-fg">{claim.text}</p>

        <div className="relative grid h-36 place-items-center">
          <div className="claim-stamp" style={{ ['--stamp' as string]: st.color }}>
            <span className="text-[30px] leading-none font-bold">{st.label}</span>
            <span className="tech mt-1 text-[12px] tracking-[0.2em]">{st.sub}</span>
          </div>
          {won && (
            <div className="pointer-events-none absolute inset-0" aria-hidden>
              {Array.from({ length: 14 }, (_, i) => (
                <i key={i} className="claim-spark" style={{ ['--a' as string]: `${(i / 14) * 360}deg`, ['--d' as string]: `${60 + (i % 3) * 22}px`, background: i % 2 ? st.color : 'var(--color-red)' }} />
              ))}
            </div>
          )}
        </div>

        <dl className="m-0 divide-y divide-line/40 border-y border-line/40">
          {claim.rows.map((r, i) => (
            <div key={r.label} className="claim-row flex gap-3 py-1.5 text-[15px]" style={{ animationDelay: `${0.25 + i * 0.12}s` }}>
              <dt className="w-20 shrink-0 text-muted">{r.label}</dt>
              <dd className={`m-0 flex-1 font-bold ${r.tone === 'good' ? 'text-positive' : r.tone === 'bad' ? 'text-red' : r.tone === 'warn' ? 'text-warning' : 'text-heading'}`}>
                {r.label === '信用點' ? <CountUp value={r.value} /> : r.value}
              </dd>
            </div>
          ))}
          {claim.rows.length === 0 && <div className="py-1.5 text-[15px] text-muted">什麼都沒拿到。</div>}
        </dl>

        <ActionButton tone="primary" onClick={() => act({ t: 'claim' })}>
          {picks ? `繼續：挑選三選一（${picks} 組）` : '繼續'}
        </ActionButton>
      </Panel>
    </div>
  )
}
