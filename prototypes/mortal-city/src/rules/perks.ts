// 名聲卡牌：名聲每升一級三選一，同一張可以再拿來升級（到上限）。效果全是固定修正，不另外擲骰，
// 所以沒有卡的角色數值和以前完全一樣。卡標流派（狂暴大猩猩／雙持／速駭／流浪者），拿過的流派較常出現。
import type { ModKey, Style } from './core'

export interface PerkDef {
  name: string
  /** 流派；'any'＝通用卡。委託成功率／報酬加成算在流派對應的路線上（STYLE_DIR）。 */
  style: Style | 'any'
  max: number
  /** 稀有卡出現的權重較低。 */
  rare?: boolean
  /** 每級的戰鬥／角色修正（和義體的 mods 加在一起）。 */
  mods?: Partial<Record<ModKey, number>>
  /** 每級：這個流派對應路線的委託成功率加成、致命機率扣減（同裝備的方向加成）。 */
  bonus?: number
  /** 每級：這個流派對應路線的委託報酬 +%。 */
  reward?: number
  /** 保底卡：可選的卡不夠三張時補上，拿了立刻生效、不留在身上。 */
  instant?: 'cash' | 'heal'
  desc: string
}

// 卡的 id 存在存檔裡，改名只改 name，不改 id。
export const PERKS: Record<string, PerkDef> = {
  // 狂暴大猩猩 Berserker：血厚、皮硬、越痛越兇（武力路線）
  tough: { name: '硬骨頭', style: 'berserker', max: 3, mods: { hp: 12 }, desc: '最大 HP +12' },
  lastStand: { name: '背水一戰', style: 'berserker', max: 2, rare: true, mods: { berserk: 0.3 }, desc: 'HP 低於一半時攻擊 +30%' },
  streetRep: { name: '街頭惡名', style: 'berserker', max: 3, bonus: 0.03, reward: 0.1, desc: '武力委託成功率 +3%、報酬 +10%' },
  ironHide: { name: '鋼鐵皮層', style: 'berserker', max: 3, mods: { armor: 5 }, desc: '護甲 +5' },
  bloodRush: { name: '見血狂熱', style: 'berserker', max: 2, mods: { berserk: 0.15, atk: 2 }, desc: '攻擊 +2、HP 低於一半時攻擊再 +15%' },
  chestBeat: { name: '捶胸怒吼', style: 'berserker', max: 3, mods: { hp: 8, atk: 2 }, desc: '最大 HP +8、攻擊 +2' },
  // 雙持 Gunslinger：準、快、兩把槍一起響（武力路線）
  gunsmith: { name: '槍匠手感', style: 'gunslinger', max: 3, mods: { atk: 3 }, desc: '攻擊 +3' },
  steady: { name: '穩定射擊', style: 'gunslinger', max: 3, mods: { hit: 0.04 }, desc: '命中 +4%' },
  executioner: { name: '處刑者', style: 'gunslinger', max: 2, mods: { crit: 0.03, critDmg: 0.25 }, desc: '爆擊率 +3%、爆擊傷害 +0.25 倍' },
  twinFire: { name: '雙槍連射', style: 'gunslinger', max: 2, rare: true, mods: { double: 0.25 }, desc: '命中後 25% 機率另一把槍補一槍（六成傷害）' },
  quickDraw: { name: '快拔', style: 'gunslinger', max: 3, mods: { hit: 0.03, crit: 0.02 }, desc: '命中 +3%、爆擊率 +2%' },
  bountyHunter: { name: '賞金獵人', style: 'gunslinger', max: 3, bonus: 0.03, reward: 0.1, desc: '武力委託成功率 +3%、報酬 +10%' },
  // 速駭 Netrunner：干擾、電擊、腦袋撐得住（駭入路線）
  iceApprentice: { name: '黑冰學徒', style: 'netrunner', max: 2, mods: { jam: 1 }, desc: '駭入的干擾 +1 回合（駭入強度 +2）' },
  buffer: { name: '神經緩衝', style: 'netrunner', max: 3, mods: { cap: 10 }, desc: '神經容量 +10（多一點義體空間）' },
  feedback: { name: '回授電擊', style: 'netrunner', max: 2, rare: true, mods: { shock: 4 }, desc: '干擾期間每回合電擊對方 −4' },
  coolant: { name: '冷卻迴路', style: 'netrunner', max: 2, mods: { calm: 1 }, desc: '駭入神經壓力 −1（最少 1）' },
  dataBroker: { name: '資料掮客', style: 'netrunner', max: 3, bonus: 0.03, reward: 0.1, desc: '駭入委託成功率 +3%、報酬 +10%' },
  spike: { name: '尖刺程式', style: 'netrunner', max: 3, mods: { shock: 2 }, desc: '干擾期間每回合電擊對方 −2' },
  quickhack: { name: '速駭協定', style: 'netrunner', max: 1, rare: true, mods: { jam: 1, calm: 1 }, desc: '駭入干擾 +1 回合、駭入神經壓力 −1' },
  // 流浪者 Nomad：繞路、撿東西、自己包紮（潛行路線）
  shadowStep: { name: '影步', style: 'nomad', max: 3, mods: { ambush: 0.3 }, desc: '光學迷彩繞背第一擊 +0.3 倍' },
  ghost: { name: '鬼影', style: 'nomad', max: 1, rare: true, mods: { ghost: 1 }, desc: '迷彩繞背後，對方多一回合打不到你（隱匿 +2）' },
  quietPro: { name: '走私老手', style: 'nomad', max: 3, bonus: 0.03, reward: 0.1, desc: '潛行委託成功率 +3%、報酬 +10%' },
  fence: { name: '黑市眼光', style: 'nomad', max: 2, mods: { loot: 0.5 }, desc: '戰利品機率 +50%（相對）' },
  roadPatch: { name: '公路急救', style: 'nomad', max: 3, mods: { patch: 8 }, desc: '打贏後立刻回復 8 HP' },
  dustRunner: { name: '荒野腳程', style: 'nomad', max: 3, mods: { ambush: 0.2, armor: 3 }, desc: '迷彩繞背第一擊 +0.2 倍、護甲 +3' },
  scavenger: { name: '拾荒者', style: 'nomad', max: 2, mods: { loot: 0.3, patch: 4 }, desc: '戰利品機率 +30%、打贏後回復 4 HP' },
  // 通用
  kevlar: { name: '防彈纖維內襯', style: 'any', max: 3, mods: { armor: 6 }, desc: '護甲 +6' },
  // 保底
  cash: { name: '一筆黑錢', style: 'any', max: Infinity, instant: 'cash', desc: '立刻 +¢400' },
  stim: { name: '白蛇的特製針劑', style: 'any', max: Infinity, instant: 'heal', desc: '傷勢立刻歸零' },
}

export const PERK_IDS = Object.keys(PERKS).filter((id) => !PERKS[id].instant)
export const FALLBACK_PERKS = ['cash', 'stim']
/** 保底卡「一筆黑錢」的金額。 */
export const PERK_CASH = 400

/** 名聲稱號（依名聲等級）。 */
export const FAME_TITLES = ['無名小卒', '街頭新面孔', '有點名氣', '中間人的常客', '地下名人', '魔都傳說']
export const fameTitle = (level: number) => FAME_TITLES[Math.min(FAME_TITLES.length - 1, level)]
