// 城市分頁的橫向場景欄：休息時在公寓沙發上，出任務時在東京風的屋頂上奔跑（參考 taskbar-hero 的行軍橫幅）。
// 由多張 sprite 圖片依 src/content/scene_layout.json 組裝；動畫用 CSS（版面資料的 anim 與 *_fx）。
// 程式手繪的舊版在 src/pixel/（保留，用途另定）。
import layout from '../content/scene_layout.json'
import sprites from '../content/sprites.json'
import { type SceneFx, type SpritePlacement, SpriteScene } from './SpriteScene'

export type StripMode = 'rest' | 'run' | 'dead'

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

export function CityStrip({ mode, label, sub }: { mode: StripMode; label: string; sub?: string }) {
  const layers = mode === 'run' ? STREET : mode === 'dead' ? ROOM_EMPTY : ROOM
  return (
    <div className="cut cut-strong">
      <div className="cut-in relative overflow-hidden">
        <SpriteScene layers={layers} fx={mode === 'run' ? STREET_FX : mode === 'rest' ? ROOM_FX : ROOM_FX.filter((f) => f.fx === 'rain')} label={label} />
        {mode === 'dead' && <div className="pointer-events-none absolute inset-0 bg-bg/60" />}
        <div className="pointer-events-none absolute inset-x-0 top-0 flex items-start justify-between gap-2 bg-gradient-to-b from-bg/85 to-transparent px-2 pt-1 pb-3">
          <span className={`text-[13px] font-bold ${mode === 'dead' ? 'text-red' : mode === 'run' ? 'text-cyan' : 'text-heading'}`}>{label}</span>
          {sub && <span className="tech text-[13px] text-heading">{sub}</span>}
        </div>
      </div>
    </div>
  )
}
