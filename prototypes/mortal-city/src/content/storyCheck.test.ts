import { describe, expect, it } from 'vitest'
import { CASES, CASE_01, TEST_CASE } from './cases'
import { checkStory } from './storyCheck'

describe('story check (docs/story-pipeline)', () => {
  it('every story case already in the game passes with no errors (a false alarm means the rule is wrong)', () => {
    for (const sc of [...CASES, TEST_CASE]) {
      const errors = checkStory(sc).filter((x) => x.level === 'error')
      expect(errors, sc.id).toEqual([])
    }
  })

  it('catches the things that would break the game or the house style', () => {
    const bad = structuredClone(CASE_01)
    bad.fixerId = 'nobody'
    bad.danger.options = bad.danger.options.filter((o) => o.lethal) // 沒有撤離選項
    bad.danger.body = '黑冰咬住了你，成功率 30%。'
    bad.approaches[0].beats = [{ title: 'x', attr: 'luck' as never, setup: '', out: { crit: 'a', clean: 'b', cost: 'c', fail: '' }, costs: [{ kind: 'pay', text: 'p' }] as never, fail: 'pay' }]
    const msgs = checkStory(bad).filter((x) => x.level === 'error').map((x) => `${x.where} ${x.msg}`)
    expect(msgs.some((m) => m.startsWith('fixerId'))).toBe(true)
    expect(msgs.some((m) => m.includes('撤離選項'))).toBe(true)
    expect(msgs.some((m) => m.includes('防火牆'))).toBe(true)
    expect(msgs.some((m) => m.includes('百分比'))).toBe(true)
    expect(msgs.some((m) => m.includes('剛好兩個'))).toBe(true)
    expect(msgs.some((m) => m.includes('fail') && m.includes('報酬打折'))).toBe(true)
  })
})
