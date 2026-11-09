// 物品型錄：義體（神機醫白蛇有賣）、武器與駭客終端（只會從戰利品或任務拿到）。
// 名稱用一般描述，不用原作的產品或品牌名。
import { type Character, type Item, type Style, attrLock, rng, statMod } from '../rules/core'

type Def = Omit<Item, 'id' | 'kind'> & { desc: string; style: Style }

export const ITEMS: Record<string, Def> = {
  // 起始裝備
  gun: { style: 'gunslinger', name: '舊型電磁手槍', slot: 'weapon', direction: 'force', bonus: 0.05, price: 1200, load: 0, mods: { atk: 6 }, desc: '攻擊 +6' },
  deck: { style: 'netrunner', name: '二手駭客終端', slot: 'deck', direction: 'hack', bonus: 0.05, price: 800, load: 0, desc: '' },
  camo: { style: 'nomad', name: '光學迷彩貼片', slot: 'implant', direction: 'stealth', bonus: 0.05, price: 1000, load: 25, desc: '能用迷彩繞背' },
  // 義體（神機醫有賣）
  subdermal: { style: 'berserker', name: '皮下護甲', slot: 'implant', direction: 'force', bonus: 0, price: 1500, load: 30, mods: { armor: 15 }, needs: { attr: 'body', min: 5 }, desc: '護甲 +15（等於 5 點技術）' },
  tendon: { style: 'berserker', name: '強化肌腱', slot: 'implant', direction: 'force', bonus: 0.03, price: 1300, load: 20, mods: { hp: 16 }, desc: '最大 HP +16' },
  reflexes: { style: 'gunslinger', name: '反射加速器', slot: 'implant', direction: 'force', bonus: 0, price: 1800, load: 25, mods: { hit: 0.06, crit: 0.06 }, needs: { attr: 'reflex', min: 5 }, desc: '命中 +6%、爆擊率 +6%' },
  coproc: { style: 'netrunner', name: '神經協處理器', slot: 'implant', direction: 'hack', bonus: 0.03, price: 1200, load: 15, mods: { jam: 1 }, desc: '駭入干擾 +1 回合' },
  // 只會掉落
  smartgun: { style: 'gunslinger', name: '智慧手槍', slot: 'weapon', direction: 'force', bonus: 0.05, price: 1600, load: 0, mods: { atk: 7, hit: 0.1 }, desc: '攻擊 +7、命中 +10%' },
  shotgun: { style: 'berserker', name: '重型霰彈槍', slot: 'weapon', direction: 'force', bonus: 0.08, price: 1900, load: 0, mods: { atk: 11, hit: -0.05 }, needs: { attr: 'body', min: 5 }, desc: '攻擊 +11、命中 −5%' },
  milDeck: { style: 'netrunner', name: '軍規駭客終端', slot: 'deck', direction: 'hack', bonus: 0.1, price: 2000, load: 0, mods: { jam: 1 }, needs: { attr: 'int', min: 5 }, desc: '駭入干擾 +1 回合' },
  silencer: { style: 'nomad', name: '消音手槍', slot: 'weapon', direction: 'stealth', bonus: 0.05, price: 1400, load: 0, mods: { atk: 5, ambush: 0.3 }, desc: '攻擊 +5、迷彩第一擊 +0.3 倍' },
  knife: { style: 'berserker', name: '振動短刀', slot: 'weapon', direction: 'force', bonus: 0.03, price: 1100, load: 0, mods: { atk: 4, crit: 0.08 }, desc: '攻擊 +4、爆擊率 +8%' },
  dampener: { style: 'nomad', name: '聲紋消除器', slot: 'implant', direction: 'stealth', bonus: 0.05, price: 1200, load: 15, mods: { ambush: 0.4 }, desc: '迷彩第一擊 +0.4 倍' },
  monoblade: { style: 'berserker', name: '單分子刃', slot: 'weapon', direction: 'force', bonus: 0.05, price: 2200, load: 0, mods: { atk: 9, crit: 0.06, critDmg: 0.2 }, needs: { attr: 'reflex', min: 5 }, desc: '攻擊 +9、爆擊率 +6%、爆擊傷害 +0.2 倍' },
  shockNode: { style: 'netrunner', name: '回授電擊節點', slot: 'implant', direction: 'hack', bonus: 0.03, price: 1700, load: 20, mods: { shock: 4 }, needs: { attr: 'int', min: 5 }, desc: '駭入干擾期間每回合電擊對方 −4' },
  adrenal: { style: 'berserker', name: '腎上腺泵', slot: 'implant', direction: 'force', bonus: 0, price: 1600, load: 20, mods: { berserk: 0.25 }, needs: { attr: 'body', min: 5 }, desc: 'HP 低於一半時攻擊 +25%' },
  icepick: { style: 'netrunner', name: '冰鑿終端', slot: 'deck', direction: 'hack', bonus: 0.08, price: 2100, load: 0, mods: { jam: 1, shock: 2 }, needs: { attr: 'int', min: 6 }, desc: '駭入干擾 +1 回合、每回合電擊 −2' },
  ghostWeave: { style: 'nomad', name: '幽影纖維', slot: 'implant', direction: 'stealth', bonus: 0.05, price: 2000, load: 20, mods: { ghost: 1 }, needs: { attr: 'cool', min: 6 }, desc: '迷彩繞背後，對方多一回合打不到你' },
  // 雙持
  pairedPistols: { style: 'gunslinger', name: '成對手槍', slot: 'weapon', direction: 'force', bonus: 0.05, price: 1300, load: 0, mods: { atk: 5, double: 0.2 }, desc: '攻擊 +5、命中後 20% 機率補一槍' },
  trigger: { style: 'gunslinger', name: '射擊輔助晶片', slot: 'implant', direction: 'force', bonus: 0.03, price: 1400, load: 15, mods: { hit: 0.05, critDmg: 0.2 }, desc: '命中 +5%、爆擊傷害 +0.2 倍' },
  twinSmart: { style: 'gunslinger', name: '雙持智慧手槍', slot: 'weapon', direction: 'force', bonus: 0.08, price: 2300, load: 0, mods: { atk: 7, hit: 0.06, double: 0.3 }, needs: { attr: 'reflex', min: 6 }, desc: '攻擊 +7、命中 +6%、命中後 30% 機率補一槍' },
  gyroArm: { style: 'gunslinger', name: '陀螺穩定手臂', slot: 'implant', direction: 'force', bonus: 0, price: 1900, load: 20, mods: { hit: 0.04, double: 0.15 }, needs: { attr: 'reflex', min: 5 }, desc: '命中 +4%、命中後 15% 機率補一槍' },
  // 狂暴大猩猩
  ironFists: { style: 'berserker', name: '液壓鐵拳', slot: 'weapon', direction: 'force', bonus: 0.05, price: 1500, load: 0, mods: { atk: 8, hp: 10, hit: -0.03 }, needs: { attr: 'body', min: 5 }, desc: '攻擊 +8、最大 HP +10、命中 −3%' },
  boneLace: { style: 'berserker', name: '骨骼強化', slot: 'implant', direction: 'force', bonus: 0, price: 1700, load: 25, mods: { hp: 20, armor: 5 }, needs: { attr: 'body', min: 6 }, desc: '最大 HP +20、護甲 +5' },
  // 速駭
  quickDeck: { style: 'netrunner', name: '速駭終端', slot: 'deck', direction: 'hack', bonus: 0.06, price: 1500, load: 0, mods: { jam: 1, calm: 1 }, desc: '駭入干擾 +1 回合、駭入神經壓力 −1' },
  neuralBuffer: { style: 'netrunner', name: '神經緩衝器', slot: 'implant', direction: 'hack', bonus: 0.03, price: 1300, load: 10, mods: { cap: 15, calm: 1 }, desc: '神經容量 +15、駭入神經壓力 −1' },
  // 流浪者
  scavEye: { style: 'nomad', name: '拾荒義眼', slot: 'implant', direction: 'stealth', bonus: 0.03, price: 1200, load: 10, mods: { loot: 0.3, hit: 0.02 }, desc: '戰利品機率 +30%、命中 +2%' },
  roadMed: { style: 'nomad', name: '公路急救泵', slot: 'implant', direction: 'stealth', bonus: 0, price: 1500, load: 15, mods: { patch: 10 }, desc: '打贏後立刻回復 10 HP' },
  dustCloak: { style: 'nomad', name: '沙塵迷彩斗篷', slot: 'implant', direction: 'stealth', bonus: 0.05, price: 1800, load: 20, mods: { ambush: 0.3, armor: 6 }, needs: { attr: 'cool', min: 5 }, desc: '能用迷彩繞背、第一擊 +0.3 倍、護甲 +6' },
  nomadRifle: { style: 'nomad', name: '部族獵槍', slot: 'weapon', direction: 'stealth', bonus: 0.05, price: 1700, load: 0, mods: { atk: 7, ambush: 0.4 }, needs: { attr: 'cool', min: 5 }, desc: '攻擊 +7、迷彩第一擊 +0.4 倍' },
}

