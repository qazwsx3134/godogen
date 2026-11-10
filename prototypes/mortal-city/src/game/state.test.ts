import { describe, expect, it } from 'vitest'
import { CASES, CASE_01, CASE_02, caseBody, caseReplies, optionLock } from '../content/cases'
import { EVENTS, EVENT_BY_ID, WANGAN_EVENTS } from '../content/events'
import { JOBS, highDanger } from '../content/data'
import { ITEMS, SHOP_IMPLANTS, STARTER_CHOICES, STARTER_GEAR, clinicOrders, itemLock, makeItem, marketPrice } from '../content/items'
import { type Pick, STYLES, addFame, fameEdge, approachBonus, perkTally, upgradeCost, attrLock, dangerOdds, dirBonus, marginOf, psychoOdds, fightStats, hashSeed, jobSuccessChance, rng, hackPower, perkOptions, sellValue, stealthPower, tacticsFor } from '../rules/core'
import { PERKS, PERK_IDS } from '../rules/perks'
import { LAYERS, STORY_LAYER, findNode } from '../rules/map'
import { type Action, type Game, caseDangerOption, eliteDangerOption, eventLock, initial, movable, nextDistrict, nodeBusy, nodeJob, reduce } from './state'
import { DISTRICTS } from '../content/districts'

/** 換一個傭兵 id（每個 id 的 seed 不同）。起始三選一先跳過：手槍＋終端＋迷彩（單元測試用的固定配備）。 */
const fresh = (id: string, over: Partial<Game['character']> = {}): Game => {
  const g = initial(0)
  const equipment = [...STARTER_GEAR, ...STARTER_CHOICES.filter((i) => i.kind !== 'tendon')].map((i) => structuredClone(i))
  return { ...g, character: { ...g.character, id, equipment, implantLoad: equipment.reduce((s, i) => s + i.load, 0), picks: [], ...over } }
}

/** 真正的新傭兵：帶著起始裝備三選一（機器人跑整段生涯用）。 */
const recruit = (id: string): Game => {
  const g = initial(0)
  return { ...g, character: { ...g.character, id } }
}

/** 依 id 決定的一個數（機器人用來分散路線與起始裝備）。 */
const idHash = (id: string) => [...id].reduce((s, ch) => s + ch.charCodeAt(0), 0)

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
 * 機器人：每一步選第一個合法動作。safe＝危險節點選不會死的；risky＝選會死的；
 * optimal＝最佳化型：屬性堆門檻（沉著 8、技術 7），做法挑自己有裝備的方向，危險節點挑不會死又算完成的，
 * 沒有就挑死亡機率最低的冒險選項。
 * 回傳下一個動作；沒有合法動作回傳 null（那就是卡死）。
 */
