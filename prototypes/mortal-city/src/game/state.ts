import { useCallback, useEffect, useReducer } from 'react'
import {
  type Character,
  type DangerOption,
  type DangerOutcome,
  type Enemy,
  type FightResult,
  type Item,
  type LogEvent,
  type Tactic,
  type Attr,
  addFame,
  addXp,
  approachBonus,
  attrLock,
  baseAttrs,
  dirBonus,
  grantProgress,
  hashSeed,
  heatEnemy,
  implantRoom,
  jobReward,
  jobSuccessChance,
  perkOptions,
  perkReward,
  perkTally,
  resolveDanger,
  resolveFight,
  rng,
  sellValue,
  statusPrefix,
  streetEnemy,
  tacticsFor,
  ATTR_LABEL,
  ATTR_MAX,
  ATTR_START_POINTS,
  CLINIC,
  STYLE_LABEL,
  type Style,
  REST,
  SEVERE_INJURY,
} from '../rules/core'
import { type District, type NodeType, STORY_LAYER, findNode, generateDistrict, reachable } from '../rules/map'
import { JOBS, JOB_LINES, OPENING, STARTER_GEAR, highDanger } from '../content/data'
import { ITEMS, LIFELINE_PRICE, SHOP_IMPLANTS, eliteLoot, eventLoot, makeItem, marketPrice, marketStock, rollKind, streetLoot } from '../content/items'
import { CASE_BY_ID, TEST_CASE, type CaseOption, type CaseRecord, type StoryCase, optionLock } from '../content/cases'
import { EVENT_BY_ID, type Effects, type EventOption } from '../content/events'
import { DISTRICTS, type DistrictDef } from '../content/districts'
import { PERKS, PERK_CASH } from '../rules/perks'

/** 正在進行的劇情委託的階段；結案後的結果記在 Run.cases。 */
export type StoryStage = 'prep' | 'auto' | 'fight' | 'danger'

/** 結算畫面的一列：一個欄位一個變化，不塞在同一句話裡。 */
export interface ResultRow {
  label: string
  value: string
  tone?: 'good' | 'bad' | 'warn'
}

/** 傭兵現在站著的節點裡發生的事。 */
export type NodeRun =
  | { kind: 'job'; nodeId: string; jobId: string; ok: boolean; stage: 'auto' | 'fight' | 'done'; fight?: FightResult; text?: string; rows?: ResultRow[] }
  | { kind: 'elite'; nodeId: string; jobId: string; stage: 'auto' | 'fight' | 'danger' | 'done'; fight?: FightResult; outcome?: DangerOutcome }
  | { kind: 'event'; nodeId: string; eventId: string; stage: 'choose' | 'done'; text?: string; rows?: ResultRow[] }
  | { kind: 'market'; nodeId: string; stock: Item[] }
  | { kind: 'clinic'; nodeId: string }
  | { kind: 'rest'; nodeId: string; used?: boolean }
  | { kind: 'story'; nodeId: string; caseId: string }

export interface Run {
  seed: number
  /** 現在在第幾個街區（DISTRICTS 的索引）。 */
  districtIndex: number
  district: District
  /** 目前所在節點（null＝還沒出發）。 */
  at: string | null
  path: string[]
  node: NodeRun | null
  /** 'safehouse'＝劇情大案打完，在安全屋；'over'＝死亡或退休。 */
  phase: 'map' | 'safehouse' | 'over'
  /** 這段生涯已結案的劇情委託。 */
  cases: Record<string, CaseRecord>
  /** 這段生涯出現過的事件（不重複）。 */
  events: string[]
  /** 委託、精英委託、劇情委託結束後還沒「收下」的完成單：收下之前不能離開節點，三選一也先不跳出來。 */
  claim?: Claim | null
}

/** 完成單：完成演出要顯示的內容。 */
export interface Claim {
  title: string
  tone: 'success' | 'partial' | 'fail' | 'rescued'
  text: string
  rows: ResultRow[]
}

export interface Legend {
  id: string
  name: string
  end: 'dead' | 'retired'
  cause: string
  level: number
  fame: number
  fameTotal: number
  district: string
  /** 主流派（卡牌最多的方向；沒有卡＝null）。 */
  style: string | null
  perks: Record<string, number>
  at: number
}

/** 跨生涯的資料：傳奇檔案，以及哪些節點類型看過（看過的自動段可以 2 倍速）。新傭兵不會清掉。 */
export interface Meta {
  legends: Legend[]
  seen: Partial<Record<NodeType, boolean>>
}

export interface Game {
  v: 2
  character: Character
  run: Run
  story: { caseId: string | null; stage: StoryStage; approach?: string; fight?: FightResult; option?: string }
  log: LogEvent[]
  systemFault: boolean
  notes: string[]
  meta: Meta
}

const RUN_KEY = 'mortal-city:run:v1'
const META_KEY = 'mortal-city:meta:v1'

function newCharacter(n: number, now: number): Character {
  return {
    id: `c${now}`,
    name: n === 1 ? '無名傭兵' : `無名傭兵 #${n}`,
    alive: true,
    level: 1,
    xp: 0,
    credits: 500,
    injury: 0,
    stress: 0,
    implantLoad: STARTER_GEAR.reduce((s, i) => s + i.load, 0),
    heat: 0,
    equipment: structuredClone(STARTER_GEAR),
    lifelines: 0,
    attrs: baseAttrs(),
    attrPoints: ATTR_START_POINTS,
    stash: [],
    fame: { level: 0, xp: 0, total: 0 },
    perks: {},
    picks: [],
  }
}

/** 某個街區的地圖：每區用自己的 seed。 */
const districtMap = (seed: number, index: number) => {
  const d = DISTRICTS[index]
  return generateDistrict(hashSeed(seed, index), d.id, d.name)
}

function newRun(c: Character): Run {
  const seed = hashSeed(c.id, 'run')
  return { seed, districtIndex: 0, district: districtMap(seed, 0), at: null, path: [], node: null, phase: 'map', cases: {}, events: [] }
}

/** 下一個街區（沒有就是還沒開放）。 */
export const nextDistrict = (g: Game) => DISTRICTS[g.run.districtIndex + 1]

