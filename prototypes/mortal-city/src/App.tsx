import { useEffect, useMemo, useRef, useState } from 'react'
import { Activity, AudioLines, type LucideIcon, Map as MapIcon, Volume2, VolumeX, ScrollText, ShieldAlert, ShieldPlus, Sparkles, User } from 'lucide-react'
import { Emblem, Panel } from './components/ui'
import { nodeBusy, useGame } from './game/state'
import { LIFELINES, NEURAL_STAGE_LABEL, SEVERE_INJURY, lifelineOf, marginOf, neuralStage } from './rules/core'
import { RunScreen } from './screens/Run'
import { CharacterScreen } from './screens/Character'
import { LogScreen } from './screens/Log'
import { COMMS_COUNT, Comms } from './screens/Comms'
import { PickDialog } from './screens/Pick'
import { CompleteDialog } from './screens/Complete'
import { LethalReveal } from './components/LethalReveal'
import { NewsTicker } from './components/Fx'
import { Notices } from './components/notice'
import { newsFor } from './content/news'
import { onSfxChange, setSfx, sfx, sfxEnabled, unlock } from './components/sfx'

export type Route = 'run' | 'char' | 'log'

const NAV: { id: Route; label: string; icon: LucideIcon }[] = [
  { id: 'run', label: '街區', icon: MapIcon },
  { id: 'char', label: '角色', icon: User },
  { id: 'log', label: '紀錄', icon: ScrollText },
]

