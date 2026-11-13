import ENEMY_PORTRAITS from '../content/enemy_portraits.json'
// 節點畫面：委託、精英委託、事件、黑市、神機醫、休息、劇情委託。戰鬥與危險節點的元件共用。
import { useEffect, useRef, useState } from 'react'
import { AlertTriangle, ArrowLeft, BedDouble, Compass, Crosshair, Eye, FastForward, Flame, MessageSquare, ShieldPlus, Stethoscope, Store, Swords, Terminal } from 'lucide-react'
import { ActionButton, Avatar, Meter, Panel, Tag, useTwoStep } from '../components/ui'
import { ItemIcon } from '../components/ItemIcon'
import { FIXERS, JOBS, highDanger } from '../content/data'
import { CASE_BY_ID, type CaseOption, type Reply, type StoryCase, caseBody, caseReplies, caseThreat, optionLock } from '../content/cases'
import { EVENT_BY_ID } from '../content/events'
import { DISTRICTS, fixerIn } from '../content/districts'
import { buzz, reducedMotion } from '../components/haptics'
import { sfx } from '../components/sfx'
import { TypeLine } from '../components/Fx'
import { itemStyle, ITEMS, SHOP_IMPLANTS, clinicOrders, itemDesc, itemLock, marketPrice } from '../content/items'
import { type NodeRun, type ResultRow, type useGame, SAFE_STRESS, caseLethal, caseReward, eliteLethal, type LethalLog, eventLock, fightEnemy, jobEnemy, jobLines, type BeatLog } from '../game/state'
import { BEATS, type Beat, storyBeats } from '../content/beats'
import { DiceIntro, DiceRoll, IntroButton, useIntro, useRollDone } from '../components/dice'
import { findNode } from '../rules/map'
import {
  type DangerOption,
  type DangerOutcome,
  type Direction,
  type Enemy,
  type FightFx,
  type FightResult,
  type Item,
  type Tactic,
  ATTR_LABEL,
  CLINIC,
  DIRECTION_LABEL,
  REST,
  RETREAT_HP,
  SLOT_LABEL,
  attrLock,
  fightStats,
  hashSeed,
  heatEnemy,
  jobReward,
  jobPool,
  scenePool,
  eventPool,
  poolSize,
  costText,
  pushStress,
  CALMER,
  type Attr as AttrKey,
  psychoRuleText,
  NEURAL_STAGE_LABEL,
  neuralStage,
  POOL_RESULT_LABEL,
  type PoolResult,
  lethalPool,
  type PoolPart,
  DROP_INJURY,
  SCAR_ATTR,
  SEVERE_INJURY,
  marginOf,
  neuralRisk,
  neuralTag,
  pct,
  perkReward,
  sellValue,
  statMod,
  tacticsFor,
  hackPower,
  stealthPower,
  type Style,
  STYLE_LABEL,
  MAX_ITEM_LEVEL,
  UPGRADE_LOAD,
  upgradeCost,
  LIFELINES,
  LIFELINE_TIERS,
  lifelineOf,
  fameEdge,
  fameEnemy,
} from '../rules/core'

type G = ReturnType<typeof useGame>

export const DIR_ICON: Record<Direction, typeof Flame> = { force: Crosshair, hack: Terminal, stealth: Eye }
export const STYLE_ICON: Record<Style, typeof Flame> = { berserker: Flame, gunslinger: Crosshair, netrunner: Terminal, nomad: Compass }
/** 流派色：卡框、道具框、圖示。 */
export const STYLE_COLOR: Record<Style, string> = { berserker: '#ff6a3d', gunslinger: '#e7d34a', netrunner: '#38f3fa', nomad: '#e0a35a' }

export function BackBar({ onBack, label }: { onBack: () => void; label: string }) {
  return (
    <button onClick={onBack} className="flex min-h-11 items-center gap-1 text-[15px] text-cyan">
      <ArrowLeft size={18} /> {label}
    </button>
  )
}

/** 自動段的總長：10～30 秒，依行數。 */
export const autoMs = (lines: number, base = 2500) => Math.min(30_000, Math.max(10_000, lines * base))

/** 剛進節點的這段時間內不自動捲動：讓玩家先看到像素圖與標題，不要一進來就被捲到最下面。 */
let revealHoldUntil = 0
const REVEAL_HOLD_MS = 600

/** 放在會長出新訊息的地方底下：dep 一變（或剛出現時）就把這裡捲進畫面，玩家不用自己捲到底。 */
function Reveal({ dep }: { dep?: unknown }) {
  const ref = useRef<HTMLDivElement>(null)
  useEffect(() => {
    if (performance.now() < revealHoldUntil) return
    // 平滑捲動只在分頁看得見時才會動（背景分頁完全不捲），其他情況直接跳過去
    const smooth = document.visibilityState === 'visible' && !reducedMotion()
    ref.current?.scrollIntoView({ block: 'nearest', behavior: smooth ? 'smooth' : 'auto' })
  }, [dep])
  return <div ref={ref} aria-hidden className="h-0" />
}

/** 結算：一列一個欄位。 */
function ResultRows({ title, text, rows }: { title: string; text?: string; rows?: ResultRow[] }) {
  const tone = { good: 'text-positive', bad: 'text-red', warn: 'text-warning' }
  return (
    <Panel tone="strong" innerClass="p-4">
      <div className="text-[18px] font-bold text-cyan">{title}</div>
      {text && <p className="mt-1 mb-0 text-fg">{text}</p>}
      {rows && rows.length > 0 && (
        <dl className="mt-2 mb-0 divide-y divide-line/40 border-y border-line/40">
          {rows.map((r) => (
            <div key={r.label} className="flex gap-3 py-1.5 text-[15px]">
              <dt className="w-20 shrink-0 text-muted">{r.label}</dt>
              <dd className={`m-0 flex-1 font-bold ${r.tone ? tone[r.tone] : 'text-heading'}`}>{r.value}</dd>
            </div>
          ))}
        </dl>
      )}
      <Reveal />
    </Panel>
  )
}

export function NodeView({ game }: { game: G }) {
  const { g } = game
  const n = g.run.node!
  // 換了節點：在子元件的捲動 effect 跑之前先擋住（effect 是子先父後，所以在 render 時設）
  const entered = useRef<string | null>(null)
  if (entered.current !== n.nodeId) {
    entered.current = n.nodeId
    revealHoldUntil = performance.now() + REVEAL_HOLD_MS
  }
  return (
    <div className="space-y-3">
      {n.kind === 'job' && <JobNode game={game} n={n} />}
      {n.kind === 'elite' && <EliteNode game={game} n={n} />}
      {n.kind === 'event' && <EventNode game={game} n={n} />}
      {n.kind === 'market' && <MarketNode game={game} n={n} />}
      {n.kind === 'clinic' && <ClinicNode game={game} n={n} />}
      {n.kind === 'rest' && <RestNode game={game} n={n} />}
      {n.kind === 'story' && <CaseThread game={game} sc={CASE_BY_ID[n.caseId]} />}
      <LeaveButton game={game} />
    </div>
  )
}

function LeaveButton({ game }: { game: G }) {
  const { g, act } = game
  const n = g.run.node!
  const busy = n.kind === 'story' ? g.story.caseId !== null : 'stage' in n && n.stage !== 'done'
  if (busy || !g.character.alive) return null
  const boss = n.kind === 'story' && findNode(g.run.district, n.nodeId)?.type === 'boss'
  return (
    <>
      <ActionButton tone="primary" onClick={() => act({ t: 'leave' })}>
        {boss ? '前往安全屋' : '離開，回到地圖'}
      </ActionButton>
      <Reveal />
    </>
  )
}

/** 節點標題卡。 */
function NodeHead({ tone = 'line', tag, title, fixer, body }: { tone?: 'line' | 'red'; tag: string; title: string; fixer?: string; body: string }) {
  return (
    <Panel tone={tone} innerClass="p-4">
      <div className={`text-[13px] ${tone === 'red' ? 'text-red' : 'text-muted'}`}>{tag}</div>
      <h1 className="my-1 text-[22px] leading-snug font-bold text-heading">{title}</h1>
      <div className="flex items-start gap-3">
        {fixer && <Avatar id={fixer} size={48} />}
        <p className="m-0 flex-1 whitespace-pre-line text-fg">{body}</p>
      </div>
    </Panel>
  )
}

/** 神經餘裕低於 40：標出神經階段（規則寫在擲骰與危險節點的畫面上）。 */
export function PsychoTag({ c }: { c: G['g']['character'] }) {
  if (!neuralRisk(c)) return null
  return <Tag tone="red">{neuralTag(c)}：任務裡要注意錯亂</Tag>
}

/** 一般委託的錯亂規則（骰池版）：穩定時不顯示。 */
function PsychoRules({ game }: { game: G }) {
  const c = game.g.character
  const t = psychoRuleText(c)
  if (!t.length) return null
  return (
    <div className="border border-red/60 p-2 text-[13px] text-red">
      <div className="font-bold">神經{NEURAL_STAGE_LABEL[neuralStage(marginOf(c))]}（餘裕 {marginOf(c)}）</div>
      {t.map((x) => (
        <div key={x}>・{x}</div>
      ))}
      {c.calmers ? <CalmerButton game={game} /> : null}
    </div>
  )
}

