// 純規則：不碰 DOM、不讀時鐘，所有時間都由呼叫端傳入，方便 M2 搬到伺服器。
// 數值來源：docs/cyberpunk-text-mmo/quest-layers.md、risk-systems.md §4（試算起始值）。
import { FALLBACK_PERKS, PERKS, PERK_IDS } from './perks'

export type Direction = 'force' | 'hack' | 'stealth'

export const DIRECTION_LABEL: Record<Direction, string> = {
  force: '武力',
  hack: '駭入',
  stealth: '潛行',
}

/** 流派：卡牌與道具的打法標籤，跟委託路線（武力／駭入／潛行）分開。每個流派的委託加成算在對應路線上。 */
export type Style = 'berserker' | 'gunslinger' | 'netrunner' | 'nomad'
export const STYLES: Style[] = ['berserker', 'gunslinger', 'netrunner', 'nomad']
export const STYLE_LABEL: Record<Style, string> = { berserker: '狂暴大猩猩', gunslinger: '雙持', netrunner: '速駭', nomad: '流浪者' }
export const STYLE_EN: Record<Style, string> = { berserker: 'Berserker', gunslinger: 'Gunslinger', netrunner: 'Netrunner', nomad: 'Nomad' }
export const STYLE_DIR: Record<Style, Direction> = { berserker: 'force', gunslinger: 'force', netrunner: 'hack', nomad: 'stealth' }
/** 能開「光學迷彩繞背」的義體種類（流浪者的其他義體不算）。 */
export const CLOAK_KINDS = ['camo', 'dampener', 'ghostWeave', 'dustCloak']

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
  reflex: '每點命中 +2%、爆擊率 +4%（爆擊 ×1.5 傷害）',
  int: '駭入的干擾每 2 點多 1 回合、神經壓力每 2 點 −1',
  cool: '每點爆擊傷害 +10%、光學迷彩繞背第一擊 +0.1 倍',
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

/** 難度 4＝精英委託：一定要打一場，之後的危險節點可能永久死亡。 */
export const LETHAL_TIER = 4

export function isLethal(job: JobDef) {
  return job.tier >= LETHAL_TIER
}

/** extra：名聲卡的報酬加成（perkReward）。 */
export function jobReward(job: JobDef, extra = 0) {
  return Math.round(job.reward * (1 + extra))
}

// ---------- 骰池判定 ----------
// 擲一把六面骰，只看最高那顆：6＝乾淨成功、4～5＝成功但付代價、1～3＝失敗；兩顆以上的 6＝大成功。
// 一顆都沒有時擲兩顆取低的。畫面不顯示機率，只顯示擲幾顆。

export type PoolResult = 'crit' | 'clean' | 'cost' | 'fail'
export const POOL_RESULT_LABEL: Record<PoolResult, string> = { crit: '大成功', clean: '乾淨成功', cost: '成功，但付代價', fail: '失敗' }
export interface PoolRoll {
  dice: number[]
  best: number
  result: PoolResult
}
/** 一次最多擲幾顆。 */
export const POOL_MAX = 6

export function rollPool(n: number, seed: number): PoolRoll {
  const r = rng(seed)
  const d = () => 1 + Math.floor(r() * 6)
  const grade = (best: number, sixes: number): PoolResult => (sixes >= 2 ? 'crit' : best === 6 ? 'clean' : best >= 4 ? 'cost' : 'fail')
  if (n <= 0) {
    const dice = [d(), d()]
    const best = Math.min(...dice)
    return { dice, best, result: grade(best, 0) }
  }
  const dice = Array.from({ length: Math.min(n, POOL_MAX) }, d)
  const best = Math.max(...dice)
  return { dice, best, result: grade(best, dice.filter((x) => x === 6).length) }
}

/** 屬性換成骰數：3→2 顆、5→3、7→4、9 以上 5 顆。 */
export const attrDice = (v: number) => Math.min(5, 1 + Math.floor((v - 1) / 2))

/** 擲之前可以加骰：硬撐（神經壓力）、鋌而走險（通緝）。各 +1 顆。 */
export const PUSH_STRESS = 8
export const GAMBLE_HEAT = 1

export interface PoolPart {
  label: string
  n: number
}

