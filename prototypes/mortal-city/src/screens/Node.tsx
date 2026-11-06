// 節點畫面：委託、精英委託、事件、黑市、診所、休息、劇情委託。戰鬥與危險節點的元件共用。
import { useEffect, useRef, useState } from 'react'
import { AlertTriangle, ArrowLeft, BedDouble, Crosshair, Eye, FastForward, Flame, MessageSquare, ShieldPlus, Stethoscope, Store, Swords, Terminal } from 'lucide-react'
import { ActionButton, Avatar, Meter, Panel, Tag } from '../components/ui'
import { FIXERS, JOBS, highDanger } from '../content/data'
import { CASE_BY_ID, type Reply, type StoryCase, caseBody, caseReplies, optionLock } from '../content/cases'
import { EVENT_BY_ID } from '../content/events'
import { buzz, reducedMotion } from '../components/haptics'
import { ITEMS, LIFELINE_PRICE, SHOP_IMPLANTS, itemDesc, marketPrice } from '../content/items'
import { type NodeRun, type ResultRow, type useGame, eventLock, fightEnemy, jobLines } from '../game/state'
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
  approachBonus,
  attrLock,
  dirBonus,
  fightStats,
  hashSeed,
  heatEnemy,
  implantRoom,
  jobReward,
  jobSuccessChance,
  marginOf,
  perkReward,
  sellValue,
  streetEnemy,
  tacticsFor,
} from '../rules/core'

type G = ReturnType<typeof useGame>

export const DIR_ICON: Record<Direction, typeof Flame> = { force: Crosshair, hack: Terminal, stealth: Eye }

export function BackBar({ onBack, label }: { onBack: () => void; label: string }) {
  return (
    <button onClick={onBack} className="flex min-h-11 items-center gap-1 text-[15px] text-cyan">
      <ArrowLeft size={18} /> {label}
    </button>
  )
}

/** 自動段的總長：10～30 秒，依行數。 */
export const autoMs = (lines: number, base = 2500) => Math.min(30_000, Math.max(10_000, lines * base))

/** 放在會長出新訊息的地方底下：dep 一變（或剛出現時）就把這裡捲進畫面，玩家不用自己捲到底。 */
function Reveal({ dep }: { dep?: unknown }) {
  const ref = useRef<HTMLDivElement>(null)
  useEffect(() => {
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
  return (
    <div className="space-y-3">
      {n.kind === 'job' && <JobNode game={game} n={n} />}
      {n.kind === 'elite' && <EliteNode game={game} n={n} />}
      {n.kind === 'event' && <EventNode game={game} n={n} />}
      {n.kind === 'market' && <MarketNode game={game} n={n} />}
      {n.kind === 'clinic' && <ClinicNode game={game} />}
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

// ---------- 委託 ----------

function JobNode({ game, n }: { game: G; n: Extract<NodeRun, { kind: 'job' }> }) {
  const { g, act } = game
  const c = g.character
  const job = JOBS[n.jobId]
  const lines = jobLines(n.jobId, n.ok)
  return (
    <>
      <NodeHead tag={`委託・${DIRECTION_LABEL[job.direction]}・階級 ${job.tier}`} title={job.name} fixer={job.fixerId} body={job.blurb} />
      <div className="flex flex-wrap gap-2">
        <Tag>報酬 ¢{jobReward(job, perkReward(c, job.direction))}</Tag>
        <Tag>成功率 {Math.round(jobSuccessChance(job, dirBonus(c, job.direction)) * 100)}%</Tag>
        <Tag tone="warning">壓力 +{job.stress}</Tag>
        {job.direction === 'force' && <Tag tone="red">⚔ 一定要打</Tag>}
      </div>
      {n.stage === 'auto' && <AutoRun lines={lines} total={autoMs(lines.length)} fast={!!g.meta.seen.job} onDone={() => act({ t: 'jobAutoDone' })} />}
      {n.stage === 'fight' && !n.fight && <TacticPicker game={game} enemy={heatEnemy(streetEnemy(job), c.heat)} onPick={(t) => act({ t: 'jobFight', tactic: t })} />}
      {n.stage === 'fight' && n.fight && <FightRun fight={n.fight} onDone={() => act({ t: 'jobFightDone' })} />}
      {n.stage === 'done' && <ResultRows title="結算" text={n.text} rows={n.rows} />}
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
      <NodeHead tone="red" tag={`精英委託・${DIRECTION_LABEL[job.direction]}・打贏一定掉寶`} title={job.name} fixer={job.fixerId} body={job.blurb} />
      {n.stage === 'auto' && <AutoRun lines={t.autoLog} total={15_000} fast={!!g.meta.seen.elite} onDone={() => act({ t: 'eliteAutoDone' })} />}
      {n.stage === 'fight' && !n.fight && <TacticPicker game={game} enemy={heatEnemy(t.fight, c.heat)} onPick={(x) => act({ t: 'eliteFight', tactic: x })} />}
      {n.stage === 'fight' && n.fight && <FightRun fight={n.fight} onDone={() => act({ t: 'eliteFightDone' })} />}
      {n.stage === 'danger' && (
        <RiskDecision
          game={game}
          title={t.title}
          body={t.body}
          options={t.options}
          locks={Object.fromEntries(t.options.map((o) => [o.id, attrLock(c, o.attrNeeds) ?? '']).filter(([, v]) => v))}
          notes={Object.fromEntries(t.options.filter((o) => o.attrNeeds).map((o) => [o.id, `屬性選項：${ATTR_LABEL[o.attrNeeds!.attr]} ≥ ${o.attrNeeds!.min}，風險比硬幹低`]))}
          safeNote="拿不到報酬（戰利品已經到手）"
          onConfirm={(id) => act({ t: 'eliteChoose', optionId: id })}
        />
      )}
      {n.stage === 'done' && n.outcome && <Result outcome={n.outcome} doneTitle="完成精英委託" safeTitle={n.fight && !n.fight.won ? '被打退・撤離' : undefined} />}
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
            const note = [o.cost ? `¢${o.cost}` : '', o.needs ? `${ATTR_LABEL[o.needs.attr]} ≥ ${o.needs.min}` : '', o.chance !== undefined ? `成功率 ${Math.round(o.chance * 100)}%` : ''].filter(Boolean).join('・')
            return (
              <button key={o.id} disabled={!!lock} onClick={() => act({ t: 'eventChoose', optionId: o.id })} className={`block w-full text-left cut cut-sm ${lock ? 'opacity-50' : ''}`}>
                <div className="cut-in min-h-12 p-3">
                  <div className="font-bold text-fg-list">{o.label}</div>
                  {note && <div className="text-[13px] text-cyan">{note}</div>}
                  {lock && <div className="text-[13px] text-warning">✖ {lock}</div>}
                </div>
              </button>
            )
          })}
        </Panel>
      ) : (
        <ResultRows title="結果" text={n.text} rows={n.rows} />
      )}
    </>
  )
}

