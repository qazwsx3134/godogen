// 道具圖示：有像素圖就用（art_src/build_items.py 產生），沒有就用流派圖示＋流派色。
import { itemStyle } from '../content/items'
import ICONS from '../content/item_icons.json'
import type { Item } from '../rules/core'
import { DIR_ICON, STYLE_COLOR, STYLE_ICON } from '../screens/Node'

export function ItemIcon({ item, size = 40 }: { item: Item; size?: number }) {
  const src = item.kind ? (ICONS as Record<string, string>)[item.kind] : undefined
  const st = itemStyle(item)
  const color = st ? STYLE_COLOR[st] : 'var(--color-line)'
  if (src)
    return (
      <span className="grid shrink-0 place-items-center border bg-bg/60" style={{ width: size, height: size, borderColor: color }}>
        <img src={src} alt="" className="max-h-[85%] max-w-[85%]" style={{ imageRendering: 'pixelated' }} />
      </span>
    )
  const Icon = st ? STYLE_ICON[st] : DIR_ICON[item.direction]
  return (
    <span className="grid shrink-0 place-items-center border bg-bg/60" style={{ width: size, height: size, borderColor: color }}>
      <Icon size={size * 0.5} style={{ color }} />
    </span>
  )
}
