import { Trophy } from 'lucide-react'
import { Panel, PanelHead } from '../components/ui'
import type { useGame } from '../game/state'

const FAKE = [
  { name: '鐵雨', pts: 4820, alive: true },
  { name: 'Kurosawa', pts: 4410, alive: true },
  { name: '零號機', pts: 3990, alive: false },
  { name: '貓與霓虹', pts: 3105, alive: true },
]

export function RankScreen({ game }: { game: ReturnType<typeof useGame> }) {
  const c = game.g.character
  const rows = [...FAKE, { name: `${c.name}（你）`, pts: c.week.points, alive: c.alive }].sort((a, b) => b.pts - a.pts)
  return (
    <div className="space-y-3">
      <Panel innerClass="pb-1">
        <PanelHead icon={<Trophy size={16} />} title="每週委託榜・街頭名聲 1 組" right={<span className="tech text-[13px] text-muted">{c.week.key} 起</span>} />
        {rows.map((r, i) => {
          const me = r.name.endsWith('（你）')
          return (
            <div key={r.name} className={`flex items-center gap-3 border-b border-line/40 px-3 py-2 ${me ? 'bg-red-bg' : ''}`}>
              <span className={`tech w-6 text-[18px] font-bold ${i < 3 ? 'text-red' : 'text-muted'}`}>{i + 1}</span>
              <span className={`flex-1 ${me ? 'font-bold text-red' : 'text-fg-list'}`}>{r.name}</span>
              {!r.alive && <span className="text-[13px] text-red">✖ 已死亡</span>}
              <span className="tech text-heading">{r.pts.toLocaleString()}</span>
            </div>
          )
        })}
        <p className="m-0 px-3 py-2 text-[13px] text-muted">
          積分＝10×階級。同一種工作每週前 20 件滿分、21～40 件 50%、之後 20%：換著做火力、入侵、潛行分數最高。（其他人是假資料）
        </p>
      </Panel>
    </div>
  )
}
