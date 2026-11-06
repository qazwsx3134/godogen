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
  perkReward,
  resolveDanger,
  resolveFight,
} from './core'
import { PERKS, PERK_IDS } from './perks'

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

describe('resolveDanger: the lifeline saves you once', () => {
  const opt = { id: 'go', label: '冒險', lethal: true, lethalBase: 0.95, survivalWindowMin: 3 }
  it('non-lethal option is always safe', () => {
    expect(resolveDanger(char(), { ...opt, lethal: false }, 1).kind).toBe('safe')
  })
  it('dies without a lifeline, is rescued with one', () => {
    const c = char({ injury: 100 })
    expect(resolveDanger(c, opt, 7).kind).toBe('dead')
    expect(resolveDanger({ ...c, lifelines: 1 }, opt, 7).kind).toBe('rescued')
  })
  it('system fault turns death into a free rescue', () => {
    expect(resolveDanger(char({ injury: 100 }), opt, 7, true).kind).toBe('rescued_system')
  })
  it('same seed gives the same outcome', () => {
    const c = char({ injury: 30 })
    expect(resolveDanger(c, { ...opt, lethalBase: 0.4 }, 42)).toEqual(resolveDanger(c, { ...opt, lethalBase: 0.4 }, 42))
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
    expect(text({})).not.toMatch(/暴擊/)
    expect(text(at({ reflex: 11 }))).toMatch(/暴擊/)
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
    for (let k = 0; k < 4; k++) grantProgress(c, brawl, true, 0, events)
    expect(c.fame).toEqual({ level: 1, xp: 40 - fameToNext(0), total: 40 })
    expect(c.picks).toEqual([{ kind: 'perk', level: 1, seed: hashSeed('c1', 'fame', 1) }])
    expect(events.some((e) => e.text.includes('名聲提升到 Lv.1'))).toBe(true)
    grantProgress(c, brawl, false, 0, events)
    expect(c.fame.total).toBe(45)
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

  it('a fresh build favours the direction you already took', () => {
    let hack = 0
    for (let i = 0; i < 300; i++) hack += perkOptions(char({ perks: { iceApprentice: 1 } }), i).filter((id) => PERKS[id].dir === 'hack').length
    let base = 0
    for (let i = 0; i < 300; i++) base += perkOptions(char(), i).filter((id) => PERKS[id].dir === 'hack').length
    expect(hack).toBeGreaterThan(base * 1.3)
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
