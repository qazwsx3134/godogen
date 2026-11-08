// 街區設定：每區的劇情委託（中段）與劇情大案（終點）、委託的難度、事件池。一段生涯依序走過。
import { CASE_01, CASE_02 } from './cases'
import { CASE_03, CASE_06 } from './cases_wangan'
import { EVENTS, WANGAN_EVENTS } from './events'

export interface DistrictDef {
  id: string
  name: string
  /** 中段的劇情委託、終點的劇情大案。 */
  story: string
  boss: string
  /** 一般委託的難度：前半段、後半段。 */
  tiers: [1 | 2 | 3, 1 | 2 | 3]
  /** 精英委託的難度。 */
  eliteTier: 4 | 5
  /** 這區會出現的事件。 */
  events: string[]
  /** 安全屋的開場白。 */
  safehouse: string
}

/** 灣岸也會出現的新宿事件（不綁地點的）。 */
const ANYWHERE = ['radio', 'stim', 'medkit', 'intel']

export const DISTRICTS: DistrictDef[] = [
  {
    id: 'shinjuku',
    name: '新宿',
    story: CASE_01.id,
    boss: CASE_02.id,
    tiers: [1, 2],
    eliteTier: 4,
    events: EVENTS.map((e) => e.id),
    safehouse: '新宿的事告一段落了。窗外的雨還沒停，灣岸那邊的封鎖線亮著紅燈。',
  },
  {
    id: 'wangan',
    name: '灣岸',
    story: CASE_03.id,
    boss: CASE_06.id,
    tiers: [2, 3],
    eliteTier: 5,
    events: [...WANGAN_EVENTS.map((e) => e.id), ...ANYWHERE],
    safehouse: '灣岸的封鎖線在你身後關上了。對岸的秋葉原亮著一整片電子招牌的光，聽說那裡的黑市什麼都買得到。',
  },
]
