import { describe, expect, it } from 'vitest'
import { initial } from '../game/state'
import { newsFor } from './news'

describe('city news ticker', () => {
  it('reacts to what you did: heat, closed cases, fame and the last legend', () => {
    const g0 = initial(0)
    const base = newsFor(g0).map((n) => n.text)
    expect(base.some((t) => t.includes('懸賞'))).toBe(false)
    const g = {
      ...g0,
      character: { ...g0.character, heat: 3, fame: { level: 3, xp: 0, total: 90 } },
      run: { ...g0.run, cases: { 'P01-02': { approach: 'hack', optionId: 'full', outcome: 'survived' as const, reason: '' } } },
      meta: { ...g0.meta, legends: [{ id: 'x', name: '鐵雨', end: 'dead' as const, cause: '', level: 3, fame: 2, fameTotal: 60, district: '新宿', style: null, perks: {}, at: 0 }] },
    }
    const t = newsFor(g).map((n) => n.text)
    expect(t.some((x) => x.includes('懸賞') && x.includes('3★'))).toBe(true)
    expect(t.some((x) => x.includes('設備異常'))).toBe(true)
    expect(t.some((x) => x.includes(g0.character.name))).toBe(true)
    expect(t.some((x) => x.startsWith('鐵雨 死在新宿'))).toBe(true)
  })
})