/** 場面的骰池：屬性、該方向的裝備與卡牌、難度 3 以上、重傷。委託與劇情做法的場面共用，畫面與判定也共用。 */
export function scenePool(c: Character, direction: Direction, tier: number, attr: Attr): PoolPart[] {
  const gear = dirBonus(c, direction)
  const parts: PoolPart[] = [{ label: `${ATTR_LABEL[attr]} ${c.attrs[attr]}`, n: attrDice(c.attrs[attr]) }]
  if (gear >= 0.05) parts.push({ label: `${DIRECTION_LABEL[direction]}的裝備與卡牌`, n: gear >= 0.2 ? 2 : 1 })
  if (tier >= 3) parts.push({ label: `難度 ${tier}`, n: -1 })
  if (c.injury >= SEVERE_INJURY) parts.push({ label: '重傷', n: -1 })
  return parts
}
export const jobPool = (c: Character, job: JobDef, attr: Attr) => scenePool(c, job.direction, job.tier, attr)

/** 事件選項的骰池：看屬性（屬性骰數 −1，臨場發揮）或純靠運氣（固定骰數）；重傷 −1。 */
export const EVENT_EDGE = -1
export function eventPool(c: Character, check: { attr?: Attr; dice?: number }): PoolPart[] {
  const parts: PoolPart[] = check.attr
    ? [
        { label: `${ATTR_LABEL[check.attr]} ${c.attrs[check.attr]}`, n: attrDice(c.attrs[check.attr]) },
        { label: '臨場發揮', n: EVENT_EDGE + (check.dice ?? 0) },
      ]
    : [{ label: '純靠運氣', n: check.dice ?? 1 }]
  if (c.injury >= SEVERE_INJURY) parts.push({ label: '重傷', n: -1 })
  return parts
}
export const poolSize = (parts: PoolPart[], extra = 0) => parts.reduce((s, p) => s + p.n, 0) + extra

/** 場面的代價種類：受傷、通緝、神經壓力、報酬打折。 */
export type CostKind = 'injury' | 'heat' | 'stress' | 'pay'
export const COST_STRESS = 8
/** 每次選「報酬打折」少拿的比例；每次大成功多拿的比例。 */
export const COST_PAY = 0.2
export const CRIT_PAY = 0.15
/** 代價只看「這件事有多容易受傷」：委託的 injury，劇情做法的路上傷勢。 */
export type CostBase = { injury: number }
export const costInjury = (job: CostBase) => Math.max(4, Math.round(job.injury * 0.5))
/** 失敗時：受傷加倍、神經壓力三倍；另外任何失敗都慌一下，神經壓力再 +FAIL_SHAKE（不管這個場面的代價是什麼）。 */
export const FAIL_STRESS_MULT = 3
export const FAIL_SHAKE = 4
export function costText(job: CostBase, k: CostKind, heavy = false): string {
  const shake = heavy && k !== 'stress' ? `、神經壓力 +${FAIL_SHAKE}` : ''
  const main = k === 'injury' ? `傷勢 +${costInjury(job) * (heavy ? 2 : 1)}%` : k === 'heat' ? '通緝 +1' : k === 'stress' ? `神經壓力 +${COST_STRESS * (heavy ? FAIL_STRESS_MULT : 1) + (heavy ? FAIL_SHAKE : 0)}` : `報酬 −${Math.round(COST_PAY * 100)}%`
  return main + shake
}
/** 套用一個代價（報酬打折由呼叫端記帳）。失敗時 heavy：受傷加倍、壓力三倍，再加慌張的 +FAIL_SHAKE。直接改 c。 */
export function applyCost(c: Character, job: CostBase, k: CostKind, heavy = false) {
  if (k === 'injury') c.injury = Math.min(100, c.injury + costInjury(job) * (heavy ? 2 : 1))
  else if (k === 'heat') c.heat = Math.min(5, c.heat + 1)
  else if (k === 'stress') c.stress += COST_STRESS * (heavy ? FAIL_STRESS_MULT : 1)
  if (heavy) c.stress += FAIL_SHAKE
}

// ---------- 裝備 ----------

export type Slot = 'weapon' | 'deck' | 'implant'
export const SLOT_LABEL: Record<Slot, string> = { weapon: '武器', deck: '駭客終端', implant: '義體' }

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
  /** 裝上要的屬性門檻（重武器、高階義體與終端）。 */
  needs?: { attr: Attr; min: number }
  /** 義體等級（神機醫升級）：沒寫＝1。效果 ×itemMult，負荷每級 +UPGRADE_LOAD。 */
  level?: number
}