/** 裝上這件要的屬性還不夠時的原因（舊存檔的物品沒有 needs，從型錄查）。 */
export const itemLock = (c: Character, it: Item) => attrLock(c, it.needs ?? (it.kind ? ITEMS[it.kind]?.needs : undefined))

export const SHOP_IMPLANTS = ['subdermal', 'tendon', 'reflexes', 'coproc', 'camo']
/** 神機醫的訂製義體：其他義體每次挑三種，原價；屬性不夠也能買，先放背包。 */
export const ORDER_IMPLANTS = Object.keys(ITEMS).filter((k) => ITEMS[k].slot === 'implant' && !SHOP_IMPLANTS.includes(k))
export const clinicOrders = (seed: number) => offer(rng(seed), ORDER_IMPLANTS, `o${seed.toString(36)}`)

export function makeItem(kind: string, tag: string | number): Item {
  const { desc: _, ...d } = ITEMS[kind]
  return { ...structuredClone(d), id: `${kind}#${tag}`, kind }
}

export const itemDesc = (i: Item) => (i.kind && ITEMS[i.kind] ? ITEMS[i.kind].desc : '')
/** 物品的流派（舊存檔的物品沒存這欄，從型錄查）。 */
export const itemStyle = (i: Item): Style | undefined => (i.kind ? ITEMS[i.kind]?.style : undefined)

