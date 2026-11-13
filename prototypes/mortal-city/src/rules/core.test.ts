import { describe, expect, it } from 'vitest'
import {
  type Character,
  type Item,
  type JobDef,
  type LogEvent,
  capacityOf,
  dirBonus,
  fameToNext,
  fightStats,
  grantProgress,
  hashSeed,
  heatEnemy,
  jobReward,
  maxHpOf,
  neuralCapacity,
  neuralStage,
  perkOptions,
  styleWeight,
  perkReward,
  PREPARED_DICE,
  lethalPool,
  lethalWound,
  riskDice,
  resolveFight,
  STYLES,
  tacticsFor,
} from './core'
import { PERKS, PERK_IDS } from './perks'
import { POOL_MAX, SEVERE_INJURY, applyCost, attrDice, costInjury, jobPool, poolSize, rollPool } from './core'
import { BEATS } from '../content/beats'
import { ITEMS, makeItem } from '../content/items'

const job: JobDef = {
  id: 'test-1',
  direction: 'stealth',
  tier: 1,
  name: '測試',
  fixerId: 'k',
  reward: 100,
  xp: 10,
  stress: 1,
  heat: 0,
  injury: 5,
  blurb: '',
}

function char(over: Partial<Character> = {}): Character {
  return {
    id: 'c1',
    name: 'T',
    alive: true,
    level: 1,
    xp: 0,
    credits: 0,
    injury: 0,
    stress: 0,
    implantLoad: 10,
    heat: 0,
    equipment: [],
    lifelines: 0,
    attrs: { tech: 3, reflex: 3, body: 3, int: 3, cool: 3 },
    attrPoints: 0,
    stash: [],
    fame: { level: 0, xp: 0, total: 0 },
    perks: {},
    picks: [],
    ...over,
  }
}

describe('neural', () => {
  it('capacity grows 4 per level from 100', () => {
    expect(neuralCapacity(1)).toBe(100)
    expect(neuralCapacity(50)).toBe(296)
  })
  it('stage thresholds', () => {
    expect(neuralStage(40)).toBe('stable')
    expect(neuralStage(39)).toBe('alert')
    expect(neuralStage(19)).toBe('critical')
    expect(neuralStage(0)).toBe('lost')
  })
})

describe('lethal check (DICE-POOL-SPEC §5): dice, not percentages', () => {
  const spec = { attr: 'cool' as const, direction: 'stealth' as const, foe: 'story' as const, risk: 0.18, prepared: false }
  it('builds the pool from the attribute, gear, the option, the foe and severe injury', () => {
    expect(lethalPool(char(), spec)).toEqual([{ label: '沉著 3', n: 2 }])
    expect(lethalPool(char(), { ...spec, risk: 0.3 }).map((p) => p.n)).toEqual([2, -1])
    expect(lethalPool(char(), { ...spec, risk: 0.06 }).map((p) => p.n)).toEqual([2, 1])
    // 器材、屬性選項：+2，不再另算險度
    expect(lethalPool(char(), { ...spec, risk: 0.3, prepared: true }).map((p) => p.n)).toEqual([2, PREPARED_DICE])
    expect(lethalPool(char({ injury: 70 }), { ...spec, foe: 'elite' }).map((p) => p.n)).toEqual([2, -1, -1])
    expect(lethalPool(char(), { ...spec, scenes: -2 }).map((p) => p.n)).toEqual([2, -2])
    expect([0.28, 0.2, 0.1].map(riskDice)).toEqual([-1, 0, 1])
  })
  it('a lethal wound kills without a lifeline, uses it when there is one, and a system fault rescues for free', () => {
    expect(lethalWound(char(), [2, 3]).kind).toBe('dead')
    expect(lethalWound(char({ lifelines: 1 }), [2, 3]).kind).toBe('rescued')
    expect(lethalWound(char(), [2, 3], true).kind).toBe('rescued_system')
    expect(lethalWound(char(), [2, 3]).reason).toMatch(/擲出 2、3/)
  })
})