/** 義體升級：最多 Lv.3；每級效果 +0.5 倍、負荷 +10；升一級要「原價 × 目前等級」。 */
export const MAX_ITEM_LEVEL = 3
export const UPGRADE_LOAD = 10
export const itemMult = (i: Item) => 1 + 0.5 * ((i.level ?? 1) - 1)
export const upgradeCost = (i: Item) => i.price * (i.level ?? 1)
/** 升級後的單項效果：整數的（攻擊、護甲、回合數）四捨五入，比率照乘。 */
export const itemModValue = (i: Item, k: ModKey) => {
  const v = (i.mods?.[k] ?? 0) * itemMult(i)
  return Number.isInteger(i.mods?.[k] ?? 0) ? Math.round(v) : v
}

/**
 * 裝備與名聲卡共用的修正：atk 攻擊、hit 命中、crit 爆擊率、critDmg 爆擊傷害倍數、armor 護甲、hp 最大 HP、
 * jam 駭入干擾回合、calm 駭客壓力減免、shock 干擾期間每回合電擊、ambush 迷彩第一擊倍數、ghost 迷彩後多幾回合打不到你、
 * berserk HP 低於一半時攻擊加成、cap 神經容量、loot 戰利品機率（相對）、
 * double 命中後補一槍的機率（六成傷害，用同一顆命中骰判定）、patch 打贏後立刻回復的 HP。
 */
export type ModKey = 'atk' | 'hit' | 'crit' | 'critDmg' | 'armor' | 'hp' | 'jam' | 'calm' | 'shock' | 'ambush' | 'ghost' | 'berserk' | 'cap' | 'loot' | 'double' | 'patch'
/** 身上裝備的某項效果總和。 */
export function gearMod(c: Character, k: ModKey) {
  return c.equipment.reduce((s, i) => s + itemModValue(i, k), 0)
}
/** 名聲卡的某項效果總和（卡的等級 × 每級效果）。 */
export function perkMod(c: Character, k: ModKey) {
  return Object.entries(c.perks).reduce((s, [id, lv]) => s + (PERKS[id]?.mods?.[k] ?? 0) * lv, 0)
}
/** 裝備＋名聲卡。 */
export const statMod = (c: Character, k: ModKey) => gearMod(c, k) + perkMod(c, k)

/** 義體想裝多少都可以，代價是神經餘裕：餘裕低於 40（警戒以下）時，任務裡的錯亂規則一階比一階重（psychoRules）。 */
export const neuralRisk = (c: Character) => neuralStage(marginOf(c)) !== 'stable'
/** 「神經警戒」這類短標籤（穩定時是空字串）。 */
export const neuralTag = (c: Character) => (neuralRisk(c) ? `神經${NEURAL_STAGE_LABEL[neuralStage(marginOf(c))]}` : '')

// ---------- 神經錯亂（骰池版，DICE-POOL-SPEC §6）----------
// 錯亂是看得到、能迴避的風險：每一條規則都寫在擲骰畫面上，錯亂骰也擲在玩家面前。
// 警戒以下：硬撐的神經壓力多 +4。臨界以下：每次硬撐後擲一顆錯亂骰，1＝這個場面直接失敗。
// 失控：每個場面開始前擲一顆錯亂骰，1～2＝任務中斷，再擲 2 顆的致命判定（失敗＝致命傷、付代價＝重傷）。
// 一般委託每個場面、精英委託與劇情委託的開場都適用；硬撐的規則也用在致命判定。
export const PSYCHO_PUSH_EXTRA = 4
export const PSYCHO_PUSH_FAIL = 1
export const PSYCHO_SCENE_ABORT = 2
export const PSYCHO_LETHAL_DICE = 2
export interface PsychoRules {
  stage: NeuralStage
  /** 硬撐多付的神經壓力。 */
  pushExtra: number
  /** 硬撐之後要擲錯亂骰。 */
  pushCheck: boolean
  /** 每個場面開始前要擲錯亂骰。 */
  sceneCheck: boolean
}
export function psychoRules(c: Character): PsychoRules {
  const stage = neuralStage(marginOf(c))
  return { stage, pushExtra: stage === 'stable' ? 0 : PSYCHO_PUSH_EXTRA, pushCheck: stage === 'critical' || stage === 'lost', sceneCheck: stage === 'lost' }
}
/** 一顆錯亂骰（1～6）。 */
export const psychoDie = (seed: number) => 1 + Math.floor(rng(seed)() * 6)
/** 這一次硬撐要付的神經壓力。 */
export const pushStress = (c: Character) => PUSH_STRESS + psychoRules(c).pushExtra
/** 擲骰畫面上的錯亂規則說明；穩定時沒有。 */
export function psychoRuleText(c: Character): string[] {
  const r = psychoRules(c)
  const t: string[] = []
  if (r.sceneCheck) t.push(`失控：每個場面先擲一顆錯亂骰，擲出 1～${PSYCHO_SCENE_ABORT}＝任務中斷，再擲 ${PSYCHO_LETHAL_DICE} 顆的致命判定`)
  if (r.pushCheck) t.push(`硬撐之後擲一顆錯亂骰，擲出 ${PSYCHO_PUSH_FAIL}＝這個場面直接失敗`)
  if (r.pushExtra) t.push(`硬撐的神經壓力 +${r.pushExtra}`)
  return t
}

