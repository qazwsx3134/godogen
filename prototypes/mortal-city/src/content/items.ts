// 物品型錄：義體（白蛇的診所有賣）、武器與作業設備（只會從戰利品或任務拿到）。
// 名稱用一般描述，不用原作的產品或品牌名。
import { type Item, rng } from '../rules/core'

type Def = Omit<Item, 'id' | 'kind'> & { desc: string }

export const ITEMS: Record<string, Def> = {
  // 起始裝備
  gun: { name: '舊型電磁手槍', slot: 'weapon', direction: 'force', bonus: 0.05, price: 1200, load: 0, mods: { atk: 6 }, desc: '攻擊 +6' },
  deck: { name: '二手駭客終端', slot: 'deck', direction: 'hack', bonus: 0.05, price: 800, load: 0, desc: '' },
  camo: { name: '光學迷彩貼片', slot: 'implant', direction: 'stealth', bonus: 0.05, price: 1000, load: 25, desc: '能用迷彩繞背' },
  // 義體（診所）
  subdermal: { name: '皮下護甲', slot: 'implant', direction: 'force', bonus: 0, price: 1500, load: 30, mods: { armor: 15 }, desc: '護甲 +15（等於 5 點技術）' },
  tendon: { name: '強化肌腱', slot: 'implant', direction: 'force', bonus: 0.03, price: 1300, load: 20, mods: { hp: 16 }, desc: '最大 HP +16' },
  reflexes: { name: '反射加速器', slot: 'implant', direction: 'force', bonus: 0, price: 1800, load: 25, mods: { hit: 0.06, crit: 0.06 }, desc: '命中 +6%、暴擊率 +6%' },
  coproc: { name: '神經協處理器', slot: 'implant', direction: 'hack', bonus: 0.03, price: 1200, load: 15, mods: { jam: 1 }, desc: '駭客干擾 +1 回合' },
  // 只會掉落
  smartgun: { name: '智慧手槍', slot: 'weapon', direction: 'force', bonus: 0.05, price: 1600, load: 0, mods: { atk: 7, hit: 0.1 }, desc: '攻擊 +7、命中 +10%' },
  shotgun: { name: '重型霰彈槍', slot: 'weapon', direction: 'force', bonus: 0.08, price: 1900, load: 0, mods: { atk: 11, hit: -0.05 }, desc: '攻擊 +11、命中 −5%' },
  milDeck: { name: '軍規駭客終端', slot: 'deck', direction: 'hack', bonus: 0.1, price: 2000, load: 0, mods: { jam: 1 }, desc: '駭客干擾 +1 回合' },
}

export const SHOP_IMPLANTS = ['subdermal', 'tendon', 'reflexes', 'coproc', 'camo']

export function makeItem(kind: string, tag: string | number): Item {
  const { desc: _, ...d } = ITEMS[kind]
  return { ...structuredClone(d), id: `${kind}#${tag}`, kind }
}

export const itemDesc = (i: Item) => (i.kind && ITEMS[i.kind] ? ITEMS[i.kind].desc : '')

/** 新角色的起始裝備（三個欄位）。抵押價＝售價 60%。 */
export const STARTER_GEAR: Item[] = [makeItem('gun', 1), makeItem('deck', 1), makeItem('camo', 1)]

/** 掉寶表：街頭工作依階級；高階工作與劇情戰鬥另有表。 */
const STREET = ['coproc', 'tendon', 'smartgun']
const RARE = ['subdermal', 'reflexes', 'shotgun', 'milDeck', 'smartgun']

/** 依 seed 擲一次：機率內就從表裡挑一件。 */
export function rollFrom(seed: number, table: string[], chance: number): Item | null {
  const r = rng(seed)
  if (r() >= chance) return null
  return makeItem(table[Math.floor(r() * table.length)], seed.toString(36))
}

/** 排隊打贏一場：每階 4%（第 1 階 4%、第 2 階 8%）。 */
export const streetLoot = (seed: number, tier: number) => rollFrom(seed, tier >= 4 ? RARE : STREET, tier >= 4 ? 0.3 : 0.04 * tier)
/** 劇情或高階工作打贏一場：25%。 */
export const fightLoot = (seed: number) => rollFrom(seed, RARE, 0.25)
/** 依種類與機率擲一次（劇情結案給的）。 */
export function rollKind(seed: number, kind: string, chance: number): Item | null {
  return rng(seed)() < chance ? makeItem(kind, seed.toString(36)) : null
}


