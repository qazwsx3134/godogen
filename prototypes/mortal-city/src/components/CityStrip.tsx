// 城市分頁的橫向場景欄：休息時在公寓沙發上，出任務時在東京風的屋頂上奔跑（參考 taskbar-hero 的行軍橫幅）。
// 由多張 sprite 圖片依 src/content/scene_layout.json 組裝；動畫用 CSS（版面資料的 anim 與 *_fx）。
// 程式手繪的舊版在 src/pixel/（保留，用途另定）。
import layout from '../content/scene_layout.json'
import sprites from '../content/sprites.json'
import { type SceneFx, type SpritePlacement, SpriteScene } from './SpriteScene'

export type StripMode = 'rest' | 'run' | 'dead' | 'node'

type Man = Record<string, { src: string; w: number; h: number }>

/** 主角外觀：a＝女主角 A、b＝男主角 B。B 的圖還沒做好時（sprites.json 沒有 hero_b_*）用 A 的。 */
export type Look = 'a' | 'b'
export const hasLook = (look: Look) => look === 'a' || 'hero_b_stand' in (sprites as object)

/** 換成 B 的圖：底邊對齊 A 原本的位置（站在同一條線上、躺在同一張沙發）。 */
function heroOf(look: Look, p: { id: string; x: number; y: number; anim?: string }): SpritePlacement {
  const man = sprites as unknown as Man
  const alt = look === 'b' && p.id.startsWith('hero_') ? p.id.replace('hero_', 'hero_b_') : p.id
  if (alt === p.id || !man[alt]) return { ...man[p.id], ...p }
  return { ...man[alt], ...p, id: alt, y: p.y + man[p.id].h - man[alt].h }
}

function placements(scene: 'room' | 'street', look: Look, skip: string[] = [], rest = false): SpritePlacement[] {
  const man = sprites as unknown as Man
  // 休息：有「沙發＋主角」一起畫的整張就用它取代沙發，原本的躺姿不畫（比例由同一張圖決定）
  const sofaRest = rest && man[`sofa_rest_${look}`] ? `sofa_rest_${look}` : null
  return (layout[scene] as { id: string; x: number; y: number; anim?: string }[])
    .filter((p) => !skip.includes(p.id) && !(sofaRest && p.id === 'hero_lying'))
    .map((p) =>
      sofaRest && p.id === 'sofa' ? { ...man[sofaRest], ...p, id: sofaRest, y: p.y + man.sofa.h - man[sofaRest].h } : heroOf(look, p),
    )
}

const SCENES = Object.fromEntries(
  (['a', 'b'] as Look[]).map((k) => [k, { room: placements('room', k, [], true), empty: placements('room', k, ['hero_lying']), street: placements('street', k) }]),
) as Record<Look, { room: SpritePlacement[]; empty: SpritePlacement[]; street: SpritePlacement[] }>
const ROOM_FX = layout.room_fx as SceneFx[]
const STREET_FX = layout.street_fx as SceneFx[]

/** 有專屬背景圖的節點類型（public/sprites/node_*.png，由 art_src/build_nodes.py 產生）。 */
export const NODE_BG = ['job', 'elite', 'event', 'market', 'clinic', 'rest'] as const
export type NodeBg = (typeof NODE_BG)[number]
/** 有自己一套節點背景的街區（檔名 node_<街區>_<類型>.png）；其他街區用新宿的（node_<類型>.png）。 */
const DISTRICT_BG = ['wangan', 'akihabara'] // ponytail: akihabara 圖已生好，街區還沒做

/** 有專屬場景背景的劇情委託（public/sprites/story_<案件>.png）。下雨特效使用者說太爛，已拿掉（2026-11-06）。 */
export const STORY_BG = ['P01-01', 'P01-02', 'P01-03', 'P01-06']

/** 節點畫面：該節點（或劇情委託）的整張背景，主角站在中間偏左。 */
function nodeLayers(file: string, look: Look): SpritePlacement[] {
  return [{ id: 'bg', src: `/sprites/${file}.png`, w: 384, h: 160, x: 0, y: 0 }, heroOf(look, { id: 'hero_stand', x: 150, y: 76 })]
}

export function CityStrip({ mode, label, sub, bg, story, district = 'shinjuku', look = 'a', safehouse }: { mode: StripMode; label: string; sub?: string; bg?: NodeBg; story?: string; district?: string; look?: Look; safehouse?: boolean }) {
  const sc = SCENES[look]
  const file = safehouse ? 'safehouse' : story ? `story_${story}` : bg ? (DISTRICT_BG.includes(district) ? `node_${district}_${bg}` : `node_${bg}`) : null
  const layers = mode === 'node' && file ? nodeLayers(file, look) : mode === 'run' ? sc.street : mode === 'dead' ? sc.empty : sc.room
  return (
    <div className="cut cut-strong">
      <div className="cut-in relative overflow-hidden">
        <SpriteScene layers={layers} fx={mode === 'run' ? STREET_FX : mode === 'rest' ? ROOM_FX.filter((f) => look === 'a' || f.fx !== 'zz') : []} label={label} />
        {mode === 'dead' && <div className="pointer-events-none absolute inset-0 bg-bg/60" />}
        <div className="pointer-events-none absolute inset-x-0 top-0 flex items-start justify-between gap-2 bg-gradient-to-b from-bg/85 to-transparent px-2 pt-1 pb-3">
          <span className={`text-[13px] font-bold ${mode === 'dead' ? 'text-red' : mode === 'run' || mode === 'node' ? 'text-cyan' : 'text-heading'}`}>{label}</span>
          {sub && <span className="tech text-[13px] text-heading">{sub}</span>}
        </div>
      </div>
    </div>
  )
}
