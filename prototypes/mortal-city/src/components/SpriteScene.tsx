// 用多張 sprite 圖片組裝場景：每張圖依版面資料放在 384×160 的像素座標上，放大顯示並保持像素銳利。
// 先做靜態組裝；動畫之後再加（例如 x 隨時間捲動、換格）。
export const SCENE_W = 384
export const SCENE_H = 160

export interface SpritePlacement {
  id: string
  src: string // public/ 下的路徑
  x: number
  y: number
  w: number // sprite 原始像素尺寸
  h: number
  flip?: boolean
}

export function SpriteScene({ layers, label }: { layers: SpritePlacement[]; label: string }) {
  return (
    <div className="relative w-full overflow-hidden bg-bg" style={{ aspectRatio: `${SCENE_W} / ${SCENE_H}` }} role="img" aria-label={label}>
      {layers.map((l) => (
        <img
          key={l.id}
          src={l.src}
          alt=""
          draggable={false}
          className="absolute select-none"
          style={{
            left: `${(l.x / SCENE_W) * 100}%`,
            top: `${(l.y / SCENE_H) * 100}%`,
            width: `${(l.w / SCENE_W) * 100}%`,
            height: `${(l.h / SCENE_H) * 100}%`,
            imageRendering: 'pixelated',
            transform: l.flip ? 'scaleX(-1)' : undefined,
          }}
        />
      ))}
    </div>
  )
}