/** 打一劑鎮定劑（身上有才出現）。 */
export function CalmerButton({ game }: { game: G }) {
  const c = game.g.character
  return (
    <button data-testid="use-calmer" disabled={!c.stress} onClick={() => game.act({ t: 'useCalmer' })} className="mt-2 flex min-h-11 w-full items-center justify-between gap-2 border border-cyan/70 px-3 text-left text-cyan disabled:opacity-50">
      <span className="font-bold">打一劑鎮定劑</span>
      <span className="text-[13px]">
        神經壓力 −{CALMER.stress}・剩 {c.calmers ?? 0} 劑
      </span>
    </button>
  )
}

// ---------- 委託 ----------

const RESULT_TONE: Record<PoolResult, string> = { crit: 'text-positive', clean: 'text-positive', cost: 'text-warning', fail: 'text-red' }

/** 一個場面那次擲骰的動畫 key（錯亂中斷的那把在全螢幕揭曉播，不在這裡）。 */
const beatKey = (keyBase: string, h: BeatLog | undefined) => (h && h.broke !== 'abort' ? `${keyBase}:${h.beat}:${h.dice.join('')}` : undefined)

/** 已經擲過的場面。keyBase 讓同一次擲骰只播一次動畫（剛擲的那個場面在這裡播）。 */
function BeatHistory({ beats, history, keyBase }: { beats: Beat[]; history: BeatLog[]; keyBase: string }) {
  if (!history.length) return null
  return (
    <div className="space-y-2">
      {history.map((h) => {
        const b = beats[h.beat]
        return (
          <div key={h.beat} className="border border-line/60 p-3">
            <div className="mb-1.5 flex flex-wrap items-center gap-2">
              <span className="font-bold text-cyan">{b.title}</span>
              {h.broke === 'abort' && <span className="text-[13px] text-red">錯亂・致命判定</span>}
            </div>
            <DiceRoll dice={h.dice} best={h.best} result={h.result} psycho={h.psycho} rollKey={beatKey(keyBase, h)}>
              <div className={`mt-1.5 font-bold ${RESULT_TONE[h.result]}`}>{h.broke === 'fail' ? '失敗（錯亂）' : POOL_RESULT_LABEL[h.result]}</div>
              {h.psycho?.length ? (
                <p className="m-0 mt-1 text-[13px] text-[#b06cff]">
                  錯亂骰 {h.psycho.join('、')}
                  {h.broke === 'fail' ? '：手不聽使喚，這個場面失敗' : h.broke === 'abort' ? '：眼前一黑，任務中斷' : '：撐住了'}
                </p>
              ) : null}
              {h.broke !== 'abort' && <p className="m-0 mt-1 text-[14px] text-fg">{b.out[h.result]}</p>}
              {h.cost && <p className="m-0 mt-1 text-[13px] text-warning">代價：{h.cost}</p>}
            </DiceRoll>
          </div>
        )
      })}
    </div>
  )
}

/** 擲之前的加骰：硬撐（神經壓力）、鋌而走險（通緝，滿了不能選）。 */
function BoostToggles({ c, push, setPush, gamble, setGamble }: { c: G['g']['character']; push: boolean; setPush: (v: boolean) => void; gamble: boolean; setGamble: (v: boolean) => void }) {
  const toggle = (on: boolean, set: (v: boolean) => void, title: string, note: string, disabled = false) => (
    <button disabled={disabled} onClick={() => set(!on)} className={`block w-full text-left ${on ? 'cut cut-sm cut-red' : 'cut cut-sm'} ${disabled ? 'opacity-50' : ''}`}>
      <div className="cut-in flex min-h-12 items-center justify-between gap-3 p-3">
        <span className={on ? 'font-bold text-red' : 'text-fg'}>{on ? '✓ ' : ''}{title}</span>
        <span className="text-[13px] text-muted">{note}</span>
      </div>
    </button>
  )
  return (
    <>
      {toggle(push, setPush, '硬撐：多擲 1 顆', `神經壓力 +${pushStress(c)}`)}
      {toggle(gamble && c.heat < 5, setGamble, '鋌而走險：多擲 1 顆', c.heat >= 5 ? '通緝已經滿了' : '通緝 +1', c.heat >= 5)}
    </>
  )
}

/** 骰池的組成：「沉著 5 +3 顆、難度 3 −1 顆」。 */
function PoolParts({ parts }: { parts: PoolPart[] }) {
  return (
    <div className="text-[14px] text-muted">
      {parts.map((p, i) => (
        <span key={i}>
          {i ? '、' : ''}
          {p.label} <b className={`tech ${p.n < 0 ? 'text-red' : 'text-heading'}`}>{p.n > 0 ? `+${p.n}` : p.n} 顆</b>
        </span>
      ))}
    </div>
  )
}

const rollLabel = (size: number) => (size <= 0 ? '擲 2 顆（取低的）' : `擲 ${Math.min(6, size)} 顆`)

/** 一個場面：情境、骰池組成、加骰、擲骰鈕。 */
function ScenePanel({ game, beats, at, parts, onRoll }: { game: G; beats: Beat[]; at: number; parts: PoolPart[]; onRoll: (push: boolean, gamble: boolean) => void }) {
  const c = game.g.character
  const intro = useIntro(!!game.g.meta.seen.dice, () => game.act({ t: 'seenIntro', key: 'dice' }))
  const beat = beats[Math.min(at, beats.length - 1)]
  const [push, setPush] = useState(false)
  const [gamble, setGamble] = useState(false)
  const size = poolSize(parts, (push ? 1 : 0) + (gamble && c.heat < 5 ? 1 : 0))
  const roll = () => {
    sfx.click()
    onRoll(push, gamble && c.heat < 5)
    setPush(false)
    setGamble(false)
  }
  return (
    <Panel tone="strong" innerClass="p-4 space-y-3">
      {intro.open && <DiceIntro kind="dice" onClose={intro.close} />}
      <div className="flex items-center justify-between gap-2">
        <span className="text-[13px] text-muted">
          場面 {at + 1}／{beats.length}
        </span>
        <IntroButton onClick={intro.show} />
      </div>
      <div className="text-[18px] font-bold text-cyan">{beat.title}</div>
      <p className="m-0 text-fg">{beat.setup}</p>
      <PoolParts parts={parts} />
      <p className="m-0 text-[13px] text-muted">只看最高那顆：6 乾淨成功、4～5 成功但付代價、1～3 失敗；兩顆 6 是大成功。{size <= 0 ? '你一顆骰都沒有：擲兩顆取低的。' : ''}</p>
      <BoostToggles c={c} push={push} setPush={setPush} gamble={gamble} setGamble={setGamble} />
      <ActionButton tone="primary" className="w-full" testId="beat-roll" onClick={roll}>
        {rollLabel(size)}
      </ActionButton>
    </Panel>
  )
}

/** 場面擲出 4～5：選一個代價。 */
function SceneCostPanel({ c, beats, at, last, base, keyBase, onPick }: { c: G['g']['character']; beats: Beat[]; at: number; last: BeatLog; base: { injury: number }; keyBase: string; onPick: (i: number) => void }) {
  const beat = beats[Math.min(at, beats.length - 1)]
  return (
    <Panel tone="strong" innerClass="p-4 space-y-3">
      <div className="text-[13px] text-muted">
        場面 {at + 1}／{beats.length}・{beat.title}
      </div>
      <DiceRoll dice={last.dice} best={last.best} result={last.result} psycho={last.psycho} rollKey={beatKey(keyBase, last)}>
        <div className="mt-1.5 font-bold text-warning">{POOL_RESULT_LABEL.cost}</div>
        {last.psycho?.length ? <p className="m-0 text-[13px] text-[#b06cff]">錯亂骰 {last.psycho.join('、')}：撐住了</p> : null}
        <p className="m-0 mt-2 mb-2 text-fg">{beat.out.cost} 選一個代價：</p>
        <div className="space-y-2">
          {beat.costs.map((o, i) => {
            const k = o.kind === 'heat' && c.heat >= 5 ? 'stress' : o.kind
            return (
              <button key={i} data-testid="beat-cost" onClick={() => onPick(i)} className="block w-full text-left cut cut-sm">
                <div className="cut-in flex min-h-12 items-center justify-between gap-3 p-3">
                  <span className="text-fg">{o.text}</span>
                  <span className="shrink-0 text-[13px] text-warning">{costText(base, k)}</span>
                </div>
              </button>
            )
          })}
        </div>
      </DiceRoll>
    </Panel>
  )
}

