import { useCallback, useEffect, useReducer } from 'react'
import {
  type Character,
  type DangerOption,
  type DangerOutcome,
  type Enemy,
  type FightResult,
  type Direction,
  type Item,
  type JobDef,
  type LogEvent,
  type Tactic,
  type Attr,
  addFame,
  addXp,
  approachBonus,
  attrLock,
  baseAttrs,
  grantProgress,
  hashSeed,
  heatEnemy,
  jobReward,
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
  addScar,
  jobFame,
  RISKY_FAME_MULT,
  scaledRisk,
  NEURAL_STAGE_LABEL,
  marginOf,
  neuralStage,
  rollPsycho,
  MAX_ITEM_LEVEL,
  UPGRADE_LOAD,
  upgradeCost,
  LIFELINES,
  lifelineOf,
  type LifelineTier,
  fameEnemy,
  type PoolResult,
  type CostKind,
  POOL_RESULT_LABEL,
  PUSH_STRESS,
  GAMBLE_HEAT,
  COST_PAY,
  CRIT_PAY,
  applyCost,
  costText,
  jobPool,
  poolSize,
  rollPool,
} from '../rules/core'
import { BEATS } from '../content/beats'
import { type District, type MapNode, type NodeType, STORY_LAYER, findNode, generateDistrict, reachable } from '../rules/map'
import { FIXERS, JOBS, JOB_LINES, OPENING, STARTER_GEAR, highDanger } from '../content/data'
import { ITEMS, SHOP_IMPLANTS, STARTER_CHOICES, clinicOrders, eliteLoot, itemLock, eventLoot, makeItem, marketPrice, marketStock, rollKind, streetLoot } from '../content/items'
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
  | {
      kind: 'job'
      nodeId: string
      jobId: string
      /** auto 開場 → scene 擲骰 → cost 選代價 → （fight 遭遇戰）→ done。 */
      stage: 'auto' | 'scene' | 'cost' | 'fight' | 'done'
      /** 現在第幾個場面（BEATS 的索引）。 */
      beat?: number
      /** 失敗幾次：駭入、潛行失敗兩次就被逮到、要打一場；武力每次失敗對手更硬。 */
      strikes?: number
      /** 成功的場面數、其中大成功幾次、選了幾次「報酬打折」。 */
      wins?: number
      crits?: number
      cuts?: number
      history?: BeatLog[]
      fight?: FightResult
      text?: string
      rows?: ResultRow[]
    }
  | { kind: 'elite'; nodeId: string; jobId: string; stage: 'auto' | 'fight' | 'danger' | 'done'; fight?: FightResult; outcome?: DangerOutcome }
  | { kind: 'event'; nodeId: string; eventId: string; stage: 'choose' | 'done'; text?: string; rows?: ResultRow[] }
  | { kind: 'market'; nodeId: string; stock: Item[] }
  | { kind: 'clinic'; nodeId: string }
  | { kind: 'rest'; nodeId: string; used?: boolean }
  | { kind: 'story'; nodeId: string; caseId: string }

/** 一個場面擲出來的結果（畫面與結算用）。 */
export interface BeatLog {
  beat: number
  dice: number[]
  result: PoolResult
  /** 付了什麼代價（成功但付代價、失敗）。 */
  cost?: string
}

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
    // 起始裝備第二件三選一，挑了直接裝上（挑完才能出發）
    picks: [{ kind: 'item', from: '起始裝備', options: structuredClone(STARTER_CHOICES), equip: true }],
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
  if (b.lifelines !== a.lifelines || b.lifelineTier !== a.lifelineTier) {
    const name = (x: Character) => (lifelineOf(x) ? LIFELINES[lifelineOf(x)!].label : '沒有')
    rows.push({ label: '救命保單', value: `${name(a)} → ${name(b)}`, tone: b.lifelines > a.lifelines ? 'good' : 'bad' })
  }
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
  return { ...opt, lethalBase: scaledRisk(opt.lethalBase + ap.lethalMod - approachBonus(c, ap.direction)) }
}

