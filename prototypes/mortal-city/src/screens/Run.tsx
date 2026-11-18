// 生涯主畫面：上方像素橫幅；下面依進度顯示街區地圖、節點、安全屋或生涯結束。
import { ArrowUpRight, BedDouble, BookOpen, Briefcase, CircleHelp, Crown, Skull, Stethoscope, Store } from 'lucide-react'
import { CityStrip, NODE_BG, STORY_BG, type NodeBg } from '../components/CityStrip'
import { type ReactNode, useEffect, useMemo, useRef } from 'react'
import { ActionButton, Panel, useTwoStep } from '../components/ui'
import { type useGame, movable, nextDistrict, nodeJob } from '../game/state'
import { DISTRICTS } from '../content/districts'
import { type MapNode, type NodeType, NODE_LABEL, findNode } from '../rules/map'
import { BEATS, jobSolutions } from '../content/beats'
import { eliteRewardStyle } from '../content/data'
import { DIRECTION_LABEL, NEURAL_STAGE_LABEL, STYLE_LABEL, hashSeed, jobReward, jobPool, marginOf, neuralStage, poolSize, perkReward, rng } from '../rules/core'
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
  const onMap = c.alive && run.phase === 'map' && !n
  const scene = <CityStrip mode={mode} bg={bg} story={story} district={run.district.id} look={c.look} safehouse={safehouse} showLabel={!onMap} label={label} sub={here ? `第 ${here.layer + 1} 層` : undefined} />
  if (onMap) return <MapView game={game} scene={scene} />
  return (
    <div className="encounter-layout">
      <div className="encounter-scene">{scene}</div>
      <div className="encounter-content space-y-3">
        {run.phase === 'over' ? <EndScreen game={game} /> : safehouse ? <Safehouse game={game} /> : <NodeView game={game} />}
      </div>
    </div>
  )
}

const ROW = 76
const TOP_PAD = 20

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

/** 起點在下，沿連線往上走。地圖獨立捲動，保留下一步清單的位置。 */
function MapView({ game, scene }: { game: G; scene: ReactNode }) {
  const { g, act } = game
  const d = g.run.district
  const next = movable(g)
  const can = new Set(next.map((n) => n.id))
  const visited = new Set(g.run.path)
  const L = d.layers.length
  const pos = (n: MapNode) => ({ x: ((d.layers[n.layer].indexOf(n) + 0.5) / d.layers[n.layer].length) * 100, y: TOP_PAD + (L - 1 - n.layer) * ROW + ROW / 2 })
  const height = TOP_PAD + L * ROW
  const deco = useMemo(() => cityBlocks(g.run.seed, d.id, height), [g.run.seed, d.id, height])
  const here = g.run.at ? findNode(d, g.run.at) : undefined
  const mapScroll = useRef<HTMLDivElement>(null)
  const nextLayer = Math.min(L, (here?.layer ?? -1) + 2)
  useEffect(() => {
    const map = mapScroll.current
    if (map) map.scrollTop = TOP_PAD + (L - nextLayer) * ROW - map.clientHeight * 0.48
  }, [L, nextLayer])
  return (
    <div className="route-board">
      <div className="route-scene" data-enter>
        {scene}
        <div className="district-title">
          <h1>{d.name}</h1>
          <span className="tech">第 {nextLayer} / {L} 層</span>
        </div>
      </div>
      <section className="route-choices" aria-labelledby="next-routes">
        <div className="screen-heading">
          <h2 id="next-routes">下一步可以去</h2>
          <span className="tech text-muted">{next.length} 條路線</span>
        </div>
        {next.length > 0
          ? <NextList game={game} nodes={next} />
          : <p className="text-muted">{g.character.picks.length ? '先挑完三選一才能前進。' : '目前沒有可前往的節點。'}</p>}
      </section>
      <section className="holo-frame route-map" aria-labelledby="route-map-title">
        <div className="screen-heading px-1">
          <h2 id="route-map-title">街區地圖</h2>
          <span className="text-muted">往上看後續路線</span>
        </div>
        <div ref={mapScroll} className="holo-scroll" tabIndex={0} aria-label="可捲動的街區路線">
          <div className="holo-plane" style={{ height }}>
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
              const eliteJob = n.type === 'elite' ? nodeJob(g, n) : undefined
              const reward = eliteJob ? eliteRewardStyle(eliteJob, g.run.districtIndex) : undefined
              const isHere = g.run.at === n.id
              const tone = n.type === 'elite' || n.type === 'boss' ? 'var(--color-red)' : n.type === 'story' ? 'var(--color-warning)' : 'var(--color-cyan)'
              const color = isHere ? 'var(--color-red)' : on ? tone : been ? 'color-mix(in srgb, var(--color-red) 55%, transparent)' : 'color-mix(in srgb, var(--color-line) 45%, transparent)'
              return (
                <button
                  key={n.id}
                  disabled={!on}
                  onClick={() => act({ t: 'move', nodeId: n.id })}
                  aria-label={`${NODE_LABEL[n.type]}（第 ${n.layer + 1} 層）${reward ? `・保證${STYLE_LABEL[reward]}稀有裝備` : ''}`}
                  className={`holo-pin ${on ? 'holo-pin-on' : ''} ${isHere ? 'holo-pin-here' : ''}`}
                  style={{ left: `${p.x}%`, top: p.y, ['--pin' as string]: color }}
                >
                  {on && <span className="holo-beam" aria-hidden />}
                  {(on || isHere) && <span className="holo-ring" aria-hidden />}
                  <span className="holo-hex">
                    <span className="holo-hex-in" style={{ color: on || isHere ? tone : undefined }}>
                      <Icon size={17} aria-hidden />
                    </span>
                  </span>
                  <span className={`holo-label ${on ? 'holo-label-on' : ''}`}>{isHere ? '你在這裡' : reward ? `精英・${STYLE_LABEL[reward]}` : NODE_LABEL[n.type]}</span>
                </button>
              )
            })}
          </div>
        </div>
      </section>
    </div>
  )
}

