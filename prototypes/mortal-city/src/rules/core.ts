// 純規則：不碰 DOM、不讀時鐘，所有時間都由呼叫端傳入，方便 M2 搬到伺服器。
// 數值來源：docs/cyberpunk-text-mmo/quest-layers.md、risk-systems.md §4（試算起始值）。

export type Direction = 'force' | 'hack' | 'stealth'

export const DIRECTION_LABEL: Record<Direction, string> = {
  force: '火力',
  hack: '入侵',
  stealth: '潛行',
}

/** 可重現的亂數：同一個 seed 永遠得到同一串結果，重整不重抽。 */
export function rng(seed: number) {
  let a = seed >>> 0
  return () => {
    a = (a + 0x6d2b79f5) >>> 0
    let t = a
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

export function hashSeed(...parts: (string | number)[]) {
  let h = 2166136261
  for (const ch of parts.join('|')) {
    h ^= ch.charCodeAt(0)
    h = Math.imul(h, 16777619)
  }
  return h >>> 0
}

// ---------- 神經負荷 ----------

export const NEURAL = { base: 100, perLevel: 4 }

export type NeuralStage = 'stable' | 'alert' | 'critical' | 'lost'
export const NEURAL_STAGE_LABEL: Record<NeuralStage, string> = {
  stable: '穩定',
  alert: '警戒',
  critical: '臨界',
  lost: '失控',
}

export function neuralCapacity(level: number) {
  return NEURAL.base + NEURAL.perLevel * (level - 1)
}

export function neuralMargin(level: number, implantLoad: number, stress: number) {
  return neuralCapacity(level) - implantLoad - stress
}

export function neuralStage(margin: number): NeuralStage {
  if (margin >= 40) return 'stable'
  if (margin >= 20) return 'alert'
  if (margin >= 1) return 'critical'
  return 'lost'
}

// ---------- 熟練度（上限 100，越重要的屬性每級越少） ----------

export const PROF_MAX = 100

export function proficiencyEffects(level: number) {
  const lv = Math.max(0, Math.min(PROF_MAX, level))
  return {
    success: 0.0005 * lv, // +5% @100
    harm: 0.0015 * lv, // −15% @100（傷勢與暴露）
    reward: 0.0025 * lv, // +25% @100
    time: 0.004 * lv, // −40% @100
  }
}

/** 每級所需熟練經驗：越後面越慢。 */
export function profXpToNext(level: number) {
  return 3 + Math.floor(level / 10) * 2
}

// ---------- 街頭工作 ----------

export interface JobDef {
  id: string
  direction: Direction
  tier: 1 | 2 | 3 | 4 | 5
  name: string
  fixerId: string
  minutes: number
  reward: number
  xp: number
  stress: number
  heat: number
  injury: number
  blurb: string
}

/** 第 4 階起可能永久死亡，只能在線手動接。 */
export const LETHAL_TIER = 4

export function isLethal(job: JobDef) {
  return job.tier >= LETHAL_TIER
}

export function jobDurationMs(job: JobDef, profLevel: number) {
  return Math.round(job.minutes * 60_000 * (1 - proficiencyEffects(profLevel).time))
}

export function jobReward(job: JobDef, profLevel: number) {
  return Math.round(job.reward * (1 + proficiencyEffects(profLevel).reward))
}

export function jobSuccessChance(job: JobDef, profLevel: number, statBonus = 0) {
  const base = 0.92 - job.tier * 0.06
  return Math.max(0.05, Math.min(0.98, base + statBonus + proficiencyEffects(profLevel).success))
}

// ---------- 週榜同類遞減（中等：前 20 件滿分、21～40 件 50%、之後 20%） ----------

export function weeklyPoints(tier: number, priorSameKindThisWeek: number) {
  const base = 10 * tier
  const mult = priorSameKindThisWeek < 20 ? 1 : priorSameKindThisWeek < 40 ? 0.5 : 0.2
  return Math.round(base * mult)
}

/** 週界線：週一 UTC 00:00。 */
export function weekKey(ms: number) {
  const d = new Date(ms)
  const day = (d.getUTCDay() + 6) % 7
  const monday = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() - day)
  return new Date(monday).toISOString().slice(0, 10)
}

// ---------- 裝備與抵押 ----------

export type Slot = 'weapon' | 'deck' | 'implant'
export const SLOT_LABEL: Record<Slot, string> = { weapon: '武器', deck: '作業設備', implant: '義體' }

export interface Item {
  id: string
  name: string
  slot: Slot
  direction: Direction // 對這個方向的工作有成功率加成
  bonus: number // 例如 0.05 = +5%
  price: number
  load: number // 義體負荷（只有義體會有）
}

/** 抵押價＝售價的 60%；贖回價＝抵押價（不收利息）。試算值，見 risk-systems §3。 */
export const PAWN_RATE = 0.6

export function pawnValue(item: Item) {
  return Math.round(item.price * PAWN_RATE)
}

export interface Pawned {
  item: Item
  redeem: number
}

export function equipBonus(c: Character, d: Direction) {
  return c.equipment.filter((i) => i.direction === d).reduce((s, i) => s + i.bonus, 0)
}

export type BillResult =
  | { ok: true; character: Character; pawned: Item[] }
  | { ok: false; character: Character; shortfall: number; total: number }

/**
 * 付救援帳單：先用現金；不夠就從價值最高的裝備開始抵押，押到夠為止，多出來的錢回到身上。
 * 現金加上全部裝備的抵押價還不夠，就付不起（救援不出勤，角色死亡）。
 */
export function payBill(start: Character, bill: number): BillResult {
  const total = start.credits + start.equipment.reduce((s, i) => s + pawnValue(i), 0)
  if (total < bill) return { ok: false, character: start, shortfall: bill - total, total }
  const c: Character = structuredClone(start)
  let owe = Math.max(0, bill - c.credits)
  c.credits = Math.max(0, c.credits - bill)
  const pawned: Item[] = []
  const order = [...c.equipment].sort((a, b) => pawnValue(b) - pawnValue(a))
  for (const item of order) {
    if (owe <= 0) break
    const v = pawnValue(item)
    owe -= v
    pawned.push(item)
    c.equipment = c.equipment.filter((i) => i.id !== item.id)
    c.implantLoad -= item.load
    c.pawned.push({ item, redeem: v })
  }
  if (owe < 0) c.credits += -owe
  return { ok: true, character: c, pawned }
}

/** 贖回抵押的裝備：付抵押價，裝備回到身上（同欄位已有新裝備時也照樣放回，原型不處理換裝）。 */
export function redeem(start: Character, itemId: string): Character | null {
  const p = start.pawned.find((x) => x.item.id === itemId)
  if (!p || start.credits < p.redeem) return null
  const c: Character = structuredClone(start)
  c.credits -= p.redeem
  c.pawned = c.pawned.filter((x) => x.item.id !== itemId)
  c.equipment.push(p.item)
  c.implantLoad += p.item.load
  return c
}

// ---------- 角色與排隊結算 ----------

export interface Character {
  id: string
  name: string
  alive: boolean
  level: number
  xp: number
  credits: number
  injury: number // 0～100
  stress: number
  implantLoad: number
  heat: number // 通緝 0～5
  prof: Record<Direction, { level: number; xp: number }>
  equipment: Item[]
  pawned: Pawned[]
  /** 本週各工作（id）已完成件數，用於同類遞減。 */
  week: { key: string; counts: Record<string, number>; points: number }
}

export interface StopRules {
  injuryAt: number // 傷勢達到就停
  heatAt: number // 通緝達到就停
  stopOnCritical: boolean // 神經進入臨界就停
  creditReserve: number // 信用點低於這個數就停
}

export const DEFAULT_STOP: StopRules = { injuryAt: 60, heatAt: 3, stopOnCritical: true, creditReserve: 0 }

export interface Queue {
  items: string[] // 尚未完成的工作 id，第一個是正在做的
  startedAt: number | null // 第一件開始的時間
  paused: boolean // 劇情委託進行中：正在做的那件做完，下一件等劇情結束
  seq: number // 已結算件數，用於亂數 seed
}

export type LogKind = 'job' | 'gain' | 'hurt' | 'warn' | 'stop' | 'level' | 'system'

export interface LogEvent {
  at: number
  kind: LogKind
  text: string
}

export function xpToNext(level: number) {
  return 40 + level * 25
}

export function statusPrefix(c: Character) {
  const m = neuralMargin(c.level, c.implantLoad, c.stress)
  return `[傷勢 ${c.injury}% / 神經 ${NEURAL_STAGE_LABEL[neuralStage(m)]} / 通緝 ${c.heat}★]`
}

function stopReason(c: Character, rules: StopRules): string | null {
  if (c.injury >= rules.injuryAt) return `傷勢 ${c.injury}% 達到停止門檻 ${rules.injuryAt}%`
  if (c.heat >= rules.heatAt) return `通緝 ${c.heat}★ 達到停止門檻 ${rules.heatAt}★`
  const stage = neuralStage(neuralMargin(c.level, c.implantLoad, c.stress))
  if (rules.stopOnCritical && (stage === 'critical' || stage === 'lost'))
    return `神經負荷進入${NEURAL_STAGE_LABEL[stage]}`
  if (c.credits < rules.creditReserve) return `信用點低於保留額 ${rules.creditReserve}`
  return null
}

/**
 * 一件工作完成後的成長：經驗、熟練度、等級、週榜積分（同類遞減）。直接改 c，回傳這件的週榜積分。
 * 排隊結算與高階手動工作共用。
 */
export function grantProgress(c: Character, job: JobDef, ok: boolean, at: number, events: LogEvent[]) {
  c.xp += ok ? job.xp : Math.round(job.xp / 3)
  const p = c.prof[job.direction]
  p.xp += 1
  while (p.level < PROF_MAX && p.xp >= profXpToNext(p.level)) {
    p.xp -= profXpToNext(p.level)
    p.level += 1
    events.push({ at, kind: 'level', text: `★ ${DIRECTION_LABEL[job.direction]}熟練度提升到 ${p.level}。` })
  }
  while (c.xp >= xpToNext(c.level)) {
    c.xp -= xpToNext(c.level)
    c.level += 1
    events.push({ at, kind: 'level', text: `★ 等級提升到 Lv.${c.level}，神經容量 ${neuralCapacity(c.level)}。` })
  }
  const wk = weekKey(at)
  if (c.week.key !== wk) c.week = { key: wk, counts: {}, points: 0 }
  const prior = c.week.counts[job.id] ?? 0
  const pts = weeklyPoints(job.tier, prior)
  c.week.counts[job.id] = prior + 1
  c.week.points += pts
  return pts
}

export interface SettleResult {
  character: Character
  queue: Queue
  events: LogEvent[]
  completed: number
  stopped: string | null
  pointsGained: number
  cityContrib: Record<string, number> // 工作 id → 完成件數，給城市事件
}

/**
 * 依 due_at 逐件結算排隊中的低階工作，直到 now。
 * 停止條件在每件完成後檢查；觸發時取消剩下的工作並寫明原因。
 */
export function settleQueue(
  start: Character,
  q: Queue,
  now: number,
  jobs: Record<string, JobDef>,
  rules: StopRules = DEFAULT_STOP,
): SettleResult {
  let c: Character = structuredClone(start)
  const queue: Queue = structuredClone(q)
  const events: LogEvent[] = []
  const cityContrib: Record<string, number> = {}
  let completed = 0
  let pointsGained = 0
  let stopped: string | null = null

  // 暫停時（劇情委託進行中）正在做的那一件照常做完，但不開始下一件
  while (queue.items.length > 0 && queue.startedAt !== null && c.alive) {
    const job = jobs[queue.items[0]]
    const p = c.prof[job.direction]
    const due = queue.startedAt + jobDurationMs(job, p.level)
    if (due > now) break

    const roll = rng(hashSeed(c.id, queue.seq, job.id))
    const ok = roll() < jobSuccessChance(job, p.level, equipBonus(c, job.direction))
    const harm = proficiencyEffects(p.level).harm
    const injury = Math.round(job.injury * (ok ? 0.4 : 1.4) * (1 - harm) * (0.6 + roll() * 0.8))
    const heatUp = !ok && roll() < 0.35 + job.heat * 0.1 ? 1 : 0
    const reward = ok ? jobReward(job, p.level) : Math.round(jobReward(job, p.level) * 0.3)

    c.injury = Math.min(100, c.injury + injury)
    c.stress += job.stress
    c.heat = Math.min(5, c.heat + heatUp)
    c.credits += reward
    const prefix = statusPrefix(c)
    events.push({
      at: due,
      kind: ok ? 'job' : 'hurt',
      text: ok
        ? `${prefix} 完成「${job.name}」，+${reward} 信用點${injury ? `，受傷 ${injury}%` : ''}。`
        : `${prefix} 「${job.name}」失手，只拿到 ${reward} 信用點，受傷 ${injury}%${heatUp ? '，MPD 盯上你了（通緝 +1）' : ''}。`,
    })

    pointsGained += grantProgress(c, job, ok, due, events)

    cityContrib[job.id] = (cityContrib[job.id] ?? 0) + 1
    completed += 1
    queue.items.shift()
    queue.seq += 1
    queue.startedAt = queue.items.length && !queue.paused ? due : null

    const reason = stopReason(c, rules)
    if (reason && queue.items.length) {
      stopped = reason
      events.push({ at: due, kind: 'stop', text: `■ 停止排隊：${reason}，取消剩下 ${queue.items.length} 件。` })
      queue.items = []
      queue.startedAt = null
    }
  }

  return { character: c, queue, events, completed, stopped, pointsGained, cityContrib }
}

// ---------- 危險節點（劇情委託與高階工作共用） ----------

export interface Coverage {
  active: boolean
  coversZone: boolean
  etaMin: number // 救援預估抵達分鐘
}

export interface DangerOption {
  id: string
  label: string
  lethal: boolean
  /** 0～1，判定為致命傷的基準機率（在加入傷勢、神經負荷後）。 */
  lethalBase: number
  survivalWindowMin: number // 致命傷後還能撐幾分鐘
}

/** 武裝醫療隊出勤帳單（試算值）。 */
export const RESCUE_BILL = 1500

export type DangerOutcome =
  | { kind: 'safe'; reason: string }
  | { kind: 'survived'; reason: string }
  | { kind: 'rescued'; reason: string; bill: number }
  | { kind: 'rescued_system'; reason: string }
  | { kind: 'dead'; reason: string }

/**
 * 玩家確認之後一次判定：結果只依 seed 與當下快照，重整不重抽。
 * systemFault 為真時（程式／部署錯誤），致死改為 Trauma Team 免費搶救並留下紀錄。
 */
export function resolveDanger(
  c: Character,
  opt: DangerOption,
  cov: Coverage,
  seed: number,
  systemFault = false,
): DangerOutcome {
  if (!opt.lethal) return { kind: 'safe', reason: '你選擇不冒險，沒有生命危險。' }
  const roll = rng(seed)
  const stage = neuralStage(neuralMargin(c.level, c.implantLoad, c.stress))
  const stagePenalty = stage === 'stable' ? 0 : stage === 'alert' ? 0.05 : 0.12
  const p = Math.min(0.95, opt.lethalBase + c.injury / 400 + stagePenalty)
  if (roll() >= p) return { kind: 'survived', reason: '你撐過去了。' }

  if (systemFault)
    return { kind: 'rescued_system', reason: '系統錯誤造成的致命結果：武裝醫療隊免費搶救，已記錄在生涯中。' }

  if (!cov.active) return { kind: 'dead', reason: '受了致命傷，而你沒有有效的醫療保障。' }
  if (!cov.coversZone) return { kind: 'dead', reason: '受了致命傷，但這一區不在保單覆蓋範圍內。' }
  if (cov.etaMin > opt.survivalWindowMin)
    return {
      kind: 'dead',
      reason: `受了致命傷。救援預估 ${cov.etaMin} 分鐘抵達，你只撐得了 ${opt.survivalWindowMin} 分鐘。`,
    }
  return { kind: 'rescued', reason: `受了致命傷，武裝醫療隊在 ${cov.etaMin} 分鐘內把你拖上了飛行器。`, bill: RESCUE_BILL }
}