export default function App() {
  const game = useGame()
  const { g } = game
  const [route, setRoute] = useState<Route>('run')
  const [comms, setComms] = useState(false)
  // 通訊的紅色數字：這次開啟頁面後還沒點開過才顯示
  const [commsRead, setCommsRead] = useState(false)
  const c = g.character
  const stage = neuralStage(marginOf(c))
  // 致命判定的揭曉播完之前，結案與三選一都先等
  const revealing = !!g.run.reveal
  const claiming = c.alive && !!g.run.claim && !revealing
  const picking = c.alive && c.picks.length > 0 && !nodeBusy(g) && !claiming && !revealing
  const mainRef = useRef<HTMLElement>(null)
  useEffect(() => {
    mainRef.current?.scrollTo(0, 0)
  }, [route])
  // 進出節點也捲回頂端：不然會停在地圖捲過的位置，節點的像素圖整張被捲到跑馬燈底下
  // （回到地圖時，地圖自己會在下一輪把能去的節點捲到中間）
  const nodeKey = g.run.node?.nodeId ?? null
  useEffect(() => {
    mainRef.current?.scrollTo(0, 0)
  }, [nodeKey])
  // 音效：開關、進節點的連線音
  const [sound, setSound] = useState(sfxEnabled())
  useEffect(() => onSfxChange(() => setSound(sfxEnabled())), [])
  const nodeId = g.run.node?.nodeId
  useEffect(() => {
    if (nodeId) sfx.enter()
  }, [nodeId])
  const news = useMemo(() => newsFor(g), [g.character.heat, g.character.fame.level, g.character.lifelines, g.run.cases, g.meta.legends])

  return (
    <div className="desk-bg terminal-desk">
      <div
        className="terminal"
        onPointerDownCapture={(e) => {
          // 瀏覽器要等使用者操作後才能發聲：第一次點擊時啟動音效；之後每個可點的按鈕都有點擊聲
          unlock()
          if ((e.target as HTMLElement).closest('button:not(:disabled)')) sfx.click()
        }}
      >
        <header className="terminal-header">
          <div className="terminal-brand">
            <Emblem size={34} />
            <div className="min-w-0">
              <div className="terminal-wordmark">魔都傭兵終端</div>
              <div className="tech terminal-callsign">{c.name} · LV.{c.level} · 名聲 {c.fame.level}</div>
            </div>
          </div>
          <dl className="terminal-meter">
            <div>
              <dt>傷勢</dt>
              <dd className={!c.alive || c.injury >= SEVERE_INJURY ? 'text-red' : c.injury ? 'text-warning' : 'text-positive'}>
                {c.alive ? `${c.injury}%` : '已死亡'}
              </dd>
            </div>
            <div>
              <dt>神經</dt>
              <dd className={stage === 'stable' ? 'text-heading' : 'text-warning'}>{NEURAL_STAGE_LABEL[stage]}{stage !== 'stable' && ` ${marginOf(c)}`}</dd>
            </div>
            <div>
              <dt>通緝</dt>
              <dd className={c.heat ? 'text-red' : 'text-muted'}>{c.heat ? `${c.heat} ★` : '—'}</dd>
            </div>
            <div>
              <dt>信用點</dt>
              <dd className="text-heading">¢{c.credits.toLocaleString()}</dd>
            </div>
          </dl>
          <div className="terminal-tools">
            <span className={`terminal-policy ${c.lifelines ? 'text-positive' : 'text-muted'}`} title="救命保單">
              <ShieldPlus size={15} aria-hidden />
              <span>{lifelineOf(c) ? LIFELINES[lifelineOf(c)!].label.slice(0, 2) : '無保單'}</span>
            </span>
            <button
              type="button"
              onClick={() => setSfx(!sound)}
              aria-label={sound ? '關閉音效' : '開啟音效'}
              className={`terminal-icon ${sound ? 'text-cyan' : 'text-muted'}`}
            >
              {sound ? <Volume2 size={18} /> : <VolumeX size={18} />}
            </button>
          </div>
        </header>
        {((c.alive && c.injury >= SEVERE_INJURY) || (c.alive && c.picks.length > 0 && nodeBusy(g))) && (
          <div className="terminal-alerts">
            {c.injury >= SEVERE_INJURY && <span className="text-red"><Activity size={14} aria-hidden /> 重傷 · 先找神機醫或休息</span>}
            {c.picks.length > 0 && nodeBusy(g) && <span className="text-warning"><Sparkles size={14} aria-hidden /> {c.picks.length} 組三選一待領</span>}
          </div>
        )}
        <div className="terminal-news"><NewsTicker items={news} /></div>

        <main ref={mainRef} className="terminal-main">
          {!c.alive && route !== 'run' && (
            <Panel tone="red" className="mb-3" innerClass="flex items-center gap-2 p-3 text-[15px]">
              <ShieldAlert size={18} className="shrink-0 text-red" />
              <span className="flex-1 text-fg">這個傭兵已經死亡，已寫進傳奇檔案。</span>
              <button className="min-h-11 font-bold text-cyan" onClick={() => setRoute('run')}>
                前往 →
              </button>
            </Panel>
          )}
          {route === 'run' && <RunScreen game={game} />}
          {route === 'char' && <CharacterScreen game={game} />}
          {route === 'log' && <LogScreen game={game} />}
        </main>

        <div className="terminal-dock">
          <nav aria-label="終端頁面" className="terminal-nav">
            {NAV.map((n) => {
              const on = n.id === route
              const Icon = n.icon
              return (
                <button key={n.id} type="button" onClick={() => setRoute(n.id)} aria-current={on ? 'page' : undefined}>
                  <Icon size={18} aria-hidden />
                  {n.label}
                  {n.id === 'char' && c.alive && c.attrPoints > 0 && (
                    <span className="terminal-count" aria-label={`${c.attrPoints} 點屬性可分配`}>{c.attrPoints}</span>
                  )}
                </button>
              )
            })}
          </nav>
          <button type="button" className="terminal-comms" onClick={() => { setComms(true); setCommsRead(true) }}>
            <AudioLines size={18} aria-hidden />
            通訊
            {!commsRead && <span className="terminal-count">{COMMS_COUNT}</span>}
          </button>
        </div>

        <Notices />
        {comms && <Comms onClose={() => setComms(false)} />}
        {claiming && <CompleteDialog game={game} />}
        {picking && <PickDialog game={game} />}
        {revealing && <LethalReveal key={g.run.reveal!.id} game={game} />}
      </div>
    </div>
  )
}