function JobNode({ game, n }: { game: G; n: Extract<NodeRun, { kind: 'job' }> }) {
  const { g, act } = game
  const c = g.character
  const job = JOBS[n.jobId]
  const lines = jobLines(n.jobId)
  const beats = BEATS[job.direction]
  const at = n.beat ?? 0
  const beat = beats[Math.min(at, beats.length - 1)]
  // 剛擲的骰還在跳：下一個場面、戰鬥、結算等它播完才出現
  const rolled = useRollDone(n.stage === 'cost' ? undefined : beatKey(`${c.id}:${n.nodeId}`, n.history?.at(-1)))
  return (
    <>
      <NodeHead tag={`委託・${DIRECTION_LABEL[job.direction]}・難度 ${job.tier}`} title={job.name} fixer={fixerIn(DISTRICTS[g.run.districtIndex], job.fixerId)} body={job.blurb} />
      <div className="flex flex-wrap gap-2">
        <Tag>報酬 ¢{jobReward(job, perkReward(c, job.direction))}</Tag>
        <Tag>{beats.length} 個場面{job.direction === 'force' ? '・最後一定要打' : '・失敗兩次要打一場'}</Tag>
        <Tag tone="warning">壓力 +{job.stress}</Tag>
        <Tag>完成時掉寶 {pct(0.1 * job.tier * (1 + statMod(c, 'loot')))}</Tag>
      </div>
      {n.stage === 'auto' && <AutoRun lines={lines} total={autoMs(lines.length)} fast={!!g.meta.seen.job} onDone={() => act({ t: 'jobAutoDone' })} />}
      {n.stage !== 'done' && <PsychoRules game={game} />}
      {n.stage !== 'auto' && <BeatHistory beats={beats} keyBase={`${c.id}:${n.nodeId}`} history={n.stage === 'cost' ? (n.history ?? []).slice(0, -1) : (n.history ?? [])} />}
      {rolled && n.stage === 'scene' && <ScenePanel key={at} game={game} beats={beats} at={at} parts={jobPool(c, job, beat.attr)} onRoll={(push, gamble) => act({ t: 'jobRoll', push, gamble })} />}
      {n.stage === 'cost' && n.history?.length ? <SceneCostPanel c={c} beats={beats} at={at} last={n.history[n.history.length - 1]} base={job} keyBase={`${c.id}:${n.nodeId}`} onPick={(i) => act({ t: 'jobCost', index: i })} /> : null}
      {rolled && n.stage === 'fight' && !n.fight && job.direction !== 'force' && <p className="m-0 text-red">你失手兩次，被逮個正著。只能打出去。</p>}
      {rolled && n.stage === 'fight' && !n.fight && <TacticPicker game={game} enemy={heatEnemy(jobEnemy(job, n), c.heat)} onPick={(t) => act({ t: 'jobFight', tactic: t })} />}
      {n.stage === 'fight' && n.fight && <FightRun fight={n.fight} onDone={() => act({ t: 'jobFightDone' })} />}
      {rolled && n.stage === 'done' && <ResultRows title="結算" text={n.text} rows={n.rows} />}
    </>
  )
}

// ---------- 精英委託 ----------

function EliteNode({ game, n }: { game: G; n: Extract<NodeRun, { kind: 'elite' }> }) {
  const { g, act } = game
  const c = g.character
  const job = JOBS[n.jobId]
  const t = highDanger(job)
  return (
    <>
      <NodeHead tone="red" tag={`精英委託・${DIRECTION_LABEL[job.direction]}・撐過去一定掉寶`} title={job.name} fixer={fixerIn(DISTRICTS[g.run.districtIndex], job.fixerId)} body={job.blurb} />
      {n.stage === 'auto' && (
        <div className="flex flex-wrap gap-2">
          <PsychoTag c={c} />
        </div>
      )}
      {n.stage === 'auto' && <AutoRun lines={t.autoLog} total={15_000} fast={!!g.meta.seen.elite} onDone={() => act({ t: 'eliteAutoDone' })} />}
      {n.stage === 'fight' && !n.fight && <TacticPicker game={game} enemy={heatEnemy(fameEnemy(t.fight, c.fame.level), c.heat)} fameEdge={fameEdge(c.fame.level)} onPick={(x) => act({ t: 'eliteFight', tactic: x })} />}
      {n.stage === 'fight' && n.fight && <FightRun fight={n.fight} onDone={() => act({ t: 'eliteFightDone' })} />}
      {n.stage === 'danger' && (
        <RiskDecision
          game={game}
          title={t.title}
          body={t.body}
          options={t.options}
          locks={Object.fromEntries(t.options.map((o) => [o.id, attrLock(c, o.attrNeeds) ?? '']).filter(([, v]) => v))}
          notes={Object.fromEntries(
            t.options.filter((o) => o.attrNeeds).map((o) => [o.id, `屬性選項：${ATTR_LABEL[o.attrNeeds!.attr]} ≥ ${o.attrNeeds!.min}，多擲 2 顆・代價：報酬七五折、名聲減半、神經壓力 +${SAFE_STRESS}`]),
          )}
          safeNote="沒有報酬、沒有戰利品"
          poolOf={(o) => lethalPool(c, eliteLethal(job, o))}
          threat={t.threat?.name}
          onConfirm={(id, push, gamble) => act({ t: 'eliteChoose', optionId: id, push, gamble })}
        />
      )}
      {n.stage === 'cost' && n.lethal && <LethalCostPick c={c} lethal={n.lethal} direction={job.direction} dropNote="沒有報酬，也沒有戰利品" onPick={(choice) => act({ t: 'lethalCost', choice })} />}
      {n.stage === 'chase' && t.threat && (
        <ChaseFight game={game} enemy={fameEnemy(t.threat, c.fame.level)} fight={n.chase} lethal={n.lethal} onPick={(x) => act({ t: 'chaseFight', tactic: x })} onDone={() => act({ t: 'chaseDone' })} />
      )}
      {n.stage === 'done' && n.outcome && <Result outcome={n.outcome} doneTitle="完成精英委託" safeTitle={n.fight && !n.fight.won ? '被打退・撤離' : n.lethal ? '丟下一切・撤離' : undefined} />}
    </>
  )
}

// ---------- 事件 ----------

function EventNode({ game, n }: { game: G; n: Extract<NodeRun, { kind: 'event' }> }) {
  const { g, act } = game
  const ev = EVENT_BY_ID[n.eventId]
  return (
    <>
      <NodeHead tag="事件" title={ev.title} body={ev.body} />
      {n.stage === 'choose' ? (
        <Panel innerClass="p-3 space-y-2">
          {ev.options.map((o) => {
            const lock = eventLock(g.character, o)
            const dice = o.check ? poolSize(eventPool(g.character, o.check)) : 0
            const note = [
              o.cost ? `¢${o.cost}` : '',
              o.needs ? `${ATTR_LABEL[o.needs.attr]} ≥ ${o.needs.min}` : '',
              o.fame ? `名聲 Lv.${o.fame}` : '',
              o.check ? `${rollLabel(dice)}（${o.check.attr ? ATTR_LABEL[o.check.attr] : '純靠運氣'}）・1～3 失敗、4～5 成功但付點代價` : '',
            ]
              .filter(Boolean)
              .join('・')
            return (
              <button key={o.id} data-testid="event-option" disabled={!!lock} onClick={() => act({ t: 'eventChoose', optionId: o.id })} className={`block w-full text-left cut cut-sm ${lock ? 'opacity-50' : ''}`}>
                <div className="cut-in min-h-12 p-3">
                  <div className="font-bold text-fg-list">{o.label}</div>
                  {note && <div className="text-[13px] text-cyan">{note}</div>}
                  {lock && <div className="text-[13px] text-warning">✖ {lock}</div>}
                </div>
              </button>
            )
          })}
        </Panel>
      ) : n.roll ? (
        <Panel tone="strong" innerClass="p-4 space-y-2">
          <div className="text-[13px] text-muted">判定</div>
          <DiceRoll dice={n.roll.dice} best={n.roll.best} result={n.roll.result} rollKey={`${g.character.id}:${n.nodeId}:event`}>
            <div className={`mt-1.5 font-bold ${RESULT_TONE[n.roll.result]}`}>{POOL_RESULT_LABEL[n.roll.result]}</div>
            <div className="mt-3">
              <ResultRows title="結果" text={n.text} rows={n.rows} />
            </div>
          </DiceRoll>
        </Panel>
      ) : (
        <ResultRows title="結果" text={n.text} rows={n.rows} />
      )}
    </>
  )
}

// ---------- 黑市、神機醫、休息 ----------

function ItemLine({ item }: { item: Item }) {
  return (
    <>
    <ItemIcon item={item} />
    <div className="min-w-0 flex-1">
      <b className="text-fg-list">{item.name}</b>
      <span className="ml-2 text-[13px] text-muted">{SLOT_LABEL[item.slot]}・{itemStyle(item) ? STYLE_LABEL[itemStyle(item)!] : DIRECTION_LABEL[item.direction]}</span>
      <div className="text-[13px] text-cyan">
        {[itemDesc(item), item.bonus ? `${DIRECTION_LABEL[item.direction]}委託 +${Math.round(item.bonus * 100)}%` : '', item.load ? `負荷 ${item.load}` : ''].filter(Boolean).filter((t, i, xs) => xs.indexOf(t) === i).join('・')}
      </div>
    </div>
    </>
  )
}

function Buy({ children, disabled, onClick }: { children: React.ReactNode; disabled?: boolean; onClick: () => void }) {
  return (
    <button onClick={onClick} disabled={disabled} className={`min-h-11 shrink-0 border px-3 text-[14px] font-bold ${disabled ? 'border-line/50 text-muted' : 'border-cyan text-cyan'}`}>
      {children}
    </button>
  )
}

/** 黑市貨的來路（依道具 id 固定挑一句）。 */
const PROVENANCE = [
  '序號被磨掉了',
  '上面還貼著 MPD 的證物標籤',
  '握把上刻著別人的名字',
  '保固貼紙寫著「九頭龍重工・內部使用」',
  '還沾著一點沒擦乾淨的血',
  '攤主說原主人不會回來拿了',
  '包裝上印著「樣品・非賣品」',
  '據說是「從卡車上掉下來的」',
]
const provenance = (id: string) => PROVENANCE[hashSeed(id) % PROVENANCE.length]

