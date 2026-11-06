import { describe, expect, it } from 'vitest'
import { CASES, CASE_01, CASE_02, caseBody, caseReplies, optionLock } from '../content/cases'
import { EVENTS, EVENT_BY_ID, WANGAN_EVENTS } from '../content/events'
import { makeItem } from '../content/items'
import { type Pick, fightStats, implantRoom, perkOptions, tacticsFor } from '../rules/core'
import { PERK_IDS } from '../rules/perks'
import { LAYERS, STORY_LAYER, findNode } from '../rules/map'
import { type Action, type Game, caseDangerOption, eventLock, initial, movable, nextDistrict, nodeBusy, reduce } from './state'
import { DISTRICTS } from '../content/districts'

/** 換一個傭兵 id（每個 id 的 seed 不同）。 */
const fresh = (id: string, over: Partial<Game['character']> = {}): Game => {
  const g = initial(0)
  return { ...g, character: { ...g.character, id, ...over } }
}

/** 直接站到地圖上的劇情節點（02＝劇情大案、01＝中段劇情委託，其他用開發節點）。 */
function atCase(g: Game, caseId: string): Game {
  const all = g.run.district.layers.flat()
  const node = caseId === CASE_02.id ? all.find((n) => n.type === 'boss') : caseId === CASE_01.id ? all.find((n) => n.type === 'story') : undefined
  const nodeId = node?.id ?? 'dev'
  return { ...g, story: { caseId, stage: 'prep' }, run: { ...g.run, at: node?.id ?? g.run.at, node: { kind: 'story', nodeId, caseId } } }
}

function play(g: Game, caseId: string, approach: string, optionId: string): Game {
  g = reduce(atCase(g, caseId), { t: 'storyApproach', id: approach })
  g = reduce(g, { t: 'storyAutoDone' })
  return reduce(g, { t: 'storyChoose', optionId })
}

/**
 * 機器人：每一步選第一個合法動作。risky＝危險節點選會死的選項。
 * 回傳下一個動作；沒有合法動作回傳 null（那就是卡死）。
 */
function botAction(g: Game, risky: boolean): Action | null {
  const c = g.character
  if (!c.alive || g.run.phase === 'over') return null
  if (g.run.claim) return { t: 'claim' }
  if (c.attrPoints > 0) return { t: 'raiseAttr', attr: (['body', 'tech', 'reflex', 'int', 'cool'] as const)[c.attrPoints % 5] }
  if (c.picks.length && !nodeBusy(g)) {
    const p = c.picks[0]
    return p.kind === 'perk' ? { t: 'pickPerk', id: perkOptions(c, p.seed)[0] } : { t: 'pickItem', index: 0 }
  }
  if (g.run.phase === 'safehouse') return nextDistrict(g) ? { t: 'continue' } : { t: 'retire' }
  const tactic = tacticsFor(c).find((t) => !t.locked)!.id
  const n = g.run.node
  if (!n) {
    // 依傭兵 id 挑不同的分支，各局走不同路線
    const opts = movable(g)
    const k = [...c.id].reduce((s, ch) => s + ch.charCodeAt(0), 0) + g.run.path.length * 7
    return { t: 'move', nodeId: opts[k % opts.length].id }
  }
  if (n.kind === 'job') {
    if (n.stage === 'auto') return { t: 'jobAutoDone' }
    if (n.stage === 'fight') return n.fight ? { t: 'jobFightDone' } : { t: 'jobFight', tactic }
    return { t: 'leave' }
  }
  if (n.kind === 'elite') {
    if (n.stage === 'auto') return { t: 'eliteAutoDone' }
    if (n.stage === 'fight') return n.fight ? { t: 'eliteFightDone' } : { t: 'eliteFight', tactic }
    if (n.stage === 'danger') return { t: 'eliteChoose', optionId: risky ? 'push' : 'abort' }
    return { t: 'leave' }
  }
  if (n.kind === 'event') {
    if (n.stage === 'done') return { t: 'leave' }
    const ev = EVENT_BY_ID[n.eventId]
    return { t: 'eventChoose', optionId: ev.options.find((o) => !eventLock(c, o))!.id }
  }
  if (n.kind === 'market' && c.credits >= 450 && c.lifelines === 0) return { t: 'buyLifeline' }
  if (n.kind === 'rest' && !n.used) return { t: 'rest', choice: 'heal' }
  if (n.kind === 'story' && g.story.caseId) {
    const sc = CASES.find((s) => s.id === g.story.caseId)!
    const st = g.story
    if (st.stage === 'prep') return { t: 'storyApproach', id: sc.approaches.find((a) => !a.needs)!.id }
    if (st.stage === 'auto') return { t: 'storyAutoDone' }
    if (st.stage === 'fight') return st.fight ? { t: 'storyFightDone' } : { t: 'storyFight', tactic }
    const opts = sc.danger.options.filter((o) => optionLock(c, st.approach, o) === undefined && !o.fight)
    return { t: 'storyChoose', optionId: (opts.find((o) => o.lethal === risky) ?? opts[0]).id }
  }
  return { t: 'leave' }
}