type BotStyle = 'safe' | 'risky' | 'optimal' | 'stacker'
function botAction(g: Game, style0: BotStyle): Action | null {
  // stacker＝最佳化型，再加上背包裡的都裝上、神機醫的義體買得起就買（測「無限裝義體」划不划算）
  const style = style0 === 'stacker' ? 'optimal' : style0
  const risky = style === 'risky'
  const c = g.character
  if (!c.alive || g.run.phase === 'over') return null
  if (g.run.claim) return { t: 'claim' }
  if (c.attrPoints > 0) {
    if (style === 'optimal') {
      const want = c.attrs.cool < 8 ? 'cool' : c.attrs.tech < 7 ? 'tech' : 'reflex'
      return { t: 'raiseAttr', attr: want }
    }
    return { t: 'raiseAttr', attr: (['body', 'tech', 'reflex', 'int', 'cool'] as const)[c.attrPoints % 5] }
  }
  if (c.picks.length && !nodeBusy(g)) {
    const p = c.picks[0]
    if (p.kind === 'item') return { t: 'pickItem', index: p.equip ? idHash(c.id) % p.options.length : 0 }
    // 卡牌：手上最多的那個流派有卡就挑它（像在湊流派的玩家），沒有就挑第一張
    const opts = perkOptions(c, p.seed)
    const tally = perkTally(c)
    const top = STYLES.reduce((a, b) => (tally[b] > tally[a] ? b : a))
    return { t: 'pickPerk', id: (tally[top] > 0 && opts.find((id) => PERKS[id].style === top)) || opts[0] }
  }
  if (style0 === 'stacker' && !nodeBusy(g)) {
    const wear = c.stash.find((i) => !itemLock(c, i) && (i.slot === 'implant' || !c.equipment.some((e) => e.slot === i.slot)))
    if (wear) return { t: 'equip', itemId: wear.id }
    const n0 = g.run.node
    if (n0?.kind === 'clinic') {
      const kind = SHOP_IMPLANTS.find((k) => !c.equipment.some((e) => e.kind === k) && c.credits >= marketPrice(ITEMS[k].price) + 450 && !itemLock(c, makeItem(k, 'probe')))
      if (kind) return { t: 'buyImplant', kind }
      const order = clinicOrders(hashSeed(c.id, n0.nodeId, 'orders')).find((i) => ![...c.equipment, ...c.stash].some((e) => e.kind === i.kind) && c.credits >= i.price + 450)
      if (order) return { t: 'buyImplant', kind: order.kind! }
      const up = c.equipment.find((i) => i.slot === 'implant' && (i.level ?? 1) < 3 && c.credits >= upgradeCost(i) + 450)
      if (up) return { t: 'upgradeImplant', itemId: up.id }
    }
  }
  if (g.run.phase === 'safehouse') return nextDistrict(g) ? { t: 'continue' } : { t: 'retire' }
  const tactic = tacticsFor(c).find((t) => !t.locked)!.id
  const n = g.run.node
  if (!n) {
    // 依傭兵 id 挑不同的分支，各局走不同路線
    const opts = movable(g)
    const k = idHash(c.id) + g.run.path.length * 7
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
    if (n.stage === 'danger') {
      if (style !== 'optimal') return { t: 'eliteChoose', optionId: risky ? 'push' : 'abort' }
      const job = JOBS[n.jobId]
      const open = highDanger(job).options.filter((o) => o.lethal && !attrLock(c, o.attrNeeds))
      const best = open.sort((a, b) => dangerOdds(c, eliteDangerOption(c, job, a)).death - dangerOdds(c, eliteDangerOption(c, job, b)).death)[0]
      return { t: 'eliteChoose', optionId: best.id }
    }
    return { t: 'leave' }
  }
  if (n.kind === 'event') {
    if (n.stage === 'done') return { t: 'leave' }
    const ev = EVENT_BY_ID[n.eventId]
    return { t: 'eventChoose', optionId: ev.options.find((o) => !eventLock(c, o))!.id }
  }
  if (n.kind === 'market' && c.credits >= 450 && c.lifelines === 0) return { t: 'buyLifeline', tier: 'basic' }
  if (n.kind === 'rest' && !n.used) return { t: 'rest', choice: 'heal' }
  if (n.kind === 'story' && g.story.caseId) {
    const sc = CASES.find((s) => s.id === g.story.caseId)!
    const st = g.story
    if (st.stage === 'prep') {
      const open = sc.approaches.filter((a) => !attrLock(c, a.needs))
      const risk = (a: (typeof open)[number]) => a.lethalMod - approachBonus(c, a.direction)
      const pick = style === 'optimal' ? [...open].sort((a, b) => risk(a) - risk(b))[0] : sc.approaches.find((a) => !a.needs)!
      return { t: 'storyApproach', id: pick.id }
    }
    if (st.stage === 'auto') return { t: 'storyAutoDone' }
    if (st.stage === 'fight') return st.fight ? { t: 'storyFightDone' } : { t: 'storyFight', tactic }
    const opts = sc.danger.options.filter((o) => optionLock(c, st.approach, o) === undefined && !o.fight)
    if (style === 'optimal') {
      const win = opts.find((o) => o.wins)
      const lethal = opts.filter((o) => o.lethal).sort((a, b) => dangerOdds(c, caseDangerOption(c, sc, st.approach, a.id)).death - dangerOdds(c, caseDangerOption(c, sc, st.approach, b.id)).death)
      return { t: 'storyChoose', optionId: (win ?? lethal[0] ?? opts[0]).id }
    }
    return { t: 'storyChoose', optionId: (opts.find((o) => o.lethal === risky) ?? opts[0]).id }
  }
  return { t: 'leave' }
}