/** 精英委託的危險選項：和劇情案一樣，扣掉該方向的裝備與卡牌加成（下限 2%）。 */
export function eliteDangerOption(c: Character, job: JobDef, opt: DangerOption): DangerOption {
  if (!opt.lethal) return opt
  return { ...opt, lethalBase: scaledRisk(opt.lethalBase - approachBonus(c, job.direction)) }
}

/** 靠器材或屬性走的安全選項要付代價：報酬打七五折、名聲減半、神經壓力 +10。 */
export const SAFE_REWARD_RATE = 0.75
export const SAFE_FAME_RATE = 0.5
export const SAFE_STRESS = 10
/** 劇情案選項實際拿到的報酬（器材或屬性選項打折）；畫面與結案共用。 */
export const caseReward = (o: CaseOption) => (o.needs ? Math.round(o.reward * SAFE_REWARD_RATE) : o.reward)

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
  /** 舊傷扣哪條路線的屬性（SCAR_ATTR）。 */
  direction: Direction
  onSurvive: (c: Character, log: LogEvent[]) => void
}

/** 重傷生還或被救回：傷勢至少 70%，留下一道舊傷。直接改 c。 */
function scar(c: Character, dir: Direction, at: number, log: LogEvent[]) {
  c.injury = Math.max(c.injury, SEVERE_INJURY)
  const a = addScar(c, dir)
  log.push({ at, kind: 'hurt', text: `✚ 舊傷：${a ? `${ATTR_LABEL[a]} −1（${ATTR_LABEL[a]} ${c.attrs[a]}）` : '屬性已經不能再低了'}，傷勢 ${c.injury}%。` })
}

/**
 * 救命保單把你從死亡拖回來的帳單，依保單等級（LIFELINES）：廉價＝拆光義體、傷勢 90%、舊傷；
 * 標準＝拆光義體、傷勢 70%（沒有義體可拆就改留舊傷）；白金＝義體保留、傷勢 50%。保單用掉。直接改 c。
 */
function rescueBill(c: Character, dir: Direction, at: number, log: LogEvent[]) {
  const tier = lifelineOf(c) ?? 'standard'
  const t = LIFELINES[tier]
  c.lifelines = 0
  c.lifelineTier = undefined
  c.injury = Math.max(c.injury, t.injury)
  const taken = t.strip ? c.equipment.filter((i) => i.slot === 'implant') : []
  if (taken.length) {
    c.equipment = c.equipment.filter((i) => i.slot !== 'implant')
    c.implantLoad -= taken.reduce((s, i) => s + i.load, 0)
  }
  log.push({
    at,
    kind: 'hurt',
    text: `✚ ${t.label}的帳：${taken.length ? `武裝醫療隊拆走了你身上的義體抵費用（${taken.map((i) => i.name).join('、')}），` : t.strip ? '' : '義體一件不少，'}傷勢 ${c.injury}%。`,
  })
  if (t.scar || (t.strip && !taken.length)) scar(c, dir, at, log)
}

/** 這區的神機醫叫什麼。 */
const doctorName = (g: Game) => FIXERS[DISTRICTS[g.run.districtIndex].doctor.id].name

/** 拿到一張保單（事件、劇情案）：沒有就收下；已經有一張（最多一張）就轉手換錢。直接改 c，回傳結果文字。 */
function grantLifeline(c: Character, tier: LifelineTier): string {
  if (c.lifelines > 0) {
    c.credits += LIFELINE_RESALE
    return `你已經有保單了，這張轉手換了 ¢${LIFELINE_RESALE}`
  }
  c.lifelines = 1
  c.lifelineTier = tier
  return `${LIFELINES[tier].label}到手`
}
/** 已經有保單時，多拿到的那張轉手的價錢。 */
const LIFELINE_RESALE = 200

/**
 * 任務進行中的神經錯亂（神經餘裕 < 40）：依 seed 擲一次。重傷照樣繼續任務；中斷、被救、死亡則任務結束（stop）。
 * 死亡時直接寫進傳奇檔案。
 */
