import { describe, expect, it } from 'vitest'
import {
  type Character,
  type Item,
  type JobDef,
  type Queue,
  jobDurationMs,
  payBill,
  payable,
  capacityOf,
  fightStats,
  resolveFight,
  rest,
  workBlock,
  redeem,
  neuralCapacity,
  neuralStage,
  proficiencyEffects,
  resolveDanger,
  settleQueue,
  weekKey,
  weeklyPoints,
} from './core'

const job: JobDef = {
  id: 'courier-1',
  direction: 'stealth',
  tier: 1,
  name: '送貨',
  fixerId: 'k',
  minutes: 3,
  reward: 100,
  xp: 10,
  stress: 1,
  heat: 0,
  injury: 5,
  blurb: '',
}
const jobs = { [job.id]: job }

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
    prof: { force: { level: 0, xp: 0 }, hack: { level: 0, xp: 0 }, stealth: { level: 0, xp: 0 } },
    equipment: [],
    pawned: [],
    week: { key: weekKey(0), counts: {}, points: 0 },
    attrs: { tech: 3, reflex: 3, body: 3, int: 3, cool: 3 },
    attrPoints: 0,
    stash: [],
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

describe('proficiency', () => {
  it('more important attributes grow slower, capped at 100', () => {
    const e = proficiencyEffects(150)
    expect(e.success).toBeCloseTo(0.05)
    expect(e.harm).toBeCloseTo(0.15)
    expect(e.reward).toBeCloseTo(0.25)
    expect(e.time).toBeCloseTo(0.4)
  })
  it('shortens duration', () => {
    expect(jobDurationMs(job, 100)).toBe(Math.round(3 * 60_000 * 0.6))
  })
})

describe('weekly decay (medium)', () => {
  it('full for first 20, half to 40, then 20%', () => {
    expect(weeklyPoints(3, 0)).toBe(30)
    expect(weeklyPoints(3, 19)).toBe(30)
    expect(weeklyPoints(3, 20)).toBe(15)
    expect(weeklyPoints(3, 40)).toBe(6)
  })
})

describe('settleQueue', () => {
  const q = (n: number): Queue => ({ items: Array(n).fill(job.id), startedAt: 0, paused: false, seq: 0 })

  it('settles only items whose due time has passed', () => {
    const r = settleQueue(char(), q(4), 3 * 60_000 * 2 + 1, jobs)
    expect(r.completed).toBe(2)
    expect(r.queue.items.length).toBe(2)
    expect(r.queue.startedAt).toBe(3 * 60_000 * 2)
  })

  it('is deterministic for the same inputs', () => {
    const a = settleQueue(char(), q(4), 10 ** 9, jobs)
    const b = settleQueue(char(), q(4), 10 ** 9, jobs)
    expect(a.character).toEqual(b.character)
  })

  it('while paused, finishes the running job but does not start the next', () => {
    const r = settleQueue(char(), { ...q(4), paused: true }, 10 ** 9, jobs)
    expect(r.completed).toBe(1)
    expect(r.queue.items.length).toBe(3)
    expect(r.queue.startedAt).toBeNull()
  })

  it('stops and cancels the rest when injury hits the threshold', () => {
    const r = settleQueue(char({ injury: 59 }), q(4), 10 ** 9, jobs, {
      injuryAt: 60,
      heatAt: 9,
      stopOnCritical: false,
      creditReserve: 0,
    })
    expect(r.stopped).toMatch(/傷勢/)
    expect(r.queue.items.length).toBe(0)
    expect(r.completed).toBeLessThan(4)
  })
})