function runBot(id: string, style: BotStyle) {
  let g = recruit(id)
  let perks = 0
  let items = 0
  // 有主流派（≥2 張）時的三選一：沒有主流派卡的組數、三張都是主流派的組數
  const offers = { committed: 0, noTop: 0, allTop: 0 }
  for (let step = 0; step < 600; step++) {
    const a = botAction(g, style)
    if (!a) return { g, perks, items, step, offers }
    if (a.t === 'pickPerk') {
      perks++
      const p = g.character.picks[0] as Extract<Pick, { kind: 'perk' }>
      const tally = perkTally(g.character)
      const top = STYLES.reduce((x, y) => (tally[y] > tally[x] ? y : x))
      if (tally[top] >= 2) {
        const n = perkOptions(g.character, p.seed).filter((id) => PERKS[id].style === top).length
        offers.committed++
        if (n === 0) offers.noTop++
        if (n === 3) offers.allTop++
      }
    }
    if (a.t === 'pickItem' && !(g.character.picks[0]?.kind === 'item' && g.character.picks[0].equip)) items++ // 起始裝備不算戰利品
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
    let fame = 0
    let share = 0
    let built = 0
    const offers = { committed: 0, noTop: 0, allTop: 0 }
    for (let i = 0; i < 200; i++) {
      const r = runBot(`safe${i}`, 'safe')
      fame += r.g.character.fame.total
      const t = Object.values(perkTally(r.g.character))
      const sum = t.reduce((a, b) => a + b, 0)
      const top = sum ? Math.max(...t) / sum : 0
      share += top
      if (top >= 0.6) built++
      for (const k of ['committed', 'noTop', 'allTop'] as const) offers[k] += r.offers[k]
      expect(r.g.run.phase).toBe('over')
      expect(r.g.meta.legends.length).toBe(1)
      expect(r.g.meta.legends[0].end).toBe(r.g.character.alive ? 'retired' : 'dead')
      expect(r.g.character.alive).toBe(true) // 一律選不會死的選項就不會死
      expect(r.g.run.districtIndex).toBe(DISTRICTS.length - 1) // 走完所有街區才退休
      expect(r.g.run.path.length).toBe(11)
      perks += r.perks
      items += r.items
    }
    // 流派成形：生涯結束時主流派（張數最多的）佔流派卡的幾成
    console.log(
      `[bot] 流派 謹慎 200 局：主流派平均佔 ${Math.round((share / 200) * 100)}%，佔 60% 以上的 ${built} 局；` +
        `有主流派時的三選一 ${offers.committed} 組：沒有主流派卡 ${offers.noTop}、三張都是主流派 ${offers.allTop}`,
    )
    // README「掉落率」那行的數字：pnpm test 的輸出裡找 [bot]
    console.log(`[bot] 謹慎 200 局：全部活著，每局卡牌 ${(perks / 200).toFixed(1)}、道具 ${(items / 200).toFixed(1)}、名聲總量 ${Math.round(fame / 200)}`)
    // 每次都選不會死的，新宿＋灣岸兩區約 6 張卡
    expect(perks / 200).toBeGreaterThanOrEqual(4)
    expect(perks / 200).toBeLessThanOrEqual(8)
    expect(items / 200).toBeGreaterThanOrEqual(1)
  })

  it('a reckless bot also always ends: dead (into the legends) or retired', () => {
    let dead = 0
    let perks = 0
    let items = 0
    let fame = 0
    let allPerks = 0
    for (let i = 0; i < 200; i++) {
      const r = runBot(`risk${i}`, 'risky')
      expect(r.g.run.phase).toBe('over')
      expect(r.g.meta.legends.length).toBe(1)
      allPerks += r.perks
      if (!r.g.character.alive) dead++
      else {
        perks += r.perks
        items += r.items
        fame += r.g.character.fame.total
      }
    }
    const alive = 200 - dead
    console.log(
      `[bot] 冒險 200 局：死 ${dead}；活下來的每局卡牌 ${(perks / alive).toFixed(1)}、道具 ${(items / alive).toFixed(1)}、名聲總量 ${Math.round(fame / alive)}；全部（含死亡）每局卡牌 ${(allPerks / 200).toFixed(1)}`,
    )
    expect(dead).toBeGreaterThan(0)
    expect(dead).toBeLessThan(100)
    // 冒險而活下來的，兩區約 13 張卡（2026-11-09：重傷生還、冒險撐過去名聲 ×1.5）
    expect(perks / (200 - dead)).toBeGreaterThanOrEqual(6)
    expect(perks / (200 - dead)).toBeLessThanOrEqual(14)
  })

  it('an event never comes back in the same career, even in the next district', () => {
    for (let i = 0; i < 100; i++) {
      const seen: string[] = []
      let g = fresh(`ev${i}`)
      for (let step = 0; step < 600; step++) {
        const a = botAction(g, 'safe')
        if (!a) break
        g = reduce(g, a)
        if (a.t === 'move' && g.run.node?.kind === 'event') {
          expect(seen).not.toContain(g.run.node.eventId)
          seen.push(g.run.node.eventId)
        }
      }
    }
  })

  it.each([
    ['最佳化', 'optimal'],
    ['堆義體', 'stacker'],
  ] as const)('an %s bot always ends, and its numbers are printed', (label, style) => {
    let dead = 0
    let maimed = 0
    let perks = 0
    let fame = 0
    let worn = 0
    let credits = 0
    for (let i = 0; i < 200; i++) {
      const r = runBot(`opt${i}`, style)
      credits += r.g.character.credits
      worn += r.g.character.equipment.filter((e) => e.slot === 'implant').length
      expect(r.g.run.phase).toBe('over')
      if (!r.g.character.alive) dead++
      else {
        perks += r.perks
        fame += r.g.character.fame.total
      }
      if (Object.values(r.g.character.scars ?? {}).some((n) => n)) maimed++
    }
    const alive = 200 - dead
    console.log(`[bot] ${label} 200 局：死 ${dead}、留下舊傷 ${maimed}；活下來的每局卡牌 ${(perks / alive).toFixed(1)}、名聲總量 ${Math.round(fame / alive)}；最後身上義體平均 ${(worn / 200).toFixed(1)} 件、剩 ¢${Math.round(credits / 200)}`)
  })

  it('a new mercenary keeps the legends and the seen node types, and gets a new map', () => {
    const r = runBot('keep', 'safe')
    const g = reduce(r.g, { t: 'newCharacter' })
    expect(g.meta.legends.length).toBe(1)
    expect(g.meta.seen.job || g.meta.seen.event).toBe(true)
    expect(g.run.path).toEqual([])
    expect(g.character.perks).toEqual({})
  })
})

