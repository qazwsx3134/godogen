import { useEffect, useRef, useState } from 'react'
import { BarChart3, Briefcase, Building2, MessageSquare, ScrollText, ShieldAlert, Square, User } from 'lucide-react'
import { Emblem, Panel } from './components/ui'
import { useGame } from './game/state'
import { NEURAL_STAGE_LABEL, neuralMargin, neuralStage } from './rules/core'
import { JobsScreen } from './screens/Jobs'
import { CharacterScreen } from './screens/Character'
import { CityScreen } from './screens/City'
import { RankScreen } from './screens/Rank'
import { LogScreen } from './screens/Log'
import { Comms } from './screens/Comms'
import { AwayDialog } from './screens/Away'

export type Route = 'jobs' | 'char' | 'city' | 'rank' | 'log'

const NAV: { id: Route; label: string; icon: typeof Briefcase; path: string }[] = [
  { id: 'jobs', label: '委託', icon: Briefcase, path: 'JOBS' },
  { id: 'char', label: '角色', icon: User, path: 'MERC' },
  { id: 'city', label: '城市', icon: Building2, path: 'CITY' },
  { id: 'rank', label: '排行', icon: BarChart3, path: 'RANK' },
  { id: 'log', label: '紀錄', icon: ScrollText, path: 'LOG' },
]

