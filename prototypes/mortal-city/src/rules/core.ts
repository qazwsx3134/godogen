// 純規則：不碰 DOM、不讀時鐘，所有時間都由呼叫端傳入，方便 M2 搬到伺服器。
// 數值來源：docs/cyberpunk-text-mmo/quest-layers.md、risk-systems.md §4（試算起始值）。
import { FALLBACK_PERKS, PERKS, PERK_IDS } from './perks'

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

// ---------- 屬性（角色的「打造」：升級給點數） ----------
// 每項起始 3。效果一律寫成 (屬性 − 3) × k。

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
  return neuralCapacity(c.level) + over(c, 'tech') * 3 + statMod(c, 'cap')
}
export function marginOf(c: Character) {
  return capacityOf(c) - c.implantLoad - c.stress
}
export function armorOf(c: Character) {
  return over(c, 'tech') * 3 + statMod(c, 'armor')
}
export function maxHpOf(c: Character) {
  return 100 + over(c, 'body') * 8 + statMod(c, 'hp')
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

// ---------- 委託（地圖上的委託與精英委託） ----------

export interface JobDef {
  id: string
  direction: Direction
  tier: 1 | 2 | 3 | 4 | 5
  name: string
  fixerId: string
  reward: number
  xp: number
  stress: number
  heat: number
  injury: number
  blurb: string
}

/** 第 4 階＝精英委託：一定要打一場，之後的危險節點可能永久死亡。 */
export const LETHAL_TIER = 4

export function isLethal(job: JobDef) {
  return job.tier >= LETHAL_TIER
}

/** extra：名聲卡的報酬加成（perkReward）。 */
export function jobReward(job: JobDef, extra = 0) {
  return Math.round(job.reward * (1 + extra))
}

export function jobSuccessChance(job: JobDef, statBonus = 0) {
  const base = 0.92 - job.tier * 0.06
  return Math.max(0.05, Math.min(0.98, base + statBonus))
}

// ---------- 裝備 ----------

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
  mods?: Partial<Record<ModKey, number>>
}

/**
 * 裝備與名聲卡共用的修正：atk 攻擊、hit 命中、crit 暴擊率、critDmg 暴擊傷害倍數、armor 護甲、hp 最大 HP、
 * jam 駭客干擾回合、calm 駭客壓力減免、shock 干擾期間每回合電擊、ambush 迷彩第一擊倍數、ghost 迷彩後多幾回合打不到你、
 * berserk HP 低於一半時攻擊加成、cap 神經容量、loot 戰利品機率（相對）。
 */
export type ModKey = 'atk' | 'hit' | 'crit' | 'critDmg' | 'armor' | 'hp' | 'jam' | 'calm' | 'shock' | 'ambush' | 'ghost' | 'berserk' | 'cap' | 'loot'
/** 身上裝備的某項效果總和。 */
export function gearMod(c: Character, k: ModKey) {
  return c.equipment.reduce((s, i) => s + (i.mods?.[k] ?? 0), 0)
}
/** 名聲卡的某項效果總和（卡的等級 × 每級效果）。 */
export function perkMod(c: Character, k: ModKey) {
  return Object.entries(c.perks).reduce((s, [id, lv]) => s + (PERKS[id]?.mods?.[k] ?? 0) * lv, 0)
}
/** 裝備＋名聲卡。 */
export const statMod = (c: Character, k: ModKey) => gearMod(c, k) + perkMod(c, k)

/** 義體要留給神經壓力的空間：義體負荷總和不能超過「神經容量 − 這個數」。技術與等級提高容量，就能多裝義體。 */
export const IMPLANT_RESERVE = 50
export function implantRoom(c: Character) {
  return capacityOf(c) - IMPLANT_RESERVE - c.implantLoad
}
/** 在黑市賣掉背包裡的東西：售價的 40%。 */
export const SELL_RATE = 0.4
export const sellValue = (i: Item) => Math.round(i.price * SELL_RATE)

