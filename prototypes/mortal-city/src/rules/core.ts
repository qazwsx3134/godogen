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

// ---------- 屬性（角色的「打造」：升級給點數；熟練度則是做工作練出來的） ----------
// 每項起始 3。效果一律寫成 (屬性 − 3) × k：起始值等於沒有屬性時的數值，舊的試算與測試照樣成立。

export type Attr = 'tech' | 'reflex' | 'body' | 'int' | 'cool'
export const ATTRS: Attr[] = ['tech', 'body', 'reflex', 'int', 'cool']
export const ATTR_LABEL: Record<Attr, string> = { tech: '技術', reflex: '反應', body: '體能', int: '智力', cool: '沉著' }
export const ATTR_BASE = 3
export const ATTR_MAX = 20
/** 建角時可自由分配的點數；之後每升一級 +1。 */
export const ATTR_START_POINTS = 4
export const ATTR_EFFECT: Record<Attr, string> = {
  tech: '每點 +3 護甲（每次被打中都減傷）、神經容量 +3（能裝更多義體）。所有流派都用得到',
  body: '每點最大 HP +8。傷勢是 HP 的百分比，HP 越多越耐打',
  reflex: '每點命中 +2%、暴擊率 +4%（暴擊 ×1.5 傷害）',
  int: '駭進智慧槍的干擾每 2 點多 1 回合、神經壓力每 2 點 −1',
  cool: '每點暴擊傷害 +10%、迷彩偷襲第一擊 +0.1 倍',
}

const over = (c: Character, a: Attr) => c.attrs[a] - ATTR_BASE

/** 屬性門檻：不夠回傳原因。 */
export function attrLock(c: Character, needs: { attr: Attr; min: number } | undefined): string | undefined {
  if (!needs || c.attrs[needs.attr] >= needs.min) return undefined
  return `需要${ATTR_LABEL[needs.attr]} ${needs.min}（現在 ${c.attrs[needs.attr]}）`
}

export function baseAttrs(): Record<Attr, number> {
  return { tech: ATTR_BASE, reflex: ATTR_BASE, body: ATTR_BASE, int: ATTR_BASE, cool: ATTR_BASE }
}

/** 神經容量：等級＋技術。 */
export function capacityOf(c: Character) {
  return neuralCapacity(c.level) + over(c, 'tech') * 3
}
export function marginOf(c: Character) {
  return capacityOf(c) - c.implantLoad - c.stress
}
export function armorOf(c: Character) {
  return over(c, 'tech') * 3 + gearMod(c, 'armor')
}
export function maxHpOf(c: Character) {
  return 100 + over(c, 'body') * 8 + gearMod(c, 'hp')
}
/** 傷勢 % 換算成目前 HP。 */
export function hpOf(c: Character) {
  return Math.round((maxHpOf(c) * (100 - c.injury)) / 100)
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
  id: string // 每件物品自己的 id（同一種可以有好幾件）
  kind?: string // 型錄裡的種類（content/items.ts）
  name: string
  slot: Slot
  direction: Direction // 對這個方向的工作有成功率加成
  bonus: number // 例如 0.05 = +5%
  price: number
  load: number // 義體負荷（只有義體會有）
  /** 戰鬥效果。起始手槍的攻擊 +6 也寫在這裡。 */
  mods?: { atk?: number; hit?: number; crit?: number; armor?: number; hp?: number; jam?: number }
}

export type ItemMod = keyof NonNullable<Item['mods']>
/** 身上裝備的某項戰鬥效果總和。 */
export function gearMod(c: Character, k: ItemMod) {
  return c.equipment.reduce((s, i) => s + (i.mods?.[k] ?? 0), 0)
}

/** 義體要留給神經壓力的空間：義體負荷總和不能超過「神經容量 − 這個數」。技術與等級提高容量，就能多裝義體。 */
export const IMPLANT_RESERVE = 50
export function implantRoom(c: Character) {
  return capacityOf(c) - IMPLANT_RESERVE - c.implantLoad
}
/** 賣掉背包裡的東西：售價的 40%（比抵押的 60% 低，抵押之後還能贖回）。 */
export const SELL_RATE = 0.4
export const sellValue = (i: Item) => Math.round(i.price * SELL_RATE)

/** 抵押價＝售價的 60%；贖回價＝抵押價（不收利息）。試算值，見 risk-systems §3。 */
export const PAWN_RATE = 0.6

export function pawnValue(item: Item) {
  return Math.round(item.price * PAWN_RATE)
}