/** 在黑市賣掉背包裡的東西：售價的 40%。 */
export const SELL_RATE = 0.4
export const sellValue = (i: Item) => Math.round(i.price * (i.level ?? 1) * SELL_RATE)

export function equipBonus(c: Character, d: Direction) {
  return c.equipment.filter((i) => i.direction === d).reduce((s, i) => s + i.bonus * itemMult(i), 0)
}
/** 名聲卡給這個方向的加成（bonus 成功率／致命扣減，reward 報酬）。 */
function perkDir(c: Character, d: Direction, k: 'bonus' | 'reward') {
  return Object.entries(c.perks).reduce((s, [id, lv]) => s + (PERKS[id] && PERKS[id].style !== 'any' && STYLE_DIR[PERKS[id].style as Style] === d ? (PERKS[id][k] ?? 0) * lv : 0), 0)
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
  /** 救命保單：0 或 1（最多一張）。受致命傷時武裝醫療隊救你一次，然後就用掉。 */
  lifelines: number
  /** 保單等級（決定救回來的下場）；舊存檔沒寫＝標準。 */
  lifelineTier?: LifelineTier
  /** 身上的鎮定劑（黑市買，隨時能用來降神經壓力）；舊存檔沒寫＝0。 */
  calmers?: number
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
  /** 主角外觀：a＝女主角 A（預設）、b＝男主角 B。只影響圖。 */
  look?: 'a' | 'b'
  /** 舊傷：重傷生還或被救命保單救回時扣掉的屬性點數（已經從 attrs 扣掉，這裡只記來由，給畫面看）。 */
  scars?: Partial<Record<Attr, number>>
}

/**
 * 三選一。名聲卡只存 seed，選項在要挑的時候用 perkOptions 算（同一個 seed、同一組卡永遠得到同樣三張，
 * 前一次挑完而滿級的卡就不會再出現）。戰利品在掉落時就抽好三件。
 */
export type Pick = { kind: 'perk'; level: number; seed: number } | { kind: 'item'; from: string; options: Item[]; equip?: boolean }

// ---------- 傷勢與治療 ----------

/** 傷勢達到這裡就是重傷（開打時 HP 已經很低）。被救出時傷勢設為 70。 */
export const SEVERE_INJURY = 70

export function injuryLabel(injury: number) {
  return injury >= SEVERE_INJURY ? '重傷' : injury >= 40 ? '中傷' : injury > 0 ? '輕傷' : '健康'
}

/** 診所：每 1% 傷勢的價格，縫完神經壓力也降一點。 */
/** 神機醫：縫傷口每 1% 傷勢的價錢與順便降的神經壓力；修好一道舊傷（恢復 1 點屬性）的價錢；神經調校（每次來限一次）的價錢與降的壓力。 */
export const CLINIC = { perPoint: 6, stress: 10, scar: 500, tunePrice: 200, tune: 20 }
/** 休息節點：二選一，回傷勢或降通緝（也降一點壓力）。 */
/** 休息：三選一。睡一覺回傷勢、躲起來降通緝（都順便壓力 −10），或斷線靜養只降壓力。 */
export const REST = { heal: 30, heat: 2, stress: 10, calm: 30 }
/** 黑市的鎮定劑：一劑壓力 −12，最多帶 3 劑，隨時能用。 */
export const CALMER = { price: 150, stress: 12, max: 3 }

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
 * 名聲每級所需。機器人實測（新宿＋灣岸兩區、各 200 局，2026-11-08）：每次都選不會死的平均 7.7 張卡、
 * 敢冒險的 8.8 張（舊曲線 20＋5×等級時是 5.9／6.8）。
 */