function MarketNode({ game, n }: { game: G; n: Extract<NodeRun, { kind: 'market' }> }) {
  const { g, act } = game
  const c = g.character
  const confirm = useTwoStep()
  return (
    <>
      <NodeHead tag="黑市" title="高架橋下的地攤" body="帆布一掀，底下全是還帶著體溫的貨。攤主的義眼一直盯著你的錢包：「來路？別問，問了就漲價。」" />
      <div className="flex justify-center">
        <span className="stolen-sign">全部七五折・不問來路・概不退換</span>
      </div>
      <Panel innerClass="pb-1">
        <div className="flex items-center gap-2 px-3 pt-3 font-bold text-heading">
          <Store size={16} className="text-cyan" /> 今晚的貨
        </div>
        {n.stock.length === 0 && <p className="m-0 px-3 py-2 text-muted">賣光了。攤主已經在收帆布。</p>}
        {n.stock.map((it, i) => {
          const price = marketPrice(it.price)
          return (
            <div key={it.id} className="relative border-b border-line/40 px-3 py-3">
              <div className="flex items-start gap-2">
                <ItemLine item={it} />
                <span className="stolen-tag" aria-label={`售價 ${price}`}>
                  ¢{price}
                  <s className="ml-1 text-[11px] opacity-70">{it.price}</s>
                </span>
              </div>
              <div className="mt-1 flex items-center gap-2">
                <span className="stolen-stamp">PROBABLY STOLEN</span>
                <span className="text-[13px] text-muted">{provenance(it.id)}</span>
              </div>
              <div className="mt-2">
                <Buy disabled={c.credits < price} onClick={() => act({ t: 'marketBuy', index: i })}>
                  {c.credits < price ? `還差 ¢${price - c.credits}` : '成交'}
                </Buy>
              </div>
            </div>
          )
        })}
        <div className="flex items-center gap-2 border-b border-line/40 px-3 py-2">
          <div className="min-w-0 flex-1">
            <b className="text-fg-list">鎮定劑</b>
            <div className="text-[13px] text-cyan">
              隨時能打，擲骰前也行：神經壓力 −{CALMER.stress}。最多帶 {CALMER.max} 劑，你身上 {c.calmers ?? 0} 劑
            </div>
          </div>
          <Buy disabled={(c.calmers ?? 0) >= CALMER.max || c.credits < CALMER.price} onClick={() => act({ t: 'buyCalmer' })}>
            ¢{CALMER.price}
          </Buy>
        </div>
        <div className="px-3 pt-3 text-[13px] text-muted">
          救命保單（空白，某架醫療飛行器上「掉」下來的）：受致命傷時武裝醫療隊救你一次，然後就用掉。最多一張
          {lifelineOf(c) ? `，你身上已經有一張${LIFELINES[lifelineOf(c)!].label}` : ''}。
        </div>
        {LIFELINE_TIERS.map((tier) => {
          const t = LIFELINES[tier]
          return (
            <div key={tier} className="flex items-center gap-2 border-b border-line/40 px-3 py-2">
              <div className="min-w-0 flex-1">
                <b className="text-fg-list">
                  <ShieldPlus size={14} className="mr-1 inline text-positive" />
                  {t.label}
                </b>
                <div className="text-[13px] text-cyan">救回來：{t.desc}</div>
              </div>
              <Buy disabled={c.lifelines > 0 || c.credits < t.price} onClick={() => act({ t: 'buyLifeline', tier })}>
                ¢{t.price}
              </Buy>
            </div>
          )
        })}
      </Panel>
      {c.stash.length + c.equipment.length > 0 && (
        <Panel innerClass="pb-1">
          <div className="px-3 pt-3 font-bold text-heading">收貨（售價四折）</div>
          <div className="px-3 text-[13px] text-muted">「我收，但我不問。你也別問我賣給誰。身上的義體？躺下，我現在就幫你拆。」</div>
          {[...c.equipment.map((it) => ({ it, worn: true })), ...c.stash.map((it) => ({ it, worn: false }))].map(({ it, worn }) => (
            <div key={it.id} className="flex items-center gap-2 border-b border-line/40 px-3 py-2">
              {worn && <span className="shrink-0 border border-warning px-1 text-[12px] text-warning">身上</span>}
              <ItemLine item={it} />
              <Buy onClick={() => confirm.press(it.id, () => act({ t: 'sell', itemId: it.id }))}>{confirm.armed === it.id ? '確定賣？' : `賣 ¢${sellValue(it)}`}</Buy>
            </div>
          ))}
        </Panel>
      )}
    </>
  )
}

function ClinicNode({ game, n }: { game: G; n: Extract<NodeRun, { kind: 'clinic' }> }) {
  const { g, act } = game
  const c = g.character
  const cost = c.injury * CLINIC.perPoint
  const margin = marginOf(c)
  const orders = clinicOrders(hashSeed(c.id, n.nodeId, 'orders'))
  const doc = DISTRICTS[g.run.districtIndex].doctor
  const upgradable = c.equipment.filter((i) => i.slot === 'implant')
  /** 一列可買的義體：裝上後的神經餘裕；屬性不夠也能買（先放背包）。 */
  const row = (kind: string, price: number) => {
    const d = ITEMS[kind]
    const item = { ...d, id: kind, kind }
    const lock = itemLock(c, item)
    const fitted = { ...c, implantLoad: c.implantLoad + d.load }
    const risk = neuralRisk(fitted)
    return (
      <div key={kind} className="flex items-center gap-2 border-b border-line/40 px-3 py-2">
        <ItemIcon item={item} />
        <div className="min-w-0 flex-1">
          <b className="text-fg-list">{d.name}</b>
          <div className="text-[13px] text-cyan">{d.desc}</div>
          {lock ? (
            <div className="text-[13px] text-warning">{lock}：買了先放背包，屬性夠了再裝</div>
          ) : (
            <div className={`text-[13px] ${risk ? 'text-warning' : 'text-muted'}`}>
              負荷 {d.load}・裝上後神經餘裕 {marginOf(fitted)}
              {risk ? `・${neuralTag(fitted)}` : ''}
            </div>
          )}
        </div>
        <Buy disabled={c.credits < price} onClick={() => act({ t: 'buyImplant', kind })}>
          ¢{price}
        </Buy>
      </div>
    )
  }
  return (
    <>
      <NodeHead tag="神機醫" title={`${FIXERS[doc.id].name}的義體診所`} fixer={doc.id} body={doc.line} />
      <ActionButton disabled={c.injury === 0 || c.credits < cost} reason={c.injury === 0 ? '沒有傷' : `需要 ¢${cost}`} onClick={() => act({ t: 'treat' })}>
        <Stethoscope size={16} /> 縫好傷口（傷勢 {c.injury}%・¢{cost}・壓力 −{CLINIC.stress}）
      </ActionButton>
      <ActionButton
        disabled={!!n.tuned || c.stress === 0 || c.credits < CLINIC.tunePrice}
        reason={n.tuned ? '這次已經調校過了' : c.stress === 0 ? '神經壓力已經是 0' : `需要 ¢${CLINIC.tunePrice}`}
        onClick={() => act({ t: 'tune' })}
      >
        神經調校（¢{CLINIC.tunePrice}・壓力 −{CLINIC.tune}，每次來一次）
      </ActionButton>
      {c.scars && Object.values(c.scars).some(Boolean) && (
        <Panel innerClass="pb-1">
          <div className="px-3 pt-3 font-bold text-heading">治療舊傷</div>
          <div className="px-3 text-[13px] text-muted">重傷或被保單救回留下的舊傷：每修好一道，恢復 1 點屬性。</div>
          {(Object.entries(c.scars) as [AttrKey, number][])
            .filter(([, k]) => k > 0)
            .map(([a, k]) => (
              <div key={a} className="flex items-center gap-2 border-b border-line/40 px-3 py-2">
                <div className="min-w-0 flex-1">
                  <b className="text-fg-list">{ATTR_LABEL[a]}的舊傷</b>
                  <span className="ml-2 text-[13px] text-red">還有 {k} 道</span>
                  <div className="text-[13px] text-muted">
                    修好一道：{ATTR_LABEL[a]} {c.attrs[a]} → {c.attrs[a] + 1}
                  </div>
                </div>
                <Buy disabled={c.credits < CLINIC.scar} onClick={() => act({ t: 'healScar', attr: a })}>
                  ¢{CLINIC.scar}
                </Buy>
              </div>
            ))}
        </Panel>
      )}
      <Panel innerClass="pb-1">
        <div className="px-3 pt-3 font-bold text-heading">常備義體（七五折，買了直接裝上）</div>
        <div className="px-3 text-[13px] text-muted">神經餘裕 {margin}：低於 40，任務裡要擲錯亂骰或付更多壓力</div>
        {SHOP_IMPLANTS.map((kind) => row(kind, marketPrice(ITEMS[kind].price)))}
      </Panel>
      <Panel innerClass="pb-1">
        <div className="px-3 pt-3 font-bold text-heading">訂製義體（原價，這次只有這三種）</div>
        {orders.map((it) => row(it.kind!, it.price))}
      </Panel>
      {upgradable.length > 0 && (
        <Panel innerClass="pb-1">
          <div className="px-3 pt-3 font-bold text-heading">升級身上的義體</div>
          <div className="px-3 text-[13px] text-muted">每升一級效果 +0.5 倍、負荷 +{UPGRADE_LOAD}，最多 Lv.{MAX_ITEM_LEVEL}</div>
          {upgradable.map((it) => {
            const lv = it.level ?? 1
            const price = upgradeCost(it)
            const after = { ...c, implantLoad: c.implantLoad + UPGRADE_LOAD }
            const risk = neuralRisk(after)
            return (
              <div key={it.id} className="flex items-center gap-2 border-b border-line/40 px-3 py-2">
                <ItemIcon item={it} />
                <div className="min-w-0 flex-1">
                  <b className="text-fg-list">
                    {it.name} <span className="tech text-heading">Lv.{lv}</span>
                  </b>
                  {lv >= MAX_ITEM_LEVEL ? (
                    <div className="text-[13px] text-muted">已經是最高等級</div>
                  ) : (
                    <div className={`text-[13px] ${risk ? 'text-warning' : 'text-muted'}`}>
                      → Lv.{lv + 1}：效果 ×{1 + 0.5 * lv}・升級後神經餘裕 {marginOf(after)}
                      {risk ? `・${neuralTag(after)}` : ''}
                    </div>
                  )}
                </div>
                {lv < MAX_ITEM_LEVEL && (
                  <Buy disabled={c.credits < price} onClick={() => act({ t: 'upgradeImplant', itemId: it.id })}>
                    ¢{price}
                  </Buy>
                )}
              </div>
            )
          })}
        </Panel>
      )}
    </>
  )
}