export function initial(now: number, meta: Meta = { legends: [], seen: {} }): Game {
  const c = newCharacter(meta.legends.length + 1, now)
  return {
    v: 2,
    character: c,
    run: newRun(c),
    story: { caseId: null, stage: 'prep' },
    log: [{ at: now, kind: 'system', text: `連線到 MORTAL CITY NETWORK。歡迎來到魔都，${c.name}。先在「角色」分配 ${ATTR_START_POINTS} 點屬性，再從新宿的地圖出發。` }],
    systemFault: false,
    notes: [],
    meta,
  }
}

const trim = (l: LogEvent[]) => l.slice(-300)
const withLog = (g: Game, ...events: LogEvent[]): Game => ({ ...g, log: trim([...g.log, ...events]) })

/** 劇情委託進行中。 */
export const storyBusy = (g: Game) => g.story.caseId !== null

/** 節點裡的事還沒結束（自動段、戰鬥、危險節點、事件選項、劇情委託）。這時不能換裝，三選一也先不跳出來。 */
export function nodeBusy(g: Game): boolean {
  const n = g.run.node
  if (!n) return false
  if (n.kind === 'job' || n.kind === 'elite' || n.kind === 'event') return n.stage !== 'done'
  if (n.kind === 'story') return storyBusy(g)
  return false
}
export const gearBusy = nodeBusy

/** 節點結束、可以離開。 */
export function nodeDone(g: Game): boolean {
  const n = g.run.node
  if (!n) return false
  return !nodeBusy(g) && !g.run.claim
}

/** 兩個時間點之間，傭兵身上變了什麼（完成單用）。 */
export function diffRows(a: Character, b: Character): ResultRow[] {
  const rows: ResultRow[] = []
  if (b.credits !== a.credits) rows.push({ label: '信用點', value: `${b.credits > a.credits ? '+' : '−'}¢${Math.abs(b.credits - a.credits)}`, tone: b.credits > a.credits ? 'good' : 'bad' })
  if (b.injury !== a.injury) rows.push({ label: '傷勢', value: `${a.injury}% → ${b.injury}%`, tone: b.injury > a.injury ? 'bad' : 'good' })
  if (b.heat !== a.heat) rows.push({ label: '通緝', value: `${a.heat}★ → ${b.heat}★`, tone: b.heat > a.heat ? 'bad' : 'good' })
  if (b.lifelines !== a.lifelines) rows.push({ label: '救命保單', value: `${a.lifelines} → ${b.lifelines}`, tone: b.lifelines > a.lifelines ? 'good' : 'bad' })
  if (b.level > a.level) rows.push({ label: '等級', value: `Lv.${a.level} → Lv.${b.level}（屬性點 +${b.level - a.level}）`, tone: 'good' })
  if (b.fame.total > a.fame.total) rows.push({ label: '名聲', value: `+${b.fame.total - a.fame.total}`, tone: 'warn' })
  const loot = b.picks.filter((p) => p.kind === 'item').length - a.picks.filter((p) => p.kind === 'item').length
  if (loot > 0) rows.push({ label: '戰利品', value: `三選一 ×${loot}`, tone: 'warn' })
  const cards = b.picks.filter((p) => p.kind === 'perk').length - a.picks.filter((p) => p.kind === 'perk').length
  if (cards > 0) rows.push({ label: '卡牌', value: `三選一 ×${cards}（名聲升級）`, tone: 'warn' })
  return rows
}

/** 結束一件委託：活著就開一張完成單（死了就沒有）。 */
function withClaim(before: Game, after: Game, claim: Omit<Claim, 'rows'> & { rows?: ResultRow[] }): Game {
  if (!after.character.alive) return after
  return { ...after, run: { ...after.run, claim: { ...claim, rows: claim.rows ?? diffRows(before.character, after.character) } } }
}

/** 現在能前往的節點。 */
export function movable(g: Game) {
  const { run, character: c } = g
  if (!c.alive || run.phase !== 'map' || run.node || c.picks.length) return []
  return reachable(run.district, run.at)
}

/** 開打：鎖住的戰術不能用；結果一次算完（seed 決定），傷勢與壓力立刻套用，畫面再逐回合播放。通緝越高對手越強。 */
function startFight(c: Character, enemy: Enemy, tactic: Tactic, seed: number): { c: Character; f: FightResult } | null {
  if (tacticsFor(c, enemy).find((t) => t.id === tactic)?.locked) return null
  const f = resolveFight(c, heatEnemy(enemy, c.heat), tactic, seed)
  return { c: { ...c, injury: f.injury, stress: c.stress + f.stress }, f }
}

/** 正在打的是哪一場：危險節點選的「打」，或做法本身的遭遇戰。 */
export function fightEnemy(sc: StoryCase, st: Game['story']): Enemy {
  if (st.option) return sc.danger.options.find((o) => o.id === st.option)!.fight!
  return sc.approaches.find((x) => x.id === st.approach)!.fight!
}

/** 掉了寶：排進三選一並寫紀錄（挑了才放進背包）。直接改 c。 */
function offerLoot(c: Character, options: Item[] | null, log: LogEvent[], at: number, from: string) {
  if (!options) return
  c.picks.push({ kind: 'item', from, options })
  log.push({ at, kind: 'gain', text: `◆ 戰利品（${from}）三選一：${options.map((i) => i.name).join('／')}。` })
}

/** 危險節點選項套上做法的修正：做法本身的風險，再扣掉該方向的裝備與卡牌加成。 */
export function caseDangerOption(c: Character, sc: StoryCase, approachId: string | undefined, optionId: string): DangerOption {
  const opt = sc.danger.options.find((o) => o.id === optionId)!
  const ap = sc.approaches.find((x) => x.id === approachId) ?? sc.approaches[0]
  if (!opt.lethal) return opt
  return { ...opt, lethalBase: Math.min(0.95, Math.max(0.02, opt.lethalBase + ap.lethalMod - approachBonus(c, ap.direction))) }
}

