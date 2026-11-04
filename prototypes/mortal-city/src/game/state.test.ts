import { describe, expect, it } from 'vitest'
import { JOBS, highDanger } from '../content/data'
import { CASES, CASE_01, CASE_02, TEST_CASE, caseBody, caseReplies, optionLock } from '../content/cases'
import { fightStats, hashSeed, implantRoom, resolveDanger, resolveFight, tacticsFor } from '../rules/core'
import { makeItem } from '../content/items'
import { type Game, caseDangerOption, initial, reduce } from './state'

/** 找一個在危險節點會受致命傷、且保單有效時會被救的角色 id。 */
function rescuedGame(credits: number): Game {
  const g0 = initial(0)
  for (let i = 0; i < 500; i++) {
    const id = `t${i}`
    const c = { ...g0.character, id, credits, injury: 18 }
    const cov = { active: true, coversZone: true, etaMin: 3 }
    const run = caseDangerOption(c, TEST_CASE, 'force', 'run')
    if (resolveDanger(c, run, cov, hashSeed(id, TEST_CASE.id, run.id)).kind === 'rescued')
      return { ...g0, character: c, coverage: cov, story: { caseId: TEST_CASE.id, stage: 'danger', approach: 'force' } }
  }
  throw new Error('no seed found')
}

describe('rescue bill in the story flow', () => {
  it('pays from cash when enough', () => {
    const g = reduce(rescuedGame(2000), { t: 'storyChoose', optionId: 'run' })
    expect(g.cases[TEST_CASE.id]?.outcome).toBe('rescued')
    expect(g.character.credits).toBe(500)
    expect(g.character.pawned).toEqual([])
  })

  it('pawns equipment when cash is short, and the item can be redeemed later', () => {
    const g = reduce(rescuedGame(100), { t: 'storyChoose', optionId: 'run' })
    expect(g.character.alive).toBe(true)
    expect(g.character.pawned.length).toBeGreaterThan(0)
    expect(g.log.at(-1)!.text).toMatch(/抵押了/)
    const first = g.character.pawned[0]
    const rich = { ...g, character: { ...g.character, credits: first.redeem } }
    const back = reduce(rich, { t: 'redeem', itemId: first.item.id })
    expect(back.character.equipment.some((i) => i.id === first.item.id)).toBe(true)
    expect(back.character.credits).toBe(0)
  })

  it('dies when cash plus every pawn value cannot cover the bill', () => {
    const base = rescuedGame(0)
    const broke = { ...base, character: { ...base.character, equipment: [] } }
    const g = reduce(broke, { t: 'storyChoose', optionId: 'run' })
    expect(g.character.alive).toBe(false)
    expect(g.cases[TEST_CASE.id]?.outcome).toBe('dead')
    expect(g.cases[TEST_CASE.id]?.reason).toMatch(/沒有出勤/)
    expect(g.careers.length).toBe(1)
    expect(g.queue.items).toEqual([])
  })
})

describe('tier-4 street job: online, manual, may kill', () => {
  const job = JOBS['hack-4']
  const push = highDanger(job).options.find((o) => o.id === 'push')!

  function atDanger(kind: 'survived' | 'dead', withCoverage = false): Game {
    const g0 = initial(0)
    for (let i = 0; i < 500; i++) {
      const c = { ...g0.character, id: `h${i}` }
      const cov = { active: withCoverage, coversZone: true, etaMin: 3 }
      if (resolveDanger(c, push, cov, hashSeed(c.id, 'high', job.id, 0)).kind === kind) {
        let g: Game = { ...g0, character: c, coverage: cov }
        g = reduce(g, { t: 'highStart', jobId: job.id })
        return reduce(g, { t: 'highAutoDone' })
      }
    }
    throw new Error('no seed')
  }

  it('cannot be queued, and starting it pauses the queue', () => {
    let g = initial(0)
    g = reduce(g, { t: 'enqueue', jobId: job.id })
    expect(g.queue.items).toEqual([])
    g = reduce(g, { t: 'enqueue', jobId: 'stealth-1' })
    g = reduce(g, { t: 'highStart', jobId: job.id })
    expect(g.high?.stage).toBe('auto')
    expect(g.queue.paused).toBe(true)
  })

  it('abort is safe and pays nothing', () => {
    const g0 = atDanger('survived')
    const g = reduce(g0, { t: 'highChoose', optionId: 'abort' })
    expect(g.high?.outcome?.kind).toBe('safe')
    expect(g.character.credits).toBe(g0.character.credits)
    expect(g.character.alive).toBe(true)
  })

  it('surviving pays the reward and weekly points', () => {
    const g0 = atDanger('survived')
    const g = reduce(g0, { t: 'highChoose', optionId: 'push' })
    expect(g.character.credits).toBe(g0.character.credits + job.reward)
    expect(g.character.week.points).toBe(40)
    expect(g.highSeq).toBe(1)
  })

  it('a lethal outcome without coverage ends the career', () => {
    const g = reduce(atDanger('dead'), { t: 'highChoose', optionId: 'push' })
    expect(g.character.alive).toBe(false)
    expect(g.careers.length).toBe(1)
  })
})

