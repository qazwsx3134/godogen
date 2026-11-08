// 三選一視窗：名聲升級挑卡牌、掉寶挑道具。三個選項直向堆疊（360px 寬放不下橫排的中文說明）。
import { Package, Sparkles } from 'lucide-react'
import { Panel } from '../components/ui'
import { itemDesc, itemStyle } from '../content/items'
import type { useGame } from '../game/state'
import { DIRECTION_LABEL, SLOT_LABEL, STYLES, STYLE_LABEL, implantRoom, perkOptions, perkTally } from '../rules/core'
import { PERKS } from '../rules/perks'
import { STYLE_COLOR, STYLE_ICON } from './Node'
import { ItemIcon } from '../components/ItemIcon'

type G = ReturnType<typeof useGame>

export function PickDialog({ game }: { game: G }) {
  const { g, act } = game
  const c = g.character
  const p = c.picks[0]
  if (!p) return null
  const tally = perkTally(c)
  const more = c.picks.length - 1
  return (
    <div className="absolute inset-0 z-30 overflow-y-auto bg-bg/90 p-3" role="dialog" aria-label="三選一">
      <Panel tone="strong" innerClass="p-4 space-y-3">
        <div className="flex items-center gap-2 text-[18px] font-bold text-heading">
          {p.kind === 'perk' ? <Sparkles size={18} className="text-warning" /> : <Package size={18} className="text-cyan" />}
          <span className="flex-1">{p.kind === 'perk' ? `名聲 Lv.${p.level}・挑一張卡` : `戰利品・挑一件`}</span>
          {more > 0 && <span className="tech text-[13px] text-muted">還有 {more} 組</span>}
        </div>
        <p className="m-0 text-[14px] text-muted">
          {p.kind === 'perk'
            ? `卡牌是這段生涯的永久效果；同一張可以再拿來升級。你的流派：${STYLES.map((s) => `${STYLE_LABEL[s]} ${tally[s]}`).join('・')}（拿過的流派比較常出現）。`
            : `來自「${p.from}」。挑的那件放進背包，另外兩件就沒了。`}
        </p>
        {p.kind === 'perk'
          ? perkOptions(c, p.seed).map((id) => {
              const d = PERKS[id]
              const lv = c.perks[id] ?? 0
              const Icon = d.style === 'any' ? Sparkles : STYLE_ICON[d.style]
              const color = d.style === 'any' ? 'var(--color-line-strong)' : STYLE_COLOR[d.style]
              return (
                <button key={id} onClick={() => act({ t: 'pickPerk', id })} className={`block w-full text-left cut cut-sm ${d.rare ? 'cut-rare' : ''}`} style={{ ['--edge' as string]: color }}>
                  <div className="cut-in flex min-h-16 gap-3 p-3">
                    <Icon size={20} className="mt-0.5 shrink-0" style={{ color }} />
                    <div className="min-w-0 flex-1">
                      <div className="flex flex-wrap items-baseline gap-x-2">
                        <b className="text-[16px] text-fg-list">{d.name}</b>
                        <span className="text-[13px]" style={{ color: d.style === 'any' ? undefined : color }}>{d.instant ? '立刻生效' : d.style === 'any' ? '通用' : STYLE_LABEL[d.style]}</span>
                        {d.rare && <span className="text-[13px] font-bold text-red">稀有</span>}
                        {!d.instant && <span className="tech ml-auto text-[13px] text-heading">{lv ? `Lv.${lv} → ${lv + 1}` : 'NEW'}／{d.max}</span>}
                      </div>
                      <div className="text-[15px] text-fg">{d.desc}{!d.instant && lv ? `（再疊一層）` : ''}</div>
                    </div>
                  </div>
                </button>
              )
            })
          : p.options.map((it, i) => {
              const noRoom = it.slot === 'implant' && implantRoom(c) < it.load
              return (
                <button key={it.id} onClick={() => act({ t: 'pickItem', index: i })} className="block w-full text-left cut cut-sm" style={{ ['--edge' as string]: itemStyle(it) ? STYLE_COLOR[itemStyle(it)!] : undefined }}>
                  <div className="cut-in flex min-h-16 items-center gap-3 p-3">
                    <ItemIcon item={it} size={48} />
                    <div className="min-w-0 flex-1">
                      <div className="flex flex-wrap items-baseline gap-x-2">
                        <b className="text-[16px] text-fg-list">{it.name}</b>
                        <span className="text-[13px] text-muted">
                          {SLOT_LABEL[it.slot]}・{itemStyle(it) ? STYLE_LABEL[itemStyle(it)!] : DIRECTION_LABEL[it.direction]}
                        </span>
                      </div>
                      <div className="text-[15px] text-fg">
                        {[itemDesc(it), it.bonus ? `${DIRECTION_LABEL[it.direction]}委託 +${Math.round(it.bonus * 100)}%` : '', it.load ? `負荷 ${it.load}` : ''].filter(Boolean).filter((t, k, xs) => xs.indexOf(t) === k).join('・')}
                      </div>
                      {noRoom && <div className="text-[13px] text-warning">義體空間現在不夠，先放背包</div>}
                    </div>
                  </div>
                </button>
              )
            })}
      </Panel>
    </div>
  )
}
