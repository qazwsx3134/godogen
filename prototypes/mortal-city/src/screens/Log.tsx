import { useState } from 'react'
import { FlaskConical, Grid3x3, RotateCcw, ScrollText, Skull } from 'lucide-react'
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
  const [gallery, setGallery] = useState(false)
  const legends = [...g.meta.legends].reverse()
  return (
    <div className="space-y-3">
      <Panel innerClass="pb-2">
        <PanelHead icon={<Skull size={16} />} title="傳奇檔案" right={<span className="text-[13px] text-muted">{legends.length} 位傭兵</span>} />
        {legends.length === 0 && <p className="m-0 px-3 py-2 text-[14px] text-muted">還沒有人在魔都留下名字。死亡或退休的傭兵會記在這裡。</p>}
        {legends.map((l) => (
          <div key={l.id} className="border-b border-line/40 px-3 py-2 text-[14px]">
            <div className="flex items-baseline gap-2">
              <b className={l.end === 'dead' ? 'text-red' : 'text-cyan'}>{l.end === 'dead' ? '✖' : '★'} {l.name}</b>
              <span className="text-muted">{l.end === 'dead' ? '死亡' : '退休'}・{l.district}</span>
              <span className="tech ml-auto text-heading">名聲 {l.fameTotal}</span>
            </div>
            <div className="text-muted">
              Lv.{l.level}・名聲 Lv.{l.fame}・{l.style ? `主流派 ${l.style}` : '沒有流派'}・{l.cause}
            </div>
          </div>
        ))}
        {g.notes.map((n, i) => (
          <div key={i} className="px-3 pt-1 text-[14px] text-cyan">
            ✚ {n}
          </div>
        ))}
      </Panel>
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
      <Panel innerClass="p-3 space-y-2">
        <div className="text-[14px] font-bold text-heading">測試工具</div>
        <label className="flex min-h-11 items-center gap-2 text-[15px]">
          <input type="checkbox" checked={g.systemFault} onChange={() => act({ t: 'toggleFault' })} className="size-5 accent-[var(--color-red)]" />
          模擬「系統錯誤」：致命結果改為免費搶救
        </label>
        <ActionButton disabled={!!g.run.node || g.run.phase !== 'map' || !g.character.alive} reason="只能在地圖上（沒進節點時）開始" onClick={() => act({ t: 'devTestCase' })}>
          <FlaskConical size={16} /> 跑一次測試案「終電後的手提箱」
        </ActionButton>
        <ActionButton onClick={() => setGallery(true)}>
          <Grid3x3 size={16} /> 像素元件圖鑑
        </ActionButton>
        <ActionButton onClick={() => act({ t: 'reset' })}>
          <RotateCcw size={16} /> 清除全部存檔重來（含傳奇檔案）
        </ActionButton>
      </Panel>
      {gallery && <PixelGallery onClose={() => setGallery(false)} />}
    </div>
  )
}