function psychoCheck(g: Game, now: number, seed: number, label: string, dir: Direction): { g: Game; stop: boolean } {
  const c = g.character
  const hit = rollPsycho(c, seed)
  if (!hit) return { g, stop: false }
  const ch = structuredClone(c)
  const log: LogEvent[] = []
  const stage = NEURAL_STAGE_LABEL[neuralStage(marginOf(c))]
  if (hit === 'maim') {
    log.push({ at: now, kind: 'hurt', text: `✚ 神經錯亂（${stage}）：「${label}」途中你失控了一陣子，回過神來滿手是血，有一部分是你自己的。` })
    scar(ch, dir, now, log)
    return { g: withLog({ ...g, character: ch }, ...log), stop: false }
  }
  if (hit === 'abort') {
    log.push({ at: now, kind: 'warn', text: `⚠ 神經錯亂（${stage}）：「${label}」途中你眼前一黑，回過神來已經在撤離的路上。任務中斷。` })
    return { g: withLog({ ...g, character: ch }, ...log), stop: true }
  }
  if (g.systemFault) {
    ch.injury = Math.max(ch.injury, 50)
    log.push({ at: now, kind: 'system', text: `✚ 神經錯亂造成的致命結果：武裝醫療隊免費搶救（系統補償）。任務中斷。` })
    return { g: withLog({ ...g, character: ch, notes: [...g.notes, `${label}：神經錯亂，緊急搶救（系統補償）`] }, ...log), stop: true }
  }
  if (ch.lifelines > 0) {
    log.push({ at: now, kind: 'hurt', text: `✚ 神經錯亂（${stage}）：「${label}」途中你的心跳停了。救命保單觸發，武裝醫療隊把你拖回來（保單用掉了）。任務中斷。` })
    rescueBill(ch, dir, now, log)
    return { g: withLog({ ...g, character: ch }, ...log), stop: true }
  }
  ch.alive = false
  const cause = `神經錯亂（${stage}）：「${label}」途中你的心跳停了，身上沒有救命保單。`
  log.push({ at: now, kind: 'stop', text: `✖ 你死了：${cause}` })
  return { g: endCareer(withLog({ ...g, character: ch }, ...log), 'dead', cause, now), stop: true }
}