/** 生涯結束（死亡或退休）：寫進傳奇檔案。 */
function endCareer(g: Game, end: Legend['end'], cause: string, now: number): Game {
  const c = g.character
  const tally = perkTally(c)
  const top = (Object.entries(tally) as [Style, number][]).sort((a, b) => b[1] - a[1])[0]
  const legend: Legend = {
    id: c.id,
    name: c.name,
    end,
    cause,
    level: c.level,
    fame: c.fame.level,
    fameTotal: c.fame.total,
    district: g.run.district.name,
    style: top && top[1] > 0 ? STYLE_LABEL[top[0]] : null,
    perks: c.perks,
    at: now,
  }
  return { ...g, run: { ...g.run, phase: 'over' }, meta: { ...g.meta, legends: [...g.meta.legends, legend] } }
}

interface LethalCtx {
  label: string
  safeText: string
  lossText: string
  onSurvive: (c: Character, log: LogEvent[]) => void
}

/**
 * 危險節點判定後的共用處理（劇情委託與精英委託）：
 * 生還給報酬；被救用掉一張救命保單、傷勢 70；死亡寫進傳奇檔案。
 */
function settleLethal(g: Game, now: number, outcome: DangerOutcome, ctx: LethalCtx): Game {
  const c = g.character
  const character: Character = structuredClone(c)
  const log: LogEvent[] = []
  const notes = [...g.notes]
  if (outcome.kind === 'safe') log.push({ at: now, kind: 'warn', text: `${statusPrefix(c)} ${ctx.safeText}` })
  else if (outcome.kind === 'survived') ctx.onSurvive(character, log)
  else if (outcome.kind === 'rescued') {
    character.lifelines -= 1
    character.injury = SEVERE_INJURY
    log.push({ at: now, kind: 'hurt', text: `✚ ${outcome.reason}${ctx.lossText}` })
  } else if (outcome.kind === 'rescued_system') {
    character.injury = 50
    notes.push(`${ctx.label}：武裝醫療隊緊急搶救（系統補償）`)
    log.push({ at: now, kind: 'system', text: `✚ ${outcome.reason}` })
  } else {
    character.alive = false
    log.push({ at: now, kind: 'stop', text: `✖ 你死了：${outcome.reason}（${ctx.label}）` })
  }
  const next = withLog({ ...g, character, notes }, ...log)
  return outcome.kind === 'dead' ? endCareer(next, 'dead', `${ctx.label}：${outcome.reason}`, now) : next
}

/**
 * 劇情委託結案：判定結果交給 settleLethal；pay 時，不冒險或生還照選項付報酬、通緝、治療、經驗與名聲。
 * 夜鴉插播，紀錄寫進 Run.cases。
 */
function closeCase(g: Game, now: number, sc: StoryCase, picked: CaseOption, outcome: DangerOutcome, pay: boolean): Game {
  const paid = (ch: Character, log: LogEvent[]) => {
    if (!pay) return
    ch.credits += picked.reward
    ch.heat = Math.min(5, ch.heat + (picked.heat ?? 0))
    if (picked.heal) ch.injury = 0
    ch.lifelines += picked.lifeline ?? 0
    const parts = [picked.reward ? `+${picked.reward} 信用點` : '沒有報酬', picked.heat ? `通緝 +${picked.heat}` : '', picked.heal ? '傷口縫好了' : '', picked.lifeline ? `救命保單 +${picked.lifeline}` : '']
    log.push({ at: now, kind: picked.reward ? 'job' : 'warn', text: `${statusPrefix(ch)} 「${sc.title}」結案：${parts.filter(Boolean).join('，')}。` })
    addXp(ch, sc.xp, now, log)
    // 名聲：冒險生還是經驗的 2 倍，其他有結案的是一半
    addFame(ch, outcome.kind === 'survived' ? sc.xp * 2 : Math.round(sc.xp / 2), now, log)
    if (outcome.kind === 'survived')
      for (const l of sc.loot ?? []) offerLoot(ch, rollKind(hashSeed(ch.id, sc.id, 'reward', l.kind), l.kind, l.chance, ch), log, now, sc.title)
  }
  let next = settleLethal(g, now, outcome, { label: sc.title, safeText: outcome.reason, lossText: sc.lossText, onSurvive: paid })
  if (outcome.kind === 'safe') {
    // 不冒險也算結案；有部分報酬就照付
    const ch = structuredClone(next.character)
    const log: LogEvent[] = []
    paid(ch, log)
    next = withLog({ ...next, character: ch }, ...log)
  }
  if (sc.broadcast && next.character.alive)
    next = withLog(next, { at: now, kind: 'system', text: outcome.kind === 'survived' ? sc.broadcast.survived : sc.broadcast.other })
  const record: CaseRecord = { approach: g.story.approach ?? '', optionId: picked.id, outcome: outcome.kind, reason: outcome.reason }
  const tone = outcome.kind === 'survived' ? 'success' : outcome.kind === 'safe' ? (pay && picked.reward ? 'partial' : 'fail') : 'rescued'
  return withClaim(g, { ...next, story: { caseId: null, stage: 'prep' }, run: { ...next.run, cases: { ...next.run.cases, [sc.id]: record } } }, { title: sc.title, tone, text: outcome.reason })
}

// ---------- 節點內容 ----------

/** 委託節點用哪個模板：前半段難度 1、後半段難度 2；精英委託用難度 4。 */
function pickJob(seed: number, layer: number, elite: boolean, d: DistrictDef) {
  const tier = elite ? d.eliteTier : layer < STORY_LAYER ? d.tiers[0] : d.tiers[1]
  const pool = Object.values(JOBS).filter((j) => j.tier === tier)
  return pool[Math.floor(rng(seed)() * pool.length)]
}

/** 這個街區的事件裡，這段生涯還沒出現過的；全部出現過就重頭來。 */
function pickEvent(seed: number, used: string[], d: DistrictDef) {
  const all = d.events.map((id) => EVENT_BY_ID[id])
  const pool = all.filter((e) => !used.includes(e.id))
  const from = pool.length ? pool : all
  return from[Math.floor(rng(seed)() * from.length)]
}

/** 一般委託自動段的文字。 */
export function jobLines(jobId: string, ok: boolean): string[] {
  const job = JOBS[jobId]
  const l = JOB_LINES[job.direction]
  return [...OPENING[job.direction](job.name), l.mid, ok ? l.ok : l.caught]
}