function RestNode({ game, n }: { game: G; n: Extract<NodeRun, { kind: 'rest' }> }) {
  const { g, act } = game
  const c = g.character
  return (
    <>
      <NodeHead tag="休息" title="膠囊旅館與網咖" body="今晚只夠做一件事：好好睡一覺、躲起來等風頭過去，或者拔掉所有連線，讓神經安靜下來。" />
      {n.used ? (
        <Panel tone="strong" innerClass="p-4 text-fg">你休息過了。</Panel>
      ) : (
        <>
          <ActionButton disabled={c.injury === 0} reason="沒有傷" onClick={() => act({ t: 'rest', choice: 'heal' })}>
            <BedDouble size={16} /> 睡一覺（傷勢 −{REST.heal}%、壓力 −{REST.stress}）
          </ActionButton>
          <ActionButton disabled={c.heat === 0} reason="沒有被通緝" onClick={() => act({ t: 'rest', choice: 'heat' })}>
            躲起來（通緝 −{REST.heat}、壓力 −{REST.stress}）
          </ActionButton>
          <ActionButton disabled={c.stress === 0} reason="神經壓力已經是 0" onClick={() => act({ t: 'rest', choice: 'calm' })}>
            斷線靜養（壓力 −{REST.calm}）
          </ActionButton>
        </>
      )}
    </>
  )
}

// ---------- 劇情委託（論壇文章＋回覆串） ----------

function CaseThread({ game, sc }: { game: G; sc: StoryCase }) {
  const { g, act } = game
  const active = g.story.caseId === sc.id ? g.story.stage : null
  const rec = g.run.cases[sc.id]
  const fixer = FIXERS[sc.fixerId]
  const replies = caseReplies(sc, g.run.cases)
  // 回覆串一則一則進來；全部到齊才選做法
  const [threadRead, setThreadRead] = useState(false)
  const visible = sc.danger.options.filter((o) => optionLock(g.character, g.story.approach, o) !== null)
  const locks = Object.fromEntries(visible.map((o) => [o.id, optionLock(g.character, g.story.approach, o) ?? '']).filter(([, v]) => v))
  const notes = Object.fromEntries(
    visible.map((o) => [
      o.id,
      [
        o.approach ? `只有走「${sc.approaches.find((x) => x.id === o.approach)!.label}」才有` : '',
        o.needs && 'attr' in o.needs ? `屬性選項：${ATTR_LABEL[o.needs.attr]} ≥ ${o.needs.min}` : '',
        o.needs ? `有備而來，多擲 2 顆・代價：報酬七五折、名聲減半、神經壓力 +${SAFE_STRESS}` : '',
        o.fight ? `⚔ 要打一場（${o.fight.name} HP ${o.fight.hp}）：打贏就生還，打輸才擲致命判定` : '',
      ]
        .filter(Boolean)
        .join('・'),
    ]),
  )
  const ap = sc.approaches.find((x) => x.id === g.story.approach) ?? sc.approaches[0]
  const auto = ap.autoLog
  const beats = storyBeats(ap)
  // 剛擲的場面骰還在跳：後面的場面、戰鬥、危險節點等它播完才出現
  const rolled = useRollDone(active === 'sceneCost' ? undefined : beatKey(`${g.character.id}:${sc.id}`, g.story.history?.at(-1)))
  return (
    <>
      <Panel innerClass="p-4">
        <div className="text-[13px] text-red">{sc.kind === 'test' ? '測試案' : '劇情委託'}・{sc.zone}</div>
        <h1 className="my-1 text-[22px] leading-snug font-bold text-heading">{sc.title}</h1>
        <div className="mt-1 flex items-start gap-3">
          <Avatar id={fixer.id} size={52} />
          <p className="m-0 flex-1 whitespace-pre-line text-fg">{caseBody(sc, g.run.cases)}</p>
        </div>
        <div className="mt-3 flex items-center gap-4 border-t border-line/40 pt-2 text-[14px] text-muted">
          <span className="flex items-center gap-1">
            <MessageSquare size={15} /> {replies.length}
          </span>
          <span>{fixer.name}</span>
          <span className="tech ml-auto">{sc.posted}</span>
        </div>
      </Panel>
      {active === 'prep' && <ReplyThread replies={replies} onAllShown={setThreadRead} />}
      {active === 'prep' && threadRead && (
        <div className="flex flex-wrap gap-2">
          <PsychoTag c={g.character} />
        </div>
      )}
      {active === 'prep' && threadRead && <ApproachPicker game={game} sc={sc} />}
      {active === 'auto' && <AutoRun lines={auto} total={autoMs(auto.length, 4000)} fast={!!(g.meta.seen.story || g.meta.seen.boss)} onDone={() => act({ t: 'storyAutoDone' })} />}
      {active && active !== 'prep' && active !== 'auto' && <PsychoRules game={game} />}
      {active && active !== 'prep' && active !== 'auto' && g.story.history?.length ? (
        <BeatHistory beats={beats} keyBase={`${g.character.id}:${sc.id}`} history={active === 'sceneCost' ? g.story.history.slice(0, -1) : g.story.history} />
      ) : null}
      {rolled && (active === 'fight' || active === 'danger') && g.story.history?.length ? (
        <p className="m-0 text-[14px] text-muted">
          做法的場面：致命判定 <b className={`tech ${(g.story.scenes ?? 0) < 0 ? 'text-red' : 'text-heading'}`}>{(g.story.scenes ?? 0) >= 0 ? '+' : ''}{g.story.scenes ?? 0} 顆</b>（乾淨成功 +1、失敗 −1、付代價不加不減）
        </p>
      ) : null}
      {rolled && active === 'scene' && (
        <ScenePanel key={g.story.beat} game={game} beats={beats} at={g.story.beat ?? 0} parts={scenePool(g.character, ap.direction, 1, beats[Math.min(g.story.beat ?? 0, beats.length - 1)].attr)} onRoll={(push, gamble) => act({ t: 'storyRoll', push, gamble })} />
      )}
      {active === 'sceneCost' && g.story.history?.length ? (
        <SceneCostPanel c={g.character} beats={beats} at={g.story.beat ?? 0} last={g.story.history[g.story.history.length - 1]} base={ap} keyBase={`${g.character.id}:${sc.id}`} onPick={(i) => act({ t: 'storySceneCost', index: i })} />
      ) : null}
      {rolled && active === 'fight' && !g.story.fight && <TacticPicker game={game} enemy={heatEnemy(fightEnemy(sc, g.story), g.character.heat)} onPick={(t) => act({ t: 'storyFight', tactic: t })} />}
      {active === 'fight' && g.story.fight && (
        <FightRun fight={g.story.fight} after={g.story.option ? undefined : sc.approaches.find((x) => x.id === g.story.approach)?.afterFight} onDone={() => act({ t: 'storyFightDone' })} />
      )}
      {rolled && active === 'danger' && (
        <RiskDecision
          game={game}
          title={sc.danger.title}
          body={sc.danger.body}
          options={visible}
          locks={locks}
          notes={notes}
          safeNote={(o) => {
            const opt = sc.danger.options.find((x) => x.id === o.id)!
            return opt.reward ? `只拿部分報酬 ¢${caseReward(opt)}` : '委託失敗、拿不到報酬'
          }}
          poolOf={(o) => lethalPool(g.character, caseLethal(sc, g.story.approach, sc.danger.options.find((x) => x.id === o.id)!, g.story.scenes))}
          threat={caseThreat(sc)?.name}
          onConfirm={(id, push, gamble) => act({ t: 'storyChoose', optionId: id, push, gamble })}
        />
      )}
      {active === 'chase' && caseThreat(sc) && (
        <ChaseFight game={game} enemy={caseThreat(sc)!} fight={g.story.fight} lethal={g.story.lethal} onPick={(x) => act({ t: 'chaseFight', tactic: x })} onDone={() => act({ t: 'chaseDone' })} />
      )}
      {active === 'cost' && g.story.lethal && (
        <LethalCostPick
          c={g.character}
          lethal={g.story.lethal}
          direction={(sc.approaches.find((x) => x.id === g.story.approach) ?? sc.approaches[0]).direction}
          dropNote="委託失敗，沒有報酬"
          onPick={(choice) => act({ t: 'lethalCost', choice })}
        />
      )}
      {rec && !active && (
        <Result
          outcome={{ kind: rec.outcome, reason: rec.reason } as DangerOutcome}
          safeTitle={caseSafeTitle(rec.optionId, sc.danger.options.find((o) => o.id === rec.optionId))}
        />
      )}
    </>
  )
}

