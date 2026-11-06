import { expect, it } from 'vitest'
import { GRIDS } from './icons'

it('every pixel icon is a 12×12 grid of . # +', () => {
  expect(Object.keys(GRIDS).length).toBeGreaterThan(35)
  for (const [name, rows] of Object.entries(GRIDS)) {
    expect(rows.length, name).toBe(12)
    for (const r of rows) expect(r, name).toMatch(/^[.#+]{12}$/)
  }
})
