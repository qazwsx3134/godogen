// 生涯主畫面：上方像素橫幅；下面依進度顯示街區地圖、節點、安全屋或生涯結束。
import { BedDouble, BookOpen, Briefcase, CircleHelp, Crown, Skull, Stethoscope, Store } from 'lucide-react'
import { CityStrip } from '../components/CityStrip'
import { ActionButton, NeonIcon, Panel } from '../components/ui'
import { type useGame, movable, nodeBusy } from '../game/state'
import { type MapNode, type NodeType, NODE_LABEL, findNode } from '../rules/map'
import { NodeView } from './Node'

type G = ReturnType<typeof useGame>

export const NODE_ICON: Record<NodeType, typeof Store> = {
  job: Briefcase,
  elite: Skull,
  event: CircleHelp,
  market: Store,
  clinic: Stethoscope,
  rest: BedDouble,
  story: BookOpen,
  boss: Crown,
}

export function RunScreen({ game }: { game: G }) {
  const { g } = game
  const { run, character: c } = g
  const here = run.at ? findNode(run.district, run.at) : undefined
  const mode = !c.alive ? 'dead' : nodeBusy(g) ? 'run' : 'rest'
  const label = !c.alive ? '空房間' : run.phase === 'safehouse' ? '安全屋' : here ? `${run.district.name}・${NODE_LABEL[here.type]}` : `${run.district.name}・出發前`
  return (
    <div className="space-y-3">
      <CityStrip mode={mode} label={label} sub={here ? `第 ${here.layer + 1} 層` : undefined} />
      {run.phase === 'over' ? <EndScreen game={game} /> : run.phase === 'safehouse' ? <Safehouse game={game} /> : run.node ? <NodeView game={game} /> : <MapView game={game} />}
    </div>
  )
}

const ROW = 68

function MapView({ game }: { game: G }) {
  const { g, act } = game
  const d = g.run.district
  const can = new Set(movable(g).map((n) => n.id))
  const visited = new Set(g.run.path)
  const pos = (n: MapNode) => ({ x: ((d.layers[n.layer].indexOf(n) + 0.5) / d.layers[n.layer].length) * 100, y: n.layer * ROW + ROW / 2 })
  const height = d.layers.length * ROW
  return (
    <Panel innerClass="p-3">
      <div className="mb-2 flex items-baseline gap-2">
        <b className="text-[17px] text-heading">{d.name}・街區地圖</b>
        <span className="ml-auto text-[13px] text-muted">{g.character.picks.length ? '先挑完三選一才能前進' : '選一個亮著的節點前進'}</span>
      </div>
      <div className="relative" style={{ height }}>
        <svg className="absolute inset-0 h-full w-full" viewBox={`0 0 100 ${height}`} preserveAspectRatio="none" aria-hidden>
          {d.layers.flat().flatMap((n) =>
            n.next.map((id) => {
              const a = pos(n)
              const b = pos(findNode(d, id)!)
              const walked = visited.has(n.id) && visited.has(id)
              return (
                <line
                  key={`${n.id}>${id}`}
                  x1={a.x}
                  y1={a.y}
                  x2={b.x}
                  y2={b.y}
                  stroke={walked ? 'var(--color-red)' : 'var(--color-line)'}
                  strokeOpacity={walked ? 1 : 0.45}
                  strokeWidth={walked ? 2.5 : 1.5}
                  vectorEffect="non-scaling-stroke"
                />
              )
            }),
          )}
        </svg>
        {d.layers.flat().map((n) => {
          const Icon = NODE_ICON[n.type]
          const p = pos(n)
          const on = can.has(n.id)
          const been = visited.has(n.id)
          const here = g.run.at === n.id
          const tone = n.type === 'elite' || n.type === 'boss' ? 'text-red' : n.type === 'story' ? 'text-warning' : 'text-cyan'
          return (
            <button
              key={n.id}
              disabled={!on}
              onClick={() => act({ t: 'move', nodeId: n.id })}
              aria-label={`${NODE_LABEL[n.type]}（第 ${n.layer + 1} 層）`}
              className="absolute flex w-16 -translate-x-1/2 -translate-y-1/2 flex-col items-center"
              style={{ left: `${p.x}%`, top: p.y }}
            >
              <span className={on ? 'map-pulse' : ''}>
                <span
                  className="cut cut-sm block size-10"
                  style={{
                    ['--edge' as string]: here ? 'var(--color-red)' : on ? 'var(--color-cyan)' : been ? 'color-mix(in srgb, var(--color-red) 60%, transparent)' : 'color-mix(in srgb, var(--color-line) 40%, transparent)',
                    ['--fill' as string]: here ? 'var(--color-red-bg)' : 'var(--color-bg)',
                  }}
                >
                  <span className={`cut-in grid place-items-center ${on || here ? tone : been ? 'text-red/70' : 'text-muted/50'}`}>
                    {on || here ? <NeonIcon icon={Icon} on={on} /> : <Icon size={18} strokeLinecap="square" strokeLinejoin="miter" />}
                  </span>
                </span>
              </span>
              <span className={`mt-0.5 text-[11px] leading-none whitespace-nowrap ${on ? 'font-bold text-heading' : 'text-muted/70'}`}>{NODE_LABEL[n.type]}</span>
            </button>
          )
        })}
      </div>
    </Panel>
  )
}

