import { Mail } from 'lucide-react'
import { ActionButton, Panel } from '../components/ui'
import type { AwayReport } from '../game/state'
import { LOG_COLOR, hhmm } from './Log'

export function AwayDialog({ report: r, onClose }: { report: AwayReport; onClose: () => void }) {
  const mins = Math.round(r.awayMs / 60_000)
  return (
    <div className="absolute inset-0 z-30 grid place-items-center bg-bg/85 p-3" role="dialog" aria-label="離開期間報告">
      <Panel tone="strong" className="w-full" innerClass="p-4 space-y-3">
        <div className="flex items-center gap-2 text-[18px] font-bold text-heading">
          <Mail size={18} className="text-cyan" /> 離開期間報告
        </div>
        <p className="m-0 text-fg">你離開了 {mins >= 60 ? `${Math.floor(mins / 60)} 小時 ${mins % 60} 分` : `${mins} 分鐘`}。這段時間：</p>
        {r.stopped && <p className="m-0 border border-red p-2 font-bold text-red">■ 停止排隊：{r.stopped}</p>}
        <div className="grid grid-cols-2 gap-2 text-[14px]">
          <div className="border border-line/60 p-2">完成工作 <b className="tech text-heading">{r.completed}</b></div>
          <div className="border border-line/60 p-2">信用點 <b className="tech text-heading">{r.credits >= 0 ? '+' : ''}{r.credits}</b></div>
          <div className="border border-line/60 p-2">週榜積分 <b className="tech text-heading">+{r.points}</b></div>
          <div className="border border-line/60 p-2">傷勢 <b className="tech text-warning">{r.injuryFrom}% → {r.injuryTo}%</b></div>
          <div className="col-span-2 border border-line/60 p-2">通緝 <b className="text-red">{'★'.repeat(r.heatFrom) || '—'} → {'★'.repeat(r.heatTo) || '—'}</b></div>
        </div>
        <div className="max-h-44 overflow-y-auto border-t border-line/40 pt-2 text-[13px] leading-6">
          {r.events.length === 0 && <div className="text-muted">這段時間沒有事件。</div>}
          {r.events.map((e, i) => (
            <div key={i} className={LOG_COLOR[e.kind]}>
              <span className="tech text-muted">[{hhmm(e.at)}]</span> {e.text}
            </div>
          ))}
        </div>
        <ActionButton tone="primary" onClick={onClose}>回到終端</ActionButton>
      </Panel>
    </div>
  )
}