describe('story cases: one per character, unlocked in order', () => {
  /** 從看板接案一路走到危險節點，選 optionId。 */
  function play(g: Game, caseId: string, approach: string, optionId: string): Game {
    g = reduce(g, { t: 'storyStart', caseId })
    g = reduce(g, { t: 'storyApproach', id: approach })
    g = reduce(g, { t: 'storyAutoDone' })
    return reduce(g, { t: 'storyChoose', optionId })
  }

  it('every formal case has a way out that cannot kill, and every option has text', () => {
    for (const sc of CASES) {
      expect(sc.danger.options.some((o) => !o.lethal), sc.id).toBe(true)
      for (const o of sc.danger.options) expect(o.text.length, `${sc.id}/${o.id}`).toBeGreaterThan(5)
      for (const a of sc.approaches) expect(a.autoLog.length, `${sc.id}/${a.id}`).toBeGreaterThan(0)
    }
  })

  it('02 is locked until 01 closes; withdrawing from 01 still opens it, with the "lost" paragraph', () => {
    let g = initial(0)
    expect(reduce(g, { t: 'storyStart', caseId: CASE_02.id }).story.caseId).toBe(null)
    g = play(g, CASE_01.id, 'stealth', 'hand')
    expect(g.cases[CASE_01.id].outcome).toBe('safe')
    expect(g.story.caseId).toBe(null)
    expect(caseBody(CASE_02, g.cases)).toContain(CASE_02.variants!.lost)
    g = reduce(g, { t: 'storyStart', caseId: CASE_02.id })
    expect(g.story.caseId).toBe(CASE_02.id)
  })

  it('a closed case cannot be taken again, and a new character can replay it', () => {
    let g = play(initial(0), CASE_01.id, 'hack', 'hand')
    const again = reduce(g, { t: 'storyStart', caseId: CASE_01.id })
    expect(again.story.caseId).toBe(null)
    g = reduce({ ...g, character: { ...g.character, alive: false } }, { t: 'newCharacter' })
    expect(g.cases).toEqual({})
    expect(reduce(g, { t: 'storyStart', caseId: CASE_01.id }).story.caseId).toBe(CASE_01.id)
  })

  it('a partial reward is paid and the clinic stitches you up even when you play it safe', () => {
    let g = play(initial(0), CASE_01.id, 'stealth', 'hand')
    const credits = g.character.credits
    g = play(g, CASE_02.id, 'stealth', 'half')
    expect(g.character.credits).toBe(credits + 400)
    expect(g.character.injury).toBe(0)
    expect(g.log.some((e) => e.text.includes('夜鴉插播'))).toBe(true)
  })

  it('the approach changes the lethal chance: its own risk, minus gear and proficiency in that direction', () => {
    const c = initial(0).character // 起始裝備每方向 +5%
    const force = caseDangerOption(c, CASE_01, 'force', 'carry').lethalBase
    const stealth = caseDangerOption(c, CASE_01, 'stealth', 'carry').lethalBase
    expect(force).toBeCloseTo(0.18 + 0.04 - 0.05)
    expect(stealth).toBeCloseTo(0.18 - 0.02 - 0.05)
    const pro = { ...c, prof: { ...c.prof, stealth: { level: 5, xp: 0 } } }
    expect(caseDangerOption(pro, CASE_01, 'stealth', 'carry').lethalBase).toBeCloseTo(stealth - 0.05)
    expect(caseDangerOption(c, CASE_01, 'force', 'hand').lethalBase).toBe(0)
  })

  it('surviving the risk pays in full and records the "won" paragraph for 02', () => {
    for (let i = 0; i < 200; i++) {
      const g0 = initial(0)
      const g = play({ ...g0, character: { ...g0.character, id: `s${i}` } }, CASE_01.id, 'stealth', 'carry')
      if (g.cases[CASE_01.id].outcome !== 'survived') continue
      expect(g.character.credits).toBe(500 + 600)
      expect(g.character.heat).toBe(1)
      expect(caseBody(CASE_02, g.cases)).toContain(CASE_02.variants!.won)
      return
    }
    throw new Error('no surviving seed')
  })
})