function runBot(id: string, risky: boolean) {
  let g = fresh(id)
  let perks = 0
  let items = 0
  for (let step = 0; step < 600; step++) {
    const a = botAction(g, risky)
    if (!a) return { g, perks, items, step }
    if (a.t === 'pickPerk') perks++
    if (a.t === 'pickItem') items++
    const next = reduce(g, a)
    if (next === g) throw new Error(`${id} stuck at step ${step}: ${JSON.stringify(a)} node=${JSON.stringify(g.run.node)} story=${JSON.stringify(g.story)}`)
    g = next
  }
  throw new Error(`${id} did not finish in 600 steps`)
}

describe('a whole career through the reducer', () => {
  it('a careful bot never gets stuck, goes through every district, retires and is written into the legends', () => {
    let perks = 0
    let items = 0
    for (let i = 0; i < 200; i++) {
      const r = runBot(`safe${i}`, false)
      expect(r.g.run.phase).toBe('over')
      expect(r.g.meta.legends.length).toBe(1)
      expect(r.g.meta.legends[0].end).toBe(r.g.character.alive ? 'retired' : 'dead')
      expect(r.g.character.alive).toBe(true) // 一律選不會死的選項就不會死
      expect(r.g.run.districtIndex).toBe(DISTRICTS.length - 1) // 走完所有街區才退休
      expect(r.g.run.path.length).toBe(11)
      perks += r.perks
      items += r.items
    }
    // 每次都選不會死的，新宿＋灣岸兩區約 6 張卡
    expect(perks / 200).toBeGreaterThanOrEqual(4)
    expect(perks / 200).toBeLessThanOrEqual(8)
    expect(items / 200).toBeGreaterThanOrEqual(1)
  })

  it('a reckless bot also always ends: dead (into the legends) or retired', () => {
    let dead = 0
    let perks = 0
    for (let i = 0; i < 200; i++) {
      const r = runBot(`risk${i}`, true)
      expect(r.g.run.phase).toBe('over')
      expect(r.g.meta.legends.length).toBe(1)
      if (!r.g.character.alive) dead++
      else perks += r.perks
    }
    expect(dead).toBeGreaterThan(0)
    expect(dead).toBeLessThan(100)
    // 冒險而活下來的，兩區約 8 張卡
    expect(perks / (200 - dead)).toBeGreaterThanOrEqual(6)
    expect(perks / (200 - dead)).toBeLessThanOrEqual(11)
  })

  it('a new mercenary keeps the legends and the seen node types, and gets a new map', () => {
    const r = runBot('keep', false)
    const g = reduce(r.g, { t: 'newCharacter' })
    expect(g.meta.legends.length).toBe(1)
    expect(g.meta.seen.job || g.meta.seen.event).toBe(true)
    expect(g.run.path).toEqual([])
    expect(g.character.perks).toEqual({})
  })
})

describe('map movement', () => {
  it('only the next layer is reachable, and not while a pick is waiting', () => {
    let g = fresh('m1')
    const first = movable(g)[0]
    expect(reduce(g, { t: 'move', nodeId: 'shinjuku-3-0' })).toBe(g)
    g = reduce(g, { t: 'move', nodeId: first.id })
    expect(g.run.at).toBe(first.id)
    expect(movable(g)).toEqual([]) // 節點裡的事還沒做完
    const waiting = { ...g, run: { ...g.run, node: null }, character: { ...g.character, picks: [{ kind: 'perk' as const, level: 1, seed: 1 }] } }
    expect(movable(waiting)).toEqual([])
    const ok = { ...waiting, character: { ...waiting.character, picks: [] } }
    expect(movable(ok).map((n) => n.id)).toEqual(findNode(g.run.district, first.id)!.next)
  })

  it('entering a node is fixed by the seed: reloading gives the same job, event or stock', () => {
    const g = fresh('m2')
    const id = movable(g)[0].id
    expect(reduce(g, { t: 'move', nodeId: id }).run.node).toEqual(reduce(g, { t: 'move', nodeId: id }).run.node)
  })
})

