// 生涯主畫面：上方像素橫幅；下面依進度顯示街區地圖、節點、安全屋或生涯結束。
import { BedDouble, BookOpen, Briefcase, CircleHelp, Crown, Skull, Stethoscope, Store } from 'lucide-react'
import { CityStrip, NODE_BG, STORY_BG, type NodeBg } from '../components/CityStrip'
import { useEffect, useMemo, useRef } from 'react'
import { ActionButton, NeonIcon, Panel, useTwoStep } from '../components/ui'
import { type useGame, movable, nextDistrict, nodeJob } from '../game/state'
import { DISTRICTS } from '../content/districts'
import { type MapNode, type NodeType, NODE_LABEL, findNode } from '../rules/map'
import { DIRECTION_LABEL, dirBonus, hashSeed, jobReward, jobSuccessChance, pct, perkReward, psychoOdds, rng } from '../rules/core'
import { DIR_ICON, NodeView } from './Node'

type G = ReturnType<typeof useGame>

/** 「下一步」清單裡非委託節點的一句說明。 */
const NODE_HINT: Record<Exclude<NodeType, 'job' | 'elite'>, string> = {
  event: '2～3 個選項，至少一個不花錢、不看屬性',
  market: '買半價貨、救命保單，收贓',
  clinic: '縫傷口、半價義體',
  rest: '傷勢 −30% 或通緝 −2',
  story: '論壇委託：讀回覆、選做法，最後有危險抉擇',
  boss: '本區劇情大案：做完就到安全屋',
}

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
  // 橫幅：自動段在跑＝屋頂奔跑；站在有專屬背景的節點＝那張背景；劇情委託＝街景；安全屋＝安全屋背景；地圖＝公寓
  const n = run.node
  const running = (n && 'stage' in n && n.stage === 'auto') || (n?.kind === 'story' && g.story.stage === 'auto')
  const bg = n && here && (NODE_BG as readonly string[]).includes(here.type) ? (here.type as NodeBg) : undefined
  const story = n?.kind === 'story' && STORY_BG.includes(n.caseId) ? n.caseId : undefined
  const safehouse = c.alive && run.phase === 'safehouse'
  const mode = !c.alive ? 'dead' : running ? 'run' : bg || story || safehouse ? 'node' : n?.kind === 'story' ? 'run' : 'rest'
  const label = !c.alive ? '空房間' : run.phase === 'safehouse' ? '安全屋' : here ? `${run.district.name}・${NODE_LABEL[here.type]}` : `${run.district.name}・出發前`
  return (
    <div className="space-y-3">
      <CityStrip mode={mode} bg={bg} story={story} district={run.district.id} look={c.look} safehouse={safehouse} label={label} sub={here ? `第 ${here.layer + 1} 層` : undefined} />
      {run.phase === 'over' ? <EndScreen game={game} /> : run.phase === 'safehouse' ? <Safehouse game={game} /> : run.node ? <NodeView game={game} /> : <MapView game={game} />}
    </div>
  )
}

const ROW = 76
/** 投影桌面往後倒的角度與透視距離（和 styles.css 的 .holo-stage／.holo-plane 一起用）。 */
const TILT = 22
const PERSPECTIVE = 1000

/** 3D 變形不會縮小排版占的空間：算出倒下後實際看得到的高度，把上方多出來的空白收掉。 */
function tiltGap(height: number) {
  const a = (TILT * Math.PI) / 180
  const seen = (height * Math.cos(a) * PERSPECTIVE) / (PERSPECTIVE + height * Math.sin(a))
  return Math.max(0, height - seen)
}

/** 各街區地圖上浮著的地名（裝飾）。 */
const PLACE_NAMES: Record<string, string[]> = {
  shinjuku: ['歌舞伎町', '新宿駅', '西口', '三丁目', '大久保', '環狀線', '神坂本社', '思い出横丁'],
  wangan: ['新木場', '冷鏈堆場', '港務部', '貨運支線', '封鎖線', '第七倉', '海底隧道', '起重機群'],
}

/** 依地圖 seed 固定產生的街區輪廓與地名（只是背景，不影響路線）。 */
function cityBlocks(seed: number, district: string, height: number) {
  const r = rng(hashSeed(seed, 'blocks', district))
  const blocks = Array.from({ length: 46 }, () => ({ x: r() * 96, y: r() * height, w: 3 + r() * 12, h: 10 + r() * 46, tall: r() < 0.18 }))
  const names = (PLACE_NAMES[district] ?? []).map((name, i) => ({ name, x: 6 + r() * 70, y: ((i + 0.5) / 8) * height + (r() - 0.5) * 30 }))
  return { blocks, names }
}