describe('resolveDanger', () => {
  const opt = { id: 'go', label: '冒險', lethal: true, lethalBase: 0.95, survivalWindowMin: 3 }
  it('non-lethal option is always safe', () => {
    expect(resolveDanger(char(), { ...opt, lethal: false }, { active: false, coversZone: false, etaMin: 9 }, 1).kind).toBe(
      'safe',
    )
  })
  it('dies without coverage, is rescued with coverage in time', () => {
    const c = char({ injury: 100 })
    expect(resolveDanger(c, opt, { active: false, coversZone: true, etaMin: 2 }, 7).kind).toBe('dead')
    expect(resolveDanger(c, opt, { active: true, coversZone: true, etaMin: 2 }, 7).kind).toBe('rescued')
    expect(resolveDanger(c, opt, { active: true, coversZone: true, etaMin: 5 }, 7).kind).toBe('dead')
  })
  it('system fault turns death into a free rescue', () => {
    const c = char({ injury: 100 })
    expect(resolveDanger(c, opt, { active: false, coversZone: false, etaMin: 9 }, 7, true).kind).toBe('rescued_system')
  })
  it('same seed gives the same outcome', () => {
    const c = char({ injury: 30 })
    const cov = { active: true, coversZone: true, etaMin: 2 }
    expect(resolveDanger(c, { ...opt, lethalBase: 0.4 }, cov, 42)).toEqual(
      resolveDanger(c, { ...opt, lethalBase: 0.4 }, cov, 42),
    )
  })
})

describe('rescue bill: pawn equipment, die if not enough, redeem later', () => {
  const gun: Item = { id: 'g', name: '槍', slot: 'weapon', direction: 'force', bonus: 0.05, price: 1200, load: 0 }
  const deck: Item = { id: 'd', name: '終端', slot: 'deck', direction: 'hack', bonus: 0.05, price: 800, load: 0 }
  const camo: Item = { id: 'c', name: '迷彩', slot: 'implant', direction: 'stealth', bonus: 0.05, price: 1000, load: 25 }
  const geared = (credits: number) => char({ credits, implantLoad: 25, equipment: [gun, deck, camo] })

  it('pays from cash when enough, pawns nothing', () => {
    const r = payBill(geared(2000), 1500)
    expect(r.ok && r.character.credits).toBe(500)
    expect(r.ok && r.pawned.length).toBe(0)
  })

  it('pawns the most valuable items first until covered, change goes back to cash', () => {
    // 現金 100，差 1400；槍 720 → 迷彩 600 → 終端 480，多出 400
    const r = payBill(geared(100), 1500)
    expect(r.ok).toBe(true)
    if (!r.ok) return
    expect(r.pawned.map((i) => i.id)).toEqual(['g', 'c', 'd'])
    expect(r.character.credits).toBe(400)
    expect(r.character.equipment.length).toBe(0)
    expect(r.character.implantLoad).toBe(0)
    expect(r.character.pawned.map((p) => p.redeem)).toEqual([720, 600, 480])
  })

  it('cannot pay when cash plus all pawn values is short', () => {
    const r = payBill(geared(0), 1900) // 0 + 720 + 600 + 480 = 1800
    expect(r.ok).toBe(false)
    if (r.ok) return
    expect(r.total).toBe(1800)
    expect(r.shortfall).toBe(100)
  })

  it('redeems at the pawn price once there is enough cash', () => {
    const r = payBill(geared(100), 1500)
    if (!r.ok) throw new Error('should pay')
    expect(redeem(r.character, 'g')).toBeNull() // 400 < 720
    const rich = { ...r.character, credits: 1000 }
    const back = redeem(rich, 'g')!
    expect(back.credits).toBe(280)
    expect(back.equipment.map((i) => i.id)).toEqual(['g'])
    expect(back.pawned.length).toBe(2)
  })
})