/** 事件選項能不能選：不夠錢或屬性不夠回傳原因。 */
export function eventLock(c: Character, o: EventOption): string | undefined {
  if (o.cost && c.credits < o.cost) return `需要 ¢${o.cost}`
  return attrLock(c, o.needs)
}

const signed = (n: number) => `${n > 0 ? '+' : ''}${n}`

/** 套用事件效果，回傳結果文字與一列一列的變化。直接改 c。 */
function applyEffects(c: Character, e: Effects, seed: number, log: LogEvent[], at: number, from: string): { text: string; rows: ResultRow[] } {
  c.credits = Math.max(0, c.credits + (e.credits ?? 0))
  c.injury = Math.max(0, Math.min(100, c.injury + (e.injury ?? 0)))
  c.heat = Math.max(0, Math.min(5, c.heat + (e.heat ?? 0)))
  c.stress = Math.max(0, c.stress + (e.stress ?? 0))
  c.lifelines += e.lifeline ?? 0
  if (e.xp) addXp(c, e.xp, at, log)
  if (e.fame) addFame(c, e.fame, at, log)
  if (e.loot) offerLoot(c, eventLoot(seed, e.loot), log, at, from)
  const rows: ResultRow[] = []
  if (e.credits) rows.push({ label: '信用點', value: `${signed(e.credits)}`, tone: e.credits > 0 ? 'good' : 'bad' })
  if (e.injury) rows.push({ label: '傷勢', value: `${signed(e.injury)}%（現在 ${c.injury}%）`, tone: e.injury > 0 ? 'bad' : 'good' })
  if (e.heat) rows.push({ label: '通緝', value: `${signed(e.heat)}★（現在 ${c.heat}★）`, tone: e.heat > 0 ? 'bad' : 'good' })
  if (e.stress) rows.push({ label: '神經壓力', value: signed(e.stress), tone: e.stress > 0 ? 'bad' : 'good' })
  if (e.xp) rows.push({ label: '經驗', value: `+${e.xp}` })
  if (e.fame) rows.push({ label: '名聲', value: `+${e.fame}`, tone: 'warn' })
  if (e.lifeline) rows.push({ label: '救命保單', value: `+${e.lifeline}`, tone: 'good' })
  if (e.loot) rows.push({ label: '戰利品', value: '三選一', tone: 'warn' })
  return { text: e.text, rows }
}

/** 紀錄用：把結算列接成一句。 */
const rowsText = (rows: ResultRow[]) => (rows.length ? `（${rows.map((r) => `${r.label} ${r.value}`).join('，')}）` : '')

type Action =
  | { t: 'move'; nodeId: string }
  | { t: 'leave' }
  | { t: 'jobAutoDone' }
  | { t: 'jobFight'; tactic: Tactic }
  | { t: 'jobFightDone' }
  | { t: 'eliteAutoDone' }
  | { t: 'eliteFight'; tactic: Tactic }
  | { t: 'eliteFightDone' }
  | { t: 'eliteChoose'; optionId: string }
  | { t: 'eventChoose'; optionId: string }
  | { t: 'marketBuy'; index: number }
  | { t: 'buyLifeline' }
  | { t: 'sell'; itemId: string }
  | { t: 'treat' }
  | { t: 'buyImplant'; kind: string }
  | { t: 'rest'; choice: 'heal' | 'heat' }
  | { t: 'storyApproach'; id: string }
  | { t: 'storyAutoDone' }
  | { t: 'storyChoose'; optionId: string }
  | { t: 'storyFight'; tactic: Tactic }
  | { t: 'storyFightDone' }
  | { t: 'claim' }
  | { t: 'continue' }
  | { t: 'retire' }
  | { t: 'raiseAttr'; attr: Attr }
  | { t: 'setLook'; look: 'a' | 'b' }
  | { t: 'pickPerk'; id: string }
  | { t: 'pickItem'; index: number }
  | { t: 'equip'; itemId: string }
  | { t: 'unequip'; itemId: string }
  | { t: 'devTestCase' }
  | { t: 'toggleFault' }
  | { t: 'newCharacter' }
  | { t: 'reset' }

/** 進入節點：依類型準備節點裡的內容（模板、事件、貨架都用節點自己的 seed，重整不重抽）。 */
function enter(g: Game, nodeId: string, now: number): Game {
  const node = findNode(g.run.district, nodeId)!
  const c = g.character
  const seed = hashSeed(c.id, nodeId)
  let n: NodeRun
  let story = g.story
  let events = g.run.events
  if (node.type === 'job' || node.type === 'elite') {
    const job = pickJob(seed, node.layer, node.type === 'elite', DISTRICTS[g.run.districtIndex])
    const ok = rng(hashSeed(seed, 'roll'))() < jobSuccessChance(job, dirBonus(c, job.direction))
    n = node.type === 'job' ? { kind: 'job', nodeId, jobId: job.id, ok, stage: 'auto' } : { kind: 'elite', nodeId, jobId: job.id, stage: 'auto' }
  } else if (node.type === 'event') {
    const ev = pickEvent(seed, g.run.events, DISTRICTS[g.run.districtIndex])
    events = [...events, ev.id]
    n = { kind: 'event', nodeId, eventId: ev.id, stage: 'choose' }
  } else if (node.type === 'market') n = { kind: 'market', nodeId, stock: marketStock(seed) }
  else if (node.type === 'clinic') n = { kind: 'clinic', nodeId }
  else if (node.type === 'rest') n = { kind: 'rest', nodeId }
  else {
    const dd = DISTRICTS[g.run.districtIndex]
    const sc = CASE_BY_ID[node.type === 'boss' ? dd.boss : dd.story]
    n = { kind: 'story', nodeId, caseId: sc.id }
    story = { caseId: sc.id, stage: 'prep' }
  }
  return withLog(
    { ...g, story, run: { ...g.run, at: nodeId, path: [...g.run.path, nodeId], node: n, events } },
    { at: now, kind: 'system', text: `▶ 前往第 ${node.layer + 1} 層的節點。` },
  )
}