describe('fights on the force routes', () => {
  const enemy = CASE_01.approaches.find((a) => a.id === 'force')!.fight!

  it('tactics depend on gear: hacking needs a deck, the ambush needs the camo implant', () => {
    const c = initial(0).character
    expect(tacticsFor(c).every((t) => !t.locked)).toBe(true)
    const bare = { ...c, equipment: c.equipment.filter((i) => i.slot === 'weapon') }
    const locked = Object.fromEntries(tacticsFor(bare).map((t) => [t.id, !!t.locked]))
    expect(locked).toEqual({ force: false, hack: true, stealth: true })
  })

  it('a fight is fixed by its seed and never kills: low HP retreats', () => {
    const c = initial(0).character
    expect(resolveFight(c, enemy, 'force', 7)).toEqual(resolveFight(c, enemy, 'force', 7))
    const hurt = { ...c, injury: 75 }
    const strong = { name: '外骨骼', hp: 400, atk: 20, hit: 0.9 }
    const f = resolveFight(hurt, strong, 'force', 1)
    expect(f.won).toBe(false)
    expect(f.hp).toBeGreaterThan(0)
    expect(f.rounds.at(-1)!.text).toMatch(/撤退/)
  })

  function toFight(g: Game): Game {
    g = reduce(g, { t: 'storyStart', caseId: CASE_01.id })
    g = reduce(g, { t: 'storyApproach', id: 'force' })
    return reduce(g, { t: 'storyAutoDone' })
  }

  it('the force route stops for a fight; a won fight leads to the danger node with its injury', () => {
    for (let i = 0; i < 100; i++) {
      const g0 = initial(0)
      let g = toFight({ ...g0, character: { ...g0.character, id: `f${i}` } })
      expect(g.story.stage).toBe('fight')
      g = reduce(g, { t: 'storyFight', tactic: 'force' })
      if (!g.story.fight!.won) continue
      expect(g.character.injury).toBe(g.story.fight!.injury)
      g = reduce(g, { t: 'storyFightDone' })
      expect(g.story.stage).toBe('danger')
      return
    }
    throw new Error('no winning seed')
  })

  it('a lost fight closes the case as a retreat and resumes the queue', () => {
    const g0 = initial(0)
    let g: Game = { ...g0, queue: { ...g0.queue, items: ['stealth-1'], startedAt: 0 } }
    g = toFight(g)
    expect(g.queue.paused).toBe(true)
    g = { ...g, character: { ...g.character, injury: 75 } } // 委託進行中受了重傷：還是可以打完這一場
    g = reduce(g, { t: 'storyFight', tactic: 'force' })
    expect(g.story.fight!.won).toBe(false)
    g = reduce(g, { t: 'storyFightDone' })
    expect(g.story.caseId).toBe(null)
    expect(g.cases[CASE_01.id]).toMatchObject({ outcome: 'safe', optionId: 'retreat' })
    expect(g.queue.paused).toBe(false)
    expect(g.character.alive).toBe(true)
  })

  it('a locked tactic does nothing; the tier-4 force job fights too', () => {
    const g0 = initial(0)
    const bare = { ...g0, character: { ...g0.character, equipment: [] } }
    const g = reduce(toFight(bare), { t: 'storyFight', tactic: 'hack' })
    expect(g.story.fight).toBeUndefined()
    let h = reduce(initial(0), { t: 'highStart', jobId: 'force-4' })
    h = reduce(h, { t: 'highAutoDone' })
    expect(h.high!.stage).toBe('fight')
    h = reduce(h, { t: 'highFight', tactic: 'stealth' })
    expect(h.high!.fight).toBeDefined()
    h = reduce(h, { t: 'highFightDone' })
    expect(h.high!.stage).toBe(h.high!.fight!.won ? 'danger' : 'done')
  })
})