/** 任務因錯亂中斷：節點或劇情案直接結束，沒有報酬。 */
const PSYCHO_ABORT = '神經錯亂，任務中斷。沒有報酬。'

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
  else if (outcome.kind === 'maimed') {
    ctx.onSurvive(character, log)
    log.push({ at: now, kind: 'hurt', text: `✚ ${outcome.reason}` })
    scar(character, ctx.direction, now, log)
  } else if (outcome.kind === 'rescued') {
    log.push({ at: now, kind: 'hurt', text: `✚ ${outcome.reason}${ctx.lossText}` })
    rescueBill(character, ctx.direction, now, log)
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
  // 重傷生還也算撐過去：報酬、名聲、掉寶照拿，代價是舊傷
  const made = outcome.kind === 'survived' || outcome.kind === 'maimed'
  const paid = (ch: Character, log: LogEvent[]) => {
    if (!pay) return
    const reward = caseReward(picked)
    ch.credits += reward
    ch.heat = Math.min(5, ch.heat + (picked.heat ?? 0))
    if (picked.needs) ch.stress += SAFE_STRESS
    if (picked.heal) ch.injury = 0
    const lifeline = picked.lifeline ? grantLifeline(ch, 'standard') : ''
    const parts = [
      reward ? `+${reward} 信用點${reward !== picked.reward ? '（靠器材或屬性：打七五折、名聲減半）' : ''}` : '沒有報酬',
      picked.heat ? `通緝 +${picked.heat}` : '',
      picked.needs ? `神經壓力 +${SAFE_STRESS}` : '',
      picked.heal ? '傷口縫好了' : '',
      lifeline,
    ]
    log.push({ at: now, kind: picked.reward ? 'job' : 'warn', text: `${statusPrefix(ch)} 「${sc.title}」結案：${parts.filter(Boolean).join('，')}。` })
    addXp(ch, sc.xp, now, log)
    // 名聲：冒險生還是經驗的 2 倍，其他有結案的是一半
    const fame = made ? sc.xp * 2 : Math.round(sc.xp / 2)
    const rate = picked.needs ? SAFE_FAME_RATE : made && picked.lethal ? RISKY_FAME_MULT : 1
    addFame(ch, Math.round(fame * rate), now, log)
    if (made)
      for (const l of sc.loot ?? []) offerLoot(ch, rollKind(hashSeed(ch.id, sc.id, 'reward', l.kind), l.kind, l.chance, ch), log, now, sc.title)
  }
  const direction = sc.approaches.find((x) => x.id === g.story.approach)?.direction ?? sc.approaches[0].direction
  let next = settleLethal(g, now, outcome, { label: sc.title, safeText: outcome.reason, lossText: sc.lossText, direction, onSurvive: paid })
  if (outcome.kind === 'safe') {
    // 不冒險也算結案；有部分報酬就照付
    const ch = structuredClone(next.character)
    const log: LogEvent[] = []
    paid(ch, log)
    next = withLog({ ...next, character: ch }, ...log)
  }
  if (sc.broadcast && next.character.alive)
    next = withLog(next, { at: now, kind: 'system', text: made ? sc.broadcast.survived : sc.broadcast.other })
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

/** 委託／精英委託節點會是哪件工作：只依傭兵與節點的 seed，地圖上就能先告訴玩家。 */
export function nodeJob(g: Game, node: MapNode): JobDef | undefined {
  if (node.type !== 'job' && node.type !== 'elite') return undefined
  return pickJob(hashSeed(g.character.id, node.id), node.layer, node.type === 'elite', DISTRICTS[g.run.districtIndex])
}

/** 這個街區的事件裡，這段生涯還沒出現過的；全部出現過就重頭來。 */
function pickEvent(seed: number, used: string[], d: DistrictDef) {
  const all = d.events.map((id) => EVENT_BY_ID[id])
  const pool = all.filter((e) => !used.includes(e.id))
  const from = pool.length ? pool : all
  return from[Math.floor(rng(seed)() * from.length)]
}

/** 一般委託自動段的文字。 */
export function jobLines(jobId: string): string[] {
  const job = JOBS[jobId]
  return [...OPENING[job.direction](job.name), JOB_LINES[job.direction].mid]
}

type JobNodeRun = Extract<NodeRun, { kind: 'job' }>

/** 委託的遭遇戰對手。武力委託：前面每個成功的場面讓對方 HP −12%（大成功再 −12%），每次失敗 +15%。 */
export function jobEnemy(job: JobDef, n: Pick<JobNodeRun, 'wins' | 'crits' | 'strikes'>): Enemy {
  const e = streetEnemy(job)
  if (job.direction !== 'force') return e
  const k = Math.max(0.5, 1 - 0.12 * ((n.wins ?? 0) + (n.crits ?? 0)) + 0.15 * (n.strikes ?? 0))
  return { ...e, hp: Math.round(e.hp * k) }
}

/** 通緝已經滿了就改付神經壓力。 */
const realCost = (c: Character, k: CostKind): CostKind => (k === 'heat' && c.heat >= 5 ? 'stress' : k)

/** 一個場面結束：往下一個場面；駭入、潛行失敗兩次就被逮到要打；場面走完，武力開打、其他直接完成。 */
function advanceJob(g: Game, now: number, n: JobNodeRun): Game {
  const job = JOBS[n.jobId]
  const next: JobNodeRun = { ...n, beat: (n.beat ?? 0) + 1, stage: 'scene' }
  const put = (node: JobNodeRun): Game => ({ ...g, run: { ...g.run, node } })
  if (job.direction !== 'force' && (next.strikes ?? 0) >= 2) return put({ ...next, stage: 'fight' })
  if ((next.beat ?? 0) < BEATS[job.direction].length) return put(next)
  if (job.direction === 'force') return put({ ...next, stage: 'fight' })
  return finishJob(put(next), now, true)
}

/** 事件選項能不能選：不夠錢或屬性不夠回傳原因。 */
export function eventLock(c: Character, o: EventOption): string | undefined {
  if (o.cost && c.credits < o.cost) return `需要 ¢${o.cost}`
  if (o.fame && c.fame.level < o.fame) return `需要名聲 Lv.${o.fame}（現在 Lv.${c.fame.level}）`
  return attrLock(c, o.needs)
}

const signed = (n: number) => `${n > 0 ? '+' : ''}${n}`

/** 套用事件效果，回傳結果文字與一列一列的變化。直接改 c。 */
function applyEffects(c: Character, e: Effects, seed: number, log: LogEvent[], at: number, from: string): { text: string; rows: ResultRow[] } {
  c.credits = Math.max(0, c.credits + (e.credits ?? 0))
  c.injury = Math.max(0, Math.min(100, c.injury + (e.injury ?? 0)))
  c.heat = Math.max(0, Math.min(5, c.heat + (e.heat ?? 0)))
  c.stress = Math.max(0, c.stress + (e.stress ?? 0))
  const lifeline = e.lifeline ? grantLifeline(c, 'basic') : ''
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
  if (lifeline) rows.push({ label: '救命保單', value: lifeline, tone: 'good' })
  if (e.loot) rows.push({ label: '戰利品', value: '三選一', tone: 'warn' })
  return { text: e.text, rows }
}

/** 紀錄用：把結算列接成一句。 */
const rowsText = (rows: ResultRow[]) => (rows.length ? `（${rows.map((r) => `${r.label} ${r.value}`).join('，')}）` : '')

type Action =
  | { t: 'move'; nodeId: string }
  | { t: 'leave' }
  | { t: 'jobAutoDone' }
  | { t: 'jobRoll'; push: boolean; gamble: boolean }
  | { t: 'jobCost'; index: number }
  | { t: 'jobFight'; tactic: Tactic }
  | { t: 'jobFightDone' }
  | { t: 'eliteAutoDone' }
  | { t: 'eliteFight'; tactic: Tactic }
  | { t: 'eliteFightDone' }
  | { t: 'eliteChoose'; optionId: string }
  | { t: 'eventChoose'; optionId: string }
  | { t: 'marketBuy'; index: number }
  | { t: 'buyLifeline'; tier: LifelineTier }
  | { t: 'sell'; itemId: string }
  | { t: 'treat' }
  | { t: 'buyImplant'; kind: string }
  | { t: 'upgradeImplant'; itemId: string }
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
    const job = nodeJob(g, node)!
    n = node.type === 'job' ? { kind: 'job', nodeId, jobId: job.id, stage: 'auto' } : { kind: 'elite', nodeId, jobId: job.id, stage: 'auto' }
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
  // 傷勢、通緝已經在各場面的代價裡付過；這裡只算報酬：選過「報酬打折」的少拿，大成功多拿
  const full = jobReward(job, perkReward(c, job.direction))
  const reward = Math.round(full * (won ? Math.max(0.2, 1 - COST_PAY * (n.cuts ?? 0) + CRIT_PAY * (n.crits ?? 0)) : 0.3))
  // 開打前的傷勢（戰鬥已經改過 c.injury）
  const startInjury = n.fight ? Math.round(100 - (n.fight.hpStart * 100) / n.fight.maxHp) : before.injury
  c.stress += job.stress
  c.credits += reward
  const picksBefore = c.picks.length
  // 掉寶只看有沒有完成，不看有沒有開打：駭入、潛行安靜得手也一樣有機會
  if (won) offerLoot(c, streetLoot(hashSeed(c.id, n.nodeId, 'loot'), job.tier, c), log, now, job.name)
  const looted = c.picks.length > picksBefore
  grantProgress(c, job, won, now, log)
  const f = n.fight
  const rows: ResultRow[] = [
    { label: '結果', value: won ? '完成' : '失手', tone: won ? 'good' : 'bad' },
    { label: '報酬', value: `+¢${reward}${won ? (reward !== full ? `（原本 ¢${full}）` : '') : '（只拿到三成）'}`, tone: 'good' },
    ...(n.history ?? []).map((h) => {
      const tone: ResultRow['tone'] = h.result === 'fail' ? 'bad' : h.result === 'cost' ? 'warn' : 'good'
      return { label: BEATS[job.direction][h.beat].title, value: `${h.dice.join(' ')} → ${POOL_RESULT_LABEL[h.result]}${h.cost ? `：${h.cost}` : ''}`, tone }
    }),
    ...(f ? [{ label: '戰鬥', value: `${f.enemy.name}・${tacticsFor(c).find((t) => t.id === f.tactic)!.label}・${f.won ? '打贏' : '被打退'}・HP ${f.hpStart}→${f.hp}`, tone: f.won ? 'good' : 'bad' } as ResultRow] : []),
    ...(c.injury !== startInjury ? [{ label: '傷勢', value: `${startInjury}% → ${c.injury}%`, tone: 'bad' } as ResultRow] : []),
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
      const p = psychoCheck(g, now, hashSeed(c.id, n.nodeId, 'psycho'), job.name, job.direction)
      if (p.stop) {
        const rows: ResultRow[] = [{ label: '結果', value: '任務中斷（神經錯亂）', tone: 'bad' }]
        const after = { ...p.g, run: { ...p.g.run, node: { ...n, stage: 'done' as const, text: PSYCHO_ABORT, rows } } }
        return withClaim(g, after, { title: job.name, tone: 'fail', text: PSYCHO_ABORT })
      }
      return { ...p.g, run: { ...p.g.run, node: { ...n, stage: 'scene', beat: 0 } } }
    }
    case 'jobRoll': {
      // 擲這個場面的骰池；擲之前可以硬撐（神經壓力）或鋌而走險（通緝）各加一顆
      if (n?.kind !== 'job' || n.stage !== 'scene') return g
      const job = JOBS[n.jobId]
      const at = n.beat ?? 0
      const beat = BEATS[job.direction][at]
      const gamble = a.gamble && c.heat < 5
      const ch = structuredClone(c)
      if (a.push) ch.stress += PUSH_STRESS
      if (gamble) ch.heat += GAMBLE_HEAT
      const roll = rollPool(poolSize(jobPool(c, job, beat.attr), (a.push ? 1 : 0) + (gamble ? 1 : 0)), hashSeed(c.id, n.nodeId, 'beat', at))
      const entry: BeatLog = { beat: at, dice: roll.dice, result: roll.result }
      const said: LogEvent = { at: now, kind: roll.result === 'fail' ? 'hurt' : 'job', text: `「${job.name}」${beat.title}：擲出 ${roll.dice.join('、')}，${POOL_RESULT_LABEL[roll.result]}。${beat.out[roll.result]}` }
      const history = [...(n.history ?? []), entry]
      if (roll.result === 'cost') return withLog({ ...g, character: ch, run: { ...g.run, node: { ...n, history, stage: 'cost' } } }, said)
      if (roll.result === 'fail') {
        const k = realCost(ch, beat.fail)
        applyCost(ch, job, k, true)
        entry.cost = costText(job, k, true)
        return advanceJob(withLog({ ...g, character: ch }, said), now, { ...n, history, strikes: (n.strikes ?? 0) + 1 })
      }
      return advanceJob(withLog({ ...g, character: ch }, said), now, { ...n, history, wins: (n.wins ?? 0) + 1, crits: (n.crits ?? 0) + (roll.result === 'crit' ? 1 : 0) })
    }
    case 'jobCost': {
      // 成功但付代價：二選一
      if (n?.kind !== 'job' || n.stage !== 'cost') return g
      const job = JOBS[n.jobId]
      const pick = BEATS[job.direction][n.beat ?? 0].costs[a.index]
      if (!pick) return g
      const k = realCost(c, pick.kind)
      const ch = structuredClone(c)
      applyCost(ch, job, k)
      const history = (n.history ?? []).map((h, i, all) => (i === all.length - 1 ? { ...h, cost: `${pick.text}（${costText(job, k)}）` } : h))
      const said: LogEvent = { at: now, kind: 'warn', text: `代價：${pick.text}（${costText(job, k)}）。` }
      return advanceJob(withLog({ ...g, character: ch }, said), now, { ...n, history, wins: (n.wins ?? 0) + 1, cuts: (n.cuts ?? 0) + (k === 'pay' ? 1 : 0) })
    }
    case 'jobFight': {
      if (n?.kind !== 'job' || n.stage !== 'fight' || n.fight) return g
      const r = startFight(c, jobEnemy(JOBS[n.jobId], n), a.tactic, hashSeed(c.id, n.nodeId, 'fight'))
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
      const p = psychoCheck(g, now, hashSeed(c.id, n.nodeId, 'psycho'), job.name, job.direction)
      if (p.stop) {
        const after = { ...p.g, run: { ...p.g.run, node: { ...n, stage: 'done' as const, outcome: { kind: 'safe' as const, reason: PSYCHO_ABORT } } } }
        return withClaim(g, after, { title: job.name, tone: 'fail', text: PSYCHO_ABORT })
      }
      const ch = p.g.character
      return { ...p.g, character: { ...ch, stress: ch.stress + job.stress }, run: { ...p.g.run, node: { ...n, stage: 'fight' } } }
    }
    case 'eliteFight': {
      if (n?.kind !== 'elite' || n.stage !== 'fight' || n.fight) return g
      const r = startFight(c, fameEnemy(highDanger(JOBS[n.jobId]).fight, c.fame.level), a.tactic, hashSeed(c.id, n.nodeId, 'fight'))
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
      const raw = highDanger(job).options.find((o) => o.id === a.optionId)
      if (!raw || attrLock(c, raw.attrNeeds)) return g
      const opt = eliteDangerOption(c, job, raw)
      const outcome = resolveDanger(c, opt, hashSeed(c.id, n.nodeId, 'danger'), g.systemFault)
      const r = settleLethal(g, now, outcome, {
        label: job.name,
        safeText: `你放棄了「${job.name}」，空手撤離。`,
        lossText: '這份工作的報酬沒了。',
        direction: job.direction,
        onSurvive: (ch, log) => {
          const full = jobReward(job, perkReward(ch, job.direction))
          const reward = opt.attrNeeds ? Math.round(full * SAFE_REWARD_RATE) : full
          if (opt.attrNeeds) ch.stress += SAFE_STRESS
          ch.credits += reward
          ch.heat = Math.min(5, ch.heat + job.heat)
          log.push({ at: now, kind: 'job', text: `${statusPrefix(ch)} 完成精英委託「${job.name}」。+${reward} 信用點${opt.attrNeeds ? `（靠屬性：打七五折、名聲減半、神經壓力 +${SAFE_STRESS}）` : ''}，通緝 +${job.heat}。` })
          addXp(ch, job.xp, now, log)
          addFame(ch, Math.round(jobFame(job) * (opt.attrNeeds ? SAFE_FAME_RATE : RISKY_FAME_MULT)), now, log)
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
      // 最多一張：身上有保單就不賣
      const t = LIFELINES[a.tier]
      if (n?.kind !== 'market' || !c.alive || !t || c.lifelines > 0 || c.credits < t.price) return g
      return withLog(
        { ...g, character: { ...c, credits: c.credits - t.price, lifelines: 1, lifelineTier: a.tier } },
        { at: now, kind: 'system', text: `黑市：買了一張${t.label}（-${t.price} 信用點）。受致命傷時武裝醫療隊會救你一次：${t.desc}。` },
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
        { at: now, kind: 'system', text: `神機醫${doctorName(g)}幫你縫好了傷口（-${cost} 信用點，神經壓力 −${CLINIC.stress}）。` },
      )
    }
    case 'buyImplant': {
      // 神機醫的義體：常備的打七五折，訂製的（這次的三種）原價。買了直接裝上；屬性還不夠就先放背包。
      // 裝多少都行，代價是神經餘裕
      if (n?.kind !== 'clinic' || !c.alive) return g
      const basic = SHOP_IMPLANTS.includes(a.kind)
      const order = clinicOrders(hashSeed(c.id, n.nodeId, 'orders')).find((i) => i.kind === a.kind)
      if (!basic && !order) return g
      const price = basic ? marketPrice(ITEMS[a.kind].price) : ITEMS[a.kind].price
      if (c.credits < price) return g
      const item = makeItem(a.kind, `${n.nodeId}-${c.equipment.length + c.stash.length}`)
      if (itemLock(c, item))
        return withLog(
          { ...g, character: { ...c, credits: c.credits - price, stash: [...c.stash, item] } },
          { at: now, kind: 'system', text: `你買下了「${item.name}」（-${price} 信用點）。${itemLock(c, item)}，${doctorName(g)}先幫你包起來，放進背包。` },
        )
      return withLog(
        { ...g, character: { ...c, credits: c.credits - price, equipment: [...c.equipment, item], implantLoad: c.implantLoad + item.load } },
        { at: now, kind: 'system', text: `${doctorName(g)}幫你裝上了「${item.name}」（-${price} 信用點，義體負荷 +${item.load}）。` },
      )
    }
    case 'upgradeImplant': {
      // 神機醫升級身上的義體：效果 +0.5 倍、負荷 +10，最多 Lv.3
      const item = c.equipment.find((i) => i.id === a.itemId)
      if (n?.kind !== 'clinic' || !c.alive || !item || item.slot !== 'implant' || (item.level ?? 1) >= MAX_ITEM_LEVEL) return g
      const cost = upgradeCost(item)
      if (c.credits < cost) return g
      const up = { ...item, level: (item.level ?? 1) + 1, load: item.load + UPGRADE_LOAD }
      return withLog(
        {
          ...g,
          character: { ...c, credits: c.credits - cost, equipment: c.equipment.map((i) => (i.id === item.id ? up : i)), implantLoad: c.implantLoad + UPGRADE_LOAD },
        },
        { at: now, kind: 'system', text: `${doctorName(g)}把「${item.name}」調到 Lv.${up.level}（-${cost} 信用點，義體負荷 +${UPGRADE_LOAD}）。` },
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
      const p = psychoCheck(g, now, hashSeed(c.id, sc.id, 'psycho'), sc.title, ap.direction)
      if (p.stop) {
        const record: CaseRecord = { approach: ap.id, optionId: 'psycho', outcome: 'safe', reason: PSYCHO_ABORT }
        const after = { ...p.g, story: { caseId: null, stage: 'prep' as const }, run: { ...p.g.run, cases: { ...p.g.run.cases, [sc.id]: record } } }
        return withClaim(g, after, { title: sc.title, tone: 'fail', text: PSYCHO_ABORT })
      }
      const ch = p.g.character
      return {
        ...p.g,
        character: { ...ch, injury: Math.min(100, ch.injury + ap.injury), stress: ch.stress + 6 },
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
        return closeCase(g, now, sc, picked, o.kind === 'survived' ? { kind: 'safe', reason: lost } : o.kind === 'maimed' ? { kind: 'maimed', reason: `${lost}${o.reason}` } : o, false)
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
      else if (outcome.kind === 'maimed') outcome = { kind: 'maimed', reason: `${picked.text}${outcome.reason}` }
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
        { ...g, run: { ...g.run, districtIndex: index, district: districtMap(g.run.seed, index), at: null, path: [], node: null, phase: 'map', claim: null } }, // 遇過的事件跟著生涯走，下一區不會再遇到
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
      if (p.equip)
        return withLog(
          { ...g, character: { ...c, picks: c.picks.slice(1), equipment: [...c.equipment, item], implantLoad: c.implantLoad + item.load } },
          { at: now, kind: 'gain', text: `◆ 起始裝備：裝上「${item.name}」。` },
        )
      return withLog(
        { ...g, character: { ...c, picks: c.picks.slice(1), stash: [...c.stash, item] } },
        { at: now, kind: 'gain', text: `◆ 從「${p.from}」的戰利品裡挑了「${item.name}」，放進背包。` },
      )
    }
    case 'equip': {
      // 從背包裝上：要過屬性門檻；義體不限數量；武器與駭客終端一次一件，換下來的放回背包
      const item = c.stash.find((i) => i.id === a.itemId)
      if (!c.alive || gearBusy(g) || !item || itemLock(c, item)) return g
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