export function equipBonus(c: Character, d: Direction) {
  return c.equipment.filter((i) => i.direction === d).reduce((s, i) => s + i.bonus, 0)
}
/** 名聲卡給這個方向的加成（bonus 成功率／致命扣減，reward 報酬）。 */
function perkDir(c: Character, d: Direction, k: 'bonus' | 'reward') {
  return Object.entries(c.perks).reduce((s, [id, lv]) => s + (PERKS[id]?.dir === d ? (PERKS[id][k] ?? 0) * lv : 0), 0)
}
/** 這個方向的工作加成：裝備＋名聲卡。 */
export const dirBonus = (c: Character, d: Direction) => equipBonus(c, d) + perkDir(c, d, 'bonus')
export const perkReward = (c: Character, d: Direction) => perkDir(c, d, 'reward')

// ---------- 傭兵 ----------

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
  equipment: Item[]
  /** 救命保單：受致命傷時武裝醫療隊救你一次，然後就用掉。 */
  lifelines: number
  attrs: Record<Attr, number>
  /** 還沒分配的屬性點。 */
  attrPoints: number
  /** 背包：沒裝在身上的物品（戰利品、卸下的裝備）。 */
  stash: Item[]
  /** 名聲：做節點累積（和等級分開），每升一級三選一一張卡；total 是這段生涯的總名聲（分數）。 */
  fame: { level: number; xp: number; total: number }
  /** 拿到的名聲卡：卡 id → 等級。 */
  perks: Record<string, number>
  /** 還沒挑的三選一，依序處理；結算只往這裡加，不停下來等玩家。 */
  picks: Pick[]
}

/**
 * 三選一。名聲卡只存 seed，選項在要挑的時候用 perkOptions 算（同一個 seed、同一組卡永遠得到同樣三張，
 * 前一次挑完而滿級的卡就不會再出現）。戰利品在掉落時就抽好三件。
 */
export type Pick = { kind: 'perk'; level: number; seed: number } | { kind: 'item'; from: string; options: Item[] }

// ---------- 傷勢與治療 ----------

/** 傷勢達到這裡就是重傷（開打時 HP 已經很低）。被救出時傷勢設為 70。 */
export const SEVERE_INJURY = 70

export function injuryLabel(injury: number) {
  return injury >= SEVERE_INJURY ? '重傷' : injury >= 40 ? '中傷' : injury > 0 ? '輕傷' : '健康'
}

/** 診所：每 1% 傷勢的價格，縫完神經壓力也降一點。 */
export const CLINIC = { perPoint: 6, stress: 10 }
/** 休息節點：二選一，回傷勢或降通緝（也降一點壓力）。 */
export const REST = { heal: 30, heat: 2, stress: 10 }

export type LogKind = 'job' | 'gain' | 'hurt' | 'warn' | 'stop' | 'level' | 'system'

export interface LogEvent {
  at: number
  kind: LogKind
  text: string
}

export function xpToNext(level: number) {
  return 40 + level * 25
}

/**
 * 名聲每級所需。機器人實測（新宿＋灣岸兩區）：每次都選不會死的約 6 張卡、敢冒險而活下來的約 8 張；
 * 冒險才湊得出完整流派。
 */
export function fameToNext(level: number) {
  return 20 + level * 5
}

/** 加名聲並處理升級：每升一級排一次卡牌三選一。直接改 c。 */
export function addFame(c: Character, n: number, at: number, events: LogEvent[]) {
  c.fame.xp += n
  c.fame.total += n
  while (c.fame.xp >= fameToNext(c.fame.level)) {
    c.fame.xp -= fameToNext(c.fame.level)
    c.fame.level += 1
    c.picks.push({ kind: 'perk', level: c.fame.level, seed: hashSeed(c.id, 'fame', c.fame.level) })
    events.push({ at, kind: 'level', text: `★ 名聲提升到 Lv.${c.fame.level}，可以從三張卡裡挑一張。` })
  }
}