describe('job loot does not depend on the route', () => {
  /** 從進節點到結算跑完一件委託（照 enter 的方式擲得手），回傳有沒有掉寶。 */
  function lootOnce(id: string, jobId: string): boolean {
    const g = fresh(id)
    const job = JOBS[jobId]
    const nodeId = 'shinjuku-1-0'
    const ok = rng(hashSeed(hashSeed(g.character.id, nodeId), 'roll'))() < jobSuccessChance(job, dirBonus(g.character, job.direction))
    let s: Game = { ...g, run: { ...g.run, at: nodeId, node: { kind: 'job', nodeId, jobId, ok, stage: 'auto' } } }
    s = reduce(s, { t: 'jobAutoDone' })
    if (s.run.node?.kind === 'job' && s.run.node.stage === 'fight') {
      s = reduce(s, { t: 'jobFight', tactic: 'force' })
      s = reduce(s, { t: 'jobFightDone' })
    }
    return s.character.picks.some((p) => p.kind === 'item')
  }
  it('force, hack and stealth jobs of the same tier drop loot within 2x of each other', () => {
    for (const tier of [1, 2, 3]) {
      const rates = (['force', 'hack', 'stealth'] as const).map((dir) => {
        let n = 0
        for (let i = 0; i < 600; i++) if (lootOnce(`loot${tier}${dir}${i}`, `${dir}-${tier}`)) n++
        return n / 600
      })
      expect(Math.min(...rates)).toBeGreaterThan(0)
      expect(Math.max(...rates) / Math.min(...rates)).toBeLessThanOrEqual(2)
    }
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

  it('the job previewed on the map is the job you get when you go there', () => {
    let checked = 0
    for (let i = 0; i < 30; i++) {
      const g = fresh(`preview${i}`)
      for (const n of g.run.district.layers.flat().filter((x) => x.type === 'job' || x.type === 'elite')) {
        const entered = reduce(g, { t: 'move', nodeId: n.id })
        if (entered.run.node?.kind !== 'job' && entered.run.node?.kind !== 'elite') continue // 不在第一層就走不到
        expect(entered.run.node.jobId).toBe(nodeJob(g, n)!.id)
        checked++
      }
    }
    expect(checked).toBeGreaterThan(10)
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
    // 名聲升級的三選一還沒挑會擋住移動；這裡只看地圖，先清掉
    g = { ...g, character: { ...g.character, picks: [] }, run: { ...g.run, phase: 'safehouse', node: null } }
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
    const c = fresh('ap').character // 手槍、終端、迷彩：每方向 +5%
    expect(caseDangerOption(c, CASE_01, 'force', 'carry').lethalBase).toBeCloseTo((0.18 + 0.04 - 0.05) * 1.5)
    expect(caseDangerOption(c, CASE_01, 'stealth', 'carry').lethalBase).toBeCloseTo((0.18 - 0.02 - 0.05) * 1.5)
    const pro = { ...c, perks: { quietPro: 1 } }
    expect(caseDangerOption(pro, CASE_01, 'stealth', 'carry').lethalBase).toBeCloseTo((0.18 - 0.02 - 0.05 - 0.03) * 1.5)
    expect(caseDangerOption(c, CASE_01, 'force', 'hand').lethalBase).toBe(0)
  })

  it('a gear or attribute option pays 75% and costs 10 stress', () => {
    const c = fresh('cost', { attrs: { ...initial(0).character.attrs, cool: 6 } })
    const g = play(c, CASE_01.id, 'stealth', 'stare')
    expect(g.character.credits).toBe(500 + Math.round(600 * 0.75))
    expect(g.character.stress).toBe(6 + 10) // 路上 6、靠屬性 10
    expect(g.character.fame.total).toBe(CASE_01.xp) // 撐過去是經驗 ×2，靠屬性減半
  })

  it('a maimed survivor is paid but keeps an old wound in that direction', () => {
    let seen = 0
    for (let i = 0; i < 300 && !seen; i++) {
      const g = play(fresh(`m${i}`), CASE_01.id, 'stealth', 'carry')
      if (g.run.cases[CASE_01.id].outcome !== 'maimed') continue
      seen++
      expect(g.character.alive).toBe(true)
      expect(g.character.credits).toBe(500 + 600)
      expect(g.character.injury).toBeGreaterThanOrEqual(70)
      expect(g.character.scars).toEqual({ reflex: 1 }) // 潛行傷反應
      expect(g.character.attrs.reflex).toBe(2)
      expect(caseBody(CASE_02, g.run.cases)).toContain(CASE_02.variants!.won) // 重傷也算撐過去
    }
    expect(seen).toBe(1)
  })

  it('elite danger options also take off the gear bonus in that direction', () => {
    const c = fresh('el').character
    const job = JOBS['hack-4']
    const push = highDanger(job).options.find((o) => o.id === 'push')!
    expect(eliteDangerOption(c, job, push).lethalBase).toBeCloseTo((push.lethalBase - 0.05) * 1.5)
  })

  it('a new mercenary picks one starting item, which is worn at once', () => {
    const g = initial(0)
    expect(g.character.equipment.map((i) => i.kind)).toEqual(['gun'])
    expect(movable(g)).toEqual([]) // 挑完才能出發
    const after = reduce(g, { t: 'pickItem', index: 1 })
    expect(after.character.equipment.map((i) => i.kind)).toEqual(['gun', 'camo'])
    expect(after.character.implantLoad).toBe(25)
    expect(after.character.stash).toEqual([])
    expect(movable(after).length).toBeGreaterThan(0)
  })

  it('surviving the risk pays in full, gives fame, and records the "won" paragraph for 02', () => {
    for (let i = 0; i < 200; i++) {
      const g = play(fresh(`s${i}`), CASE_01.id, 'stealth', 'carry')
      if (g.run.cases[CASE_01.id].outcome !== 'survived') continue
      expect(g.character.credits).toBe(500 + 600)
      expect(g.character.heat).toBe(2) // 案子 +1；名聲 90 到 Lv.3，MPD 觀察名單再 +1
      expect(g.character.fame.total).toBe(90) // 經驗 30 ×2，冒險撐過去再 ×1.5
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

  it('the market sells its stock at 75% and the lifeline; selling only works there', () => {
    const g0 = fresh('k1', { credits: 3000, stash: [makeItem('smartgun', 'x')] })
    expect(reduce(g0, { t: 'sell', itemId: 'smartgun#x' })).toBe(g0)
    const stock = [makeItem('knife', 'a'), makeItem('shotgun', 'b')]
    let g = atNode(g0, { kind: 'market', nodeId: 'mk', stock })
    g = reduce(g, { t: 'marketBuy', index: 1 })
    expect(g.character.credits).toBe(3000 - 1425)
    expect(g.character.stash.map((i) => i.kind)).toEqual(['smartgun', 'shotgun'])
    g = reduce(reduce(g, { t: 'buyLifeline', tier: 'basic' }), { t: 'sell', itemId: 'smartgun#x' })
    expect(g.character.lifelines).toBe(1)
    expect(g.character.credits).toBe(3000 - 1425 - 450 + 640)
  })

  it('the market also buys what you are wearing, implants included', () => {
    const g0 = fresh('k5', { credits: 0 })
    const gun = g0.character.equipment.find((i) => i.slot === 'weapon')!
    let g = atNode(g0, { kind: 'market', nodeId: 'mk', stock: [] })
    g = reduce(g, { t: 'sell', itemId: gun.id })
    expect(g.character.equipment.some((i) => i.id === gun.id)).toBe(false)
    expect(g.character.credits).toBe(sellValue(gun))
    expect(() => fightStats(g.character)).not.toThrow()
    const imp = makeItem('subdermal', 'w')
    g = { ...g, character: { ...g.character, equipment: [...g.character.equipment, imp], implantLoad: g.character.implantLoad + imp.load } }
    const load = g.character.implantLoad
    g = reduce(g, { t: 'sell', itemId: imp.id })
    expect(g.character.implantLoad).toBe(load - imp.load)
  })

  it('the clinic heals for money; implants have no cap, only attribute gates and neural margin', () => {
    let g = atNode(fresh('k2', { credits: 8000, injury: 20 }), { kind: 'clinic', nodeId: 'cl' })
    g = reduce(g, { t: 'treat' })
    expect(g.character).toMatchObject({ injury: 0, credits: 8000 - 120 })
    // 皮下護甲要體能 5：屬性不夠也能買（七五折），先放背包
    g = reduce(g, { t: 'buyImplant', kind: 'subdermal' })
    expect(g.character.credits).toBe(8000 - 120 - 1125)
    expect(g.character.stash.map((i) => i.kind)).toEqual(['subdermal'])
    g = reduce(reduce(g, { t: 'raiseAttr', attr: 'body' }), { t: 'raiseAttr', attr: 'body' })
    g = reduce({ ...g, run: { ...g.run, node: null } }, { t: 'equip', itemId: g.character.stash[0].id })
    g = atNode(g, { kind: 'clinic', nodeId: 'cl' })
    expect(fightStats(g.character).armor).toBe(15)
    // 沒有義體上限：一直裝，神經餘裕一路往下掉，任務錯亂的機率跟著升
    for (let i = 0; i < 3; i++) g = reduce(g, { t: 'buyImplant', kind: 'tendon' })
    expect(g.character.equipment.filter((i) => i.kind === 'tendon').length).toBe(3)
    expect(marginOf(g.character)).toBe(100 - 25 - 30 - 60)
    expect(reduce(g, { t: 'buyImplant', kind: 'nope' })).toBe(g) // 不在這次的訂製清單（也不是常備）就不能買
    expect(psychoOdds(g.character).total).toBeCloseTo(0.85) // 餘裕 −15：失控 70%，每低 1 點 +1%
  })

  it('the clinic upgrades a worn implant: effect x1.5 then x2, +10 load each, list price x level', () => {
    let g = atNode(fresh('up', { credits: 5000 }), { kind: 'clinic', nodeId: 'cl' })
    const camo = g.character.equipment.find((i) => i.kind === 'camo')!
    const bonus = dirBonus(g.character, 'stealth')
    g = reduce(g, { t: 'upgradeImplant', itemId: camo.id })
    expect(g.character.credits).toBe(5000 - 1000)
    expect(g.character.implantLoad).toBe(25 + 10)
    expect(dirBonus(g.character, 'stealth')).toBeCloseTo(bonus + 0.025)
    g = reduce(g, { t: 'upgradeImplant', itemId: camo.id })
    expect(g.character.credits).toBe(5000 - 1000 - 2000)
    expect(g.character.equipment.find((i) => i.id === camo.id)!.level).toBe(3)
    expect(reduce(g, { t: 'upgradeImplant', itemId: camo.id })).toBe(g) // Lv.3 封頂
  })

  it('gear with an attribute gate cannot be worn until the attribute is high enough', () => {
    const shotgun = makeItem('shotgun', 'x')
    let g = fresh('gate', { stash: [shotgun] })
    expect(reduce(g, { t: 'equip', itemId: shotgun.id })).toBe(g)
    g = reduce(reduce(g, { t: 'raiseAttr', attr: 'body' }), { t: 'raiseAttr', attr: 'body' })
    expect(reduce(g, { t: 'equip', itemId: shotgun.id }).character.equipment.some((i) => i.kind === 'shotgun')).toBe(true)
  })

  it('below 40 neural margin a mission can go wrong: abort, maim or death, by seed', () => {
    const seen = { none: 0, abort: 0, maim: 0, dead: 0 }
    for (let i = 0; i < 400; i++) {
      // 餘裕 0：失控，錯亂 70%（中斷 28%、重傷 7%、死亡 35%）
      const g = atNode(fresh(`ps${i}`, { stress: 75 }), { kind: 'job', nodeId: 'j', jobId: 'hack-1', ok: true, stage: 'auto' })
      const r = reduce(g, { t: 'jobAutoDone' })
      if (!r.character.alive) seen.dead++
      else if (r.character.scars) seen.maim++
      else if (r.run.node?.kind === 'job' && r.run.node.text?.includes('神經錯亂')) seen.abort++
      else seen.none++
      const again = reduce(g, { t: 'jobAutoDone' }) // 同一個 seed 同一個結果（紀錄的時間戳不比）
      expect([again.character, again.run.node]).toEqual([r.character, r.run.node])
    }
    expect(seen.none).toBeGreaterThan(80)
    expect(seen.abort).toBeGreaterThan(70)
    expect(seen.maim).toBeGreaterThan(10)
    expect(seen.dead).toBeGreaterThan(90)
  })

  it('fame opens named options in events, and gets you on the MPD watch list every 3 levels', () => {
    const vendor = EVENT_BY_ID['vendor'].options.find((o) => o.id === 'name')!
    expect(eventLock(fresh('f0').character, vendor)).toMatch(/名聲 Lv.3/)
    const famous = fresh('f1', { fame: { level: 3, xp: 0, total: 60 } }).character
    expect(eventLock(famous, vendor)).toBeUndefined()
    const c = fresh('f2').character
    const log: Parameters<typeof addFame>[3] = []
    addFame(c, 60, 0, log) // Lv.1、2、3
    expect(c.fame.level).toBe(3)
    expect(c.heat).toBe(1)
    expect(fameEdge(2)).toBe(0)
    expect(fameEdge(5)).toBeCloseTo(0.12)
    expect(fameEdge(30)).toBe(0.4)
  })

  it('only one lifeline at a time: the market will not sell a second', () => {
    let g = atNode(fresh('l1', { credits: 5000 }), { kind: 'market', nodeId: 'mk', stock: [] })
    g = reduce(g, { t: 'buyLifeline', tier: 'platinum' })
    expect(g.character).toMatchObject({ lifelines: 1, lifelineTier: 'platinum', credits: 2000 })
    expect(reduce(g, { t: 'buyLifeline', tier: 'basic' })).toBe(g)
  })

  it('the lifeline tier decides how you come back', () => {
    const back = (tier: 'basic' | 'standard' | 'platinum') => {
      for (let i = 0; i < 400; i++) {
        const g = atNode(fresh(`lt${tier}${i}`, { stress: 75, lifelines: 1, lifelineTier: tier }), { kind: 'job', nodeId: 'j', jobId: 'hack-1', ok: true, stage: 'auto' })
        const r = reduce(g, { t: 'jobAutoDone' })
        if (r.character.lifelines === 0) return r.character
      }
      throw new Error('no rescue')
    }
    const basic = back('basic')
    expect(basic.equipment.map((i) => i.kind)).toEqual(['gun', 'deck'])
    expect(basic.injury).toBe(90)
    expect(basic.scars).toEqual({ int: 1 }) // 駭入委託：燒腦
    const plat = back('platinum')
    expect(plat.equipment.map((i) => i.kind)).toEqual(['gun', 'deck', 'camo'])
    expect(plat.injury).toBe(50)
    expect(plat.scars).toBeUndefined()
    expect(plat.lifelineTier).toBeUndefined()
  })

  it('a lifeline pulls you back from death, and the medics strip your implants to pay for it', () => {
    let seen = 0
    for (let i = 0; i < 400 && !seen; i++) {
      const g = atNode(fresh(`rb${i}`, { stress: 75, lifelines: 1 }), { kind: 'job', nodeId: 'j', jobId: 'hack-1', ok: true, stage: 'auto' })
      const r = reduce(g, { t: 'jobAutoDone' })
      if (r.character.lifelines !== 0) continue
      seen++
      expect(r.character.alive).toBe(true)
      expect(r.character.equipment.map((i) => i.kind)).toEqual(['gun', 'deck']) // 迷彩被拆走
      expect(r.character.implantLoad).toBe(0)
      expect(r.character.injury).toBeGreaterThanOrEqual(70)
      expect(r.character.scars).toBeUndefined()
    }
    expect(seen).toBe(1)
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

describe('戰術的素質判定', () => {
  it('對方防火牆擋駭入、感知擋光學迷彩繞背，正面交火一定能用', () => {
    const c = fresh('tac').character
    const weak = { name: 'a', hp: 10, atk: 1, hit: 0.1, ice: 3, sense: 3 }
    const strong = { ...weak, ice: 4, sense: 4 }
    const lock = (ch: typeof c, e: typeof weak) => Object.fromEntries(tacticsFor(ch, e).map((t) => [t.id, !!t.locked]))
    expect([hackPower(c), stealthPower(c)]).toEqual([3, 3])
    expect(lock(c, weak)).toEqual({ force: false, hack: false, stealth: false })
    expect(lock(c, strong)).toEqual({ force: false, hack: true, stealth: true })
    expect(tacticsFor(c, strong).find((t) => t.id === 'hack')!.locked).toMatch(/防火牆 4/)
    expect(lock({ ...c, attrs: { ...c.attrs, int: 4, cool: 4 } }, strong)).toEqual({ force: false, hack: false, stealth: false })
  })
})