describe('districts', () => {
  it('the safehouse continues into 灣岸 with a new map, keeping the mercenary; after the last district only retiring is left', () => {
    let g = play(fresh('d1'), CASE_01.id, 'stealth', 'hand')
    g = play(g, CASE_02.id, 'stealth', 'half')
    g = reduce(reduce(g, { t: 'claim' }), { t: 'leave' })
    expect(g.run.phase).toBe('safehouse')
    expect(reduce(g, { t: 'continue' })).toBe(g) // 名聲升級的三選一還沒挑
    while (g.character.picks.length) {
      const p = g.character.picks[0]
      g = reduce(g, p.kind === 'perk' ? { t: 'pickPerk', id: perkOptions(g.character, p.seed)[0] } : { t: 'pickItem', index: 0 })
    }
    const before = g.character
    g = reduce(g, { t: 'continue' })
    expect(g.run).toMatchObject({ districtIndex: 1, phase: 'map', at: null, path: [] })
    expect(g.run.district.id).toBe('wangan')
    expect(g.character).toBe(before)
    // 灣岸的劇情委託是 03、劇情大案是 06
    const story = g.run.district.layers.flat().find((n) => n.type === 'story')!
    const boss = g.run.district.layers.flat().find((n) => n.type === 'boss')!
    const atStory = reduce({ ...g, run: { ...g.run, at: g.run.district.layers[STORY_LAYER - 1][0].id } }, { t: 'move', nodeId: story.id })
    expect(atStory.story.caseId).toBe('P01-03')
    const atBoss = reduce({ ...g, run: { ...g.run, at: g.run.district.layers[LAYERS - 2][0].id } }, { t: 'move', nodeId: boss.id })
    expect(atBoss.story.caseId).toBe('P01-06')
    expect(reduce({ ...g, run: { ...g.run, phase: 'safehouse' } }, { t: 'continue' }).run.districtIndex).toBe(1) // 沒有下一區
  })

  it('灣岸 jobs are tier 2-3 and its elites tier 5', () => {
    let g = reduce(play(fresh('d2'), CASE_01.id, 'stealth', 'hand'), { t: 'claim' })
    g = { ...g, run: { ...g.run, phase: 'safehouse', node: null } }
    g = reduce(g, { t: 'continue' })
    const tiers = new Set<number>()
    for (const n of g.run.district.layers.flat()) {
      if (n.type !== 'job' && n.type !== 'elite') continue
      const prev = g.run.district.layers.flat().find((p) => p.next.includes(n.id))
      const h = reduce({ ...g, run: { ...g.run, at: prev?.id ?? null } }, { t: 'move', nodeId: n.id })
      const node = h.run.node as { jobId: string } | null
      if (node) tiers.add(Number(node.jobId.split('-')[1]))
    }
    expect([...tiers].every((t) => [2, 3, 5].includes(t))).toBe(true)
    expect(tiers.has(5)).toBe(true)
  })
})

