import { Grid3x3, RotateCcw, ScrollText, Skull } from '../components/icons'
import { useState } from 'react'
import { PixelGallery } from '../components/PixelGallery'
import { ActionButton, Panel, PanelHead } from '../components/ui'
import type { useGame } from '../game/state'
import type { LogKind } from '../rules/core'

export const LOG_COLOR: Record<LogKind, string> = {
  job: 'text-fg',
  gain: 'text-warning',
  hurt: 'text-red',
  warn: 'text-warning',
  stop: 'text-red font-bold',
  level: 'text-warning font-bold',
  system: 'text-cyan',
}

export const hhmm = (ms: number) => new Date(ms).toTimeString().slice(0, 8)

export function LogScreen({ game }: { game: ReturnType<typeof useGame> }) {
  const { g, act } = game
  const c = g.character
  const last = g.careers[g.careers.length - 1]
  const [gallery, setGallery] = useState(false)
  return (
    <div className="space-y-3">
      {!c.alive && last && (
        <Panel tone="red" innerClass="p-4 space-y-2">
          <div className="flex items-center gap-2 text-[20px] font-bold text-red">
            <Skull size={20} /> 生涯結束：{last.name}
          </div>
          <p className="m-0 text-fg">{last.cause}</p>
          <div className="text-[14px] text-muted">
            Lv.{last.level}・本週積分 {last.weekPoints}・身上 ¢{last.credits.toLocaleString()}。紀錄保存為唯讀，不能復活。
          </div>
          <p className="m-0 text-[14px] text-muted">死亡的角色不能再聊天。</p>
          <ActionButton tone="primary" onClick={() => act({ t: 'newCharacter' })}>
            建立新角色
          </ActionButton>
        </Panel>
      )}
      <Panel innerClass="pb-2">
        <PanelHead icon={<ScrollText size={16} />} title="行動紀錄" right={<span className="text-[13px] text-muted">最近 {Math.min(60, g.log.length)} 筆</span>} />
        <div className="max-h-[55dvh] overflow-y-auto px-3 pt-2 font-[family-name:var(--font-sans)] text-[14px] leading-6">
          {g.log.slice(-60).reverse().map((e, i) => (
            <div key={i} className={LOG_COLOR[e.kind]}>
              <span className="tech text-muted">[{hhmm(e.at)}]</span> {e.text}
            </div>
          ))}
        </div>
      </Panel>
      {(g.careers.length > 0 || g.notes.length > 0) && (
        <Panel innerClass="p-3 text-[14px]">
          <div className="mb-1 font-bold text-heading">歷代生涯</div>
          {g.careers.map((k) => (
            <div key={k.id} className="text-muted">
              ✖ {k.name}・Lv.{k.level}・{k.cause}
            </div>
          ))}
          {g.notes.map((n, i) => (
            <div key={i} className="text-cyan">✚ {n}</div>
          ))}
        </Panel>
      )}
      <Panel innerClass="p-3 space-y-2">
        <div className="text-[14px] font-bold text-heading">測試工具</div>
        <label className="flex min-h-11 items-center gap-2 text-[15px]">
          <input type="checkbox" checked={g.systemFault} onChange={() => act({ t: 'toggleFault' })} className="size-5 accent-[var(--color-red)]" />
          模擬「系統錯誤」：致命結果改為免費搶救
        </label>
        <ActionButton onClick={() => setGallery(true)}>
          <Grid3x3 size={16} /> 像素元件圖鑑
        </ActionButton>
        <ActionButton onClick={() => act({ t: 'reset' })}>
          <RotateCcw size={16} /> 清除存檔重來
        </ActionButton>
      </Panel>
      {gallery && <PixelGallery onClose={() => setGallery(false)} />}
    </div>
  )
}
