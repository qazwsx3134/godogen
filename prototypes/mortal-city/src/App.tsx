import { useEffect, useMemo, useRef, useState } from 'react'
import { type LucideIcon, Map as MapIcon, MessageSquare, Volume2, VolumeX, ScrollText, ShieldAlert, ShieldPlus, Sparkles, User } from 'lucide-react'
import { Emblem, NeonIcon, Panel } from './components/ui'
import { nodeBusy, useGame } from './game/state'
import { LIFELINES, NEURAL_STAGE_LABEL, SEVERE_INJURY, lifelineOf, marginOf, neuralStage } from './rules/core'
import { RunScreen } from './screens/Run'
import { CharacterScreen } from './screens/Character'
import { LogScreen } from './screens/Log'
import { COMMS_COUNT, Comms } from './screens/Comms'
import { PickDialog } from './screens/Pick'
import { CompleteDialog } from './screens/Complete'
import { LethalReveal } from './components/LethalReveal'
import { GlitchFlash, NewsTicker } from './components/Fx'
import { Notices } from './components/notice'
import { newsFor } from './content/news'
import { onSfxChange, setSfx, sfx, sfxEnabled, unlock } from './components/sfx'

export type Route = 'run' | 'char' | 'log'

const NAV: { id: Route; label: string; icon: LucideIcon; path: string }[] = [
  { id: 'run', label: '街區', icon: MapIcon, path: 'RUN' },
  { id: 'char', label: '角色', icon: User, path: 'MERC' },
  { id: 'log', label: '紀錄', icon: ScrollText, path: 'LOG' },
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
  const glitchKey = `${route}|${nodeId ?? 'map'}|${g.run.phase}`

  return (
    <div className="desk-bg flex min-h-full justify-center">
      <div
        className="relative flex h-dvh w-full max-w-[430px] flex-col bg-bg/95 shadow-[0_0_0_1px_var(--color-line)]"
        onPointerDownCapture={(e) => {
          // 瀏覽器要等使用者操作後才能發聲：第一次點擊時啟動音效；之後每個可點的按鈕都有點擊聲
          unlock()
          if ((e.target as HTMLElement).closest('button:not(:disabled)')) sfx.click()
        }}
      >
        <GlitchFlash key={glitchKey} />
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
            <button
              onClick={() => setSfx(!sound)}
              aria-label={sound ? '關閉音效' : '開啟音效'}
              className={`grid size-11 shrink-0 place-items-center border ${sound ? 'border-line text-cyan' : 'border-line/50 text-muted'}`}
            >
              {sound ? <Volume2 size={18} /> : <VolumeX size={18} />}
            </button>
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
            <div className="flex flex-wrap items-center gap-x-3 gap-y-0.5 text-[14px] [&>span]:whitespace-nowrap">
              <span className={`font-bold ${c.alive ? (c.injury >= 60 ? 'text-warning' : 'text-positive') : 'text-red'}`}>
                {c.alive ? (c.injury ? `傷勢 ${c.injury}%` : '存活') : '✖ 已死亡'}
              </span>
              <span className="tech text-heading">LV.{c.level}</span>
              <span className="tech text-warning">名聲 {c.fame.level}</span>
              <span className={stage === 'stable' ? 'text-muted' : 'font-bold text-warning'}>
                神經 {NEURAL_STAGE_LABEL[stage]}
                {stage !== 'stable' && ` ${marginOf(c)}`}
              </span>
              <span className={c.heat ? 'font-bold text-red' : 'text-muted'}>
                通緝 {'★'.repeat(c.heat) || '—'}
              </span>
              <span className={`flex items-center gap-0.5 ${c.lifelines ? 'text-positive' : 'text-muted'}`} title="救命保單">
                <ShieldPlus size={14} />
                {lifelineOf(c) ? LIFELINES[lifelineOf(c)!].label.slice(0, 2) : 0}
              </span>
              <span className="tech ml-auto text-heading">¢{c.credits.toLocaleString()}</span>
            </div>
            {c.alive && c.injury >= SEVERE_INJURY && (
              <div className="mt-2 border-t border-red/50 pt-2 text-[13px] font-bold text-red">✚ 重傷：開打時 HP 很低，先找神機醫或休息節點</div>
            )}
            {c.alive && c.picks.length > 0 && nodeBusy(g) && (
              <div className="mt-2 flex items-center gap-1 border-t border-line/40 pt-2 text-[13px] text-warning">
                <Sparkles size={14} /> 有 {c.picks.length} 組三選一，這個節點結束後挑
              </div>
            )}
          </Panel>
          <div className="mt-2">
            <NewsTicker items={news} />
          </div>
        </div>

        <main ref={mainRef} className="min-h-0 flex-1 overflow-y-auto px-3 pt-3 pb-4">
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

        {/* 通訊入口（收合） */}
        <button
          onClick={() => {
            setComms(true)
            setCommsRead(true)
          }}
          className="mx-3 mb-2 flex min-h-11 shrink-0 items-center gap-2 border border-line/70 bg-surface px-3 text-[14px] text-fg-list"
        >
          <MessageSquare size={16} className="text-cyan" />
          <span className="flex-1 text-left">通訊・魔都 FM 104.9</span>
          {!commsRead && <span className="tech rounded-sm bg-red px-1 text-[12px] leading-5 text-bg">{COMMS_COUNT}</span>}
          <span className="text-muted">展開</span>
        </button>

        {/* 底部導覽：參考圖左側分類欄的手機版 */}
        <nav className="grid shrink-0 grid-cols-3 border-t border-line bg-surface pb-[env(safe-area-inset-bottom)]">
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
                <NeonIcon icon={Icon} size={20} on={on} />
                {n.label}
                {n.id === 'char' && c.alive && c.attrPoints > 0 && (
                  <span className="tech absolute top-1.5 right-[calc(50%-22px)] rounded-sm bg-red px-1 text-[11px] leading-4 text-bg" aria-label={`${c.attrPoints} 點屬性可分配`}>
                    {c.attrPoints}
                  </span>
                )}
              </button>
            )
          })}
        </nav>

        <Notices />
        {comms && <Comms onClose={() => setComms(false)} />}
        {claiming && <CompleteDialog game={game} />}
        {picking && <PickDialog game={game} />}
        {revealing && <LethalReveal key={g.run.reveal!.id} game={game} />}
      </div>
    </div>
  )
}