/** 劇情案沒撐過去也沒受致命傷時的標題：撤離選項有部分報酬才算「部分完成」；冒險選項落到這裡是丟下一切或打輸。 */
function caseSafeTitle(optionId: string, o: CaseOption | undefined): string | undefined {
  if (optionId === 'retreat' || o?.fight) return '被打退・委託失敗'
  if (optionId === 'psycho') return '神經錯亂・任務中斷'
  if (o?.lethal) return '丟下一切・委託失敗'
  return o?.reward ? '部分完成' : undefined
}

/** 論壇回覆一則一則進來（約 1.5 秒一則，先顯示「正在輸入…」）；點一下回覆串就立刻顯示下一則。 */
function ReplyThread({ replies, onAllShown }: { replies: Reply[]; onAllShown: (v: boolean) => void }) {
  const [shown, setShown] = useState(0)
  const all = shown >= replies.length
  const done = useRef(onAllShown)
  done.current = onAllShown
  useEffect(() => {
    if (all) {
      done.current(true)
      return
    }
    const id = setTimeout(() => setShown(shown + 1), 1500)
    return () => clearTimeout(id)
  }, [shown, all])
  const next = replies[shown]
  return (
    <div onClick={() => !all && setShown(shown + 1)} className={all ? '' : 'cursor-pointer'}>
      <Panel innerClass="divide-y divide-line/40">
        {replies.slice(0, shown).map((r, i) => (
          <div key={i} className="reply-in flex gap-3 p-3">
            <Avatar id={r.who} size={44} />
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-2 text-[14px]">
                <b className="text-heading">{FIXERS[r.who].name}</b>
                <span className="text-[12px] text-muted">{FIXERS[r.who].role}</span>
                <span className="tech ml-auto text-[13px] text-muted">{r.at}</span>
              </div>
              <p className="mt-1 mb-0 text-[16px] text-fg">{r.text}</p>
            </div>
          </div>
        ))}
        {next && (
          <div className="flex items-center gap-2 p-3 text-[14px] text-muted">
            <span className="typing-dots" aria-hidden>
              <i />
              <i />
              <i />
            </span>
            {FIXERS[next.who].name} 正在輸入…<span className="ml-auto text-[12px]">點一下顯示</span>
          </div>
        )}
        <Reveal dep={shown} />
      </Panel>
    </div>
  )
}

function ApproachPicker({ game, sc }: { game: G; sc: StoryCase }) {
  const [sel, setSel] = useState<string | null>(null)
  const c = game.g.character
  return (
    <Panel innerClass="p-3 space-y-2">
      <div className="text-[15px] font-bold text-heading">選擇做法</div>
      <p className="m-0 text-[13px] text-muted">做法決定路上的傷勢與最後關頭的風險；帶著這個方向的裝備與卡牌，會比較好走。</p>
      {sc.approaches.map((a) => {
        const Icon = DIR_ICON[a.direction]
        const on = sel === a.id
        const lock = attrLock(c, a.needs)
        // 照 storyAutoDone 先加上路上的傷勢與壓力，算出抵達最後關頭時的機率
        const there = { ...c, injury: Math.min(100, c.injury + a.injury), stress: c.stress + 6 }
        const risks = sc.danger.options
          .filter((o) => o.lethal && (!o.approach || o.approach === a.id) && !o.needs)
          .map((o) => Math.max(0, poolSize(lethalPool(there, caseLethal(sc, a.id, o)))))
        const range = (xs: number[]) => (Math.max(...xs) > Math.min(...xs) ? `${Math.min(...xs)}～${Math.max(...xs)}` : `${xs[0]}`)
        return (
          <button key={a.id} disabled={!!lock} onClick={() => setSel(a.id)} className={`block w-full text-left ${on ? 'cut cut-sm cut-red' : 'cut cut-sm'} ${lock ? 'opacity-50' : ''}`}>
            <div className="cut-in flex min-h-12 gap-3 p-3">
              <Icon size={18} className={on ? 'mt-1 text-red' : 'mt-1 text-line'} />
              <div className="flex-1">
                <div className="font-bold text-fg-list">{a.label}</div>
                <div className="text-[15px] text-fg">{a.summary}</div>
                <div className="text-[13px] text-muted">
                  {DIRECTION_LABEL[a.direction]}・{a.fight ? `⚔ 要打一場（${a.fight.name}）` : `路上傷勢 +${a.injury}%`}
                </div>
                {risks.length > 0 && (
                  <div className="text-[13px] text-red">
                    最後關頭的冒險選項：擲 {range(risks)} 顆（還沒算做法的 2 個場面、加骰與器材），失敗＝致命傷
                  </div>
                )}
                {a.needs && <div className="text-[13px] text-cyan">屬性做法：{ATTR_LABEL[a.needs.attr]} ≥ {a.needs.min}</div>}
                {lock && <div className="text-[13px] text-warning">✖ {lock}</div>}
              </div>
            </div>
          </button>
        )
      })}
      <ActionButton tone="primary" disabled={!sel} reason="先選一種做法" onClick={() => game.act({ t: 'storyApproach', id: sel! })}>
        出發
      </ActionButton>
      <Reveal />
    </Panel>
  )
}

// ---------- 自動段、戰鬥、危險節點 ----------

/** 自動段：時間連續往前推（2 倍速就推得快一倍），文字依「總時長 ÷ 行數」逐行出現，進度條跟著跑；看過這種節點才能 2 倍速。 */
export function AutoRun({ lines, total, fast, onDone }: { lines: string[]; total: number; fast: boolean; onDone: () => void }) {
  const [elapsed, setElapsed] = useState(0)
  const [x2, setX2] = useState(false)
  // callback 與倍速放 ref：父元件重新渲染時 onDone 是新函式，不能讓它重設計時迴圈
  const done = useRef(onDone)
  done.current = onDone
  const speed = useRef(1)
  speed.current = x2 ? 2 : 1
  useEffect(() => {
    // 用計時器加實際經過的時間推進，不用 requestAnimationFrame：背景分頁會整個暫停 rAF，計時器只是被降頻
    let last = performance.now()
    let t = 0
    const id = setInterval(() => {
      const now = performance.now()
      t += (now - last) * speed.current
      last = now
      setElapsed(Math.min(t, total))
      if (t >= total) {
        clearInterval(id)
        done.current()
      }
    }, 50)
    return () => clearInterval(id)
  }, [total])
  const step = total / Math.max(1, lines.length)
  const n = Math.min(lines.length, Math.floor(elapsed / step) + 1)
  const pct = Math.min(100, (elapsed / total) * 100)
  return (
    <Panel innerClass="p-3 space-y-2">
      <div className="flex items-center gap-2 text-[13px] text-muted">
        <span className="flex-1">▶ 執行中</span>
        <span className="tech text-heading">{Math.ceil((total - elapsed) / 1000 / speed.current)}s</span>
        {fast && (
          <button onClick={() => setX2(!x2)} className={`flex min-h-11 items-center gap-1 border px-3 font-bold ${x2 ? 'border-red text-red' : 'border-line text-cyan'}`}>
            <FastForward size={14} /> 2×
          </button>
        )}
      </div>
      <ol className="m-0 list-none p-0">
        {lines.slice(0, n).map((l, i) => (
          <li key={i} className={`sys-line reply-in ${i === n - 1 ? 'sys-line-now' : ''}`}>
            <span className="tech sys-line-tag">{String(i + 1).padStart(2, '0')}</span>
            <span className="flex-1">{i === n - 1 ? <TypeLine text={l} /> : l}</span>
          </li>
        ))}
      </ol>
      <div className="run-bar" role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(pct)}>
        <div className={`run-bar-fill ${x2 ? 'run-bar-fast' : ''}`} style={{ width: `${pct}%` }} />
      </div>
      <Reveal dep={n} />
    </Panel>
  )
}