/** 新角色的起始裝備：一把手槍。抵押價＝售價 60%。 */
export const STARTER_GEAR: Item[] = [makeItem('gun', 1)]
/** 建立傭兵時再三選一件直接裝上：決定一開始走得動哪條路線（駭入、潛行，或武力的耐打）。 */
export const STARTER_CHOICES: Item[] = [makeItem('deck', 1), makeItem('camo', 1), makeItem('tendon', 1)]

/** 掉寶表：街頭工作依難度；高階工作與劇情戰鬥另有表。每個流派都有幾件，三選一才有得挑。 */
export const STREET = ['tendon', 'knife', 'ironFists', 'smartgun', 'pairedPistols', 'trigger', 'coproc', 'quickDeck', 'neuralBuffer', 'silencer', 'dampener', 'scavEye', 'roadMed']
export const RARE = ['subdermal', 'shotgun', 'monoblade', 'adrenal', 'boneLace', 'reflexes', 'smartgun', 'twinSmart', 'gyroArm', 'milDeck', 'shockNode', 'icepick', 'ghostWeave', 'dustCloak', 'nomadRifle']

/** 掉了寶就是三選一：從表裡抽三種不重複的（fixed＝一定在選項裡的那件，例如劇情指定的）。 */
function offer(r: () => number, table: string[], tag: string, fixed?: string): Item[] {
  const pool = table.filter((k) => k !== fixed)
  const kinds = fixed ? [fixed] : []
  while (kinds.length < 3 && pool.length) kinds.push(pool.splice(Math.floor(r() * pool.length), 1)[0])
  return kinds.map((k, i) => makeItem(k, `${tag}${i}`))
}

/** 依 seed 擲一次：機率內（乘上名聲卡「黑市眼光」等的 loot 加成）就從表裡抽三件。 */
export function rollFrom(seed: number, table: string[], chance: number, lootBoost = 0): Item[] | null {
  const r = rng(seed)
  if (r() >= chance * (1 + lootBoost)) return null
  return offer(r, table, seed.toString(36))
}

/** 完成一件委託（不管有沒有開打）：每級難度 10%（難度 1 10%、難度 3 30%）。 */
export const streetLoot = (seed: number, tier: number, c: Character) => rollFrom(seed, STREET, 0.1 * tier, statMod(c, 'loot'))
/** 依種類與機率擲一次（劇情結案給的，機率 ×1.5）：掉了就是指定的那件＋兩件稀有表裡的。 */
export function rollKind(seed: number, kind: string, chance: number, c: Character): Item[] | null {
  const r = rng(seed)
  return r() < chance * 1.5 * (1 + statMod(c, 'loot')) ? offer(r, RARE, seed.toString(36), kind) : null
}


/** 精英委託打贏：一定掉，稀有表三選一。 */
export const eliteLoot = (seed: number) => rollFrom(seed, RARE, 1)!
/** 事件給的掉寶：一定掉。 */
export const eventLoot = (seed: number, table: 'street' | 'rare') => rollFrom(seed, table === 'rare' ? RARE : STREET, 1)!

/** 黑市與診所的義體都是半價（贓貨）。 */
export const MARKET_RATE = 0.75
export const marketPrice = (price: number) => Math.round(price * MARKET_RATE)
/** 黑市貨架：兩表合併抽三件。 */
export const marketStock = (seed: number) => offer(rng(seed), [...new Set([...STREET, ...RARE])], `m${seed.toString(36)}`)
/** 救命保單的價格。 */
export const LIFELINE_PRICE = 450