export default function App() {
  const game = useGame()
  const { g, act } = game
  const [route, setRoute] = useState<Route>('jobs')
  const [comms, setComms] = useState(false)
  const c = g.character
  const stage = neuralStage(neuralMargin(c.level, c.implantLoad, c.stress))
  const busy = g.queue.items.length > 0
  const mainRef = useRef<HTMLElement>(null)
  useEffect(() => {
    mainRef.current?.scrollTo(0, 0)
  }, [route])

  return (
    <div className="desk-bg flex min-h-full justify-center">
      <div className="relative flex h-dvh w-full max-w-[430px] flex-col bg-bg/95 shadow-[0_0_0_1px_var(--color-line)]">
        {/* 頂列：品牌＋地點＋網址列 */}
        <header className="shrink-0 px-3 pt-[max(8px,env(safe-area-inset-top))]">
          <div className="flex items-center gap-2">
            <Emblem size={34} />
            <div className="min-w-0 flex-1 leading-none">
              <div className="tech text-[20px] font-bold text-cyan">MC</div>
              <div className="tech text-[10px] text-line">MORTAL CITY NETWORK</div>
            </div>
            <div className="text-right leading-tight">
              <div className="text-[14px] font-bold text-red">魔都 傭兵終端</div>
              <div className="text-[12px] text-muted">登入中：{c.name}</div>
            </div>
          </div>
          <div className="mt-2 flex items-center gap-2 border border-line/70 bg-raised px-2 text-[12px] leading-7">
            <span className="text-cyan">▣</span>
            <span className="tech flex-1 truncate text-fg-list">NETDIR://MORTAL.CITY/{NAV.find((n) => n.id === route)!.path}</span>
            <span className="tech text-[10px] text-line">SECURED BY MPD-NET</span>
          </div>
        </header>

        {/* 固定狀態列：生命、等級、神經、通緝、信用點，以及停止鍵 */}
        <div className="shrink-0 px-3 pt-2">
          <Panel small tone={c.alive ? 'line' : 'red'} innerClass="px-3 py-2">
            <div className="flex items-center gap-3 text-[14px]">
              <span className={`font-bold ${c.alive ? (c.injury >= 60 ? 'text-warning' : 'text-positive') : 'text-red'}`}>
                {c.alive ? (c.injury ? `傷勢 ${c.injury}%` : '存活') : '✖ 已死亡'}
              </span>
              <span className="tech text-heading">LV.{c.level}</span>
              <span className={stage === 'stable' ? 'text-muted' : 'font-bold text-warning'}>神經 {NEURAL_STAGE_LABEL[stage]}</span>
              <span className={c.heat ? 'font-bold text-red' : 'text-muted'}>
                通緝 {'★'.repeat(c.heat) || '—'}
              </span>
              <span className="tech ml-auto text-heading">¢{c.credits.toLocaleString()}</span>
            </div>
            {g.high && g.high.stage !== 'done' && (
              <div className="mt-2 flex items-center gap-2 border-t border-red/50 pt-2 text-[13px]">
                <span className="flex-1 font-bold text-red">
                  ⚠ 高階工作{g.high.stage === 'danger' ? '等待你的選擇' : '進行中'}
                </span>
                <button onClick={() => setRoute('jobs')} className="flex min-h-11 items-center border border-red px-3 font-bold text-red">
                  前往
                </button>
              </div>
            )}
            {busy && (
              <div className="mt-2 flex items-center gap-2 border-t border-line/40 pt-2 text-[13px]">
                <span className="flex-1 text-muted">
                  {g.queue.paused ? '⏸ 排隊暫停中（劇情委託進行中）' : `▶ 排隊執行中：剩 ${g.queue.items.length} 件`}
                </span>
                <button
                  onClick={() => act({ t: 'clearQueue' })}
                  className="flex min-h-11 items-center gap-1 border border-red px-3 font-bold text-red"
                >
                  <Square size={14} /> 停止排隊
                </button>
              </div>
            )}
          </Panel>
        </div>

        <main ref={mainRef} className="min-h-0 flex-1 overflow-y-auto px-3 pt-3 pb-4">
          {!c.alive && route !== 'log' && (
            <Panel tone="red" className="mb-3" innerClass="flex items-center gap-2 p-3 text-[15px]">
              <ShieldAlert size={18} className="shrink-0 text-red" />
              <span className="flex-1 text-fg">這個角色已經死亡。生涯紀錄在「紀錄」。</span>
              <button className="min-h-11 font-bold text-cyan" onClick={() => setRoute('log')}>
                前往 →
              </button>
            </Panel>
          )}
          {route === 'jobs' && <JobsScreen game={game} />}
          {route === 'char' && <CharacterScreen game={game} />}
          {route === 'city' && <CityScreen game={game} />}
          {route === 'rank' && <RankScreen game={game} />}
          {route === 'log' && <LogScreen game={game} />}
        </main>

        {/* 通訊入口（收合） */}
        <button
          onClick={() => setComms(true)}
          className="mx-3 mb-2 flex min-h-11 shrink-0 items-center gap-2 border border-line/70 bg-surface px-3 text-[14px] text-fg-list"
        >
          <MessageSquare size={16} className="text-cyan" />
          <span className="flex-1 text-left">通訊・魔都 FM 104.9</span>
          <span className="tech rounded-sm bg-red px-1 text-[12px] leading-5 text-bg">3</span>
          <span className="text-muted">展開</span>
        </button>

        {/* 底部導覽：參考圖左側分類欄的手機版 */}
        <nav className="grid shrink-0 grid-cols-5 border-t border-line bg-surface pb-[env(safe-area-inset-bottom)]">
          {NAV.map((n) => {
            const on = n.id === route
            const Icon = n.icon
            return (
              <button
                key={n.id}
                onClick={() => setRoute(n.id)}
                className={`relative flex min-h-14 flex-col items-center justify-center gap-0.5 text-[13px] ${on ? 'bg-red-bg font-bold text-red' : 'text-muted'}`}
                aria-current={on ? 'page' : undefined}
              >
                {on && <span className="absolute inset-x-2 top-0 h-0.5 bg-red" />}
                <Icon size={20} />
                {n.label}
              </button>
            )
          })}
        </nav>

        {comms && <Comms onClose={() => setComms(false)} />}
        {g.away && <AwayDialog report={g.away} onClose={() => act({ t: 'dismissAway' })} />}
      </div>
    </div>
  )
}