function TacticPicker({ game, enemy, onPick, fameEdge: edge = 0 }: { game: G; enemy: Enemy; onPick: (t: Tactic) => void; fameEdge?: number }) {
  const c = game.g.character
  const st = fightStats(c)
  const [sel, setSel] = useState<Tactic | null>(null)
  return (
    <Panel tone="red" innerClass="p-3 space-y-2">
      <div className="flex items-center gap-2 text-[18px] font-bold text-red">
        <EnemyFace name={enemy.name} />
        <Swords size={20} /> 遭遇戰：{enemy.name}
      </div>
      <div className="grid grid-cols-2 gap-2 text-[14px]">
        <div className="border border-line/70 p-2">
          你 <b className="tech text-heading">HP {st.hp}/{st.maxHp}</b>・攻擊 <b className="tech text-heading">{st.atk}</b>・命中 <b className="tech text-heading">{Math.round(st.hit * 100)}%</b>
          {st.armor ? <>・護甲 <b className="tech text-heading">{st.armor}</b></> : null}
          {st.crit ? <>・爆擊 <b className="tech text-heading">{Math.round(st.crit * 100)}%</b></> : null}
          ・駭入強度 <b className="tech text-heading">{hackPower(c)}</b>・隱匿 <b className="tech text-heading">{stealthPower(c)}</b>
        </div>
        <div className="border border-red/60 p-2">
          對方 <b className="tech text-heading">HP {enemy.hp}</b>・攻擊 <b className="tech text-heading">{enemy.atk}</b>・命中 <b className="tech text-heading">{Math.round(enemy.hit * 100)}%</b>
          ・防火牆 <b className={`tech ${(enemy.ice ?? 0) > hackPower(c) ? 'text-red' : 'text-heading'}`}>{enemy.ice ?? 0}</b>・感知{' '}
          <b className={`tech ${(enemy.sense ?? 0) > stealthPower(c) ? 'text-red' : 'text-heading'}`}>{enemy.sense ?? 0}</b>
          {c.heat ? <span className="block text-[12px] text-red">通緝 {c.heat}★：對方 +{c.heat * 8}%</span> : null}
          {edge ? <span className="block text-[12px] text-red">你的名聲 Lv.{c.fame.level}：對方派出更硬的人（+{Math.round(edge * 100)}%）</span> : null}
        </div>
      </div>
      <p className="m-0 text-[13px] text-muted">自動戰鬥，打鬥本身不會死：HP 低於最大 HP 的 {RETREAT_HP}% 會自動撤退。受的傷會帶到之後的節點。選一個戰術：</p>
      {tacticsFor(c, enemy).map((t) => {
        const Icon = DIR_ICON[t.id]
        const on = sel === t.id
        return (
          <button key={t.id} disabled={!!t.locked} onClick={() => setSel(t.id)} className={`block w-full text-left ${on ? 'cut cut-sm cut-red' : 'cut cut-sm'} ${t.locked ? 'opacity-50' : ''}`}>
            <div className="cut-in flex min-h-12 gap-3 p-3">
              <Icon size={18} className={on ? 'mt-1 text-red' : 'mt-1 text-line'} />
              <div className="flex-1">
                <div className="font-bold text-fg-list">
                  {t.label}
                  {DIRECTION_LABEL[t.id] !== t.label && <span className="ml-2 text-[13px] font-normal text-muted">{DIRECTION_LABEL[t.id]}</span>}
                </div>
                <div className="text-[14px] text-fg">{t.summary}</div>
                {t.locked && <div className="text-[13px] text-warning">✖ {t.locked}</div>}
              </div>
            </div>
          </button>
        )
      })}
      <ActionButton tone="danger" disabled={!sel} reason="先選一個戰術" onClick={() => onPick(sel!)}>
        開打
      </ActionButton>
      <Reveal />
    </Panel>
  )
}

/** 每種回合事件的音效。 */
const FIGHT_SFX: Partial<Record<FightFx, () => void>> = {
  hit: sfx.hit,
  crit: sfx.crit,
  hurt: sfx.hurt,
  shock: sfx.zap,
  hack: sfx.zap,
  jammed: sfx.zap,
  ambush: sfx.whoosh,
  stealth: sfx.whoosh,
  win: sfx.success,
  retreat: sfx.fail,
}

/** 每種回合事件的特效：面板震動、畫面閃光的顏色、手機震動。 */
const FIGHT_FX: Partial<Record<FightFx, { shake?: number; flash?: string; buzz?: number }>> = {
  hurt: { shake: 7, flash: 'fx-blood', buzz: 25 },
  crit: { shake: 4, flash: 'fx-crit', buzz: 40 },
  hit: { flash: 'fx-hit' },
  ambush: { shake: 3, flash: 'fx-ambush', buzz: 30 },
  shock: { flash: 'fx-shock', buzz: 15 },
  hack: { flash: 'fx-shock' },
  jammed: { flash: 'fx-glitch' },
  stealth: { flash: 'fx-ambush' },
  win: { flash: 'fx-crit' },
  retreat: { flash: 'fx-blood' },
}

/** 戰鬥逐回合播放：每回合約 0.6 秒，隨時可以 2 倍速；每回合依事件播特效（震動、流血、電流、爆擊）。 */
/** 對手頭像（art_src/build_enemies.py 產生；沒有圖的對手不顯示）。 */
function EnemyFace({ name, size = 48 }: { name: string; size?: number }) {
  const src = (ENEMY_PORTRAITS as Record<string, string>)[name]
  if (!src) return null
  return (
    <span className="cut cut-sm shrink-0" style={{ width: size, height: size }}>
      <span className="cut-in grid place-items-end overflow-hidden bg-raised">
        <img src={src} alt="" className="h-full w-full object-contain [image-rendering:pixelated]" />
      </span>
    </span>
  )
}

function FightRun({ fight: f, after = [], onDone }: { fight: FightResult; after?: string[]; onDone: () => void }) {
  const [n, setN] = useState(1)
  const [x2, setX2] = useState(false)
  const done = useRef(onDone)
  done.current = onDone
  const total = f.rounds.length + (f.won ? after.length : 0)
  useEffect(() => {
    if (n > total) {
      done.current()
      return
    }
    const id = setTimeout(() => setN(n + 1), (n > f.rounds.length ? 1600 : 600) / (x2 ? 2 : 1))
    return () => clearTimeout(id)
  }, [n, total, f.rounds.length, x2])
  const idx = Math.min(n, f.rounds.length) - 1
  const last = f.rounds[idx]
  const logRef = useRef<HTMLDivElement>(null)
  const stage = useRef<HTMLDivElement>(null)
  // 新的一回合：面板震動＋手機震動（只在播到這一回合的那一刻）
  useEffect(() => {
    logRef.current?.scrollTo({ top: logRef.current.scrollHeight })
    if (n > f.rounds.length) return
    const fx = FIGHT_FX[last.fx]
    if (fx?.buzz) buzz(fx.buzz)
    FIGHT_SFX[last.fx]?.()
    if (fx?.shake && stage.current && !reducedMotion()) {
      const d = fx.shake
      stage.current.animate(
        [{ transform: 'translate(0,0)' }, { transform: `translate(${-d}px,${d / 2}px)` }, { transform: `translate(${d}px,${-d / 2}px)` }, { transform: `translate(${-d / 2}px,0)` }, { transform: 'translate(0,0)' }],
        { duration: 260, easing: 'ease-out' },
      )
    }
  }, [n])
  const fx = n <= f.rounds.length ? FIGHT_FX[last.fx] : undefined
  const low = last.you < f.maxHp * 0.3
  const pop = n <= f.rounds.length && last.dmg ? last : undefined
  return (
    <div ref={stage}>
      <Panel tone="red" innerClass={`relative p-3 space-y-2 ${low ? 'fx-low' : ''}`}>
        {fx?.flash && <div key={n} className={`fx-flash ${fx.flash}`} aria-hidden />}
        <div className="flex items-center gap-2 text-[15px] font-bold text-red">
          <Swords size={16} />
          <EnemyFace name={f.enemy.name} size={36} />
          <span className="flex-1">戰鬥中：{f.enemy.name}</span>
          <button onClick={() => setX2(!x2)} className={`relative z-10 flex min-h-11 items-center gap-1 border px-3 ${x2 ? 'border-red text-red' : 'border-line text-cyan'}`}>
            <FastForward size={14} /> 2×
          </button>
        </div>
        <div className="relative">
          <Meter label="你" value={last.you} max={f.maxHp} tone={last.you < (f.maxHp * (RETREAT_HP + 10)) / 100 ? 'red' : 'positive'} text={`HP ${last.you}/${f.maxHp}`} />
          {pop?.fx === 'hurt' && (
            <span key={n} className="dmg-pop dmg-you">
              −{pop.dmg}
            </span>
          )}
        </div>
        <div className="relative">
          <Meter label={f.enemy.name} value={last.foe} max={f.enemy.hp} tone="red" text={`HP ${last.foe}/${f.enemy.hp}`} />
          {pop && pop.fx !== 'hurt' && (
            <span key={n} className={`dmg-pop dmg-foe ${pop.fx === 'crit' ? 'dmg-crit' : ''} ${pop.fx === 'shock' ? 'dmg-shock' : ''}`}>
              {pop.fx === 'crit' ? '爆擊! ' : ''}−{pop.dmg}
            </span>
          )}
        </div>
        <div ref={logRef} className="relative max-h-56 space-y-1 overflow-y-auto border-t border-line/40 pt-2">
          {f.rounds.slice(0, n).map((r, i) => (
            <p key={i} className={`m-0 border-l-2 pl-2 text-[15px] ${ROUND_TONE[r.fx]} ${i === idx && n <= f.rounds.length ? 'font-bold' : ''}`}>
              {r.text}
            </p>
          ))}
          {f.won &&
            after.slice(0, Math.max(0, n - f.rounds.length)).map((l, i) => (
              <p key={`a${i}`} className="m-0 border-l-2 border-line/40 pl-2 text-fg">
                {l}
              </p>
            ))}
        </div>
        <Reveal dep={n} />
      </Panel>
    </div>
  )
}

/** 戰鬥紀錄每一行左邊的色線：你打中＝青、被打＝紅、電流＝青白、爆擊＝黃。 */
const ROUND_TONE: Record<FightFx, string> = {
  hit: 'border-cyan text-fg',
  crit: 'border-warning text-warning',
  ambush: 'border-[#b06cff] text-fg',
  shock: 'border-cyan text-cyan',
  hack: 'border-cyan text-cyan',
  stealth: 'border-[#b06cff] text-fg',
  miss: 'border-line/40 text-muted',
  dodge: 'border-line/40 text-muted',
  jammed: 'border-cyan/50 text-muted',
  hurt: 'border-red text-red',
  win: 'border-positive text-positive',
  retreat: 'border-red text-red',
}