describe('story cases on the map', () => {
  it('every case has a way out that cannot kill, and every option has text', () => {
    for (const sc of CASES) {
      expect(sc.danger.options.some((o) => !o.lethal), sc.id).toBe(true)
      for (const o of sc.danger.options) expect(o.text.length, `${sc.id}/${o.id}`).toBeGreaterThan(5)
      for (const a of sc.approaches) expect(a.autoLog.length, `${sc.id}/${a.id}`).toBeGreaterThan(0)
    }
  })

  it('withdrawing from 01 still closes it, and 02 gets the "lost" paragraph', () => {
    const g = play(fresh('s1'), CASE_01.id, 'stealth', 'hand')
    expect(g.run.cases[CASE_01.id].outcome).toBe('safe')
    expect(g.story.caseId).toBe(null)
    expect(caseBody(CASE_02, g.run.cases)).toContain(CASE_02.variants!.lost)
  })

  it('a partial reward is paid and the clinic stitches you up even when you play it safe; 02 leads to the safehouse', () => {
    let g = play(fresh('s2'), CASE_01.id, 'stealth', 'hand')
    const credits = g.character.credits
    g = play(g, CASE_02.id, 'stealth', 'half')
    expect(g.character.credits).toBe(credits + 400)
    expect(g.character.injury).toBe(0)
    expect(g.log.some((e) => e.text.includes('夜鴉插播'))).toBe(true)
    expect(reduce(g, { t: 'leave' })).toBe(g) // 完成單還沒收下
    expect(g.run.claim).toMatchObject({ title: CASE_02.title, tone: 'partial' })
    g = reduce(reduce(g, { t: 'claim' }), { t: 'leave' })
    expect(g.run.phase).toBe('safehouse')
  })

  it('the approach changes the lethal chance: its own risk, minus gear in that direction', () => {
    const c = initial(0).character // 起始裝備每方向 +5%
    expect(caseDangerOption(c, CASE_01, 'force', 'carry').lethalBase).toBeCloseTo(0.18 + 0.04 - 0.05)
    expect(caseDangerOption(c, CASE_01, 'stealth', 'carry').lethalBase).toBeCloseTo(0.18 - 0.02 - 0.05)
    const pro = { ...c, perks: { quietPro: 1 } }
    expect(caseDangerOption(pro, CASE_01, 'stealth', 'carry').lethalBase).toBeCloseTo(0.18 - 0.02 - 0.05 - 0.03)
    expect(caseDangerOption(c, CASE_01, 'force', 'hand').lethalBase).toBe(0)
  })

  it('surviving the risk pays in full, gives fame, and records the "won" paragraph for 02', () => {
    for (let i = 0; i < 200; i++) {
      const g = play(fresh(`s${i}`), CASE_01.id, 'stealth', 'carry')
      if (g.run.cases[CASE_01.id].outcome !== 'survived') continue
      expect(g.character.credits).toBe(500 + 600)
      expect(g.character.heat).toBe(1)
      expect(g.character.fame.total).toBe(60)
      expect(caseBody(CASE_02, g.run.cases)).toContain(CASE_02.variants!.won)
      return
    }
    throw new Error('no surviving seed')
  })

  it('a lethal outcome uses up the lifeline instead of killing you', () => {
    for (let i = 0; i < 300; i++) {
      const g = play(fresh(`l${i}`, { lifelines: 1 }), CASE_01.id, 'hack', 'carry')
      if (g.run.cases[CASE_01.id]?.outcome !== 'rescued') continue
      expect(g.character.alive).toBe(true)
      expect(g.character.lifelines).toBe(0)
      expect(g.character.injury).toBe(70)
      return
    }
    throw new Error('no rescued seed')
  })

  it('choosing to fight at the danger node: a won fight survives with the bigger reward', () => {
    for (let i = 0; i < 300; i++) {
      let g = reduce(atCase(fresh(`b${i}`), CASE_01.id), { t: 'storyApproach', id: 'force' })
      g = reduce(g, { t: 'storyAutoDone' })
      g = reduce(g, { t: 'storyFight', tactic: 'stealth' })
      if (!g.story.fight!.won) continue
      g = reduce(g, { t: 'storyFightDone' })
      expect(g.character.heat).toBe(1) // 打了 MPD 巡警
      g = reduce(g, { t: 'storyChoose', optionId: 'brawl' })
      g = reduce(g, { t: 'storyFight', tactic: 'force' })
      const won = g.story.fight!.won
      g = reduce(g, { t: 'storyFightDone' })
      if (!won) continue
      expect(g.run.cases[CASE_01.id]).toMatchObject({ outcome: 'survived', optionId: 'brawl' })
      expect(g.character.credits).toBe(500 + 900)
      expect(caseReplies(CASE_02, g.run.cases)[0].who).toBe('mpd')
      return
    }
    throw new Error('no seed won both fights')
  })

  it('attribute options: 沉著 6 finishes 01 without risk; the 體能 approach is locked below 6', () => {
    let g = fresh('a1')
    for (let i = 0; i < 3; i++) g = reduce(g, { t: 'raiseAttr', attr: 'cool' })
    g = play(g, CASE_01.id, 'hack', 'stare')
    expect(g.run.cases[CASE_01.id]).toMatchObject({ outcome: 'survived', optionId: 'stare' })
    const h = atCase(fresh('a2'), CASE_01.id)
    expect(reduce(h, { t: 'storyApproach', id: 'roof' }).story.stage).toBe('prep')
  })
})