describe('重傷 stops all work until rest or treatment', () => {
  const hurt = (over: Partial<Game['character']> = {}): Game => {
    const g0 = initial(Date.now()) // reducer 用真實時鐘：起點要是現在，skip 才只走 N 分鐘
    return { ...g0, character: { ...g0.character, injury: 75, ...over } }
  }

  it('cannot queue, take a case or a tier-4 job while badly hurt', () => {
    const g = hurt()
    expect(reduce(g, { t: 'enqueue', jobId: 'stealth-1' }).queue.items).toEqual([])
    expect(reduce(g, { t: 'storyStart', caseId: CASE_01.id }).story.caseId).toBe(null)
    expect(reduce(g, { t: 'highStart', jobId: 'force-4' }).high).toBe(null)
  })

  it('a broke character still recovers by resting, and can work again', () => {
    let g = hurt({ credits: 0 })
    g = reduce(g, { t: 'skip', minutes: 30 })
    expect(g.character.injury).toBeLessThan(70)
    expect(g.log.some((e) => e.text.includes('可以再接工作'))).toBe(true)
    expect(reduce(g, { t: 'enqueue', jobId: 'stealth-1' }).queue.items).toEqual(['stealth-1'])
  })

  it('the hospital refuses 3★ but treats more stress; resting brings the heat down', () => {
    let g = hurt({ credits: 5000, heat: 3, stress: 40 })
    expect(reduce(g, { t: 'hospital' }).character.injury).toBe(75)
    g = reduce(g, { t: 'skip', minutes: 31 })
    expect(g.character.heat).toBe(2)
    const after = reduce(g, { t: 'hospital' })
    expect(after.character.injury).toBe(0)
    expect(after.character.stress).toBe(10)
    expect(reduce(hurt({ credits: 5000, stress: 40 }), { t: 'treat' }).character.stress).toBe(30)
  })
})

describe('different actions, different results', () => {
  function toDanger(g: Game, approach: string): Game {
    g = reduce(g, { t: 'storyStart', caseId: CASE_01.id })
    g = reduce(g, { t: 'storyApproach', id: approach })
    return reduce(g, { t: 'storyAutoDone' })
  }

  it('the hacking route opens a hacking option, which needs the deck', () => {
    const c = initial(0).character
    const broadcast = CASE_01.danger.options.find((o) => o.id === 'broadcast')!
    expect(optionLock(c, 'stealth', broadcast)).toBe(null) // 別的做法看不到
    expect(optionLock(c, 'hack', broadcast)).toBeUndefined()
    expect(optionLock({ ...c, equipment: [] }, 'hack', broadcast)).toMatch(/作業設備/)
    const g = reduce(toDanger(initial(0), 'stealth'), { t: 'storyChoose', optionId: 'broadcast' })
    expect(g.story.stage).toBe('danger') // 不屬於這個做法的選項無效
  })

  it('choosing to fight at the danger node: a won fight survives with the bigger reward', () => {
    for (let i = 0; i < 300; i++) {
      const g0 = initial(0)
      let g = toDanger({ ...g0, character: { ...g0.character, id: `b${i}` } }, 'force')
      g = reduce(g, { t: 'storyFight', tactic: 'stealth' })
      if (!g.story.fight!.won) continue
      g = reduce(g, { t: 'storyFightDone' })
      expect(g.character.heat).toBe(1) // 打了 MPD 巡警
      g = reduce(g, { t: 'storyChoose', optionId: 'brawl' })
      expect(g.story.stage).toBe('fight')
      g = reduce(g, { t: 'storyFight', tactic: 'force' })
      const won = g.story.fight!.won
      g = reduce(g, { t: 'storyFightDone' })
      if (!won) continue
      expect(g.cases[CASE_01.id]).toMatchObject({ outcome: 'survived', optionId: 'brawl' })
      expect(g.character.credits).toBe(500 + 900)
      expect(caseReplies(CASE_02, g.cases)[0].who).toBe('mpd')
      return
    }
    throw new Error('no seed won both fights')
  })
})

describe('attribute points and attribute options', () => {
  it('a new character has 4 points to spend; spending is one-way and capped by the points', () => {
    let g = initial(0)
    expect(g.character.attrPoints).toBe(4)
    for (let i = 0; i < 6; i++) g = reduce(g, { t: 'raiseAttr', attr: 'cool' })
    expect(g.character.attrs.cool).toBe(7)
    expect(g.character.attrPoints).toBe(0)
  })

  it('the 沉著 option shows on every route, is locked below 6, and finishes the case without risk', () => {
    const stare = CASE_01.danger.options.find((o) => o.id === 'stare')!
    const c = initial(0).character
    expect(optionLock(c, 'stealth', stare)).toMatch(/沉著 6/)
    let g = initial(0)
    for (let i = 0; i < 3; i++) g = reduce(g, { t: 'raiseAttr', attr: 'cool' })
    expect(optionLock(g.character, 'hack', stare)).toBeUndefined()
    g = reduce(g, { t: 'storyStart', caseId: CASE_01.id })
    g = reduce(g, { t: 'storyApproach', id: 'hack' })
    g = reduce(g, { t: 'storyAutoDone' })
    g = reduce(g, { t: 'storyChoose', optionId: 'stare' })
    expect(g.cases[CASE_01.id]).toMatchObject({ outcome: 'survived', optionId: 'stare' })
    expect(g.character.credits).toBe(500 + 600)
    expect(caseBody(CASE_02, g.cases)).toContain(CASE_02.variants!.won)
  })

  it('at most four options show at a danger node on any route', () => {
    const c = initial(0).character
    for (const sc of CASES) for (const ap of sc.approaches) {
      expect(sc.danger.options.filter((o) => optionLock(c, ap.id, o) !== null).length, `${sc.id}/${ap.id}`).toBeLessThanOrEqual(4)
    }
  })
})