/** 致命判定失敗、追兵逼近：先選戰術再打；打贏算撐過去，打輸才是致命傷。 */
function ChaseFight({ game, enemy, fight, lethal, onPick, onDone }: { game: G; enemy: Enemy; fight?: FightResult; lethal?: LethalLog; onPick: (t: Tactic) => void; onDone: () => void }) {
  return (
    <>
      <Panel tone="red" innerClass="p-4 space-y-2">
        <div className="flex items-center gap-2 text-[18px] font-bold text-red">
          <AlertTriangle size={20} /> {enemy.name}逼近了
        </div>
        {lethal && <DiceRoll dice={lethal.dice} best={lethal.best} result="fail" />}
        <p className="m-0 text-fg">致命判定失敗，但你還站著。打出去就算撐過去，報酬照拿；打輸（HP 掉到撤退線）才是致命傷。</p>
      </Panel>
      {!fight && <TacticPicker game={game} enemy={heatEnemy(enemy, game.g.character.heat)} onPick={onPick} />}
      {fight && <FightRun fight={fight} onDone={onDone} />}
    </>
  )
}

function RiskDecision({
  game,
  title,
  body,
  options,
  safeNote,
  locks = {},
  notes = {},
  poolOf,
  threat,
  onConfirm,
}: {
  game: G
  title: string
  body: string
  options: DangerOption[]
  safeNote: string | ((o: DangerOption) => string)
  locks?: Record<string, string>
  notes?: Record<string, string>
  /** 這個選項致命判定的骰池（與判定同一個函式）。 */
  poolOf: (o: DangerOption) => PoolPart[]
  /** 有人在場時，失敗會變成追兵逼近、要打一場（不是直接致命傷）。 */
  threat?: string
  onConfirm: (id: string, push: boolean, gamble: boolean) => void
}) {
  const c = game.g.character
  const intro = useIntro(!!game.g.meta.seen.lethal, () => game.act({ t: 'seenIntro', key: 'lethal' }))
  const [sel, setSel] = useState<string | null>(null)
  const [push, setPush] = useState(false)
  const [gamble, setGamble] = useState(false)
  const picked = options.find((o) => o.id === sel)
  const boostable = !!picked?.lethal && !('fight' in picked && picked.fight)
  const extra = boostable ? (push ? 1 : 0) + (gamble && c.heat < 5 ? 1 : 0) : 0
  return (
    <Panel tone="red" innerClass="p-4 space-y-3">
      {intro.open && <DiceIntro kind="lethal" onClose={intro.close} />}
      <div className="flex items-center gap-2 text-[18px] font-bold text-red">
        <AlertTriangle size={20} /> 重大危險：{title}
      </div>
      <IntroButton onClick={intro.show} label="致命判定怎麼玩？" />
      <p className="m-0 whitespace-pre-line text-fg">{body}</p>
      <div className="grid grid-cols-2 gap-2 text-[14px]">
        <div className="border border-red/60 p-2">
          傷勢 <b className="tech text-warning">{c.injury}%</b>
        </div>
        <div className="border border-red/60 p-2">
          神經餘裕 <b className="tech text-heading">{marginOf(c)}</b>
        </div>
        <div className="border border-red/60 p-2">
          通緝 <b className="text-red">{'★'.repeat(c.heat) || '—'}</b>
        </div>
        <div className="border border-red/60 p-2">
          救命保單 <b className={c.lifelines ? 'text-positive' : 'text-red'}>{lifelineOf(c) ? LIFELINES[lifelineOf(c)!].label : '沒有'}</b>
        </div>
      </div>
      <p className="m-0 text-[14px] text-muted">
        冒險選項是一次<b className="text-red">致命判定</b>：只看最高那顆，6 撐過去、4～5 撐過去但要付重代價（重傷或丟下一切）、1～3 {threat ? `會讓${threat}逼近，要打一場，打輸才是致命傷` : '是致命傷'}。沒有倒數，可以先離開再回來；擲過就不會重擲。
        {lifelineOf(c) ? `受致命傷時會用掉${LIFELINES[lifelineOf(c)!].label}：${LIFELINES[lifelineOf(c)!].desc}。` : '沒有救命保單：致命傷就是永久死亡。'}
      </p>
      <PsychoRules game={game} />
      {options.map((o) => {
        const on = sel === o.id
        const size = o.lethal ? poolSize(poolOf(o)) : 0
        return (
          <button key={o.id} data-testid="danger-option" disabled={!!locks[o.id]} onClick={() => setSel(o.id)} className={`block w-full text-left cut cut-sm ${on ? 'cut-strong' : ''} ${locks[o.id] ? 'opacity-50' : ''}`}>
            <div className="cut-in min-h-12 p-3">
              <div className={`font-bold ${on ? 'text-cyan' : 'text-fg-list'}`}>{o.label}</div>
              {notes[o.id] && <div className="text-[13px] text-cyan">{notes[o.id]}</div>}
              {locks[o.id] && <div className="text-[13px] text-warning">✖ {locks[o.id]}</div>}
              <div className="text-[14px]">
                {o.lethal ? (
                  <span className="flex items-center gap-1 font-bold text-red">
                    <AlertTriangle size={14} />
                    {'fight' in o && o.fight ? '打輸時：' : ''}致命判定・{rollLabel(size)}・{threat && !('fight' in o && o.fight) ? `失敗＝${threat}逼近，打輸才致命` : '失敗＝致命傷'}
                  </span>
                ) : (
                  <span className="text-positive">不會死・{typeof safeNote === 'string' ? safeNote : safeNote(o)}</span>
                )}
              </div>
            </div>
          </button>
        )
      })}
      {picked?.lethal && (
        <div className="space-y-2 border border-red/60 p-3">
          <PoolParts parts={poolOf(picked)} />
          {boostable && <BoostToggles c={c} push={push} setPush={setPush} gamble={gamble} setGamble={setGamble} />}
        </div>
      )}
      <ActionButton tone="danger" testId="danger-confirm" disabled={!sel} reason="先選一個行動" onClick={() => onConfirm(sel!, boostable && push, boostable && gamble && c.heat < 5)}>
        {picked?.lethal && boostable ? `確認：${rollLabel(poolSize(poolOf(picked), extra))}` : '確認這個行動'}
      </ActionButton>
      <Reveal />
    </Panel>
  )
}

/** 致命判定擲出 4～5：重傷生還，或丟下一切脫身。 */
function LethalCostPick({ c, lethal, direction, dropNote, onPick }: { c: G['g']['character']; lethal: LethalLog; direction: Direction; dropNote: string; onPick: (choice: 'maim' | 'drop') => void }) {
  const a = SCAR_ATTR[direction]
  return (
    <Panel tone="red" innerClass="p-4 space-y-3">
      <div className="flex flex-wrap items-center gap-2">
        <span className="font-bold text-red">致命判定</span>
        <DiceRoll dice={lethal.dice} best={lethal.best} result="cost" />
        <span className="font-bold text-warning">撐過去了，但要付重代價</span>
      </div>
      {lethal.psycho?.length ? <p className="m-0 text-[13px] text-red">錯亂骰 {lethal.psycho.join('、')}：撐住了</p> : null}
      <p className="m-0 text-fg">選一個：</p>
      <button data-testid="lethal-cost" onClick={() => onPick('maim')} className="block w-full text-left cut cut-sm cut-red">
        <div className="cut-in min-h-12 p-3">
          <div className="font-bold text-fg-list">咬牙撐完：重傷生還</div>
          <div className="text-[13px] text-warning">
            報酬與名聲照拿・傷勢至少 {SEVERE_INJURY}%・舊傷：{ATTR_LABEL[a]} −1（{ATTR_LABEL[a]} {c.attrs[a]} → {Math.max(1, c.attrs[a] - 1)}）
          </div>
        </div>
      </button>
      <button data-testid="lethal-cost" onClick={() => onPick('drop')} className="block w-full text-left cut cut-sm">
        <div className="cut-in min-h-12 p-3">
          <div className="font-bold text-fg-list">丟下一切脫身</div>
          <div className="text-[13px] text-warning">
            {dropNote}・傷勢 +{DROP_INJURY}%（{c.injury}% → {Math.min(100, c.injury + DROP_INJURY)}%）・沒有舊傷
          </div>
        </div>
      </button>
    </Panel>
  )
}

function Result({ outcome: o, doneTitle = '完成委託', safeTitle = '撤離・委託失敗' }: { outcome: DangerOutcome; doneTitle?: string; safeTitle?: string }) {
  const title = { safe: safeTitle, survived: doneTitle, maimed: '重傷生還', rescued: '救命保單觸發', rescued_system: '緊急搶救（系統補償）', dead: '永久死亡' }[o.kind]
  return (
    <Panel tone={o.kind === 'dead' ? 'red' : 'strong'} innerClass="p-4">
      <div className={`text-[20px] font-bold ${o.kind === 'dead' ? 'text-red' : 'text-cyan'}`}>{title}</div>
      <p className="mt-1 mb-0 text-fg">{o.reason}</p>
      <Reveal />
    </Panel>
  )
}