export function fameToNext(level: number) {
  return 12 + level * 4
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
    // 出名的代價：每 3 級，MPD 把你往觀察名單上挪一格
    if (c.fame.level % FAME_WATCH_EVERY === 0 && c.heat < 5) {
      c.heat += 1
      events.push({ at, kind: 'warn', text: `⚠ 你出名了：MPD 把你列進觀察名單（通緝 +1，現在 ${c.heat}★）。` })
    }
  }
}

/** 名聲每升這麼多級，通緝 +1（出名的代價）。 */
export const FAME_WATCH_EVERY = 3
/** 精英委託的對手看你的名聲加強：名聲 Lv.2 以上每級 +4%，最多 +40%。 */
export const fameEdge = (fameLevel: number) => Math.min(0.4, Math.max(0, fameLevel - 2) * 0.04)
export function fameEnemy(e: Enemy, fameLevel: number): Enemy {
  const k = 1 + fameEdge(fameLevel)
  return k === 1 ? e : { ...e, hp: Math.round(e.hp * k), atk: Math.round(e.atk * k) }
}

/** 各流派拿了幾級的卡（看主流派）。 */
export function perkTally(c: Character): Record<Style, number> {
  const t: Record<Style, number> = { berserker: 0, gunslinger: 0, netrunner: 0, nomad: 0 }
  for (const [id, lv] of Object.entries(c.perks)) {
    const d = PERKS[id]?.style
    if (d && d !== 'any') t[d] += lv
  }
  return t
}

/**
 * 名聲卡三選一的選項：排除已滿級的卡；已經拿過的流派權重 ×2、稀有卡 ×0.4。
 * 可選的不到三張時用保底卡補。
 */
/** 流派越投入越容易抽到：每張 +0.5 倍，最多 ×3（4 張以上）。 */
export const styleWeight = (count: number) => 1 + 0.5 * Math.min(count, 4)

