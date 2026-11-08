// 街區地圖：依 seed 程序產生的分岔路線圖。只能往下一層相鄰的節點走。
// 規則：第 0 層只有委託與事件；中段那一層只有劇情委託；最後一層只有劇情大案、前一層只有診所或休息；
// 精英委託不早於第 4 層、每區 2 個；每區至少一個黑市。
import { hashSeed, rng } from './core'

export type NodeType = 'job' | 'elite' | 'event' | 'market' | 'clinic' | 'rest' | 'story' | 'boss'

export const NODE_LABEL: Record<NodeType, string> = {
  job: '委託',
  elite: '精英委託',
  event: '事件',
  market: '黑市',
  clinic: '神機醫',
  rest: '休息',
  story: '劇情委託',
  boss: '劇情大案',
}

export interface MapNode {
  id: string
  layer: number
  type: NodeType
  /** 下一層可以前往的節點 id。 */
  next: string[]
}

export interface District {
  id: string
  name: string
  layers: MapNode[][]
}

export const LAYERS = 11
export const STORY_LAYER = 5
export const ELITE_FROM = 4
export const ELITES = 2

/** 一般層的節點類型權重。 */
const WEIGHTS: [NodeType, number][] = [
  ['job', 45],
  ['event', 25],
  ['rest', 12],
  ['market', 10],
  ['clinic', 8],
]

function pickWeighted(r: () => number, ws: [NodeType, number][]): NodeType {
  let x = r() * ws.reduce((s, [, w]) => s + w, 0)
  for (const [t, w] of ws) if ((x -= w) < 0) return t
  return ws[0][0]
}

/** 第 i 個節點（n 個中）連到下一層（m 個中）的哪些節點：把兩層各自等分，區段重疊的就相連，不會交叉、也不會有走不到的節點。 */
function links(i: number, n: number, m: number): number[] {
  const lo = Math.floor((i * m) / n)
  const hi = Math.max(lo, Math.ceil(((i + 1) * m) / n) - 1)
  return Array.from({ length: hi - lo + 1 }, (_, k) => lo + k)
}

export function generateDistrict(seed: number, id = 'shinjuku', name = '新宿'): District {
  const r = rng(hashSeed(seed, 'map', id))
  const width = (l: number) => (l === STORY_LAYER || l === LAYERS - 1 ? 1 : l === 0 ? 2 + Math.floor(r() * 2) : 2 + Math.floor(r() * 3))
  const types: NodeType[][] = []
  for (let l = 0; l < LAYERS; l++) {
    const w = width(l)
    types.push(
      Array.from({ length: w }, () => {
        if (l === LAYERS - 1) return 'boss'
        if (l === STORY_LAYER) return 'story'
        if (l === LAYERS - 2) return r() < 0.5 ? 'clinic' : 'rest'
        if (l === 0) return r() < 0.7 ? 'job' : 'event'
        return pickWeighted(r, WEIGHTS)
      }),
    )
  }
  // 精英委託：從第 4 層起的一般層隨機挑格子換掉
  const open = (l: number) => l >= 1 && l < LAYERS - 2 && l !== STORY_LAYER
  const slots: [number, number][] = []
  types.forEach((row, l) => row.forEach((_, i) => l >= ELITE_FROM && open(l) && slots.push([l, i])))
  for (let k = 0; k < ELITES && slots.length; k++) {
    const [l, i] = slots.splice(Math.floor(r() * slots.length), 1)[0]
    types[l][i] = 'elite'
  }
  // 至少一個黑市：沒有就把第一個一般層的委託或事件換掉
  if (!types.flat().includes('market')) {
    outer: for (let l = 1; l < LAYERS - 2; l++)
      for (let i = 0; i < types[l].length; i++)
        if (open(l) && (types[l][i] === 'job' || types[l][i] === 'event')) {
          types[l][i] = 'market'
          break outer
        }
  }
  const idOf = (l: number, i: number) => `${id}-${l}-${i}`
  const layers = types.map((row, l) =>
    row.map((type, i) => ({
      id: idOf(l, i),
      layer: l,
      type,
      next: l < LAYERS - 1 ? links(i, row.length, types[l + 1].length).map((j) => idOf(l + 1, j)) : [],
    })),
  )
  return { id, name, layers }
}

export function findNode(d: District, id: string): MapNode | undefined {
  const l = Number(id.split('-').at(-2))
  return d.layers[l]?.find((n) => n.id === id)
}

/** 從目前位置（null＝還沒出發）能前往的節點。 */
export function reachable(d: District, at: string | null): MapNode[] {
  if (at === null) return d.layers[0]
  const here = findNode(d, at)
  return here ? here.next.map((id) => findNode(d, id)!) : []
}
