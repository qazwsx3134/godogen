// 名聲卡牌：名聲每升一級三選一，同一張可以再拿來升級（到上限）。效果全是固定修正，不另外擲骰，
// 所以沒有卡的角色數值和以前完全一樣。卡標方向，已經拿過的方向較常出現，用來湊出自己的流派。
import type { Direction, ModKey } from './core'

export interface PerkDef {
  name: string
  /** 'any'＝通用卡。 */
  dir: Direction | 'any'
  max: number
  /** 稀有卡出現的權重較低。 */
  rare?: boolean
  /** 每級的戰鬥／角色修正（和義體的 mods 加在一起）。 */
  mods?: Partial<Record<ModKey, number>>
  /** 每級：這個方向的委託成功率加成、致命機率扣減（同裝備的方向加成）。 */
  bonus?: number
  /** 每級：這個方向的委託報酬 +%。 */
  reward?: number
  /** 保底卡：可選的卡不夠三張時補上，拿了立刻生效、不留在身上。 */
  instant?: 'cash' | 'heal'
  desc: string
}

export const PERKS: Record<string, PerkDef> = {
  // 火力
  gunsmith: { name: '槍匠手感', dir: 'force', max: 3, mods: { atk: 3 }, desc: '攻擊 +3' },
  tough: { name: '硬骨頭', dir: 'force', max: 3, mods: { hp: 12 }, desc: '最大 HP +12' },
  steady: { name: '穩定射擊', dir: 'force', max: 3, mods: { hit: 0.04 }, desc: '命中 +4%' },
  executioner: { name: '處刑者', dir: 'force', max: 2, mods: { crit: 0.03, critDmg: 0.25 }, desc: '暴擊率 +3%、暴擊傷害 +0.25 倍' },
  lastStand: { name: '背水一戰', dir: 'force', max: 2, rare: true, mods: { berserk: 0.3 }, desc: 'HP 低於一半時攻擊 +30%' },
  streetRep: { name: '街頭惡名', dir: 'force', max: 3, bonus: 0.03, reward: 0.1, desc: '火力委託成功率 +3%、報酬 +10%' },
  // 入侵
  iceApprentice: { name: '黑冰學徒', dir: 'hack', max: 2, mods: { jam: 1 }, desc: '駭進智慧槍的干擾 +1 回合' },
  buffer: { name: '神經緩衝', dir: 'hack', max: 3, mods: { cap: 10 }, desc: '神經容量 +10（多一點義體空間）' },
  feedback: { name: '回授電擊', dir: 'hack', max: 2, rare: true, mods: { shock: 4 }, desc: '干擾期間每回合電擊對方 −4' },
  coolant: { name: '冷卻迴路', dir: 'hack', max: 2, mods: { calm: 1 }, desc: '駭客神經壓力 −1（最少 1）' },
  dataBroker: { name: '資料掮客', dir: 'hack', max: 3, bonus: 0.03, reward: 0.1, desc: '入侵委託成功率 +3%、報酬 +10%' },
  // 潛行
  shadowStep: { name: '影步', dir: 'stealth', max: 3, mods: { ambush: 0.3 }, desc: '迷彩偷襲第一擊 +0.3 倍' },
  ghost: { name: '鬼影', dir: 'stealth', max: 1, rare: true, mods: { ghost: 1 }, desc: '迷彩繞背後，對方多一回合打不到你' },
  quietPro: { name: '無聲專家', dir: 'stealth', max: 3, bonus: 0.03, reward: 0.1, desc: '潛行委託成功率 +3%、報酬 +10%' },
  // 通用
  kevlar: { name: '防彈纖維內襯', dir: 'any', max: 3, mods: { armor: 6 }, desc: '護甲 +6' },
  fence: { name: '黑市眼光', dir: 'any', max: 2, mods: { loot: 0.5 }, desc: '戰利品機率 +50%（相對）' },
  // 保底
  cash: { name: '一筆黑錢', dir: 'any', max: Infinity, instant: 'cash', desc: '立刻 +¢400' },
  stim: { name: '白蛇的特製針劑', dir: 'any', max: Infinity, instant: 'heal', desc: '傷勢立刻歸零' },
}

export const PERK_IDS = Object.keys(PERKS).filter((id) => !PERKS[id].instant)
export const FALLBACK_PERKS = ['cash', 'stim']
/** 保底卡「一筆黑錢」的金額。 */
export const PERK_CASH = 400

/** 名聲稱號（依名聲等級）。 */
export const FAME_TITLES = ['無名小卒', '街頭新面孔', '有點名氣', '中間人的常客', '地下名人', '魔都傳說']
export const fameTitle = (level: number) => FAME_TITLES[Math.min(FAME_TITLES.length - 1, level)]