// ---------- 黑市、診所、休息 ----------

function ItemLine({ item }: { item: Item }) {
  return (
    <div className="min-w-0 flex-1">
      <b className="text-fg-list">{item.name}</b>
      <span className="ml-2 text-[13px] text-muted">{SLOT_LABEL[item.slot]}・{DIRECTION_LABEL[item.direction]}</span>
      <div className="text-[13px] text-cyan">
        {[itemDesc(item), item.bonus ? `${DIRECTION_LABEL[item.direction]}委託 +${Math.round(item.bonus * 100)}%` : '', item.load ? `負荷 ${item.load}` : ''].filter(Boolean).filter((t, i, xs) => xs.indexOf(t) === i).join('・')}
      </div>
    </div>
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
  return (
    <>
      <NodeHead tag="黑市" title="高架橋下的地攤" body="帆布一掀，底下全是還帶著體溫的貨。攤主的義眼一直盯著你的錢包：「來路？別問，問了就漲價。」" />
      <div className="flex justify-center">
        <span className="stolen-sign">全部半價・不問來路・概不退換</span>
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
        <div className="flex items-center gap-2 px-3 py-3">
          <div className="min-w-0 flex-1">
            <b className="text-fg-list">
              <ShieldPlus size={14} className="mr-1 inline text-positive" />
              救命保單（空白）
            </b>
            <div className="text-[13px] text-cyan">受致命傷時武裝醫療隊救你一次，然後就用掉。你有 {c.lifelines} 張。</div>
            <div className="text-[13px] text-muted">某架醫療飛行器上「掉」下來的，還沒人登記。</div>
          </div>
          <Buy disabled={c.credits < LIFELINE_PRICE} onClick={() => act({ t: 'buyLifeline' })}>
            ¢{LIFELINE_PRICE}
          </Buy>
        </div>
      </Panel>
      {c.stash.length > 0 && (
        <Panel innerClass="pb-1">
          <div className="px-3 pt-3 font-bold text-heading">收贓（售價四折）</div>
          <div className="px-3 text-[13px] text-muted">「我收，但我不問。你也別問我賣給誰。」</div>
          {c.stash.map((it) => (
            <div key={it.id} className="flex items-center gap-2 border-b border-line/40 px-3 py-2">
              <ItemLine item={it} />
              <Buy onClick={() => act({ t: 'sell', itemId: it.id })}>賣 ¢{sellValue(it)}</Buy>
            </div>
          ))}
        </Panel>
      )}
    </>
  )
}

function ClinicNode({ game }: { game: G }) {
  const { g, act } = game
  const c = g.character
  const cost = c.injury * CLINIC.perPoint
  const room = implantRoom(c)
  return (
    <>
      <NodeHead tag="診所" title="白蛇的地下診所" fixer="snake" body="「裝什麼都可以，裝不下的別怪我。你的神經只有那麼大。」" />
      <ActionButton disabled={(c.injury === 0 && c.stress === 0) || c.credits < cost} reason={c.injury === 0 && c.stress === 0 ? '沒有傷' : `需要 ¢${cost}`} onClick={() => act({ t: 'treat' })}>
        <Stethoscope size={16} /> 縫好傷口（傷勢 {c.injury}%・¢{cost}・壓力 −{CLINIC.stress}）
      </ActionButton>
      <Panel innerClass="pb-1">
        <div className="px-3 pt-3 font-bold text-heading">義體（半價，買了直接裝上）</div>
        <div className="px-3 text-[13px] text-muted">義體空間剩 {room}</div>
        {SHOP_IMPLANTS.map((kind) => {
          const d = ITEMS[kind]
          const price = marketPrice(d.price)
          const after = room - d.load
          const why = c.credits < price ? `需要 ¢${price}` : after < 0 ? `義體空間不夠（還差 ${-after}）` : undefined
          return (
            <div key={kind} className="flex items-center gap-2 border-b border-line/40 px-3 py-2">
              <div className="min-w-0 flex-1">
                <b className="text-fg-list">{d.name}</b>
                <div className="text-[13px] text-cyan">{d.desc}</div>
                <div className="text-[13px] text-muted">負荷 {d.load}・裝上後空間剩 {after}</div>
                {why && <div className="text-[13px] text-warning">✖ {why}</div>}
              </div>
              <Buy disabled={!!why} onClick={() => act({ t: 'buyImplant', kind })}>
                ¢{price}
              </Buy>
            </div>
          )
        })}
      </Panel>
    </>
  )
}

function RestNode({ game, n }: { game: G; n: Extract<NodeRun, { kind: 'rest' }> }) {
  const { g, act } = game
  const c = g.character
  return (
    <>
      <NodeHead tag="休息" title="膠囊旅館與網咖" body="今晚只夠做一件事：好好睡一覺，或者躲起來等風頭過去。" />
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
        o.fight ? `⚔ 要打一場（${o.fight.name} HP ${o.fight.hp}）：打贏就生還，打輸才擲致命判定` : '',
      ]
        .filter(Boolean)
        .join('・'),
    ]),
  )
  const auto = sc.approaches.find((x) => x.id === g.story.approach)?.autoLog ?? []
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
      {active === 'prep' && threadRead && <ApproachPicker game={game} sc={sc} />}
      {active === 'auto' && <AutoRun lines={auto} total={autoMs(auto.length, 4000)} fast={!!(g.meta.seen.story || g.meta.seen.boss)} onDone={() => act({ t: 'storyAutoDone' })} />}
      {active === 'fight' && !g.story.fight && <TacticPicker game={game} enemy={heatEnemy(fightEnemy(sc, g.story), g.character.heat)} onPick={(t) => act({ t: 'storyFight', tactic: t })} />}
      {active === 'fight' && g.story.fight && (
        <FightRun fight={g.story.fight} after={g.story.option ? undefined : sc.approaches.find((x) => x.id === g.story.approach)?.afterFight} onDone={() => act({ t: 'storyFightDone' })} />
      )}
      {active === 'danger' && (
        <RiskDecision
          game={game}
          title={sc.danger.title}
          body={sc.danger.body}
          options={visible}
          locks={locks}
          notes={notes}
          safeNote={(o) => {
            const opt = sc.danger.options.find((x) => x.id === o.id)!
            return opt.wins ? `完成委託 ¢${opt.reward}` : opt.reward ? `只拿部分報酬 ¢${opt.reward}` : '委託失敗、拿不到報酬'
          }}
          onConfirm={(id) => act({ t: 'storyChoose', optionId: id })}
        />
      )}
      {rec && !active && (
        <Result
          outcome={{ kind: rec.outcome, reason: rec.reason } as DangerOutcome}
          safeTitle={rec.optionId === 'retreat' ? '被打退・委託失敗' : sc.danger.options.find((o) => o.id === rec.optionId)?.reward ? '部分完成' : undefined}
        />
      )}
    </>
  )
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
      <p className="m-0 text-[13px] text-muted">做法決定路上的傷勢與最後關頭的風險；該方向的裝備與卡牌會降低風險。</p>
      {sc.approaches.map((a) => {
        const Icon = DIR_ICON[a.direction]
        const on = sel === a.id
        const bonus = Math.round(approachBonus(c, a.direction) * 100)
        const mod = Math.round(a.lethalMod * 100)
        const lock = attrLock(c, a.needs)
        return (
          <button key={a.id} disabled={!!lock} onClick={() => setSel(a.id)} className={`block w-full text-left ${on ? 'cut cut-sm cut-red' : 'cut cut-sm'} ${lock ? 'opacity-50' : ''}`}>
            <div className="cut-in flex min-h-12 gap-3 p-3">
              <Icon size={18} className={on ? 'mt-1 text-red' : 'mt-1 text-line'} />
              <div className="flex-1">
                <div className="font-bold text-fg-list">{a.label}</div>
                <div className="text-[15px] text-fg">{a.summary}</div>
                <div className="text-[13px] text-muted">
                  {DIRECTION_LABEL[a.direction]}・{a.fight ? `⚔ 要打一場（${a.fight.name}）` : `路上傷勢 +${a.injury}%`}・風險 {mod > 0 ? `+${mod}` : mod}%
                  {bonus ? `・你的裝備與卡牌 −${bonus}%` : ''}
                </div>
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
            <span className="flex-1">{l}</span>
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

function TacticPicker({ game, enemy, onPick }: { game: G; enemy: Enemy; onPick: (t: Tactic) => void }) {
  const c = game.g.character
  const st = fightStats(c)
  const [sel, setSel] = useState<Tactic | null>(null)
  return (
    <Panel tone="red" innerClass="p-3 space-y-2">
      <div className="flex items-center gap-2 text-[18px] font-bold text-red">
        <Swords size={20} /> 遭遇戰：{enemy.name}
      </div>
      <div className="grid grid-cols-2 gap-2 text-[14px]">
        <div className="border border-line/70 p-2">
          你 <b className="tech text-heading">HP {st.hp}/{st.maxHp}</b>・攻擊 <b className="tech text-heading">{st.atk}</b>・命中 <b className="tech text-heading">{Math.round(st.hit * 100)}%</b>
          {st.armor ? <>・護甲 <b className="tech text-heading">{st.armor}</b></> : null}
          {st.crit ? <>・暴擊 <b className="tech text-heading">{Math.round(st.crit * 100)}%</b></> : null}
        </div>
        <div className="border border-red/60 p-2">
          對方 <b className="tech text-heading">HP {enemy.hp}</b>・攻擊 <b className="tech text-heading">{enemy.atk}</b>・命中 <b className="tech text-heading">{Math.round(enemy.hit * 100)}%</b>
          {c.heat ? <span className="block text-[12px] text-red">通緝 {c.heat}★：對方 +{c.heat * 8}%</span> : null}
        </div>
      </div>
      <p className="m-0 text-[13px] text-muted">自動戰鬥，打鬥本身不會死：HP 低於最大 HP 的 {RETREAT_HP}% 會自動撤退。受的傷會帶到之後的節點。選一個戰術：</p>
      {tacticsFor(c).map((t) => {
        const Icon = DIR_ICON[t.id]
        const on = sel === t.id
        return (
          <button key={t.id} disabled={!!t.locked} onClick={() => setSel(t.id)} className={`block w-full text-left ${on ? 'cut cut-sm cut-red' : 'cut cut-sm'} ${t.locked ? 'opacity-50' : ''}`}>
            <div className="cut-in flex min-h-12 gap-3 p-3">
              <Icon size={18} className={on ? 'mt-1 text-red' : 'mt-1 text-line'} />
              <div className="flex-1">
                <div className="font-bold text-fg-list">
                  {t.label}
                  <span className="ml-2 text-[13px] font-normal text-muted">{DIRECTION_LABEL[t.id]}</span>
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

/** 戰鬥逐回合播放：每回合約 0.6 秒，隨時可以 2 倍速；每回合依事件播特效（震動、流血、電流、暴擊）。 */
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
          <span className="flex-1">戰鬥中：{f.enemy.name}</span>
          <button onClick={() => setX2(!x2)} className={`relative z-10 flex min-h-11 items-center gap-1 border px-3 ${x2 ? 'border-red text-red' : 'border-line text-cyan'}`}>
            <FastForward size={14} /> 2×
          </button>
        </div>
        <div className="relative">
          <Meter label="你" value={last.you} max={f.hpStart} tone={last.you < (f.maxHp * (RETREAT_HP + 10)) / 100 ? 'red' : 'positive'} text={`HP ${last.you}`} />
          {pop?.fx === 'hurt' && (
            <span key={n} className="dmg-pop dmg-you">
              −{pop.dmg}
            </span>
          )}
        </div>
        <div className="relative">
          <Meter label={f.enemy.name} value={last.foe} max={f.enemy.hp} tone="red" text={`HP ${last.foe}`} />
          {pop && pop.fx !== 'hurt' && (
            <span key={n} className={`dmg-pop dmg-foe ${pop.fx === 'crit' ? 'dmg-crit' : ''} ${pop.fx === 'shock' ? 'dmg-shock' : ''}`}>
              {pop.fx === 'crit' ? '暴擊! ' : ''}−{pop.dmg}
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

/** 戰鬥紀錄每一行左邊的色線：你打中＝青、被打＝紅、電流＝青白、暴擊＝黃。 */
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

function RiskDecision({
  game,
  title,
  body,
  options,
  safeNote,
  locks = {},
  notes = {},
  onConfirm,
}: {
  game: G
  title: string
  body: string
  options: DangerOption[]
  safeNote: string | ((o: DangerOption) => string)
  locks?: Record<string, string>
  notes?: Record<string, string>
  onConfirm: (id: string) => void
}) {
  const c = game.g.character
  const [sel, setSel] = useState<string | null>(null)
  return (
    <Panel tone="red" innerClass="p-4 space-y-3">
      <div className="flex items-center gap-2 text-[18px] font-bold text-red">
        <AlertTriangle size={20} /> 重大危險：{title}
      </div>
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
          救命保單 <b className={c.lifelines ? 'text-positive' : 'text-red'}>{c.lifelines ? `${c.lifelines} 張` : '沒有'}</b>
        </div>
      </div>
      <p className="m-0 text-[14px] text-muted">沒有倒數，可以先離開再回來。確認後一次判定，重新整理不會重抽。{c.lifelines ? '受致命傷時會用掉一張救命保單。' : '沒有救命保單：受致命傷就是永久死亡。'}</p>
      {options.map((o) => {
        const on = sel === o.id
        return (
          <button key={o.id} disabled={!!locks[o.id]} onClick={() => setSel(o.id)} className={`block w-full text-left cut cut-sm ${on ? 'cut-strong' : ''} ${locks[o.id] ? 'opacity-50' : ''}`}>
            <div className="cut-in min-h-12 p-3">
              <div className={`font-bold ${on ? 'text-cyan' : 'text-fg-list'}`}>{o.label}</div>
              {notes[o.id] && <div className="text-[13px] text-cyan">{notes[o.id]}</div>}
              {locks[o.id] && <div className="text-[13px] text-warning">✖ {locks[o.id]}</div>}
              <div className="text-[14px]">
                {o.lethal ? (
                  <span className="flex items-center gap-1 font-bold text-red">
                    <AlertTriangle size={14} /> 可能永久死亡
                  </span>
                ) : (
                  <span className="text-positive">不會死・{typeof safeNote === 'string' ? safeNote : safeNote(o)}</span>
                )}
              </div>
            </div>
          </button>
        )
      })}
      <ActionButton tone="danger" disabled={!sel} reason="先選一個行動" onClick={() => onConfirm(sel!)}>
        確認這個行動
      </ActionButton>
      <Reveal />
    </Panel>
  )
}

function Result({ outcome: o, doneTitle = '完成委託', safeTitle = '撤離・委託失敗' }: { outcome: DangerOutcome; doneTitle?: string; safeTitle?: string }) {
  const title = { safe: safeTitle, survived: doneTitle, rescued: '救命保單觸發', rescued_system: '緊急搶救（系統補償）', dead: '永久死亡' }[o.kind]
  return (
    <Panel tone={o.kind === 'dead' ? 'red' : 'strong'} innerClass="p-4">
      <div className={`text-[20px] font-bold ${o.kind === 'dead' ? 'text-red' : 'text-cyan'}`}>{title}</div>
      <p className="mt-1 mb-0 text-fg">{o.reason}</p>
      <Reveal />
    </Panel>
  )
}