/** 各方向拿了幾級的卡（看主流派）。 */
export function perkTally(c: Character): Record<Direction, number> {
  const t: Record<Direction, number> = { force: 0, hack: 0, stealth: 0 }
  for (const [id, lv] of Object.entries(c.perks)) {
    const d = PERKS[id]?.dir
    if (d && d !== 'any') t[d] += lv
  }
  return t
}

/**
 * 名聲卡三選一的選項：排除已滿級的卡；已經拿過的方向權重 ×2、稀有卡 ×0.4。
 * 可選的不到三張時用保底卡補。
 */
export function perkOptions(c: Character, seed: number): string[] {
  const r = rng(seed)
  const tally = perkTally(c)
  const pool = PERK_IDS.filter((id) => (c.perks[id] ?? 0) < PERKS[id].max).map((id) => {
    const p = PERKS[id]
    return { id, w: (p.rare ? 0.4 : 1) * (p.dir !== 'any' && tally[p.dir] > 0 ? 2 : 1) }
  })
  const out: string[] = []
  while (out.length < 3 && pool.length) {
    let x = r() * pool.reduce((s, p) => s + p.w, 0)
    const i = Math.max(0, pool.findIndex((p) => (x -= p.w) < 0))
    out.push(pool.splice(i, 1)[0].id)
  }
  for (const id of FALLBACK_PERKS) if (out.length < 3) out.push(id)
  return out
}