describe('heat makes the other side stronger', () => {
  it('+8% HP and attack per star', () => {
    const e = { name: 'x', hp: 100, atk: 10, hit: 0.5 }
    expect(heatEnemy(e, 0)).toBe(e)
    expect(heatEnemy(e, 3)).toEqual({ ...e, hp: 124, atk: 12 })
  })
})

describe('attributes', () => {
  const foe = { name: 'x', hp: 70, atk: 9, hit: 0.55 }
  const lost = (f: ReturnType<typeof resolveFight>) => f.hpStart - f.hp
  const sum = (over: Partial<Character>, n = 200) => {
    let won = 0
    let hurt = 0
    for (let i = 0; i < n; i++) {
      const f = resolveFight(char(over), foe, 'force', i * 13)
      won += f.won ? 1 : 0
      hurt += lost(f)
    }
    return { won, hurt }
  }
  const at = (a: Partial<Character['attrs']>) => ({ attrs: { tech: 3, reflex: 3, body: 3, int: 3, cool: 3, ...a } })

  it('技術 armour cuts the damage you take, and raises neural capacity', () => {
    expect(sum(at({ tech: 9 })).hurt).toBeLessThan(sum({}).hurt * 0.85)
    expect(capacityOf(char(at({ tech: 9 })))).toBe(capacityOf(char()) + 18)
  })

  it('體能 raises max HP and the injury % still matches the HP left', () => {
    const c = char({ ...at({ body: 7 }), injury: 25 })
    const f = resolveFight(c, foe, 'force', 3)
    expect(f.maxHp).toBe(132)
    expect(f.hpStart).toBe(99)
    expect(f.injury).toBe(Math.round(100 - (f.hp * 100) / 132))
  })

  it('反應 lands crits, 沉著 makes them hit harder, 智力 jams longer', () => {
    const text = (over: Partial<Character>) => resolveFight(char(over), foe, 'force', 5).rounds.map((r) => r.text).join()
    expect(text({})).not.toMatch(/爆擊/)
    expect(text(at({ reflex: 11 }))).toMatch(/爆擊/)
    expect(fightStats(char(at({ cool: 8 }))).critDmg).toBeCloseTo(2.0)
    const jammed = (int: number) => resolveFight(char(at({ int })), foe, 'hack', 1).rounds.filter((r) => r.text.includes('亂跳')).length
    expect(jammed(9)).toBeGreaterThanOrEqual(jammed(3))
    expect(resolveFight(char(at({ int: 9 })), foe, 'hack', 1).stress).toBe(2)
  })
})

describe('items', () => {
  const foe = { name: 'x', hp: 70, atk: 9, hit: 0.55 }
  const plate: Item = { id: 'p#1', kind: 'subdermal', name: '皮下護甲', slot: 'implant', direction: 'force', bonus: 0, price: 1500, load: 30, mods: { armor: 15 } }

  it('an armour implant cuts more damage than a few points of 技術', () => {
    let bare = 0
    let armoured = 0
    for (let i = 0; i < 200; i++) {
      const a = resolveFight(char(), foe, 'force', i)
      const b = resolveFight(char({ equipment: [plate] }), foe, 'force', i)
      bare += a.hpStart - a.hp
      armoured += b.hpStart - b.hp
    }
    expect(armoured).toBeLessThan(bare * 0.8)
  })

})