/** 各神經階段的錯亂規則（短版，地圖用）。 */
const JOB_PSYCHO_SHORT: Record<ReturnType<typeof neuralStage>, string> = { stable: '', alert: '硬撐的壓力加重', critical: '硬撐後要擲錯亂骰', lost: '開場與每個場面先擲錯亂骰，可能中斷並致命' }

/** 地圖下方的「下一步」：每個能去的節點是什麼（委託的方向、難度、報酬、要不要打），點了就前往。 */
function NextList({ game, nodes }: { game: G; nodes: MapNode[] }) {
  const { g, act } = game
  const c = g.character
  return (
    <div className="route-list">
      {nodes.map((n) => {
        const job = nodeJob(g, n)
        const Icon = job ? DIR_ICON[job.direction] : NODE_ICON[n.type]
        const head = job ? `${NODE_LABEL[n.type]}・${DIRECTION_LABEL[job.direction]}・難度 ${job.tier}` : NODE_LABEL[n.type]
        const sub = !job
          ? NODE_HINT[n.type as keyof typeof NODE_HINT]
          : [
              n.type === 'elite' ? '⚔ 硬仗＋可能致命的抉擇・撐過去一定掉寶' : `${BEATS[job.direction].length} 個場面・第一場擲 ${Math.max(0, poolSize(jobPool(c, job, BEATS[job.direction][0].attr)))} 顆${job.direction === 'force' ? '・最後一定要打' : ''}`,
            ].join('・')
        const rewardStyle = job && n.type === 'elite' ? eliteRewardStyle(job, g.run.districtIndex) : undefined
        const solutions = job && n.type === 'job' ? jobSolutions(job.id, 0, c) : []
        const mission = n.type === 'job' || n.type === 'elite' || n.type === 'story' || n.type === 'boss'
        return (
          <button key={n.id} data-testid="next-node" onClick={() => act({ t: 'move', nodeId: n.id })} className="route-option" data-risk={n.type === 'elite' || n.type === 'boss' ? 'high' : undefined}>
            <div className="route-option-inner">
              <Icon size={18} className={`mt-0.5 shrink-0 ${n.type === 'elite' || n.type === 'boss' ? 'text-red' : 'text-cyan'}`} />
              <div className="min-w-0 flex-1">
                <div className="flex flex-wrap items-baseline justify-between gap-x-2">
                  <span className="route-option-title">{job?.name ?? head}</span>
                  {job && <span className="route-reward">¢{jobReward(job, perkReward(c, job.direction)).toLocaleString()}</span>}
                </div>
                <div className="text-[13px] text-muted">{job && <span>{head} · </span>}{sub}</div>
                {rewardStyle && <div className="text-[13px] text-warning">完成保證出現 1 件{STYLE_LABEL[rewardStyle]}稀有裝備</div>}
                {solutions.length > 0 && <div className="text-[13px] text-cyan">可用解法・{solutions.map((s) => s.label).join('／')}</div>}
                {mission && neuralStage(marginOf(c)) !== 'stable' && <div className="text-[13px] text-red">{`神經${NEURAL_STAGE_LABEL[neuralStage(marginOf(c))]}：${JOB_PSYCHO_SHORT[neuralStage(marginOf(c))]}`}</div>}
              </div>
              <ArrowUpRight size={17} className="route-arrow" aria-hidden />
            </div>
          </button>
        )
      })}
    </div>
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