/** 街區地圖：斜躺的全息投影桌面。起點在最下面（離你最近），劇情大案在最上方的地平線。 */
function MapView({ game }: { game: G }) {
  const { g, act } = game
  const d = g.run.district
  const next = movable(g)
  const can = new Set(next.map((n) => n.id))
  const visited = new Set(g.run.path)
  const L = d.layers.length
  const pos = (n: MapNode) => ({ x: ((d.layers[n.layer].indexOf(n) + 0.5) / d.layers[n.layer].length) * 100, y: (L - 1 - n.layer) * ROW + ROW / 2 })
  const height = L * ROW
  const deco = useMemo(() => cityBlocks(g.run.seed, d.id, height), [g.run.seed, d.id, height])
  const here = g.run.at ? findNode(d, g.run.at) : undefined
  const focus = useRef<HTMLButtonElement | null>(null)
  // 進地圖時把能前往的節點捲到畫面中間（地圖是從下往上走的）。
  // 延到下一輪：App 換分頁時會把主畫面捲回頂端，它的 effect 比子元件晚跑，會蓋掉這次捲動
  useEffect(() => {
    const id = setTimeout(() => focus.current?.scrollIntoView({ block: 'center', behavior: 'auto' }), 0)
    return () => clearTimeout(id)
  }, [g.run.at])
  const types = [...new Set(d.layers.flat().map((n) => n.type))]
  return (
    <>
      <div className="holo-frame">
        <div className="holo-hud">
          <span className="tech text-[12px] text-cyan">NETMAP://{d.id.toUpperCase()}</span>
          <span className="text-[15px] font-bold text-heading">{d.name}・街區地圖</span>
          <span className="tech ml-auto text-[12px] text-muted">
            LAYER {String((here?.layer ?? -1) + 2).padStart(2, '0')}/{L}
          </span>
        </div>
        <div className="holo-hint">
          {g.character.picks.length
            ? '先挑完三選一才能前進'
            : g.character.attrPoints > 0
              ? `還有 ${g.character.attrPoints} 點屬性：點下方「角色」分配`
              : '▼ 你在這裡・往上走，點亮著的節點前進'}
        </div>
        <div className="holo-stage" style={{ perspective: `${PERSPECTIVE}px`, marginTop: -tiltGap(height) + 4 }}>
          <div className="holo-plane" style={{ height, transform: `rotateX(${TILT}deg)` }}>
            <svg className="absolute inset-0 h-full w-full overflow-visible" aria-hidden>
              {deco.blocks.map((b, i) => (
                <rect key={i} x={`${b.x}%`} y={b.y} width={`${b.w}%`} height={b.h} className={b.tall ? 'holo-block holo-block-tall' : 'holo-block'} />
              ))}
              {d.layers.flat().flatMap((n) =>
                n.next.map((id) => {
                  const a = pos(n)
                  const b = pos(findNode(d, id)!)
                  const walked = visited.has(n.id) && visited.has(id)
                  const open = g.run.at === n.id && can.has(id)
                  return (
                    <line
                      key={`${n.id}>${id}`}
                      x1={`${a.x}%`}
                      y1={a.y}
                      x2={`${b.x}%`}
                      y2={b.y}
                      className={walked ? 'holo-road holo-road-walked' : open ? 'holo-road holo-road-open' : 'holo-road'}
                    />
                  )
                }),
              )}
            </svg>
            {deco.names.map((p) => (
              <span key={p.name} className="holo-place" style={{ left: `${p.x}%`, top: p.y }}>
                {p.name}
              </span>
            ))}
            {d.layers.flat().map((n) => {
              const Icon = NODE_ICON[n.type]
              const p = pos(n)
              const on = can.has(n.id)
              const been = visited.has(n.id)
              const isHere = g.run.at === n.id
              const tone = n.type === 'elite' || n.type === 'boss' ? 'var(--color-red)' : n.type === 'story' ? 'var(--color-warning)' : 'var(--color-cyan)'
              const color = isHere ? 'var(--color-red)' : on ? tone : been ? 'color-mix(in srgb, var(--color-red) 55%, transparent)' : 'color-mix(in srgb, var(--color-line) 45%, transparent)'
              return (
                <button
                  key={n.id}
                  ref={n.id === next[0]?.id ? focus : undefined}
                  disabled={!on}
                  onClick={() => act({ t: 'move', nodeId: n.id })}
                  aria-label={`${NODE_LABEL[n.type]}（第 ${n.layer + 1} 層）`}
                  className={`holo-pin ${on ? 'holo-pin-on' : ''} ${isHere ? 'holo-pin-here' : ''}`}
                  style={{ left: `${p.x}%`, top: p.y, ['--pin' as string]: color }}
                >
                  {on && <span className="holo-beam" aria-hidden />}
                  {(on || isHere) && <span className="holo-ring" aria-hidden />}
                  <span className="holo-hex">
                    <span className="holo-hex-in" style={{ color: on || isHere ? tone : undefined }}>
                      {on || isHere ? <NeonIcon icon={Icon} on={on} size={17} /> : <Icon size={16} strokeLinecap="square" strokeLinejoin="miter" />}
                    </span>
                  </span>
                  <span className={`holo-label ${on ? 'holo-label-on' : ''}`}>{isHere ? '你在這裡' : NODE_LABEL[n.type]}</span>
                </button>
              )
            })}
          </div>
        </div>
        <div className="holo-legend">
          {types.map((t) => {
            const Icon = NODE_ICON[t]
            return (
              <span key={t} className="flex items-center gap-1">
                <Icon size={12} /> {NODE_LABEL[t]}
              </span>
            )
          })}
        </div>
      </div>
      {next.length > 0 && <NextList game={game} nodes={next} />}
    </>
  )
}