function Safehouse({ game }: { game: G }) {
  const { g, act } = game
  const c = g.character
  return (
    <Panel tone="strong" innerClass="p-4 space-y-3">
      <div className="text-[20px] font-bold text-cyan">安全屋</div>
      <p className="m-0 text-fg">
        新宿的事告一段落了。窗外的雨還沒停，灣岸那邊的封鎖線亮著紅燈。你可以在這裡收手，讓「{c.name}」留在魔都的傳說裡；或者繼續往下一個街區。
      </p>
      <div className="grid grid-cols-2 gap-2 text-[14px]">
        <div className="border border-line/60 p-2">名聲 <b className="tech text-heading">Lv.{c.fame.level}</b>（總 {c.fame.total}）</div>
        <div className="border border-line/60 p-2">卡牌 <b className="tech text-heading">{Object.values(c.perks).reduce((a, b) => a + b, 0)}</b> 張</div>
      </div>
      <ActionButton tone="primary" disabled={c.picks.length > 0} reason="先挑完三選一" onClick={() => act({ t: 'retire' })}>
        退休
      </ActionButton>
      <ActionButton disabled reason="灣岸街區還沒開放（這個版本只有新宿）">
        繼續：前往灣岸
      </ActionButton>
    </Panel>
  )
}

function EndScreen({ game }: { game: G }) {
  const { g, act } = game
  const l = g.meta.legends.at(-1)
  if (!l) return null
  const dead = l.end === 'dead'
  return (
    <Panel tone={dead ? 'red' : 'strong'} innerClass="p-4 space-y-2">
      <div className={`flex items-center gap-2 text-[20px] font-bold ${dead ? 'text-red' : 'text-cyan'}`}>
        {dead ? <Skull size={20} /> : <Crown size={20} />} {dead ? '生涯結束' : '退休'}：{l.name}
      </div>
      <p className="m-0 text-fg">{l.cause}</p>
      <div className="text-[14px] text-muted">
        Lv.{l.level}・名聲 Lv.{l.fame}（總 {l.fameTotal}）・{l.style ? `主流派：${l.style}` : '還沒有流派'}・{l.district}
      </div>
      <p className="m-0 text-[14px] text-muted">已寫進「紀錄 → 傳奇檔案」。這段生涯的存檔已經結束，不能讀檔回去。</p>
      <ActionButton tone="primary" onClick={() => act({ t: 'newCharacter' })}>
        建立新的傭兵
      </ActionButton>
    </Panel>
  )
}