describe('fame cards: pick 1 of 3 on each fame level', () => {
  const brawl: JobDef = { ...job, id: 'brawl-1', direction: 'hack', tier: 1, reward: 100 }

  it('fame comes from jobs and queues a card pick per level', () => {
    const c = char()
    const events: LogEvent[] = []
    for (let k = 0; k < 2; k++) grantProgress(c, brawl, true, 0, events)
    expect(c.fame).toEqual({ level: 1, xp: 20 - fameToNext(0), total: 20 })
    expect(c.picks).toEqual([{ kind: 'perk', level: 1, seed: hashSeed('c1', 'fame', 1) }])
    expect(events.some((e) => e.text.includes('名聲提升到 Lv.1'))).toBe(true)
    grantProgress(c, brawl, false, 0, events)
    expect(c.fame.total).toBe(25)
  })

  it('options are 3 distinct, fixed by the seed, skip maxed cards, and fill up with fallback cards', () => {
    const o = perkOptions(char(), 42)
    expect(new Set(o).size).toBe(3)
    expect(perkOptions(char(), 42)).toEqual(o)
    const maxed = Object.fromEntries(PERK_IDS.map((id) => [id, PERKS[id].max]))
    expect(perkOptions(char({ perks: maxed }), 42)).toEqual(['cash', 'stim'])
    const oneLeft = { ...maxed, kevlar: 0 }
    expect(perkOptions(char({ perks: oneLeft }), 42)).toEqual(['kevlar', 'cash', 'stim'])
  })

  it('the deeper you go into a style, the more often its cards show up (capped)', () => {
    const net = PERK_IDS.filter((id) => PERKS[id].style === 'netrunner' && !PERKS[id].rare)
    const count = (perks: Record<string, number>) => {
      let n = 0
      for (let i = 0; i < 300; i++) n += perkOptions(char({ perks }), i).filter((id) => PERKS[id].style === 'netrunner').length
      return n
    }
    const base = count({})
    const one = count({ [net[0]]: 1 })
    const four = count(Object.fromEntries(net.slice(0, 4).map((id) => [id, 1])))
    expect(one).toBeGreaterThan(base * 1.15)
    expect(four).toBeGreaterThan(one)
    expect(styleWeight(1)).toBe(1.5)
    expect(styleWeight(4)).toBe(3)
    expect(styleWeight(9)).toBe(3)
  })

  it('once a style has 2+ cards, every pick has at least one of it and at least one other card', () => {
    const net = PERK_IDS.filter((id) => PERKS[id].style === 'netrunner' && !PERKS[id].rare)
    const c = char({ perks: { [net[0]]: 1, [net[1]]: 1 } })
    for (let i = 0; i < 300; i++) {
      const styles = perkOptions(c, i).map((id) => PERKS[id].style)
      expect(styles).toContain('netrunner')
      expect(styles.some((s) => s !== 'netrunner')).toBe(true)
      expect(new Set(perkOptions(c, i)).size).toBe(3)
    }
  })

  it('cards change combat by fixed amounts only: no cards = same fight; ghost and feedback help their tactic', () => {
    const foe = { name: 'x', hp: 90, atk: 10, hit: 0.6 }
    const camo: Item = { id: 'cm', name: '迷彩', slot: 'implant', direction: 'stealth', bonus: 0, price: 1, load: 0 }
    const deck: Item = { id: 'dk', name: '終端', slot: 'deck', direction: 'hack', bonus: 0, price: 1, load: 0 }
    let plain = 0
    let ghost = 0
    let shock = 0
    for (let i = 0; i < 200; i++) {
      expect(resolveFight(char({ perks: {} }), foe, 'force', i)).toEqual(resolveFight(char(), foe, 'force', i))
      plain += resolveFight(char({ equipment: [camo] }), foe, 'stealth', i).hp
      ghost += resolveFight(char({ equipment: [camo], perks: { ghost: 1 } }), foe, 'stealth', i).hp
      const a = resolveFight(char({ equipment: [deck] }), foe, 'hack', i)
      const b = resolveFight(char({ equipment: [deck], perks: { feedback: 2 } }), foe, 'hack', i)
      shock += b.rounds.length <= a.rounds.length ? 1 : 0
    }
    expect(ghost).toBeGreaterThan(plain)
    expect(shock).toBeGreaterThan(150)
    expect(fightStats(char({ perks: { gunsmith: 2, tough: 1 } })).atk).toBe(fightStats(char()).atk + 6)
    expect(maxHpOf(char({ perks: { tough: 1 } }))).toBe(112)
  })

  it('direction cards add to job success and reward', () => {
    const c = char({ perks: { dataBroker: 2 } })
    expect(dirBonus(c, 'hack')).toBeCloseTo(0.06)
    expect(dirBonus(c, 'force')).toBe(0)
    expect(jobReward(brawl, perkReward(c, 'hack'))).toBe(120)
  })
})

