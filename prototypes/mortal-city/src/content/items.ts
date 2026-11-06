// 物品型錄：義體（白蛇的診所有賣）、武器與駭客終端（只會從戰利品或任務拿到）。
// 名稱用一般描述，不用原作的產品或品牌名。
import { type Item, rng } from '../rules/core'

type Def = Omit<Item, 'id' | 'kind'> & { desc: string }

export const ITEMS: Record<string, Def> = {
  // 起始裝備
  gun: { name: '舊型電磁手槍', slot: 'weapon', direction: 'force', bonus: 0.05, price: 1200, load: 0, mods: { atk: 6 }, desc: '攻擊 +6' },
  deck: { name: '二手駭客終端', slot: 'deck', direction: 'hack', bonus: 0.05, price: 800, load: 0, desc: '' },
  camo: { name: '光學迷彩貼片', slot: 'implant', direction: 'stealth', bonus: 0.05, price: 1000, load: 25, desc: '能用光學迷彩繞背' },
  // 義體（診所）
  subdermal: { name: '皮下護甲', slot: 'implant', direction: 'force', bonus: 0, price: 1500, load: 30, mods: { armor: 15 }, desc: '護甲 +15（等於 5 點技術）' },
  tendon: { name: '強化肌腱', slot: 'implant', direction: 'force', bonus: 0.03, price: 1300, load: 20, mods: { hp: 16 }, desc: '最大 HP +16' },
  reflexes: { name: '反射加速器', slot: 'implant', direction: 'force', bonus: 0, price: 1800, load: 25, mods: { hit: 0.06, crit: 0.06 }, desc: '命中 +6%、爆擊率 +6%' },
  coproc: { name: '神經協處理器', slot: 'implant', direction: 'hack', bonus: 0.03, price: 1200, load: 15, mods: { jam: 1 }, desc: '駭入干擾 +1 回合' },
  // 只會掉落
  smartgun: { name: '智慧手槍', slot: 'weapon', direction: 'force', bonus: 0.05, price: 1600, load: 0, mods: { atk: 7, hit: 0.1 }, desc: '攻擊 +7、命中 +10%' },
  shotgun: { name: '重型霰彈槍', slot: 'weapon', direction: 'force', bonus: 0.08, price: 1900, load: 0, mods: { atk: 11, hit: -0.05 }, desc: '攻擊 +11、命中 −5%' },
  milDeck: { name: '軍規駭客終端', slot: 'deck', direction: 'hack', bonus: 0.1, price: 2000, load: 0, mods: { jam: 1 }, desc: '駭入干擾 +1 回合' },
}

/** 每件貨的來歷（商店用，全是「大概是偷來的」）。 */
export const PROVENANCE: Record<string, string> = {
  subdermal: '從前一位客人身上拆下來的，已消毒（應該）',
  tendon: '冷藏箱上還貼著別家醫院的條碼',
  reflexes: '韌體被改過，序號欄是空白',
  coproc: '包裝盒上寫著「醫療廢棄物」',
  camo: '軍方庫存，帳上已經註銷',
  smartgun: '上週還在 MPD 的證物室',
  shotgun: '槍托上刻著別人的名字',
  milDeck: '開機畫面是某企業的資產編號',
}

export interface Shop {
  id: string
  name: string
  fixerId: string
  line: string
  kinds: string[]
  /** 售價倍率（贓貨也要加價）。 */
  markup: number
  /** 要先有這位中間人的信任。 */
  trust?: number
  /** 買了直接裝上（白蛇的診所）；否則放進背包。 */
  install?: boolean
}

export const SHOPS: Shop[] = [
  { id: 'snake', name: '白蛇的義體診所', fixerId: 'snake', line: '「裝什麼都可以，裝不下的別怪我。來歷？我也不知道。」', kinds: ['subdermal', 'tendon', 'reflexes', 'coproc', 'camo'], markup: 1, install: true },
  { id: 'k', name: '老K的後巷貨架', fixerId: 'k', line: '「序號我都磨掉了。出了這個門，你沒見過我。」', kinds: ['smartgun', 'shotgun', 'milDeck'], markup: 1.25, trust: 3 },
]

export const shopPrice = (shop: Shop, kind: string) => Math.round(ITEMS[kind].price * shop.markup)

export function makeItem(kind: string, tag: string | number): Item {
  const { desc: _, ...d } = ITEMS[kind]
  return { ...structuredClone(d), id: `${kind}#${tag}`, kind }
}

export const itemDesc = (i: Item) => (i.kind && ITEMS[i.kind] ? ITEMS[i.kind].desc : '')

/** 新角色的起始裝備（三個欄位）。抵押價＝售價 60%。 */
export const STARTER_GEAR: Item[] = [makeItem('gun', 1), makeItem('deck', 1), makeItem('camo', 1)]

/** 掉寶表：街頭工作依難度；高階工作與劇情戰鬥另有表。 */
const STREET = ['coproc', 'tendon', 'smartgun']
const RARE = ['subdermal', 'reflexes', 'shotgun', 'milDeck', 'smartgun']

/** 依 seed 擲一次：機率內就從表裡挑一件。 */
export function rollFrom(seed: number, table: string[], chance: number): Item | null {
  const r = rng(seed)
  if (r() >= chance) return null
  return makeItem(table[Math.floor(r() * table.length)], seed.toString(36))
}

/** 排隊打贏一場：每級難度 4%（難度 1 4%、難度 2 8%）。 */
export const streetLoot = (seed: number, tier: number) => rollFrom(seed, tier >= 4 ? RARE : STREET, tier >= 4 ? 0.3 : 0.04 * tier)
/** 劇情或高階工作打贏一場：25%。 */
export const fightLoot = (seed: number) => rollFrom(seed, RARE, 0.25)
/** 依種類與機率擲一次（劇情結案給的）。 */
export function rollKind(seed: number, kind: string, chance: number): Item | null {
  return rng(seed)() < chance ? makeItem(kind, seed.toString(36)) : null
}