export function perkOptions(c: Character, seed: number): string[] {
  const r = rng(seed)
  const tally = perkTally(c)
  const pool = PERK_IDS.filter((id) => (c.perks[id] ?? 0) < PERKS[id].max).map((id) => {
    const p = PERKS[id]
    return { id, w: (p.rare ? 0.4 : 1) * (p.style === 'any' ? 1 : styleWeight(tally[p.style])) }
  })
  const draw = (from: typeof pool) => {
    let x = r() * from.reduce((s, p) => s + p.w, 0)
    const pick = from[Math.max(0, from.findIndex((p) => (x -= p.w) < 0))]
    pool.splice(pool.indexOf(pick), 1)
    return pick.id
  }
  const out: string[] = []
  while (out.length < 3 && pool.length) out.push(draw(pool))
  // 保底：主流派（張數最多、至少 2 張）每組至少一張；同時至少一張別的，留轉型的路
  const top = STYLES.reduce((a, b) => (tally[b] > tally[a] ? b : a))
  if (tally[top] >= 2 && out.length === 3) {
    const isTop = (id: string) => PERKS[id].style === top
    const swap = (want: boolean) => {
      const from = pool.filter((p) => isTop(p.id) === want)
      if (!from.length) return
      const i = out.map(isTop).lastIndexOf(!want)
      out[i] = draw(from)
    }
    if (!out.some(isTop)) swap(true)
    else if (out.every(isTop)) swap(false)
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

/** 一件委託的名聲：每級難度 10（精英委託 40）。 */
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
  | { kind: 'maimed'; reason: string }
  | { kind: 'rescued'; reason: string }
  | { kind: 'rescued_system'; reason: string }
  | { kind: 'dead'; reason: string }

/** 救命保單的等級：越貴，救回來失去的越少。最多持有一張。 */
export type LifelineTier = 'basic' | 'standard' | 'platinum'
export const LIFELINES: Record<LifelineTier, { label: string; price: number; injury: number; strip: boolean; scar: boolean; desc: string }> = {
  basic: { label: '廉價保單', price: 450, injury: 90, strip: true, scar: true, desc: '拆光身上的義體抵費用、傷勢 90%、留一道舊傷' },
  standard: { label: '標準保單', price: 1200, injury: 70, strip: true, scar: false, desc: '拆光身上的義體抵費用、傷勢 70%' },
  platinum: { label: '白金保單', price: 3000, injury: 50, strip: false, scar: false, desc: '義體保留、傷勢 50%' },
}
export const LIFELINE_TIERS: LifelineTier[] = ['basic', 'standard', 'platinum']
/** 身上這張保單的等級（沒有保單＝null）。 */
export const lifelineOf = (c: Character): LifelineTier | null => (c.lifelines > 0 ? (c.lifelineTier ?? 'standard') : null)

/** 機率顯示成整數百分比。 */
export const pct = (p: number) => `${Math.round(p * 100)}%`

// ---------- 致命判定（骰池版，DICE-POOL-SPEC §5）----------
// 危險節點的冒險選項擲一次骰池：大成功／乾淨成功＝撐過去；4～5＝撐過去但要付重代價（二選一：重傷生還，或丟下報酬脫身）；
// 失敗＝致命傷（有保單被救，沒有就死）。畫面只顯示擲幾顆、哪些東西加減骰，不顯示百分比。

/** 選項沒有指定屬性時，用路線的屬性：武力拚體能、駭入拚智力、潛行拚沉著。 */
export const DIR_ATTR: Record<Direction, Attr> = { force: 'body', hack: 'int', stealth: 'cool' }
/** 靠器材或屬性門檻的選項多擲的骰數（代價：報酬七五折、名聲減半、神經壓力 +10）。 */
export const PREPARED_DICE = 2
/** 選項本身的險度換成骰數：基準 ≥28% −1、≤10% +1（器材、屬性選項不另算）。 */
export const riskDice = (raw: number) => (raw >= 0.28 ? -1 : raw <= 0.1 ? 1 : 0)
/** 對手修正：精英委託 −1、劇情大案 −2（規格第 5 節）。 */
export const FOE_DICE = { elite: -1, boss: -2, story: 0 } as const
export type FoeKind = keyof typeof FOE_DICE
/** 不靠器材、屬性的冒險選項撐過去（含重傷生還）時，名聲的倍數。 */
export const RISKY_FAME_MULT = 1.5
/** 擲出 4～5、選「丟下報酬脫身」時加的傷勢。 */
export const DROP_INJURY = 20

export interface LethalSpec {
  attr: Attr
  direction: Direction
  foe: FoeKind
  /** 選項的基準險度（加上做法修正，0～1）。 */
  risk: number
  /** 靠器材或屬性門檻的選項。 */
  prepared: boolean
  /** 前面場面的結果（劇情做法的場面：每個成功 +1、每次失敗 −1）。 */
  scenes?: number
}
/** 致命判定的骰池：畫面與判定共用。 */
export function lethalPool(c: Character, s: LethalSpec): PoolPart[] {
  const gear = dirBonus(c, s.direction)
  const parts: PoolPart[] = [{ label: `${ATTR_LABEL[s.attr]} ${c.attrs[s.attr]}`, n: attrDice(c.attrs[s.attr]) }]
  if (gear >= 0.05) parts.push({ label: `${DIRECTION_LABEL[s.direction]}的裝備與卡牌`, n: gear >= 0.2 ? 2 : 1 })
  if (s.prepared) parts.push({ label: '有備而來（器材或屬性）', n: PREPARED_DICE })
  else if (riskDice(s.risk)) parts.push({ label: riskDice(s.risk) > 0 ? '這條路比較穩' : '這條路特別險', n: riskDice(s.risk) })
  if (FOE_DICE[s.foe]) parts.push({ label: s.foe === 'elite' ? '精英對手' : '劇情大案', n: FOE_DICE[s.foe] })
  if (s.scenes) parts.push({ label: '前面的場面', n: s.scenes })
  if (c.injury >= SEVERE_INJURY) parts.push({ label: '重傷', n: -1 })
  return parts
}

/** 擲出致命傷之後：有保單被救、系統錯誤免費搶救，沒有就死。 */
export function lethalWound(c: Character, dice: number[], systemFault = false): DangerOutcome {
  const d = dice.join('、')
  if (systemFault) return { kind: 'rescued_system', reason: '系統錯誤造成的致命結果：武裝醫療隊免費搶救，已記錄在生涯中。' }
  if (c.lifelines <= 0)
    return { kind: 'dead', reason: `致命判定擲出 ${d}，受了致命傷，而你身上沒有救命保單。先去神機醫治傷、帶該方向的裝備、走有備而來的選項，或擲之前硬撐、鋌而走險，都能多擲幾顆。` }
  return { kind: 'rescued', reason: `致命判定擲出 ${d}，受了致命傷。救命保單觸發，武裝醫療隊把你拖上了飛行器（保單用掉了）。` }
}

/** 舊傷扣哪個屬性：依那次行動的路線（武力傷身體、駭入燒腦、潛行傷反應）。 */
export const SCAR_ATTR: Record<Direction, Attr> = { force: 'body', hack: 'int', stealth: 'reflex' }

/** 留下一道舊傷：該屬性 −1（最低 1），記在 scars。直接改 c。 */
export function addScar(c: Character, dir: Direction): Attr | undefined {
  const a = SCAR_ATTR[dir]
  if (c.attrs[a] <= 1) return undefined
  c.attrs = { ...c.attrs, [a]: c.attrs[a] - 1 }
  c.scars = { ...c.scars, [a]: (c.scars?.[a] ?? 0) + 1 }
  return a
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
  /** 防火牆：比你的駭入強度高，「駭入」就沒用。沒寫＝0。 */
  ice?: number
  /** 感知：比你的隱匿高，「光學迷彩繞背」就沒用。沒寫＝0。 */
  sense?: number
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

/** 委託遇到的對手：依難度與方向決定，不必每件委託各寫一份。精英委託是難度 4。 */
export function streetEnemy(job: JobDef): Enemy {
  const name = { force: ['街頭混混', '幫派打手', '幫派幹部', '倉庫私兵'], hack: ['趕來的保全', '企業保全', '企業保全小隊', '資安反制小組'], stealth: ['巡邏保全', '巡邏保全', '武裝巡邏', '研究所警衛'] }[job.direction][Math.min(3, job.tier - 1)]
  const level = [0, 2, 4, 5, 7, 8][Math.min(5, job.tier)] // 防火牆與感知：難度 1新角色打得過，之後要靠屬性、卡牌或義體
  return { name, hp: 15 + job.tier * 20, atk: 4 + job.tier * 2, hit: 0.4 + job.tier * 0.05, ice: level, sense: level }
}

/** 通緝越高，MPD 和各方的人越把你當回事：每顆星對方 HP 與攻擊 +8%。 */
export function heatEnemy(e: Enemy, heat: number): Enemy {
  if (!heat) return e
  const k = 1 + heat * 0.08
  return { ...e, hp: Math.round(e.hp * k), atk: Math.round(e.atk * k) }
}
const MAX_ROUNDS = 12

const has = (c: Character, slot: Slot) => c.equipment.some((i) => i.slot === slot)

/** 你的戰鬥數值：HP 看體能與傷勢；攻擊看等級與武器；命中與爆擊看反應；爆擊傷害看沉著；護甲看技術。卡牌與義體再加上去。 */
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

/** 駭入強度：智力＋干擾加成每點 +2。新角色 3。 */
export const hackPower = (c: Character) => c.attrs.int + statMod(c, 'jam') * 2
/** 隱匿：沉著＋鬼影加成每點 +2。新角色 3。 */
export const stealthPower = (c: Character) => c.attrs.cool + statMod(c, 'ghost') * 2

/** 挑卡、挑道具、加屬性前後，畫面上看得到的數值變了哪些（例如「攻擊 16→19」）。 */
export function statChanges(a: Character, b: Character): string[] {
  const fa = fightStats(a)
  const fb = fightStats(b)
  const pctv = (x: number) => `${Math.round(x * 100)}%`
  const rows: [string, number, number, (x: number) => string][] = [
    ['最大 HP', fa.maxHp, fb.maxHp, String],
    ['攻擊', fa.atk, fb.atk, String],
    ['命中', fa.hit, fb.hit, pctv],
    ['爆擊', fa.crit, fb.crit, pctv],
    ['爆擊傷害', fa.critDmg, fb.critDmg, (x) => `×${x.toFixed(1)}`],
    ['護甲', fa.armor, fb.armor, String],
    ['駭入強度', hackPower(a), hackPower(b), String],
    ['隱匿', stealthPower(a), stealthPower(b), String],
    ['神經容量', capacityOf(a), capacityOf(b), String],
    ...(['force', 'hack', 'stealth'] as const).map((d) => [`${DIRECTION_LABEL[d]}委託加成`, dirBonus(a, d), dirBonus(b, d), pctv] as [string, number, number, (x: number) => string]),
  ]
  return rows.filter(([, x, y, f]) => f(x) !== f(y)).map(([label, x, y, f]) => `${label} ${f(x)}→${f(y)}`)
}

const jamRounds = (c: Character) => 3 + Math.floor(over(c, 'int') / 2) + statMod(c, 'jam')
const hackStress = (c: Character) => Math.max(1, 5 - Math.floor(over(c, 'int') / 2) - statMod(c, 'calm'))
/** 迷彩第一擊的倍數。 */
const ambushMult = (c: Character) => 1.6 + over(c, 'cool') * 0.1 + statMod(c, 'ambush')

/** 依裝備與屬性能用的戰術：武力一定能用；駭客要有駭客終端；光學迷彩繞背要有光學迷彩義體。 */
/**
 * 能用的戰術：正面交火一定能用；駭入要有駭客終端、駭入強度不低於對方防火牆；
 * 光學迷彩繞背要有光學迷彩義體、隱匿不低於對方感知。沒給對手就只看裝備。
 */
export function tacticsFor(c: Character, enemy?: Enemy): TacticInfo[] {
  const weapon = has(c, 'weapon')
  const jam = jamRounds(c)
  const hp = hackPower(c)
  const sp = stealthPower(c)
  const ice = enemy?.ice ?? 0
  const sense = enemy?.sense ?? 0
  return [
    {
      id: 'force',
      label: weapon ? '正面交火' : '赤手空拳',
      summary: weapon ? '全力開火：攻擊 ×1.25、命中 +10%，神經壓力最少（+1）。攻擊看等級與武器。' : '武器抵押中，只能用拳頭（攻擊 ×1.25、命中 +10%，但沒有武器加成）。',
    },
    {
      id: 'hack',
      label: '駭入',
      summary: `駭入對方的智慧槍：前 ${jam} 回合準星亂跳，命中率大降${statMod(c, 'shock') ? `，每回合電擊對方 −${statMod(c, 'shock')}` : ''}；神經壓力 +${hackStress(c)}。你的駭入強度 ${hp}${enemy ? `、對方防火牆 ${ice}` : ''}。`,
      locked: !has(c, 'deck') ? '需要駭客終端' : hp < ice ? `對方防火牆 ${ice}，你的駭入強度只有 ${hp}，駭不進去` : undefined,
    },
    {
      id: 'stealth',
      label: '光學迷彩繞背',
      summary: `${statMod(c, 'ghost') ? `前 ${1 + statMod(c, 'ghost')} 回合` : '第一回合'}對方看不到你，第一擊 ×${ambushMult(c).toFixed(1)}，之後是普通攻擊；迷彩同步神經壓力 +3。你的隱匿 ${sp}${enemy ? `、對方感知 ${sense}` : ''}。`,
      locked: !c.equipment.some((i) => i.slot === 'implant' && CLOAK_KINDS.includes(i.kind ?? ''))
        ? '需要光學迷彩義體'
        : sp < sense
          ? `對方感知 ${sense}，你的隱匿只有 ${sp}，會被看穿`
          : undefined,
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
  const double = statMod(c, 'double')
  const patch = statMod(c, 'patch')
  const pick = (xs: string[]) => xs[Math.floor(r() * xs.length)]
  const push = (text: string, fx: FightFx, dmg?: number) => rounds.push({ text, you: Math.max(0, you), foe: Math.max(0, foe), fx, dmg })
  if (tactic === 'hack') push(`你接上神經線，黑進${enemy.name}的智慧槍。準星開始亂跳。`, 'hack')
  if (tactic === 'stealth') push(`迷彩啟動。${enemy.name}只看見一陣扭曲的雨。`, 'stealth')
  for (let i = 1; i <= MAX_ROUNDS && foe > 0; i++) {
    // 你的攻擊
    const first = tactic === 'stealth' && i === 1
    // 爆擊從同一個命中骰判定，不多抽亂數（多抽一次，所有戰鬥的結果都會變）
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
            ? `爆擊！你打中了${enemy.name}的要害（−${dmg}）。`
          : s.weapon
            ? `${pick(['你壓低身子連開三槍', '你貼著柱子探身射擊', '電磁手槍的電弧劈開雨幕'])}，命中${enemy.name}（−${dmg}）。`
            : `${pick(['你一拳打在對方的下巴', '你抓住槍管往回撞', '你用膝蓋頂進對方的肋骨'])}（−${dmg}）。`,
        first ? 'ambush' : crit ? 'crit' : 'hit',
        dmg,
      )
      // 雙持：用同一顆命中骰判定，不多抽亂數（沒有 double 的角色結果完全不變）
      if (!first && double && h < (s.hit + (tactic === 'force' ? 0.1 : 0)) * double && foe > 0) {
        const d2 = Math.round(base * 0.6)
        foe -= d2
        push(`你另一隻手的槍跟著響了，再補${enemy.name}一槍（−${d2}）。`, 'hit', d2)
      }
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
  if (won && patch) {
    you = Math.min(s.maxHp, you + patch)
    push(`你靠在牆邊替自己包紮，回復了 ${patch} HP。`, 'win')
  }
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