describe('四個流派', () => {
  it('每個流派都有足夠的卡與道具，掉寶表裡也有', async () => {
    const { ITEMS, STREET, RARE } = await import('../content/items')
    for (const s of STYLES) {
      expect(PERK_IDS.filter((id) => PERKS[id].style === s).length).toBeGreaterThanOrEqual(6)
      const items = Object.keys(ITEMS).filter((k) => ITEMS[k].style === s)
      expect(items.length).toBeGreaterThanOrEqual(5)
      expect(STREET.filter((k) => ITEMS[k].style === s).length).toBeGreaterThanOrEqual(3)
      expect(RARE.filter((k) => ITEMS[k].style === s).length).toBeGreaterThanOrEqual(3)
    }
    for (const k of [...STREET, ...RARE]) expect(ITEMS[k]).toBeDefined()
    const icons = (await import('../content/item_icons.json')).default as Record<string, string>
    expect(Object.keys(ITEMS).filter((k) => !icons[k])).toEqual([]) // 每件道具都有像素圖示
  })

  it('雙持會補槍、流浪者打贏會包紮；只有迷彩類義體能開光學迷彩繞背', async () => {
    const { makeItem } = await import('../content/items')
    const foe = { name: 'x', hp: 90, atk: 10, hit: 0.6 }
    let plain = 0
    let twin = 0
    let healed = 0
    for (let i = 0; i < 200; i++) {
      plain += resolveFight(char(), foe, 'force', i).rounds.filter((r) => r.text.includes('補')).length
      twin += resolveFight(char({ perks: { twinFire: 2 } }), foe, 'force', i).rounds.filter((r) => r.text.includes('補')).length
      const a = resolveFight(char(), foe, 'force', i)
      const b = resolveFight(char({ perks: { roadPatch: 1 } }), foe, 'force', i)
      if (a.won) healed += b.hp - a.hp
    }
    expect(plain).toBe(0)
    expect(twin).toBeGreaterThan(50)
    expect(healed).toBeGreaterThan(0)
    const stealth = (kind: string) => tacticsFor(char({ equipment: [makeItem(kind, 1)] })).find((t) => t.id === 'stealth')!.locked
    expect(stealth('dustCloak')).toBeUndefined()
    expect(stealth('roadMed')).toBe('需要光學迷彩義體')
  })
})