describe('implant clinic, gear and loot', () => {
  it('a 30-load implant does not fit a fresh character; 2 points of 技術 make room', () => {
    let g = { ...initial(0), character: { ...initial(0).character, credits: 3000 } }
    expect(implantRoom(g.character)).toBe(25)
    expect(reduce(g, { t: 'buy', kind: 'subdermal' }).character.equipment.length).toBe(3)
    g = reduce(reduce(g, { t: 'raiseAttr', attr: 'tech' }), { t: 'raiseAttr', attr: 'tech' })
    g = reduce(g, { t: 'buy', kind: 'subdermal' })
    expect(g.character.equipment.some((i) => i.kind === 'subdermal')).toBe(true)
    expect(g.character.implantLoad).toBe(55)
    expect(g.character.credits).toBe(1500)
    expect(fightStats(g.character).armor).toBe(15 + 6)
  })

  it('equip swaps a weapon into the stash, unequip frees implant room, sell pays 40%', () => {
    const g0 = initial(0)
    const smart = makeItem('smartgun', 'x')
    let g: Game = { ...g0, character: { ...g0.character, stash: [smart] } }
    g = reduce(g, { t: 'equip', itemId: smart.id })
    expect(g.character.equipment.find((i) => i.slot === 'weapon')!.kind).toBe('smartgun')
    expect(g.character.stash.map((i) => i.kind)).toEqual(['gun'])
    const camo = g.character.equipment.find((i) => i.kind === 'camo')!
    g = reduce(g, { t: 'unequip', itemId: camo.id })
    expect(g.character.implantLoad).toBe(0)
    expect(tacticsFor(g.character).find((t) => t.id === 'stealth')!.locked).toBeTruthy()
    const credits = g.character.credits
    g = reduce(g, { t: 'sell', itemId: camo.id })
    expect(g.character.credits).toBe(credits + 400)
  })

  it('gear cannot change during a case', () => {
    const g = reduce(initial(0), { t: 'storyStart', caseId: CASE_01.id })
    const camo = g.character.equipment.find((i) => i.kind === 'camo')!
    expect(reduce(g, { t: 'unequip', itemId: camo.id }).character.equipment.length).toBe(3)
  })

  it('queue fights can drop loot, shown in the away report', () => {
    for (let i = 0; i < 300; i++) {
      const g0 = initial(Date.now())
      let g: Game = { ...g0, character: { ...g0.character, id: `L${i}` } }
      for (let k = 0; k < 4; k++) g = reduce(g, { t: 'enqueue', jobId: 'force-2' })
      g = reduce(g, { t: 'skip', minutes: 30 })
      if (!g.character.stash.length) continue
      expect(g.away!.events.some((e) => e.text.includes(`戰利品：${g.character.stash[0].name}`))).toBe(true)
      return
    }
    throw new Error('no drop in 300 tries')
  })

  it('attribute methods are locked in the reducer: 01 roof needs 體能 6, the tier-4 skilled option needs 7', () => {
    let g = reduce(initial(0), { t: 'storyStart', caseId: CASE_01.id })
    expect(reduce(g, { t: 'storyApproach', id: 'roof' }).story.stage).toBe('prep')
    for (let i = 0; i < 3; i++) g = reduce(g, { t: 'raiseAttr', attr: 'body' })
    expect(reduce(g, { t: 'storyApproach', id: 'roof' }).story.stage).toBe('auto')
    let h = reduce(initial(0), { t: 'highStart', jobId: 'hack-4' })
    h = reduce(h, { t: 'highAutoDone' })
    expect(reduce(h, { t: 'highChoose', optionId: 'skilled' }).high!.stage).toBe('danger')
    expect(caseReplies(CASE_02, { [CASE_01.id]: { approach: 'roof', optionId: 'climb', outcome: 'survived', reason: '' } })[0].who).toBe('crow')
  })
})