describe('severe injury, rest and queue fights', () => {
  const brawl: JobDef = { ...job, id: 'brawl-3', direction: 'force', tier: 3, injury: 20 }
  const fjobs = { [brawl.id]: brawl }
  const q4 = (id: string): Queue => ({ items: [id, id, id, id], startedAt: 0, paused: false, seq: 0 })
  const loose = { injuryAt: 101, heatAt: 9, stopOnCritical: false, creditReserve: 0 }

  it('every force job is a fight, logged in one line, fixed by its seed', () => {
    const a = settleQueue(char(), q4(brawl.id), 10 ** 9, fjobs, loose)
    expect(a.events.filter((e) => e.text.includes('⚔')).length).toBe(a.completed)
    expect(settleQueue(char(), q4(brawl.id), 10 ** 9, fjobs, loose).character).toEqual(a.character)
  })

  it('a locked default tactic falls back to a straight fight', () => {
    const r = settleQueue(char(), q4(brawl.id), 10 ** 9, fjobs, { ...loose, tactic: 'hack' })
    expect(r.events[0].text).toMatch(/預設戰術被鎖住/)
  })

  it('the queue always stops at 重傷, whatever the player set', () => {
    for (let i = 0; i < 200; i++) {
      const r = settleQueue(char({ id: `s${i}`, injury: 55 }), q4(brawl.id), 10 ** 9, fjobs, loose)
      if (r.character.injury < 70 || r.completed === 4) continue
      expect(r.stopped).toMatch(/重傷/)
      expect(r.queue.items).toEqual([])
      return
    }
    throw new Error('no seed reached 重傷 mid-queue')
  })

  it('rest heals 1% a minute (half speed when severe) and drops heat every 30 minutes, carrying leftovers', () => {
    const c = char({ injury: 71, heat: 2 })
    let carry = rest(c, { ms: 0, heatMs: 0 }, 4 * 60_000)
    expect(c.injury).toBe(69) // 71→70 用 2 分鐘，70→69 再 2 分鐘
    carry = rest(c, carry, 30 * 1000)
    expect(c.injury).toBe(69)
    rest(c, carry, 30 * 1000)
    expect(c.injury).toBe(68)
    const h = char({ heat: 2 })
    rest(h, { ms: 0, heatMs: 0 }, 61 * 60_000)
    expect(h.heat).toBe(0)
    expect(workBlock(char({ injury: 70 }))).toMatch(/重傷/)
    expect(workBlock(char({ injury: 69 }))).toBeUndefined()
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

describe('items: implant armour, loot, paying with the stash', () => {
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

  it('loot has its own seed: the same queue settles the same with or without drops', () => {
    const brawl: JobDef = { ...job, id: 'brawl-2', direction: 'force', tier: 2 }
    const q: Queue = { items: Array(4).fill(brawl.id), startedAt: 0, paused: false, seq: 0 }
    const rules = { injuryAt: 101, heatAt: 9, stopOnCritical: false, creditReserve: 0 }
    const always = (seed: number) => ({ ...plate, id: `p#${seed}` })
    const a = settleQueue(char(), q, 10 ** 9, { [brawl.id]: brawl }, rules)
    const b = settleQueue(char(), q, 10 ** 9, { [brawl.id]: brawl }, rules, always)
    expect({ ...b.character, stash: [] }).toEqual(a.character)
    expect(b.character.stash.length).toBe(b.events.filter((e) => e.text.includes('打贏')).length)
    expect(b.events.find((e) => e.text.includes('打贏'))!.text).toMatch(/戰利品：皮下護甲/)
  })

  it('a bill pawns the stash before the gear you wear, and redeeming puts it back where it was', () => {
    const c = char({ stash: [plate], equipment: [{ id: 'g', name: '槍', slot: 'weapon', direction: 'force', bonus: 0, price: 1200, load: 0 }] })
    expect(payable(c)).toBe(900 + 720)
    const r = payBill(c, 800)
    if (!r.ok) throw new Error('should pay')
    expect(r.pawned.map((i) => i.id)).toEqual(['p#1'])
    expect(r.character.equipment.length).toBe(1)
    const back = redeem({ ...r.character, credits: 900 }, 'p#1')!
    expect(back.stash.map((i) => i.id)).toEqual(['p#1'])
    expect(back.equipment.length).toBe(1)
  })
})