describe('node services and three-way picks', () => {
  /** 站在某種節點上。 */
  function atNode(g: Game, node: NonNullable<Game['run']['node']>): Game {
    return { ...g, run: { ...g.run, node } }
  }

  it('the market sells its stock at half price and the lifeline; selling only works there', () => {
    const g0 = fresh('k1', { credits: 3000, stash: [makeItem('smartgun', 'x')] })
    expect(reduce(g0, { t: 'sell', itemId: 'smartgun#x' })).toBe(g0)
    const stock = [makeItem('knife', 'a'), makeItem('shotgun', 'b')]
    let g = atNode(g0, { kind: 'market', nodeId: 'mk', stock })
    g = reduce(g, { t: 'marketBuy', index: 1 })
    expect(g.character.credits).toBe(3000 - 950)
    expect(g.character.stash.map((i) => i.kind)).toEqual(['smartgun', 'shotgun'])
    g = reduce(reduce(g, { t: 'buyLifeline' }), { t: 'sell', itemId: 'smartgun#x' })
    expect(g.character.lifelines).toBe(1)
    expect(g.character.credits).toBe(3000 - 950 - 450 + 640)
  })

  it('the clinic heals for money and fits implants at half price when there is room', () => {
    let g = atNode(fresh('k2', { credits: 3000, injury: 20 }), { kind: 'clinic', nodeId: 'cl' })
    g = reduce(g, { t: 'treat' })
    expect(g.character).toMatchObject({ injury: 0, credits: 3000 - 120 })
    expect(implantRoom(g.character)).toBe(25)
    expect(reduce(g, { t: 'buyImplant', kind: 'subdermal' })).toBe(g)
    g = reduce(reduce(g, { t: 'raiseAttr', attr: 'tech' }), { t: 'raiseAttr', attr: 'tech' })
    g = reduce(g, { t: 'buyImplant', kind: 'subdermal' })
    expect(fightStats(g.character).armor).toBe(15 + 6)
  })

  it('rest is one choice: heal or lose heat', () => {
    const g = atNode(fresh('k3', { injury: 50, heat: 3 }), { kind: 'rest', nodeId: 'r' })
    const healed = reduce(g, { t: 'rest', choice: 'heal' })
    expect(healed.character).toMatchObject({ injury: 20, heat: 3 })
    expect(reduce(healed, { t: 'rest', choice: 'heat' })).toBe(healed)
    expect(reduce(g, { t: 'rest', choice: 'heat' }).character).toMatchObject({ injury: 50, heat: 1 })
  })

  it('a fame card pick applies the card once and only from the offered three', () => {
    const g0 = fresh('p1', { picks: [{ kind: 'perk', level: 1, seed: 7 }] })
    const opts = perkOptions(g0.character, 7)
    expect(reduce(g0, { t: 'pickPerk', id: PERK_IDS.find((id) => !opts.includes(id))! })).toBe(g0)
    const g = reduce(g0, { t: 'pickPerk', id: opts[0] })
    expect(g.character.perks).toEqual({ [opts[0]]: 1 })
    expect(g.character.picks).toEqual([])
  })

  it('an item pick puts the chosen one in the stash; the other two are gone', () => {
    const options = [makeItem('knife', 1), makeItem('silencer', 2), makeItem('dampener', 3)]
    const g = reduce(fresh('p2', { picks: [{ kind: 'item', from: 'x', options } as Pick] }), { t: 'pickItem', index: 2 })
    expect(g.character.stash.map((i) => i.kind)).toEqual(['dampener'])
    expect(g.character.picks).toEqual([])
  })

  it('gear cannot change during a fight or a case', () => {
    const g = atCase(fresh('p3'), CASE_01.id)
    const camo = g.character.equipment.find((i) => i.kind === 'camo')!
    expect(reduce(g, { t: 'unequip', itemId: camo.id })).toBe(g)
  })

  it('every event has an option that needs no money and no attribute', () => {
    const broke = { ...initial(0).character, credits: 0 }
    for (const ev of [...EVENTS, ...WANGAN_EVENTS]) expect(ev.options.some((o) => !eventLock(broke, o)), ev.id).toBe(true)
  })
})
