import { describe, expect, it } from 'vitest'
import { JOBS, TEST_CASE, highDanger } from '../content/data'
import { hashSeed, resolveDanger } from '../rules/core'
import { type Game, initial, reduce } from './state'

const run = TEST_CASE.danger.options.find((o) => o.id === 'run')!

/** 找一個在危險節點會受致命傷、且保單有效時會被救的角色 id。 */
function rescuedGame(credits: number): Game {
  const g0 = initial(0)
  for (let i = 0; i < 500; i++) {
    const id = `t${i}`
    const c = { ...g0.character, id, credits, injury: 18 }
    const cov = { active: true, coversZone: true, etaMin: 3 }
    if (resolveDanger(c, run, cov, hashSeed(id, TEST_CASE.id, run.id)).kind === 'rescued')
      return { ...g0, character: c, coverage: cov, story: { stage: 'danger' } }
  }
  throw new Error('no seed found')
}

describe('rescue bill in the story flow', () => {
  it('pays from cash when enough', () => {
    const g = reduce(rescuedGame(2000), { t: 'storyChoose', optionId: 'run' })
    expect(g.story.outcome?.kind).toBe('rescued')
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
    expect(g.story.outcome?.kind).toBe('dead')
    expect(g.story.outcome?.reason).toMatch(/沒有出勤/)
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
