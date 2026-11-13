// 骰子：賽博風的六面骰（切角外框、霓虹發光、LED 方點）、擲骰動畫，以及第一次遇到時的介紹。
// 結果由 reducer 依 seed 決定，這裡只負責把它演出來；動畫可以點一下跳過，偏好減少動態時直接顯示結果。
import { useEffect, useRef, useState, type ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { sfx } from './sfx'
import type { PoolResult } from '../rules/core'

export type DieTone = PoolResult | 'idle' | 'psycho'

/** 骰子的霓虹色：大成功洋紅、乾淨成功青、付代價黃、失敗紅、錯亂骰紫。 */
export const DIE_COLOR: Record<DieTone, string> = {
  crit: '#ff5cf0',
  clean: '#38f3fa',
  cost: '#e7d34a',
  fail: '#ed5258',
  idle: '#1b8d9c',
  psycho: '#b06cff',
}

/** 3×3 格上的點位（欄、列）。 */
const PIPS: Record<number, [number, number][]> = {
  1: [[1, 1]],
  2: [[0, 0], [2, 2]],
  3: [[0, 0], [1, 1], [2, 2]],
  4: [[0, 0], [2, 0], [0, 2], [2, 2]],
  5: [[0, 0], [2, 0], [1, 1], [0, 2], [2, 2]],
  6: [[0, 0], [0, 1], [0, 2], [2, 0], [2, 1], [2, 2]],
}

/** 一顆骰子。lit＝決定結果的那顆（發光）；dim＝沒用到的骰。 */
export function DieFace({ value, tone = 'idle', size = 36, lit = false, dim = false, rolling = false }: { value: number; tone?: DieTone; size?: number; lit?: boolean; dim?: boolean; rolling?: boolean }) {
  const col = DIE_COLOR[tone]
  return (
    <svg
      viewBox="0 0 40 40"
      width={size}
      height={size}
      role="img"
      aria-label={`${value} 點`}
      className={`die ${rolling ? 'die-rolling' : ''} ${lit ? 'die-lit' : ''}`}
      style={{ ['--die' as string]: col, opacity: dim ? 0.45 : 1 }}
    >
      <polygon points="9,1.5 38.5,1.5 38.5,31 31,38.5 1.5,38.5 1.5,9" fill="#061218" stroke={col} strokeWidth={lit ? 2.2 : 1.4} />
      <polygon points="11,5 35,5 35,29.5 29.5,35 5,35 5,11" fill="none" stroke={col} strokeOpacity={0.22} strokeWidth={0.8} />
      <path d="M30 1.5 h6" stroke={col} strokeWidth={2.5} />
      <path d="M1.5 30 v6" stroke={col} strokeWidth={2.5} opacity={0.6} />
      {(PIPS[value] ?? []).map(([cx, cy], i) => (
        <rect key={i} x={11 + cx * 9 - 2.8} y={11 + cy * 9 - 2.8} width={5.6} height={5.6} rx={1} fill={col} />
      ))}
    </svg>
  )
}

const reduced = () => typeof window !== 'undefined' && !!window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
/** 播過動畫的擲骰（同一次擲骰在別處再出現時不重播）。 */
const played = new Set<string>()
/** 播完（或不用播）的擲骰；等著它的畫面（下一個場面、結果）在這之後才出現。 */
const finished = new Set<string>()
const waiters = new Set<() => void>()
function markDone(key?: string) {
  if (!key || finished.has(key)) return
  finished.add(key)
  waiters.forEach((f) => f())
}
/** 這次擲骰播完了沒（沒有 key＝不用等）。 */
export function useRollDone(key?: string) {
  const [, tick] = useState(0)
  useEffect(() => {
    const f = () => tick((x) => x + 1)
    waiters.add(f)
    return () => void waiters.delete(f)
  }, [])
  return !key || finished.has(key)
}

/** 骰子亂跳多久後第一顆落定，之後每顆間隔多久。 */
const SETTLE_MS = 520
const STEP_MS = 120

/**
 * 一把骰子：rollKey 第一次出現時播擲骰動畫（亂跳 → 逐顆落定 → 決定結果的那顆亮起 → 結果音效），
 * 播完才顯示 children（結果文字、代價選項）。沒有 rollKey 就直接顯示結果。點一下可以跳過。
 */
export function DiceRoll({
  dice,
  best,
  result,
  rollKey,
  size = 36,
  psycho,
  children,
  onDone,
}: {
  dice: number[]
  best?: number
  result: PoolResult
  rollKey?: string
  size?: number
  /** 這次一起擲的錯亂骰（另外顯示成紫色）。 */
  psycho?: number[]
  children?: ReactNode
  /** 骰子全部落定（沒有動畫時是掛上時）。 */
  onDone?: () => void
}) {
  const [fresh] = useState(() => !!rollKey && !played.has(rollKey) && !reduced())
  const [faces, setFaces] = useState<number[]>(fresh ? dice.map(() => 1 + Math.floor(Math.random() * 6)) : dice)
  const [settled, setSettled] = useState(fresh ? 0 : dice.length)
  const done = settled >= dice.length
  const timer = useRef<ReturnType<typeof setInterval> | null>(null)
  const finish = useRef(() => {})
  finish.current = () => {
    if (timer.current) clearInterval(timer.current)
    timer.current = null
    setFaces(dice)
    setSettled(dice.length)
    ;({ crit: sfx.crit, clean: sfx.success, cost: sfx.toast, fail: sfx.fail })[result]()
    markDone(rollKey)
    onDone?.()
  }
  useEffect(() => {
    if (!fresh) {
      markDone(rollKey)
      onDone?.()
      return
    }
    played.add(rollKey!)
    sfx.dice()
    const start = performance.now()
    let shown = 0
    timer.current = setInterval(() => {
      const t = performance.now() - start
      const n = dice.filter((_, i) => t >= SETTLE_MS + i * STEP_MS).length
      if (n > shown) {
        shown = n
        sfx.die()
      }
      setSettled(n)
      setFaces(dice.map((d, i) => (i < n ? d : 1 + Math.floor(Math.random() * 6))))
      if (n >= dice.length) finish.current()
    }, 60)
    return () => {
      if (timer.current) clearInterval(timer.current)
    }
    // 只在第一次掛上時播；結果由 props 決定，不會變
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])
  const key = best ?? Math.max(...dice)
  const hi = dice.indexOf(key)
  return (
    <div onClick={() => !done && finish.current()} className={!done ? 'cursor-pointer' : undefined}>
      <div className="flex flex-wrap items-center gap-1.5" data-testid="dice">
        {faces.map((d, i) => (
          <DieFace key={i} value={d} size={size} rolling={i >= settled} tone={!done ? 'idle' : i === hi ? result : 'idle'} lit={done && i === hi} dim={done && i !== hi} />
        ))}
        {done && psycho?.length ? (
          <span className="ml-1 inline-flex items-center gap-1">
            <span className="text-[12px] text-[#b06cff]">錯亂</span>
            {psycho.map((d, i) => (
              <DieFace key={i} value={d} size={Math.round(size * 0.78)} tone="psycho" lit />
            ))}
          </span>
        ) : null}
        {!done && <span className="ml-1 text-[12px] text-muted">擲骰中…（點一下跳過）</span>}
      </div>
      {done && children ? <div className="dice-after">{children}</div> : null}
    </div>
  )
}

/** 規則說明裡的一排示意骰。 */
function Sample({ dice, tone }: { dice: number[]; tone: PoolResult }) {
  const hi = dice.indexOf(Math.max(...dice))
  const on = (d: number, i: number) => (tone === 'crit' ? d === 6 : i === hi)
  return (
    <span className="inline-flex shrink-0 gap-1">
      {dice.map((d, i) => (
        <DieFace key={i} value={d} size={26} tone={on(d, i) ? tone : 'idle'} lit={on(d, i)} dim={!on(d, i)} />
      ))}
    </span>
  )
}

/** 第一次遇到骰池或致命判定時的介紹；之後可以從「？」重看。 */
export function DiceIntro({ kind, onClose }: { kind: 'dice' | 'lethal'; onClose: () => void }) {
  const row = (dice: number[], tone: PoolResult, title: string, note: string) => (
    <div className="flex items-center gap-3 border-b border-line/30 py-2">
      <Sample dice={dice} tone={tone} />
      <div className="min-w-0">
        <div className="font-bold" style={{ color: DIE_COLOR[tone] }}>
          {title}
        </div>
        <div className="text-[13px] text-muted">{note}</div>
      </div>
    </div>
  )
  // 掛到 body：節點畫面在捲動容器裡，fixed 會被那層的堆疊順序蓋在導覽列底下
  return createPortal(
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-bg/90 p-3" role="dialog" aria-label={kind === 'dice' ? '骰池怎麼玩' : '致命判定怎麼玩'}>
      <div className="cut cut-strong max-h-full w-full max-w-[460px] overflow-y-auto">
        <div className="cut-in space-y-3 p-4">
          <div className="tech text-[12px] tracking-widest text-cyan">// NEURAL-LINK TUTORIAL</div>
          {kind === 'dice' ? (
            <>
              <h2 className="m-0 text-[20px] font-bold text-heading">骰池：魔都不會照你的計畫走</h2>
              <p className="m-0 text-fg">
                每件委託拆成幾個<b className="text-cyan">場面</b>。計畫總會出狀況，所以每個場面都要擲一把六面骰，看這一步順不順。
                <b className="text-cyan">準備越多，骰越多</b>：屬性、這個方向的裝備與卡牌都會多給骰；難度高、受重傷會少骰。
              </p>
              <p className="m-0 text-fg">
                擲幾顆都只看<b className="text-cyan">最高的那一顆</b>：
              </p>
              <div>
                {row([6, 3, 6], 'crit', '兩顆 6：大成功', '漂亮得手，報酬 +15%')}
                {row([2, 6, 4], 'clean', '最高是 6：乾淨成功', '沒有任何代價')}
                {row([5, 1, 3], 'cost', '最高是 4 或 5：成功，但付代價', '你挑要付什麼：受傷、通緝、神經壓力，或少拿報酬')}
                {row([3, 1, 2], 'fail', '最高只有 1～3：失敗', '吃下這個場面的代價而且更重（受傷加倍、壓力三倍），還會慌得多 4 點神經壓力；駭入、潛行失敗兩次會被逮到要打')}
              </div>
              <p className="m-0 text-[14px] text-fg">
                <b className="text-red">加骰</b>：擲之前可以「硬撐」（神經壓力）或「鋌而走險」（通緝），各多擲 1 顆。一顆骰都沒有時，擲兩顆、取低的。
              </p>
              <p className="m-0 text-[13px] text-muted">結果由這段生涯的 seed 決定，重新整理不會重擲。神經壓力太高時還要多擲一顆紫色的錯亂骰。</p>
            </>
          ) : (
            <>
              <h2 className="m-0 text-[20px] font-bold text-red">致命判定：這次賭的是命</h2>
              <p className="m-0 text-fg">
                危險節點的冒險選項只擲一次，但輸了可能就是<b className="text-red">永久死亡</b>。骰數一樣看屬性、裝備與卡牌；精英對手和劇情大案會扣骰，劇情做法的場面打得好會加骰。
              </p>
              <div>
                {row([2, 6, 3], 'clean', '最高是 6：撐過去', '報酬、名聲全拿')}
                {row([4, 5, 1], 'cost', '最高是 4 或 5：撐過去，但要付重代價', '二選一：重傷生還（拿報酬、留一道舊傷），或丟下一切脫身')}
                {row([3, 2, 1], 'fail', '最高只有 1～3：出大事', '現場有敵人：他們逼近，你得打一場，打贏算撐過去、打輸才是致命傷。沒有敵人（例如防火牆攻擊你的神經）：直接是致命傷。致命傷有救命保單會被救回來，沒有就是永久死亡')}
              </div>
              <p className="m-0 text-[14px] text-fg">
                一定有一個<b className="text-positive">不用擲骰的撤離選項</b>。骰太少時，先去神機醫治傷、帶這個方向的裝備，或在擲之前硬撐、鋌而走險。
              </p>
            </>
          )}
          <button data-testid="intro-ok" onClick={onClose} className="cut cut-sm cut-strong block w-full" style={{ ['--fill' as string]: 'var(--color-cyan)' }}>
            <span className="cut-in flex min-h-12 items-center justify-center text-[16px] font-bold text-bg">懂了</span>
          </button>
        </div>
      </div>
    </div>,
    document.body,
  )
}

/** 第一次遇到就自動打開介紹，之後點「？」重看。 */
export function useIntro(seen: boolean, markSeen: () => void) {
  const [open, setOpen] = useState(!seen)
  return {
    open,
    show: () => setOpen(true),
    close: () => {
      setOpen(false)
      if (!seen) markSeen()
    },
  }
}

/** 「？」：重看介紹。 */
export function IntroButton({ onClick, label = '怎麼擲骰？' }: { onClick: () => void; label?: string }) {
  return (
    <button onClick={onClick} className="tech inline-flex min-h-8 items-center gap-1 border border-line/60 px-2 text-[13px] text-cyan">
      ？ {label}
    </button>
  )
}