export interface Pawned {
  item: Item
  redeem: number
  /** 抵押前是裝在身上的（贖回後裝回去）；false＝從背包抵押的（贖回放回背包）。 */
  worn?: boolean
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
/** 付帳單時能動用的總額：現金＋背包與身上所有東西的抵押價。 */
export function payable(c: Character) {
  return c.credits + [...c.stash, ...c.equipment].reduce((s, i) => s + pawnValue(i), 0)
}

export function payBill(start: Character, bill: number): BillResult {
  const total = payable(start)
  if (total < bill) return { ok: false, character: start, shortfall: bill - total, total }
  const c: Character = structuredClone(start)
  let owe = Math.max(0, bill - c.credits)
  c.credits = Math.max(0, c.credits - bill)
  const pawned: Item[] = []
  // 先押背包裡的東西，再押身上的；各自價值高的先押
  const byValue = (a: Item, b: Item) => pawnValue(b) - pawnValue(a)
  const order = [...[...c.stash].sort(byValue).map((item) => ({ item, worn: false })), ...[...c.equipment].sort(byValue).map((item) => ({ item, worn: true }))]
  for (const { item, worn } of order) {
    if (owe <= 0) break
    const v = pawnValue(item)
    owe -= v
    pawned.push(item)
    if (worn) {
      c.equipment = c.equipment.filter((i) => i.id !== item.id)
      c.implantLoad -= item.load
    } else c.stash = c.stash.filter((i) => i.id !== item.id)
    c.pawned.push({ item, redeem: v, worn })
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
  if (p.worn === false) c.stash.push(p.item)
  else {
    c.equipment.push(p.item)
    c.implantLoad += p.item.load
  }
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
  attrs: Record<Attr, number>
  /** 還沒分配的屬性點。 */
  attrPoints: number
  /** 背包：沒裝在身上的物品（戰利品、卸下的裝備）。 */
  stash: Item[]
}

export interface StopRules {
  /** 排隊工作遇到打鬥時用的戰術（沒設＝正面交火；被鎖住時也改用正面交火）。 */
  tactic?: Tactic
  injuryAt: number // 傷勢達到就停
  heatAt: number // 通緝達到就停
  stopOnCritical: boolean // 神經進入臨界就停
  creditReserve: number // 信用點低於這個數就停
}

export const DEFAULT_STOP: StopRules = { tactic: 'force', injuryAt: 60, heatAt: 3, stopOnCritical: true, creditReserve: 0 }

// ---------- 傷勢分級、休養與治療 ----------

/** 傷勢達到這裡就是重傷：不能接任何工作（排隊、劇情、高階），要先休養或治療。被救出時傷勢設為 70，等於直接送醫。 */
export const SEVERE_INJURY = 70

export function injuryLabel(injury: number) {
  return injury >= SEVERE_INJURY ? '重傷' : injury >= 40 ? '中傷' : injury > 0 ? '輕傷' : '健康'
}

/** 能不能開始新工作；不能時回傳原因。進行中的委託不受影響，可以做完。 */
export function workBlock(c: Character): string | undefined {
  if (!c.alive) return '角色已死亡'
  if (c.injury >= SEVERE_INJURY) return `重傷（傷勢 ${c.injury}%），先休養或治療`
  return undefined
}

/** 休養：每多少毫秒恢復 1% 傷勢（重傷時慢一倍）；每 30 分鐘通緝 −1★。 */
export const REST = { msPerPoint: 60_000, severeMsPerPoint: 120_000, heatMs: 30 * 60_000 }

/** 診所與醫院的價格（每 1% 傷勢）。醫院不收通緝 3★ 以上的人（會通報 MPD），但壓力降得多。 */
export const CLINIC = { perPoint: 6, stress: 10 }
export const HOSPITAL = { perPoint: 10, stress: 30, maxHeat: 2 }

/**
 * 在公寓休養 ms 毫秒：先用累積的時間恢復傷勢與通緝，回傳新的角色與剩下沒用完的累積時間。
 * 直接改 c。
 */
export function rest(c: Character, carry: { ms: number; heatMs: number }, ms: number) {
  let left = carry.ms + ms
  for (;;) {
    const need = c.injury >= SEVERE_INJURY ? REST.severeMsPerPoint : REST.msPerPoint
    if (c.injury <= 0 || left < need) break
    left -= need
    c.injury -= 1
  }
  if (c.injury <= 0) left = 0
  let heatLeft = carry.heatMs + ms
  while (c.heat > 0 && heatLeft >= REST.heatMs) {
    heatLeft -= REST.heatMs
    c.heat -= 1
  }
  if (c.heat <= 0) heatLeft = 0
  return { ms: left, heatMs: heatLeft }
}

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
  const m = marginOf(c)
  return `[傷勢 ${c.injury}% / 神經 ${NEURAL_STAGE_LABEL[neuralStage(m)]} / 通緝 ${c.heat}★]`
}

function stopReason(c: Character, rules: StopRules): string | null {
  if (c.injury >= SEVERE_INJURY) return `重傷（傷勢 ${c.injury}%），不能繼續工作，要休養或治療`
  if (c.injury >= rules.injuryAt) return `傷勢 ${c.injury}% 達到停止門檻 ${rules.injuryAt}%`
  if (c.heat >= rules.heatAt) return `通緝 ${c.heat}★ 達到停止門檻 ${rules.heatAt}★`
  const stage = neuralStage(marginOf(c))
  if (rules.stopOnCritical && (stage === 'critical' || stage === 'lost'))
    return `神經負荷進入${NEURAL_STAGE_LABEL[stage]}`
  if (c.credits < rules.creditReserve) return `信用點低於保留額 ${rules.creditReserve}`
  return null
}

/** 加經驗並處理升級。直接改 c。 */
export function addXp(c: Character, xp: number, at: number, events: LogEvent[]) {
  c.xp += xp
  while (c.xp >= xpToNext(c.level)) {
    c.xp -= xpToNext(c.level)
    c.level += 1
    c.attrPoints += 1
    events.push({ at, kind: 'level', text: `★ 等級提升到 Lv.${c.level}，神經容量 ${capacityOf(c)}，屬性點 +1。` })
  }
}

/** 劇情委託的做法：該方向的裝備加成＋熟練度每級 1%，從致命機率裡扣掉。 */
export function approachBonus(c: Character, d: Direction) {
  return equipBonus(c, d) + c.prof[d].level * 0.01
}

/**
 * 一件工作完成後的成長：經驗、熟練度、等級、週榜積分（同類遞減）。直接改 c，回傳這件的週榜積分。
 * 排隊結算與高階手動工作共用。
 */
export function grantProgress(c: Character, job: JobDef, ok: boolean, at: number, events: LogEvent[]) {
  addXp(c, ok ? job.xp : Math.round(job.xp / 3), at, events)
  const p = c.prof[job.direction]
  p.xp += 1
  while (p.level < PROF_MAX && p.xp >= profXpToNext(p.level)) {
    p.xp -= profXpToNext(p.level)
    p.level += 1
    events.push({ at, kind: 'level', text: `★ ${DIRECTION_LABEL[job.direction]}熟練度提升到 ${p.level}。` })
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
  /** 打贏時擲戰利品（seed、工作階級）→ 物品或 null。沒給就不掉。 */
  loot?: (seed: number, tier: number) => Item | null,
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
    let ok = roll() < jobSuccessChance(job, p.level, equipBonus(c, job.direction))
    const harm = proficiencyEffects(p.level).harm
    let injury = Math.round(job.injury * (ok ? 0.4 : 1.4) * (1 - harm) * (0.6 + roll() * 0.8))
    const heatUp = !ok && roll() < 0.35 + job.heat * 0.1 ? 1 : 0

    // 打鬥：火力工作每件都要打（打贏＝成功）；入侵／潛行工作失手＝被發現，打贏就帶著東西脫身。
    // 用自己的 seed，不動上面那串亂數。打鬥的掉血取代原本的傷勢公式。
    let fightNote = ''
    if (job.direction === 'force' || !ok) {
      const want = rules.tactic ?? 'force'
      const tactic = tacticsFor(c).find((t) => t.id === want)?.locked ? 'force' : want
      const f = resolveFight(c, streetEnemy(job), tactic, hashSeed(c.id, queue.seq, job.id, 'fight'))
      ok = f.won
      injury = f.injury - c.injury
      c.stress += f.stress
      const tl = tacticsFor(c).find((t) => t.id === tactic)!.label
      // 戰利品用自己的 seed，不影響戰鬥與工作的亂數
      const drop = f.won && loot ? loot(hashSeed(c.id, queue.seq, job.id, 'loot'), job.tier) : null
      if (drop) c.stash.push(drop)
      fightNote = `⚔ ${f.enemy.name}（${tl}${tactic !== want ? '，預設戰術被鎖住' : ''}，${f.won ? '打贏' : '被打退'}，−${injury} HP${drop ? `，戰利品：${drop.name}` : ''}）`
    }
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
        ? `${prefix} 完成「${job.name}」，+${reward} 信用點${injury ? `，受傷 ${injury}%` : ''}。${fightNote}`
        : `${prefix} 「${job.name}」失手，只拿到 ${reward} 信用點，受傷 ${injury}%${heatUp ? '，MPD 盯上你了（通緝 +1）' : ''}。${fightNote}`,
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
  /** 屬性門檻（高階工作的屬性選項）。 */
  attrNeeds?: { attr: Attr; min: number }
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
  const stage = neuralStage(marginOf(c))
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

// ---------- 自動戰鬥（劇情委託的火力路線、高階火力工作） ----------
// 打鬥本身不會死：血量掉到 RETREAT_HP 以下就自動撤退（委託失敗）。死亡只發生在玩家確認過的危險節點。

export interface Enemy {
  name: string
  hp: number
  /** 每次命中的傷害。 */
  atk: number
  /** 命中率 0～1。 */
  hit: number
}

export type Tactic = 'force' | 'hack' | 'stealth'

export interface TacticInfo {
  id: Tactic
  label: string
  summary: string
  /** 不能用的原因；undefined＝可以用。 */
  locked?: string
}

export interface FightRound {
  text: string
  you: number
  foe: number
}

export interface FightResult {
  tactic: Tactic
  enemy: Enemy
  hpStart: number
  maxHp: number
  rounds: FightRound[]
  won: boolean
  /** 打完剩下的血量。 */
  hp: number
  /** 打完的傷勢 %（HP 佔最大 HP 的比例換算）。 */
  injury: number
  /** 這場加的神經壓力。 */
  stress: number
}

/** HP 低於最大 HP 的這個百分比就撤退。 */
export const RETREAT_HP = 20

/** 街頭工作遇到的對手：依階級與方向決定，不必每件工作各寫一份。 */
export function streetEnemy(job: JobDef): Enemy {
  const name = { force: ['街頭混混', '幫派打手', '幫派幹部'], hack: ['趕來的保全', '企業保全', '企業保全小隊'], stealth: ['巡邏保全', '巡邏保全', '武裝巡邏'] }[job.direction][Math.min(2, job.tier - 1)]
  return { name, hp: 15 + job.tier * 20, atk: 4 + job.tier * 2, hit: 0.4 + job.tier * 0.05 }
}
const MAX_ROUNDS = 12

const has = (c: Character, slot: Slot) => c.equipment.some((i) => i.slot === slot)

/** 你的戰鬥數值：HP 看體能與傷勢；攻擊看等級、火力熟練度、有沒有武器；命中看火力熟練度；暴擊看反應與沉著；護甲看技術。 */
export function fightStats(c: Character) {
  const weapon = has(c, 'weapon')
  return {
    hp: hpOf(c),
    maxHp: maxHpOf(c),
    atk: 8 + c.level * 2 + c.prof.force.level + gearMod(c, 'atk'),
    hit: Math.min(0.95, 0.7 + c.prof.force.level * 0.01 + over(c, 'reflex') * 0.02 + gearMod(c, 'hit')),
    crit: Math.max(0, over(c, 'reflex') * 0.04 + gearMod(c, 'crit')),
    critDmg: 1.5 + over(c, 'cool') * 0.1,
    armor: armorOf(c),
    weapon,
  }
}

const jamRounds = (c: Character) => 3 + Math.floor(c.prof.hack.level / 5) + Math.floor(over(c, 'int') / 2) + gearMod(c, 'jam')
const hackStress = (c: Character) => Math.max(1, 5 - Math.floor(over(c, 'int') / 2))

/** 依裝備與屬性能用的戰術：火力一定能用；駭客要有作業設備；迷彩偷襲要有光學迷彩義體。 */
export function tacticsFor(c: Character): TacticInfo[] {
  const weapon = has(c, 'weapon')
  const jam = jamRounds(c)
  return [
    {
      id: 'force',
      label: weapon ? '正面交火' : '赤手空拳',
      summary: weapon ? '全力開火：攻擊 ×1.25、命中 +10%，神經壓力最少（+1）。攻擊看等級、火力熟練度與武器。' : '武器抵押中，只能用拳頭（攻擊 ×1.25、命中 +10%，但沒有武器加成）。',
    },
    {
      id: 'hack',
      label: '駭進他們的智慧槍',
      summary: `前 ${jam} 回合對方的準星亂跳，命中率大降；神經壓力 +${hackStress(c)}。入侵熟練度與智力越高，干擾越久。`,
      locked: has(c, 'deck') ? undefined : '需要作業設備（抵押中或沒有）',
    },
    {
      id: 'stealth',
      label: '光學迷彩繞背',
      summary: `第一回合對方看不到你，第一擊 ×${(1.6 + c.prof.stealth.level * 0.05 + over(c, 'cool') * 0.1).toFixed(1)}，之後是普通攻擊；迷彩同步神經壓力 +3。潛行熟練度與沉著越高，第一擊越重。`,
      locked: c.equipment.some((i) => i.slot === 'implant' && i.direction === 'stealth') ? undefined : '需要光學迷彩義體',
    },
  ]
}

/** 一次算完整場戰鬥（seed 決定，重整不重抽）。 */
export function resolveFight(c: Character, enemy: Enemy, tactic: Tactic, seed: number): FightResult {
  const r = rng(seed)
  const s = fightStats(c)
  const retreat = Math.round(s.maxHp * (RETREAT_HP / 100))
  const guard = 1 - s.armor / (s.armor + 40) // 護甲減傷
  let you = s.hp
  let foe = enemy.hp
  const rounds: FightRound[] = []
  const jam = tactic === 'hack' ? jamRounds(c) : 0
  const pick = (xs: string[]) => xs[Math.floor(r() * xs.length)]
  const push = (text: string) => rounds.push({ text, you: Math.max(0, you), foe: Math.max(0, foe) })
  if (tactic === 'hack') push(`你接上神經線，黑進${enemy.name}的智慧槍。準星開始亂跳。`)
  if (tactic === 'stealth') push(`迷彩啟動。${enemy.name}只看見一陣扭曲的雨。`)
  for (let i = 1; i <= MAX_ROUNDS && foe > 0; i++) {
    // 你的攻擊
    const first = tactic === 'stealth' && i === 1
    // 暴擊從同一個命中骰判定，不多抽亂數（多抽一次，所有戰鬥的結果都會變）
    const h = first ? 0 : r()
    if (first || h < s.hit + (tactic === 'force' ? 0.1 : 0)) {
      const crit = !first && h < s.crit
      const base = s.atk * (first ? 1.6 + c.prof.stealth.level * 0.05 + over(c, 'cool') * 0.1 : (tactic === 'force' ? 1.25 : 1) * (0.8 + r() * 0.4))
      const dmg = Math.round(crit ? base * s.critDmg : base)
      foe -= dmg
      push(
        first
          ? `你從背後出手，${enemy.name}來不及轉身（−${dmg}）。`
          : crit
            ? `暴擊！你打中了${enemy.name}的要害（−${dmg}）。`
          : s.weapon
            ? `${pick(['你壓低身子連開三槍', '你貼著柱子探身射擊', '電磁手槍的電弧劈開雨幕'])}，命中${enemy.name}（−${dmg}）。`
            : `${pick(['你一拳打在對方的下巴', '你抓住槍管往回撞', '你用膝蓋頂進對方的肋骨'])}（−${dmg}）。`,
      )
    } else push(pick(['你的子彈打在牆上，濺起一串火花。', '你撲空了，差一點滑倒在積水裡。']))
    if (foe <= 0) break
    // 對方的攻擊
    const hit = enemy.hit - (i <= jam ? 0.35 : 0) - (first ? 1 : 0)
    if (r() < hit) {
      const dmg = Math.round(enemy.atk * (0.8 + r() * 0.4) * guard)
      you -= dmg
      push(`${enemy.name}${pick(['還擊', '開火', '撲了上來'])}，你中了一下（−${dmg}）。`)
    } else push(i <= jam ? `${enemy.name}的準星還在亂跳，子彈全打偏了。` : `${enemy.name}的攻擊擦過你的肩膀。`)
    if (you < retreat) break
  }
  const won = foe <= 0
  if (won) push(`${enemy.name}倒下了。`)
  else push(you < retreat ? `你的血量太低，只能丟下一切撤退。` : `對方的增援到了，你只能撤退。`)
  const hp = Math.max(1, you)
  return {
    tactic,
    enemy,
    hpStart: s.hp,
    maxHp: s.maxHp,
    rounds,
    won,
    hp,
    injury: Math.min(100, Math.round(100 - (hp * 100) / s.maxHp)),
    stress: tactic === 'hack' ? hackStress(c) : tactic === 'stealth' ? 3 : 1,
  }
}
