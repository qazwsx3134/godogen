// 城市分頁的橫向場景欄：休息時在公寓沙發上，出任務時在東京風的屋頂上奔跑（參考 taskbar-hero 的行軍橫幅）。
// 由多張 sprite 圖片依 src/content/scene_layout.json 組裝；動畫用 CSS（版面資料的 anim 與 *_fx）。
// 程式手繪的舊版在 src/pixel/（保留，用途另定）。
import layout from '../content/scene_layout.json'
import sprites from '../content/sprites.json'
import { type SceneFx, type SpritePlacement, SpriteScene } from './SpriteScene'

export type StripMode = 'rest' | 'run' | 'dead' | 'node'

type Man = Record<string, { src: string; w: number; h: number }>

function placements(scene: 'room' | 'street', skip: string[] = []): SpritePlacement[] {
  const man = sprites as unknown as Man
  return (layout[scene] as { id: string; x: number; y: number; anim?: string }[])
    .filter((p) => !skip.includes(p.id))
    .map((p) => ({ ...man[p.id], ...p }))
}

const ROOM = placements('room')
const ROOM_EMPTY = placements('room', ['hero_lying'])
const STREET = placements('street')
const ROOM_FX = layout.room_fx as SceneFx[]
const STREET_FX = layout.street_fx as SceneFx[]
const RAIN = STREET_FX.filter((f) => f.fx === 'rain')

/** 有專屬背景圖的節點類型（public/sprites/node_*.png，由 art_src/build_nodes.py 產生）。 */
export const NODE_BG = ['job', 'elite', 'event', 'market', 'clinic', 'rest'] as const
export type NodeBg = (typeof NODE_BG)[number]
/** 室內的節點背景不疊雨（依街區：灣岸的休息是戶外的貨櫃旅館）。 */
const INDOOR: Record<string, NodeBg[]> = { shinjuku: ['clinic', 'rest'], wangan: ['clinic'] }

/** 有自己一套節點背景的街區（檔名 node_<街區>_<類型>.png）；其他街區用新宿的（node_<類型>.png）。 */
const DISTRICT_BG = ['wangan']

/** 有專屬場景背景的劇情委託（public/sprites/story_<案件>.png）；地下的 01、02 不下雨。 */
export const STORY_BG = ['P01-01', 'P01-02', 'P01-03', 'P01-06']
const STORY_INDOOR = ['P01-01', 'P01-02']

/** 節點畫面：該節點（或劇情委託）的整張背景，主角站在中間偏左。 */
function nodeLayers(file: string): SpritePlacement[] {
  const man = sprites as unknown as Man
  return [
    { id: 'bg', src: `/sprites/${file}.png`, w: 384, h: 160, x: 0, y: 0 },
    { id: 'hero_stand', ...man.hero_stand, x: 150, y: 76, anim: 'breathe:3.4' },
  ]
}

export function CityStrip({ mode, label, sub, bg, story, district = 'shinjuku' }: { mode: StripMode; label: string; sub?: string; bg?: NodeBg; story?: string; district?: string }) {
  const file = story ? `story_${story}` : bg ? (DISTRICT_BG.includes(district) ? `node_${district}_${bg}` : `node_${bg}`) : null
  const indoor = story ? STORY_INDOOR.includes(story) : !!bg && (INDOOR[district] ?? INDOOR.shinjuku).includes(bg)
  const layers = mode === 'node' && file ? nodeLayers(file) : mode === 'run' ? STREET : mode === 'dead' ? ROOM_EMPTY : ROOM
  return (
    <div className="cut cut-strong">
      <div className="cut-in relative overflow-hidden">
        <SpriteScene layers={layers} fx={mode === 'run' ? STREET_FX : mode === 'node' ? (indoor ? [] : RAIN) : mode === 'rest' ? ROOM_FX : ROOM_FX.filter((f) => f.fx === 'rain')} label={label} />
        {mode === 'dead' && <div className="pointer-events-none absolute inset-0 bg-bg/60" />}
        <div className="pointer-events-none absolute inset-x-0 top-0 flex items-start justify-between gap-2 bg-gradient-to-b from-bg/85 to-transparent px-2 pt-1 pb-3">
          <span className={`text-[13px] font-bold ${mode === 'dead' ? 'text-red' : mode === 'run' || mode === 'node' ? 'text-cyan' : 'text-heading'}`}>{label}</span>
          {sub && <span className="tech text-[13px] text-heading">{sub}</span>}
        </div>
      </div>
    </div>
  )
}
