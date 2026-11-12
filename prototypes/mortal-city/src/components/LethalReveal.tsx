// 致命判定的揭曉：全螢幕擲骰演出。播完（或點一下跳過）才出現結案、代價選擇或死亡畫面。
import { useState } from 'react'
import type { useGame } from '../game/state'
import { POOL_RESULT_LABEL } from '../rules/core'
import { DIE_COLOR, DiceRoll } from './dice'

type G = ReturnType<typeof useGame>

const HEAD: Record<string, string> = { crit: '撐過去了', clean: '撐過去了', cost: '撐過去了……但要付代價', fail: '致命傷' }

export function LethalReveal({ game }: { game: G }) {
  const { g, act } = game
  const r = g.run.reveal!
  const [ready, setReady] = useState(false)
  const col = DIE_COLOR[r.result]
  return (
    <div className="reveal-scan fixed inset-0 z-50 flex items-center justify-center bg-bg p-3" role="dialog" aria-label="致命判定">
      <div className="w-full max-w-[460px] space-y-4 text-center">
        <div className="tech text-[12px] tracking-[0.3em] text-red">// LETHAL CHECK</div>
        <div className="text-[15px] text-muted">{r.title}</div>
        <div className="text-[24px] font-bold text-red">致命判定</div>
        <div className="flex justify-center">
          <DiceRoll dice={r.dice} best={r.best} result={r.result} psycho={r.psycho} rollKey={r.id} size={56} onDone={() => setReady(true)} />
        </div>
        {ready && (
          <div className="dice-after space-y-3">
            <div className="text-[22px] font-bold" style={{ color: col, textShadow: `0 0 12px ${col}` }}>
              {r.broke ? '錯亂骰擲出 1：失敗' : HEAD[r.result]}
            </div>
            <div className="text-[13px] text-muted">只看最高那顆：{POOL_RESULT_LABEL[r.result]}</div>
            {r.text && <p className="m-0 text-left text-fg">{r.text}</p>}
            <button data-testid="reveal-ok" onClick={() => act({ t: 'revealDone' })} className="cut cut-sm cut-strong block w-full" style={{ ['--fill' as string]: 'var(--color-cyan)' }}>
              <span className="cut-in flex min-h-12 items-center justify-center text-[16px] font-bold text-bg">繼續</span>
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