/** 地圖下方的「下一步」：每個能去的節點是什麼（委託的方向、難度、報酬、要不要打），點了就前往。 */
function NextList({ game, nodes }: { game: G; nodes: MapNode[] }) {
  const { g, act } = game
  const c = g.character
  const psycho = psychoOdds(c).total
  return (
    <Panel innerClass="p-3 space-y-2">
      <div className="text-[15px] font-bold text-heading">下一步可以去</div>
      {nodes.map((n) => {
        const job = nodeJob(g, n)
        const Icon = job ? DIR_ICON[job.direction] : NODE_ICON[n.type]
        const head = job ? `${NODE_LABEL[n.type]}・${DIRECTION_LABEL[job.direction]}・難度 ${job.tier}` : NODE_LABEL[n.type]
        const sub = !job
          ? NODE_HINT[n.type as keyof typeof NODE_HINT]
          : [
              `「${job.name}」¢${jobReward(job, perkReward(c, job.direction))}`,
              n.type === 'elite' ? '⚔ 硬仗＋可能致命的抉擇・打贏一定掉寶' : job.direction === 'force' ? '⚔ 一定要打' : `安靜得手 ${pct(jobSuccessChance(job, dirBonus(c, job.direction)))}`,
            ].join('・')
        const mission = n.type === 'job' || n.type === 'elite' || n.type === 'story' || n.type === 'boss'
        return (
          <button key={n.id} data-testid="next-node" onClick={() => act({ t: 'move', nodeId: n.id })} className={`block w-full text-left cut cut-sm ${n.type === 'elite' || n.type === 'boss' ? 'cut-red' : ''}`}>
            <div className="cut-in flex min-h-12 items-start gap-3 p-2.5">
              <Icon size={18} className={`mt-0.5 shrink-0 ${n.type === 'elite' || n.type === 'boss' ? 'text-red' : 'text-cyan'}`} />
              <div className="min-w-0 flex-1">
                <div className="font-bold text-fg-list">{head}</div>
                <div className="text-[13px] text-muted">{sub}</div>
                {mission && psycho > 0 && <div className="text-[13px] text-red">神經錯亂 {pct(psycho)}</div>}
              </div>
            </div>
          </button>
        )
      })}
    </Panel>
  )
}

function Safehouse({ game }: { game: G }) {
  const { g, act } = game
  const c = g.character
  const next = nextDistrict(g)
  const confirm = useTwoStep()
  return (
    <Panel tone="strong" innerClass="p-4 space-y-3">
      <div className="text-[20px] font-bold text-cyan">安全屋</div>
      <p className="m-0 text-fg">
        {DISTRICTS[g.run.districtIndex].safehouse}你可以在這裡收手，讓「{c.name}」留在魔都的傳說裡；或者繼續往下一個街區。
      </p>
      <div className="grid grid-cols-2 gap-2 text-[14px]">
        <div className="border border-line/60 p-2">名聲 <b className="tech text-heading">Lv.{c.fame.level}</b>（總 {c.fame.total}）</div>
        <div className="border border-line/60 p-2">卡牌 <b className="tech text-heading">{Object.values(c.perks).reduce((a, b) => a + b, 0)}</b> 張</div>
      </div>
      <ActionButton tone="primary" disabled={c.picks.length > 0} reason="先挑完三選一" onClick={() => confirm.press('retire', () => act({ t: 'retire' }))}>
        {confirm.armed === 'retire' ? '再按一次確認退休（這段生涯就此結束）' : '退休'}
      </ActionButton>
      <ActionButton
        disabled={!next || c.picks.length > 0}
        reason={!next ? '下一個街區還沒開放（這個版本到灣岸為止）' : '先挑完三選一'}
        onClick={() => act({ t: 'continue' })}
      >
        {next ? `繼續：前往${next.name}` : '繼續：前往秋葉原'}
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