describe('dice pool (DICE-POOL-SPEC §2)', () => {
  it('grades by the highest die: two 6s crit, 6 clean, 4-5 cost, 1-3 fail; every result shows up', () => {
    const seen = { crit: 0, clean: 0, cost: 0, fail: 0 }
    for (let s = 0; s < 2000; s++) {
      const r = rollPool(3, s)
      expect(r.dice).toHaveLength(3)
      expect(r.best).toBe(Math.max(...r.dice))
      const sixes = r.dice.filter((d) => d === 6).length
      expect(r.result).toBe(sixes >= 2 ? 'crit' : r.best === 6 ? 'clean' : r.best >= 4 ? 'cost' : 'fail')
      seen[r.result]++
    }
    for (const k of ['crit', 'clean', 'cost', 'fail'] as const) expect(seen[k]).toBeGreaterThan(0)
  })

  it('with no dice it rolls two and keeps the lower, and never crits', () => {
    for (let s = 0; s < 500; s++)
      for (const n of [0, -1, -3]) {
        const r = rollPool(n, s)
        expect(r.dice).toHaveLength(2)
        expect(r.best).toBe(Math.min(...r.dice))
        expect(r.result).not.toBe('crit')
      }
  })

  it('is capped at POOL_MAX, fixed by the seed, and an extra die keeps the dice already rolled', () => {
    expect(rollPool(9, 7).dice).toHaveLength(POOL_MAX)
    for (let s = 0; s < 200; s++) {
      expect(rollPool(4, s)).toEqual(rollPool(4, s))
      expect(rollPool(4, s).dice).toEqual(rollPool(3, s).dice.concat(rollPool(4, s).dice[3]))
    }
  })

  it('more dice never make the best die lower', () => {
    for (let s = 0; s < 500; s++) expect(rollPool(4, s).best).toBeGreaterThanOrEqual(rollPool(2, s).best)
  })

  it('turns attributes into dice: 3 -> 2, 5 -> 3, 7 -> 4, 9 and up -> 5', () => {
    expect([1, 3, 4, 5, 7, 9, 12].map(attrDice)).toEqual([1, 2, 2, 3, 4, 5, 5])
  })

  it('builds the job pool from the attribute, gear in that direction, tier 3+ and severe injury', () => {
    const c = char({ attrs: { tech: 3, reflex: 3, body: 3, int: 3, cool: 5 } })
    expect(jobPool(c, job, 'cool')).toEqual([{ label: '沉著 5', n: 3 }])
    const hard = jobPool(char({ injury: SEVERE_INJURY }), { ...job, tier: 3 }, 'tech')
    expect(hard.map((p) => p.n)).toEqual([2, -1, -1])
    expect(poolSize(hard)).toBe(0)
    expect(poolSize(hard, 2)).toBe(2)
    // 裝備與卡牌：該方向加成 ≥5% +1 顆、≥20% +2 顆（每件裝備、兩件疊起來都檢查）
    const kinds = Object.keys(ITEMS)
    const levels = new Set<number>()
    for (const [i, kind] of kinds.entries()) {
      const g = char({ equipment: [makeItem(kind, 1), makeItem(kinds[(i + 7) % kinds.length], 2)] })
      const b = dirBonus(g, job.direction)
      const gear = jobPool(g, job, 'cool').find((p) => p.label.includes('裝備'))
      expect(gear?.n ?? 0).toBe(b >= 0.2 ? 2 : b >= 0.05 ? 1 : 0)
      levels.add(gear?.n ?? 0)
    }
    expect([...levels].sort()).toEqual([0, 1])
    // 一件裝備最多 +10%：要 +2 顆得堆好幾件或加上卡牌
    const stacked = char({ equipment: kinds.map((k) => makeItem(k, 1)) })
    expect(dirBonus(stacked, job.direction)).toBeGreaterThanOrEqual(0.2)
    expect(jobPool(stacked, job, 'cool').find((p) => p.label.includes('裝備'))?.n).toBe(2)
  })

  it('a cost hurts once; a failure hurts twice, and a full wanted level is not raised further', () => {
    const c = char({ heat: 4 })
    applyCost(c, job, 'injury')
    expect(c.injury).toBe(costInjury(job))
    applyCost(c, job, 'injury', true)
    expect(c.injury).toBe(costInjury(job) * 3)
    applyCost(c, job, 'stress', true)
    // 受傷失敗慌張 +4；壓力失敗 8×3＋慌張 4
    expect(c.stress).toBe(4 + 28)
    applyCost(c, job, 'heat')
    applyCost(c, job, 'heat')
    expect(c.heat).toBe(5)
  })

  it('no scene lets a failure cost only pay (a failure must hurt)', () => {
    for (const beats of Object.values(BEATS)) for (const b of beats) expect(b.fail).not.toBe('pay')
  })
})