/** 委託做完（打完或沒打）：報酬、通緝、經驗、名聲、掉寶。 */
function finishJob(g: Game, now: number, won: boolean): Game {
  const n = g.run.node as Extract<NodeRun, { kind: 'job' }>
  const job = JOBS[n.jobId]
  const c = structuredClone(g.character)
  const before = { injury: g.character.injury, xp: c.xp, level: c.level, fame: c.fame.total }
  const log: LogEvent[] = []
  const roll = rng(hashSeed(c.id, n.nodeId, 'harm'))
  // 沒打的成功：路上小傷；打過的傷勢已經由戰鬥決定
  const injury = n.fight ? 0 : Math.round(job.injury * 0.4 * (0.6 + roll() * 0.8))
  const heatUp = !won && roll() < 0.35 + job.heat * 0.1 ? 1 : 0
  const full = jobReward(job, perkReward(c, job.direction))
  const reward = won ? full : Math.round(full * 0.3)
  // 開打前的傷勢（戰鬥已經改過 c.injury）
  const startInjury = n.fight ? Math.round(100 - (n.fight.hpStart * 100) / n.fight.maxHp) : before.injury
  c.injury = Math.min(100, c.injury + injury)
  c.stress += job.stress
  c.heat = Math.min(5, c.heat + heatUp)
  c.credits += reward
  const picksBefore = c.picks.length
  if (won && n.fight) offerLoot(c, streetLoot(hashSeed(c.id, n.nodeId, 'loot'), job.tier, c), log, now, job.name)
  const looted = c.picks.length > picksBefore
  grantProgress(c, job, won, now, log)
  const f = n.fight
  const rows: ResultRow[] = [
    { label: '結果', value: won ? '完成' : '失手', tone: won ? 'good' : 'bad' },
    { label: '報酬', value: `+¢${reward}${won ? '' : '（只拿到三成）'}`, tone: 'good' },
    ...(f ? [{ label: '戰鬥', value: `${f.enemy.name}・${tacticsFor(c).find((t) => t.id === f.tactic)!.label}・${f.won ? '打贏' : '被打退'}・HP ${f.hpStart}→${f.hp}`, tone: f.won ? 'good' : 'bad' } as ResultRow] : []),
    ...(c.injury !== startInjury ? [{ label: '傷勢', value: `${startInjury}% → ${c.injury}%`, tone: 'bad' } as ResultRow] : []),
    ...(heatUp ? [{ label: '通緝', value: `+1★（MPD 盯上你了）`, tone: 'bad' } as ResultRow] : []),
    { label: '神經壓力', value: `+${job.stress + (f?.stress ?? 0)}`, tone: 'warn' },
    { label: '經驗', value: `+${won ? job.xp : Math.round(job.xp / 3)}${c.level > before.level ? `（升到 Lv.${c.level}）` : ''}` },
    { label: '名聲', value: `+${c.fame.total - before.fame}`, tone: 'warn' },
    ...(looted ? [{ label: '戰利品', value: '三選一（節點結束後挑）', tone: 'warn' } as ResultRow] : []),
  ]
  const text = won ? `完成「${job.name}」。` : `「${job.name}」失手了。`
  log.unshift({ at: now, kind: won ? 'job' : 'hurt', text: `${statusPrefix(c)} ${text}${rowsText(rows.slice(1))}` })
  const after = withLog({ ...g, character: c, run: { ...g.run, node: { ...n, stage: 'done', text, rows } } }, ...log)
  return withClaim(g, after, { title: job.name, tone: won ? 'success' : 'fail', text, rows: rows.slice(1) })
}

