// 城市分頁的橫向場景欄：休息時在公寓沙發上，出任務時在東京風的屋頂上奔跑（參考 taskbar-hero 的行軍橫幅）。
// 由多張 sprite 圖片依 src/content/scene_layout.json 組裝；動畫用 CSS（版面資料的 anim 與 *_fx）。
// 程式手繪的舊版在 src/pixel/（保留，用途另定）。
import layout from '../content/scene_layout.json'
import sprites from '../content/sprites.json'
import { type SceneFx, type SpritePlacement, SpriteScene } from './SpriteScene'

export type StripMode = 'rest' | 'run' | 'dead'

type Man = Record<string, { src: string; w: number; h: number }>

/** 主角外觀：a＝女主角 A、b＝男主角 B。B 的圖還沒做好時（sprites.json 沒有 hero_b_*）用 A 的。 */
export type Look = 'a' | 'b'
export const hasLook = (look: Look) => look === 'a' || 'hero_b_lying' in (sprites as object)

function placements(scene: 'room' | 'street', look: Look, skip: string[] = [], rest = false): SpritePlacement[] {
  const man = sprites as unknown as Man
  // 休息：有「沙發＋人」的整張就用它取代沙發，原本的躺姿不畫
  const sofaRest = rest && man[`sofa_rest_${look}`] ? `sofa_rest_${look}` : null
  return (layout[scene] as { id: string; x: number; y: number; anim?: string }[])
    .filter((p) => !skip.includes(p.id) && !(sofaRest && p.id === 'hero_lying'))
    .map((p) => {
      if (sofaRest && p.id === 'sofa') return { ...man[sofaRest], ...p, id: sofaRest, y: p.y + man.sofa.h - man[sofaRest].h }
      const alt = look === 'b' && p.id.startsWith('hero_') ? p.id.replace('hero_', 'hero_b_') : p.id
      if (alt === p.id || !man[alt]) return { ...man[p.id], ...p }
      // 換成 B：底邊對齊 A 的位置（躺在同一張沙發、踩在同一條線上）
      return { ...man[alt], ...p, id: alt, y: p.y + man[p.id].h - man[alt].h }
    })
}

const SCENES = Object.fromEntries(
  (['a', 'b'] as Look[]).map((k) => [k, { room: placements('room', k, [], true), empty: placements('room', k, ['hero_lying']), street: placements('street', k) }]),
) as Record<Look, { room: SpritePlacement[]; empty: SpritePlacement[]; street: SpritePlacement[] }>
const ROOM_FX = layout.room_fx as SceneFx[]
const STREET_FX = layout.street_fx as SceneFx[]

export function CityStrip({ mode, label, sub, look = 'a' }: { mode: StripMode; label: string; sub?: string; look?: Look }) {
  const sc = SCENES[look]
  const layers = mode === 'run' ? sc.street : mode === 'dead' ? sc.empty : sc.room
  return (
    <div className="cut cut-strong">
      <div className="cut-in relative overflow-hidden">
        <SpriteScene layers={layers} fx={mode === 'run' ? STREET_FX : mode === 'rest' ? ROOM_FX.filter((f) => look === 'a' || f.fx !== 'zz') : []} label={label} />
        {mode === 'dead' && <div className="pointer-events-none absolute inset-0 bg-bg/60" />}
        <div className="pointer-events-none absolute inset-x-0 top-0 flex items-start justify-between gap-2 bg-gradient-to-b from-bg/85 to-transparent px-2 pt-1 pb-3">
          <span className={`text-[13px] font-bold ${mode === 'dead' ? 'text-red' : mode === 'run' ? 'text-cyan' : 'text-heading'}`}>{label}</span>
          {sub && <span className="tech text-[13px] text-heading">{sub}</span>}
        </div>
      </div>
    </div>
  )
}