export function statusPrefix(c: Character) {
  const m = marginOf(c)
  return `[傷勢 ${c.injury}% / 神經 ${NEURAL_STAGE_LABEL[neuralStage(m)]} / 通緝 ${c.heat}★]`
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

/** 劇情委託的做法：該方向的裝備與名聲卡加成，從致命機率裡扣掉。 */
export function approachBonus(c: Character, d: Direction) {
  return dirBonus(c, d)
}

/** 一件委託的名聲：每階 10（精英委託 40）。 */
export const jobFame = (job: JobDef) => 10 * job.tier

/** 一件委託完成後的成長：經驗（失手 1/3）、名聲。直接改 c。 */
export function grantProgress(c: Character, job: JobDef, ok: boolean, at: number, events: LogEvent[]) {
  addXp(c, ok ? job.xp : Math.round(job.xp / 3), at, events)
  addFame(c, ok ? jobFame(job) : Math.round(jobFame(job) / 2), at, events)
}

// ---------- 危險節點（劇情委託與高階工作共用） ----------

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

export type DangerOutcome =
  | { kind: 'safe'; reason: string }
  | { kind: 'survived'; reason: string }
  | { kind: 'rescued'; reason: string }
  | { kind: 'rescued_system'; reason: string }
  | { kind: 'dead'; reason: string }

/**
 * 玩家確認之後一次判定：結果只依 seed 與當下快照，重整不重抽。
 * 受致命傷時有救命保單就被救（保單由呼叫端扣掉）；systemFault 為真時（程式／部署錯誤），改為免費搶救並留下紀錄。
 */
export function resolveDanger(c: Character, opt: DangerOption, seed: number, systemFault = false): DangerOutcome {
  if (!opt.lethal) return { kind: 'safe', reason: '你選擇不冒險，沒有生命危險。' }
  const roll = rng(seed)
  const stage = neuralStage(marginOf(c))
  const stagePenalty = stage === 'stable' ? 0 : stage === 'alert' ? 0.05 : 0.12
  const p = Math.min(0.95, opt.lethalBase + c.injury / 400 + stagePenalty)
  if (roll() >= p) return { kind: 'survived', reason: '你撐過去了。' }
  if (systemFault) return { kind: 'rescued_system', reason: '系統錯誤造成的致命結果：武裝醫療隊免費搶救，已記錄在生涯中。' }
  if (c.lifelines <= 0) return { kind: 'dead', reason: '受了致命傷，而你身上沒有救命保單。' }
  return { kind: 'rescued', reason: '受了致命傷。救命保單觸發，武裝醫療隊把你拖上了飛行器（保單用掉了）。' }
}

// ---------- 自動戰鬥（委託、精英委託、劇情委託） ----------
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

/** 這一回合發生的事，畫面依它播特效（不影響判定）。 */
export type FightFx = 'hack' | 'stealth' | 'ambush' | 'hit' | 'crit' | 'miss' | 'shock' | 'hurt' | 'dodge' | 'jammed' | 'win' | 'retreat'

export interface FightRound {
  text: string
  you: number
  foe: number
  fx: FightFx
  /** 這一回合的傷害（hit／crit／ambush／shock＝對方受到的，hurt＝你受到的）。 */
  dmg?: number
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

/** 委託遇到的對手：依階級與方向決定，不必每件委託各寫一份。精英委託是第 4 階。 */
export function streetEnemy(job: JobDef): Enemy {
  const name = { force: ['街頭混混', '幫派打手', '幫派幹部', '倉庫私兵'], hack: ['趕來的保全', '企業保全', '企業保全小隊', '黑冰反制小組'], stealth: ['巡邏保全', '巡邏保全', '武裝巡邏', '研究所警衛'] }[job.direction][Math.min(3, job.tier - 1)]
  return { name, hp: 15 + job.tier * 20, atk: 4 + job.tier * 2, hit: 0.4 + job.tier * 0.05 }
}

/** 通緝越高，MPD 和各方的人越把你當回事：每顆星對方 HP 與攻擊 +8%。 */
export function heatEnemy(e: Enemy, heat: number): Enemy {
  if (!heat) return e
  const k = 1 + heat * 0.08
  return { ...e, hp: Math.round(e.hp * k), atk: Math.round(e.atk * k) }
}
const MAX_ROUNDS = 12

const has = (c: Character, slot: Slot) => c.equipment.some((i) => i.slot === slot)

/** 你的戰鬥數值：HP 看體能與傷勢；攻擊看等級與武器；命中與暴擊看反應；暴擊傷害看沉著；護甲看技術。卡牌與義體再加上去。 */
export function fightStats(c: Character) {
  const weapon = has(c, 'weapon')
  return {
    hp: hpOf(c),
    maxHp: maxHpOf(c),
    atk: 8 + c.level * 2 + statMod(c, 'atk'),
    hit: Math.min(0.95, 0.7 + over(c, 'reflex') * 0.02 + statMod(c, 'hit')),
    crit: Math.max(0, over(c, 'reflex') * 0.04 + statMod(c, 'crit')),
    critDmg: 1.5 + over(c, 'cool') * 0.1 + statMod(c, 'critDmg'),
    armor: armorOf(c),
    weapon,
  }
}

const jamRounds = (c: Character) => 3 + Math.floor(over(c, 'int') / 2) + statMod(c, 'jam')
const hackStress = (c: Character) => Math.max(1, 5 - Math.floor(over(c, 'int') / 2) - statMod(c, 'calm'))
/** 迷彩第一擊的倍數。 */
const ambushMult = (c: Character) => 1.6 + over(c, 'cool') * 0.1 + statMod(c, 'ambush')

/** 依裝備與屬性能用的戰術：火力一定能用；駭客要有作業設備；迷彩偷襲要有光學迷彩義體。 */
export function tacticsFor(c: Character): TacticInfo[] {
  const weapon = has(c, 'weapon')
  const jam = jamRounds(c)
  return [
    {
      id: 'force',
      label: weapon ? '正面交火' : '赤手空拳',
      summary: weapon ? '全力開火：攻擊 ×1.25、命中 +10%，神經壓力最少（+1）。攻擊看等級與武器。' : '武器抵押中，只能用拳頭（攻擊 ×1.25、命中 +10%，但沒有武器加成）。',
    },
    {
      id: 'hack',
      label: '駭進他們的智慧槍',
      summary: `前 ${jam} 回合對方的準星亂跳，命中率大降${statMod(c, 'shock') ? `，每回合電擊對方 −${statMod(c, 'shock')}` : ''}；神經壓力 +${hackStress(c)}。智力越高，干擾越久。`,
      locked: has(c, 'deck') ? undefined : '需要作業設備（抵押中或沒有）',
    },
    {
      id: 'stealth',
      label: '光學迷彩繞背',
      summary: `${statMod(c, 'ghost') ? `前 ${1 + statMod(c, 'ghost')} 回合` : '第一回合'}對方看不到你，第一擊 ×${ambushMult(c).toFixed(1)}，之後是普通攻擊；迷彩同步神經壓力 +3。沉著越高，第一擊越重。`,
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
  // 名聲卡與義體的固定修正（不抽亂數）：電擊、鬼影、背水一戰
  const shock = tactic === 'hack' ? statMod(c, 'shock') : 0
  const unseen = tactic === 'stealth' ? 1 + statMod(c, 'ghost') : 0
  const berserk = statMod(c, 'berserk')
  const pick = (xs: string[]) => xs[Math.floor(r() * xs.length)]
  const push = (text: string, fx: FightFx, dmg?: number) => rounds.push({ text, you: Math.max(0, you), foe: Math.max(0, foe), fx, dmg })
  if (tactic === 'hack') push(`你接上神經線，黑進${enemy.name}的智慧槍。準星開始亂跳。`, 'hack')
  if (tactic === 'stealth') push(`迷彩啟動。${enemy.name}只看見一陣扭曲的雨。`, 'stealth')
  for (let i = 1; i <= MAX_ROUNDS && foe > 0; i++) {
    // 你的攻擊
    const first = tactic === 'stealth' && i === 1
    // 暴擊從同一個命中骰判定，不多抽亂數（多抽一次，所有戰鬥的結果都會變）
    const h = first ? 0 : r()
    if (first || h < s.hit + (tactic === 'force' ? 0.1 : 0)) {
      const crit = !first && h < s.crit
      const rage = berserk && you < s.maxHp / 2 ? 1 + berserk : 1
      const base = s.atk * rage * (first ? ambushMult(c) : (tactic === 'force' ? 1.25 : 1) * (0.8 + r() * 0.4))
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
        first ? 'ambush' : crit ? 'crit' : 'hit',
        dmg,
      )
    } else push(pick(['你的子彈打在牆上，濺起一串火花。', '你撲空了，差一點滑倒在積水裡。']), 'miss')
    if (shock && i <= jam && foe > 0) {
      foe -= shock
      push(`回授電流順著神經線燒進${enemy.name}的手臂（−${shock}）。`, 'shock', shock)
    }
    if (foe <= 0) break
    // 對方的攻擊
    const hit = enemy.hit - (i <= jam ? 0.35 : 0) - (i <= unseen ? 1 : 0)
    if (r() < hit) {
      const dmg = Math.round(enemy.atk * (0.8 + r() * 0.4) * guard)
      you -= dmg
      push(`${enemy.name}${pick(['還擊', '開火', '撲了上來'])}，你中了一下（−${dmg}）。`, 'hurt', dmg)
    } else push(i <= jam ? `${enemy.name}的準星還在亂跳，子彈全打偏了。` : `${enemy.name}的攻擊擦過你的肩膀。`, i <= jam ? 'jammed' : 'dodge')
    if (you < retreat) break
  }
  const won = foe <= 0
  if (won) push(`${enemy.name}倒下了。`, 'win')
  else push(you < retreat ? `你的血量太低，只能丟下一切撤退。` : `對方的增援到了，你只能撤退。`, 'retreat')
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
