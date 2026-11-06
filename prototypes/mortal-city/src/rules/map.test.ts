import { describe, expect, it } from 'vitest'
import { ELITES, ELITE_FROM, LAYERS, STORY_LAYER, generateDistrict, reachable } from './map'

describe('district map', () => {
  const maps = Array.from({ length: 500 }, (_, i) => generateDistrict(i * 7919))

  it('the same seed gives the same map', () => {
    expect(generateDistrict(42)).toEqual(generateDistrict(42))
  })

  it('fixed layers: 01 in the middle, 02 at the end, a clinic or rest right before it', () => {
    for (const d of maps) {
      expect(d.layers.length).toBe(LAYERS)
      expect(d.layers[STORY_LAYER].map((n) => n.type)).toEqual(['story'])
      expect(d.layers[LAYERS - 1].map((n) => n.type)).toEqual(['boss'])
      for (const n of d.layers[LAYERS - 2]) expect(['clinic', 'rest']).toContain(n.type)
      for (const n of d.layers[0]) expect(['job', 'event']).toContain(n.type)
    }
  })

  it('elites come from layer 4 on, two per district, and there is always a market', () => {
    for (const d of maps) {
      const all = d.layers.flat()
      const elites = all.filter((n) => n.type === 'elite')
      expect(elites.length).toBe(ELITES)
      for (const e of elites) expect(e.layer).toBeGreaterThanOrEqual(ELITE_FROM)
      expect(all.some((n) => n.type === 'market')).toBe(true)
    }
  })

  it('every node is reachable from the start and leads to the boss', () => {
    for (const d of maps) {
      const seen = new Set(d.layers[0].map((n) => n.id))
      for (let l = 0; l < LAYERS - 1; l++) for (const n of d.layers[l]) if (seen.has(n.id)) for (const x of reachable(d, n.id)) seen.add(x.id)
      expect(seen.size).toBe(d.layers.flat().length)
      for (let l = 0; l < LAYERS - 1; l++) for (const n of d.layers[l]) expect(n.next.length).toBeGreaterThan(0)
    }
  })
})