export function reduce(g: Game, a: Action): Game {
  const now = Date.now()
  const c = g.character
  const n = g.run.node
  switch (a.t) {
    case 'move': {
      if (!movable(g).some((x) => x.id === a.nodeId)) return g
      return enter(g, a.nodeId, now)
    }
    case 'leave': {
      // 離開節點：記下看過這種節點（之後自動段可以 2 倍速）；劇情大案打完就到安全屋
      if (!n || !nodeDone(g) || !c.alive) return g
      const type = findNode(g.run.district, n.nodeId)?.type
      const dev = n.nodeId === 'dev'
      const boss = !dev && type === 'boss'
      return {
        ...g,
        run: { ...g.run, node: null, phase: boss ? 'safehouse' : g.run.phase },
        meta: type && !dev ? { ...g.meta, seen: { ...g.meta.seen, [type]: true } } : g.meta,
      }
    }
    case 'jobAutoDone': {
      if (n?.kind !== 'job' || n.stage !== 'auto') return g
      const job = JOBS[n.jobId]
      // 武力委託一定要打；駭入、潛行失手被發現也要打
      if (job.direction === 'force' || !n.ok) return { ...g, run: { ...g.run, node: { ...n, stage: 'fight' } } }
      return finishJob(g, now, true)
    }
    case 'jobFight': {
      if (n?.kind !== 'job' || n.stage !== 'fight' || n.fight) return g
      const r = startFight(c, streetEnemy(JOBS[n.jobId]), a.tactic, hashSeed(c.id, n.nodeId, 'fight'))
      if (!r) return g
      return { ...g, character: r.c, run: { ...g.run, node: { ...n, fight: r.f } } }
    }
    case 'jobFightDone': {
      if (n?.kind !== 'job' || n.stage !== 'fight' || !n.fight) return g
      return finishJob(g, now, n.fight.won)
    }
    case 'eliteAutoDone': {
      if (n?.kind !== 'elite' || n.stage !== 'auto') return g
      const job = JOBS[n.jobId]
      return { ...g, character: { ...c, stress: c.stress + job.stress }, run: { ...g.run, node: { ...n, stage: 'fight' } } }
    }
    case 'eliteFight': {
      if (n?.kind !== 'elite' || n.stage !== 'fight' || n.fight) return g
      const r = startFight(c, highDanger(JOBS[n.jobId]).fight, a.tactic, hashSeed(c.id, n.nodeId, 'fight'))
      if (!r) return g
      return { ...g, character: r.c, run: { ...g.run, node: { ...n, fight: r.f } } }
    }
    case 'eliteFightDone': {
      if (n?.kind !== 'elite' || n.stage !== 'fight' || !n.fight) return g
      const f = n.fight
      const job = JOBS[n.jobId]
      if (f.won) {
        // 打贏一定掉寶（稀有表三選一）
        const ch = structuredClone(c)
        const log: LogEvent[] = []
        offerLoot(ch, eliteLoot(hashSeed(ch.id, n.nodeId, 'loot')), log, now, f.enemy.name)
        return withLog({ ...g, character: ch, run: { ...g.run, node: { ...n, stage: 'danger' } } }, ...log)
      }
      const reason = `你被${f.enemy.name}打退了，只能撤離。這份工作沒有報酬。`
      const lost = withLog(
        { ...g, run: { ...g.run, node: { ...n, stage: 'done', outcome: { kind: 'safe', reason } } } },
        { at: now, kind: 'warn', text: `${statusPrefix(c)} 「${job.name}」：${reason}` },
      )
      return withClaim(g, lost, { title: job.name, tone: 'fail', text: reason })
    }
    case 'eliteChoose': {
      if (n?.kind !== 'elite' || n.stage !== 'danger') return g
      const job = JOBS[n.jobId]
      const opt = highDanger(job).options.find((o) => o.id === a.optionId)
      if (!opt || attrLock(c, opt.attrNeeds)) return g
      const outcome = resolveDanger(c, opt, hashSeed(c.id, n.nodeId, 'danger'), g.systemFault)
      const r = settleLethal(g, now, outcome, {
        label: job.name,
        safeText: `你放棄了「${job.name}」，空手撤離。`,
        lossText: '這份工作的報酬沒了。',
        onSurvive: (ch, log) => {
          const reward = jobReward(job, perkReward(ch, job.direction))
          ch.credits += reward
          ch.heat = Math.min(5, ch.heat + job.heat)
          log.push({ at: now, kind: 'job', text: `${statusPrefix(ch)} 完成精英委託「${job.name}」。+${reward} 信用點，通緝 +${job.heat}。` })
          grantProgress(ch, job, true, now, log)
        },
      })
      const done = { ...r, run: { ...r.run, node: { ...n, stage: 'done' as const, outcome } } }
      const tone = outcome.kind === 'survived' ? 'success' : outcome.kind === 'safe' ? 'partial' : 'rescued'
      return withClaim(g, done, { title: job.name, tone, text: outcome.kind === 'safe' ? '你空手撤離，但打贏那一場拿到的戰利品還在。' : outcome.reason })
    }
    case 'eventChoose': {
      if (n?.kind !== 'event' || n.stage !== 'choose') return g
      const ev = EVENT_BY_ID[n.eventId]
      const o = ev.options.find((x) => x.id === a.optionId)
      if (!o || eventLock(c, o)) return g
      const seed = hashSeed(c.id, n.nodeId, o.id)
      const won = o.chance === undefined || rng(seed)() < o.chance
      const ch = structuredClone(c)
      ch.credits -= o.cost ?? 0
      const log: LogEvent[] = []
      const { text, rows } = applyEffects(ch, won ? o.win : (o.lose ?? o.win), hashSeed(seed, 'loot'), log, now, ev.title)
      if (o.cost) rows.unshift({ label: '花費', value: `−¢${o.cost}`, tone: 'bad' })
      if (o.chance !== undefined) rows.unshift({ label: '判定', value: `${won ? '成功' : '失敗'}（成功率 ${Math.round(o.chance * 100)}%）`, tone: won ? 'good' : 'bad' })
      log.unshift({ at: now, kind: 'system', text: `${statusPrefix(ch)} 「${ev.title}」：${text}${rowsText(rows)}` })
      return withLog({ ...g, character: ch, run: { ...g.run, node: { ...n, stage: 'done', text, rows } } }, ...log)
    }
    case 'marketBuy': {
      if (n?.kind !== 'market' || !c.alive) return g
      const item = n.stock[a.index]
      if (!item || c.credits < marketPrice(item.price)) return g
      const price = marketPrice(item.price)
      return withLog(
        { ...g, character: { ...c, credits: c.credits - price, stash: [...c.stash, item] }, run: { ...g.run, node: { ...n, stock: n.stock.filter((_, i) => i !== a.index) } } },
        { at: now, kind: 'system', text: `黑市：買下「${item.name}」（-${price} 信用點），放進背包。` },
      )
    }
    case 'buyLifeline': {
      if (n?.kind !== 'market' || !c.alive || c.credits < LIFELINE_PRICE) return g
      return withLog(
        { ...g, character: { ...c, credits: c.credits - LIFELINE_PRICE, lifelines: c.lifelines + 1 } },
        { at: now, kind: 'system', text: `黑市：買了一張救命保單（-${LIFELINE_PRICE} 信用點）。受致命傷時武裝醫療隊會救你一次。` },
      )
    }
    case 'sell': {
      // 背包與身上的都能賣；身上的義體由攤主當場拆下，負荷一併扣掉
      const worn = c.equipment.find((i) => i.id === a.itemId)
      const item = worn ?? c.stash.find((i) => i.id === a.itemId)
      if (n?.kind !== 'market' || !c.alive || !item) return g
      const drop = (xs: Item[]) => xs.filter((i) => i.id !== item.id)
      return withLog(
        { ...g, character: { ...c, stash: drop(c.stash), equipment: drop(c.equipment), implantLoad: c.implantLoad - (worn ? item.load : 0), credits: c.credits + sellValue(item) } },
        { at: now, kind: 'system', text: `黑市：賣掉${worn ? '身上的' : ''}「${item.name}」（+${sellValue(item)} 信用點）。` },
      )
    }
    case 'treat': {
      const cost = c.injury * CLINIC.perPoint
      if (n?.kind !== 'clinic' || !c.alive || c.credits < cost || (c.injury === 0 && c.stress === 0)) return g
      return withLog(
        { ...g, character: { ...c, credits: c.credits - cost, injury: 0, stress: Math.max(0, c.stress - CLINIC.stress) } },
        { at: now, kind: 'system', text: `神機醫白蛇幫你縫好了傷口（-${cost} 信用點，神經壓力 −${CLINIC.stress}）。` },
      )
    }
    case 'buyImplant': {
      // 神機醫的義體：買了直接裝上（裝不下就不賣），半價
      const def = ITEMS[a.kind]
      const price = def ? marketPrice(def.price) : 0
      if (n?.kind !== 'clinic' || !c.alive || !SHOP_IMPLANTS.includes(a.kind) || c.credits < price || implantRoom(c) < def.load) return g
      const item = makeItem(a.kind, `${n.nodeId}-${c.equipment.length}`)
      return withLog(
        { ...g, character: { ...c, credits: c.credits - price, equipment: [...c.equipment, item], implantLoad: c.implantLoad + item.load } },
        { at: now, kind: 'system', text: `白蛇幫你裝上了「${item.name}」（-${price} 信用點，義體負荷 +${item.load}）。` },
      )
    }
    case 'rest': {
      if (n?.kind !== 'rest' || n.used || !c.alive) return g
      const ch = { ...c, stress: Math.max(0, c.stress - REST.stress) }
      if (a.choice === 'heal') ch.injury = Math.max(0, c.injury - REST.heal)
      else ch.heat = Math.max(0, c.heat - REST.heat)
      const text = a.choice === 'heal' ? `你在膠囊旅館睡了一覺（傷勢 −${REST.heal}%）。` : `你在網咖躲了一晚，等 MPD 的注意力移開（通緝 −${REST.heat}）。`
      return withLog({ ...g, character: ch, run: { ...g.run, node: { ...n, used: true } } }, { at: now, kind: 'system', text: `${statusPrefix(ch)} ${text}` })
    }
    case 'storyApproach': {
      if (g.story.stage !== 'prep' || !g.story.caseId) return g
      const ap = CASE_BY_ID[g.story.caseId].approaches.find((x) => x.id === a.id)
      if (!ap || attrLock(c, ap.needs)) return g
      return { ...g, story: { ...g.story, stage: 'auto', approach: a.id } }
    }
    case 'storyAutoDone': {
      if (g.story.stage !== 'auto' || !g.story.caseId) return g
      const sc = CASE_BY_ID[g.story.caseId]
      const ap = sc.approaches.find((x) => x.id === g.story.approach) ?? sc.approaches[0]
      return {
        ...g,
        character: { ...c, injury: Math.min(100, c.injury + ap.injury), stress: c.stress + 6 },
        story: { ...g.story, stage: ap.fight ? 'fight' : 'danger' },
      }
    }
    case 'storyFight': {
      if (g.story.stage !== 'fight' || g.story.fight || !g.story.caseId) return g
      const sc = CASE_BY_ID[g.story.caseId]
      const r = startFight(c, fightEnemy(sc, g.story), a.tactic, hashSeed(c.id, sc.id, 'fight', g.story.option ?? ''))
      if (!r) return g
      return { ...g, character: r.c, story: { ...g.story, fight: r.f } }
    }
    case 'storyFightDone': {
      const f = g.story.fight
      if (g.story.stage !== 'fight' || !f || !g.story.caseId) return g
      const sc = CASE_BY_ID[g.story.caseId]
      if (g.story.option) {
        // 危險節點選了「打」：打贏＝生還；打輸才擲致命判定，沒死也只是被打退、沒有報酬
        const picked = sc.danger.options.find((o) => o.id === g.story.option)!
        if (f.won) return closeCase(g, now, sc, picked, { kind: 'survived', reason: picked.text }, true)
        const opt = caseDangerOption(c, sc, g.story.approach, picked.id)
        const o = resolveDanger(c, opt, hashSeed(c.id, sc.id, opt.id), g.systemFault)
        const lost = `你被${f.enemy.name}打倒在地，最後只能拖著傷撤退。委託失敗，沒有報酬。`
        return closeCase(g, now, sc, picked, o.kind === 'survived' ? { kind: 'safe', reason: lost } : o, false)
      }
      const ap = sc.approaches.find((x) => x.id === g.story.approach)!
      if (f.won) {
        const heat = ap.fightHeat ?? 0
        const ch = { ...c, heat: Math.min(5, c.heat + heat) }
        const log: LogEvent[] = heat ? [{ at: now, kind: 'warn', text: `${statusPrefix(ch)} 你打倒了${f.enemy.name}，MPD 記住了你的臉（通緝 +${heat}）。` }] : []
        return withLog({ ...g, character: ch, story: { ...g.story, stage: 'danger', fight: undefined } }, ...log)
      }
      const reason = `你被${f.enemy.name}打退了，只能先撤。委託失敗，沒有報酬。`
      const record: CaseRecord = { approach: g.story.approach ?? '', optionId: 'retreat', outcome: 'safe', reason }
      const lost = withLog(
        { ...g, story: { caseId: null, stage: 'prep' }, run: { ...g.run, cases: { ...g.run.cases, [sc.id]: record } } },
        { at: now, kind: 'warn', text: `${statusPrefix(c)} 「${sc.title}」：${reason}` },
      )
      return withClaim(g, lost, { title: sc.title, tone: 'fail', text: reason })
    }
    case 'storyChoose': {
      if (g.story.stage !== 'danger' || !g.story.caseId) return g
      const sc = CASE_BY_ID[g.story.caseId]
      const picked = sc.danger.options.find((o) => o.id === a.optionId)
      if (!picked || optionLock(c, g.story.approach, picked) !== undefined) return g
      if (picked.fight) return { ...g, story: { ...g.story, stage: 'fight', option: picked.id, fight: undefined } }
      const opt = caseDangerOption(c, sc, g.story.approach, picked.id)
      let outcome = resolveDanger(c, opt, hashSeed(c.id, sc.id, opt.id), g.systemFault)
      if (outcome.kind === 'safe' || outcome.kind === 'survived') outcome = { kind: picked.wins ? 'survived' : outcome.kind, reason: picked.text }
      return closeCase(g, now, sc, picked, outcome, true)
    }
    case 'claim': {
      // 收下完成單：之後才能離開節點，三選一也才跳出來
      if (!g.run.claim) return g
      return { ...g, run: { ...g.run, claim: null } }
    }
    case 'continue': {
      // 安全屋：前往下一個街區（新地圖，傭兵、卡牌、道具都帶著走）
      const next = nextDistrict(g)
      if (g.run.phase !== 'safehouse' || !c.alive || c.picks.length || !next) return g
      const index = g.run.districtIndex + 1
      return withLog(
        { ...g, run: { ...g.run, districtIndex: index, district: districtMap(g.run.seed, index), at: null, path: [], node: null, phase: 'map', events: [], claim: null } },
        { at: now, kind: 'level', text: `▶ 離開安全屋，前往${next.name}。` },
      )
    }
    case 'retire': {
      if (g.run.phase !== 'safehouse' || !c.alive || c.picks.length) return g
      const text = `你在安全屋收起了槍。魔都會記得「${c.name}」這個名字。`
      return endCareer(withLog(g, { at: now, kind: 'level', text: `★ 退休：${text}` }), 'retired', text, now)
    }
    case 'pickPerk': {
      // 名聲卡三選一：只能挑最前面那一組裡的卡
      const p = c.picks[0]
      if (!c.alive || p?.kind !== 'perk' || !perkOptions(c, p.seed).includes(a.id)) return g
      const def = PERKS[a.id]
      const lv = (c.perks[a.id] ?? 0) + (def.instant ? 0 : 1)
      const next: Character = {
        ...c,
        picks: c.picks.slice(1),
        perks: def.instant ? c.perks : { ...c.perks, [a.id]: lv },
        credits: c.credits + (def.instant === 'cash' ? PERK_CASH : 0),
        injury: def.instant === 'heal' ? 0 : c.injury,
      }
      const text = def.instant ? `◆ 名聲 Lv.${p.level}：${def.name}（${def.desc}）。` : `★ 名聲 Lv.${p.level}：拿到「${def.name}」${lv > 1 ? ` Lv.${lv}` : ''}（${def.desc}）。`
      return withLog({ ...g, character: next }, { at: now, kind: 'level', text })
    }
    case 'pickItem': {
      // 戰利品三選一：挑的那件放進背包，其他兩件不要了
      const p = c.picks[0]
      const item = p?.kind === 'item' ? p.options[a.index] : undefined
      if (!c.alive || !item || p?.kind !== 'item') return g
      return withLog(
        { ...g, character: { ...c, picks: c.picks.slice(1), stash: [...c.stash, item] } },
        { at: now, kind: 'gain', text: `◆ 從「${p.from}」的戰利品裡挑了「${item.name}」，放進背包。` },
      )
    }
    case 'equip': {
      // 從背包裝上：義體要裝得下；武器與駭客終端一次一件，換下來的放回背包
      const item = c.stash.find((i) => i.id === a.itemId)
      if (!c.alive || gearBusy(g) || !item) return g
      if (item.slot === 'implant' && implantRoom(c) < item.load) return g
      const swapped = item.slot === 'implant' ? [] : c.equipment.filter((i) => i.slot === item.slot)
      return withLog(
        {
          ...g,
          character: {
            ...c,
            stash: [...c.stash.filter((i) => i.id !== item.id), ...swapped],
            equipment: [...c.equipment.filter((i) => !swapped.includes(i)), item],
            implantLoad: c.implantLoad + item.load - swapped.reduce((s, i) => s + i.load, 0),
          },
        },
        { at: now, kind: 'system', text: `裝上「${item.name}」${swapped.length ? `，換下「${swapped[0].name}」` : ''}。` },
      )
    }
    case 'unequip': {
      const item = c.equipment.find((i) => i.id === a.itemId)
      if (!c.alive || gearBusy(g) || !item) return g
      return withLog(
        { ...g, character: { ...c, equipment: c.equipment.filter((i) => i.id !== item.id), stash: [...c.stash, item], implantLoad: c.implantLoad - item.load } },
        { at: now, kind: 'system', text: `卸下「${item.name}」，放進背包。` },
      )
    }
    case 'setLook':
      return g.character.alive ? { ...g, character: { ...g.character, look: a.look } } : g
    case 'raiseAttr': {
      // 分配屬性點：不能退回
      if (!c.alive || c.attrPoints <= 0 || c.attrs[a.attr] >= ATTR_MAX) return g
      return withLog(
        { ...g, character: { ...c, attrs: { ...c.attrs, [a.attr]: c.attrs[a.attr] + 1 }, attrPoints: c.attrPoints - 1 } },
        { at: now, kind: 'level', text: `★ ${ATTR_LABEL[a.attr]}提升到 ${c.attrs[a.attr] + 1}。` },
      )
    }
    case 'devTestCase': {
      // 開發工具：在地圖上（沒進節點時）直接跑一次測試案，可以重複
      if (n || !c.alive || g.run.phase !== 'map') return g
      const { [TEST_CASE.id]: _, ...cases } = g.run.cases
      return { ...g, story: { caseId: TEST_CASE.id, stage: 'prep' }, run: { ...g.run, cases, node: { kind: 'story', nodeId: 'dev', caseId: TEST_CASE.id } } }
    }
    case 'toggleFault':
      return { ...g, systemFault: !g.systemFault }
    case 'newCharacter': {
      if (c.alive && g.run.phase !== 'over') return g
      return initial(now, g.meta)
    }
    case 'reset':
      return initial(now)
  }
}

function load(): Game {
  const now = Date.now()
  let meta: Meta = { legends: [], seen: {} }
  try {
    const m = localStorage.getItem(META_KEY)
    if (m) meta = JSON.parse(m) as Meta
    const raw = localStorage.getItem(RUN_KEY)
    if (raw) {
      const g = JSON.parse(raw) as Omit<Game, 'meta'>
      // 加街區之前的存檔沒有 districtIndex：那時只有新宿
      if (g.v === 2) return { ...g, run: { ...g.run, districtIndex: g.run.districtIndex ?? 0 }, meta }
    }
  } catch {
    /* 存檔壞掉就重來 */
  }
  return initial(now, meta)
}

export function useGame() {
  const [g, dispatch] = useReducer(reduce, undefined, load)
  useEffect(() => {
    // 生涯（單一欄位）與跨生涯資料分開存；每走一步都存
    try {
      const { meta, ...run } = g
      localStorage.setItem(RUN_KEY, JSON.stringify(run))
      localStorage.setItem(META_KEY, JSON.stringify(meta))
    } catch {
      /* 私密模式等情況忽略 */
    }
  }, [g])
  const act = useCallback((a: Action) => dispatch(a), [])
  return { g, act }
}

export type { Action }
