import { Cpu, Dna, Package, Plus, ShieldPlus, Sparkles, Swords } from 'lucide-react'
import { Meter, Panel, PanelHead, Tabs } from '../components/ui'
import { useState, type ReactNode } from 'react'
import { type useGame, gearBusy, reduce } from '../game/state'
import { notify } from '../components/notice'
import { itemDesc, itemLock, itemStyle } from '../content/items'
import { type Look, hasLook } from '../components/CityStrip'
import {
  CALMER,
  CLINIC,
  REST,
  ATTRS,
  ATTR_EFFECT,
  ATTR_LABEL,
  ATTR_MAX,
  DIRECTION_LABEL,
  type Item,
  NEURAL_STAGE_LABEL,
  SEVERE_INJURY,
  SLOT_LABEL,
  STYLES,
  STYLE_EN,
  STYLE_LABEL,
  type Slot,
  capacityOf,
  fameToNext,
  fightStats,
  injuryLabel,
  itemMult,
  marginOf,
  neuralStage,
  neuralRisk,
  neuralTag,
  perkTally,
  sellValue,
  statChanges,
  xpToNext,
  LIFELINES,
  lifelineOf,
} from '../rules/core'
import { PERKS, fameTitle } from '../rules/perks'
import { CalmerButton, STYLE_COLOR, STYLE_ICON } from './Node'
import { ItemIcon } from '../components/ItemIcon'

export function CharacterScreen({ game }: { game: ReturnType<typeof useGame> }) {
  const { g, act } = game
  const c = g.character
  const [tab, setTab] = useState<'status' | 'gear' | 'attrs' | 'style'>('status')
  const busy = gearBusy(g)
  const cap = capacityOf(c)
  const margin = marginOf(c)
  const stage = neuralStage(margin)
  const st = fightStats(c)
  const severe = c.injury >= SEVERE_INJURY
  const tally = perkTally(c)
  const perkCount = Object.values(c.perks).reduce((a, b) => a + b, 0)
  return (
    <div className="space-y-3">
      <Panel innerClass="p-4">
        <div className="tech text-[13px] text-muted">MERC ID・{c.id.toUpperCase()}</div>
        <h1 className="my-0 text-[22px] font-bold text-heading">{c.name}</h1>
        <div className="text-[14px] text-warning">{fameTitle(c.fame.level)}</div>
        <div className="mt-1 flex items-center gap-2 text-[14px] text-muted">
          外觀
          {(['a', 'b'] as Look[]).map((k) => (
            <button
              key={k}
              disabled={!hasLook(k) || !c.alive}
              onClick={() => act({ t: 'setLook', look: k })}
              className={`min-h-11 border px-3 ${(c.look ?? 'a') === k ? 'border-red font-bold text-red' : 'border-line/70 text-fg'} disabled:opacity-50`}
            >
              {k === 'a' ? '女' : '男'}
            </button>
          ))}
        </div>
        <div className="mt-2 space-y-2">
          <Meter label={`等級 Lv.${c.level}（升級給屬性點）`} value={c.xp} max={xpToNext(c.level)} />
          <Meter label={`名聲 Lv.${c.fame.level}（升級挑一張卡）`} value={c.fame.xp} max={fameToNext(c.fame.level)} tone="warning" />
          <Meter label={`傷勢・${injuryLabel(c.injury)}`} value={c.injury} max={100} tone={severe ? 'red' : 'warning'} text={`${c.injury}%`} />
        </div>
        <div className="mt-2 flex items-center gap-2 text-[14px] text-muted">
          <Swords size={14} className="shrink-0 text-line" />
          <span>
            HP <b className="tech text-heading">{st.hp}/{st.maxHp}</b>・攻擊 <b className="tech text-heading">{st.atk}</b>・命中 <b className="tech text-heading">{Math.round(st.hit * 100)}%</b>・護甲{' '}
            <b className="tech text-heading">{st.armor}</b>・爆擊 <b className="tech text-heading">{Math.round(st.crit * 100)}%×{st.critDmg.toFixed(1)}</b>
          </span>
          {!st.weapon && <span className="text-warning">（沒有武器）</span>}
        </div>
      </Panel>

      <Tabs
        value={tab}
        onChange={setTab}
        items={[
          { id: 'status', label: '狀態' },
          { id: 'gear', label: '裝備', badge: c.stash.length },
          { id: 'attrs', label: '屬性', badge: c.attrPoints },
          { id: 'style', label: '流派', badge: c.picks.length },
        ]}
      />

      {tab === 'status' && (
        <>
          <Panel innerClass="pb-3">
            <PanelHead icon={<Cpu size={16} />} title="神經負荷" right={<span className={stage === 'stable' ? 'text-positive' : 'font-bold text-warning'}>{NEURAL_STAGE_LABEL[stage]}</span>} />
            <div className="space-y-2 px-3 pt-2">
              <Meter label="抗性容量（隨等級、技術與卡牌提升）" value={cap} max={cap} text={String(cap)} />
              <Meter label="義體負荷" value={c.implantLoad} max={cap} tone="warning" />
              <Meter label="神經壓力" value={c.stress} max={cap} tone="red" />
              <p className="m-0 text-[14px] text-muted">
                安全餘裕 = 容量 − 負荷 − 壓力 = <b className="tech text-heading">{margin}</b>。40 以上穩定、20～39 警戒、1～19 臨界、0 以下失控。降壓力：休息節點（斷線靜養 −{REST.calm}，或睡覺、躲起來各 −{REST.stress}）、神機醫（縫傷口 −{CLINIC.stress}、神經調校 ¢{CLINIC.tunePrice} −{CLINIC.tune}）、黑市的鎮定劑（−{CALMER.stress}，隨時能用）。
              </p>
              {c.calmers ? <CalmerButton game={game} /> : null}
            </div>
          </Panel>
          <Panel innerClass="p-3 space-y-1 text-[15px]">
            <div className="flex items-center gap-2 font-bold text-heading">
              <ShieldPlus size={16} className="text-cyan" /> 救命保單 {lifelineOf(c) ? LIFELINES[lifelineOf(c)!].label : '沒有'}
            </div>
            <p className="m-0 text-fg">{lifelineOf(c) ? `受致命傷時武裝醫療隊救你一次，救回來：${LIFELINES[lifelineOf(c)!].desc}。用掉就沒了，最多持有一張。` : '沒有保單：受致命傷就是永久死亡。黑市買得到（廉價、標準、白金三種，越貴救回來失去的越少）。'}</p>
            <p className="m-0 text-[14px] text-muted">通緝 {c.heat}★：每顆星讓對手 HP 與攻擊 +8%。休息節點可以躲起來降通緝。</p>
          </Panel>
        </>
      )}

      {tab === 'attrs' && (
        <Panel innerClass="pb-2">
          <PanelHead
            icon={<Dna size={16} />}
            title="屬性"
            right={<span className={c.attrPoints ? 'font-bold text-red' : 'text-[13px] text-muted'}>{c.attrPoints ? `可分配 ${c.attrPoints} 點` : '升級時 +1 點'}</span>}
          />
          {ATTRS.map((a) => (
            <div key={a} className="flex items-center gap-3 border-b border-line/40 px-3 py-2">
              <div className="min-w-0 flex-1">
                <div className="flex items-baseline gap-2">
                  <b className="text-fg-list">{ATTR_LABEL[a]}</b>
                  <span className="tech text-[18px] text-heading">{c.attrs[a]}</span>
                  {c.scars?.[a] ? <span className="text-[13px] font-bold text-red">舊傷 −{c.scars[a]}</span> : null}
                </div>
                <div className="text-[13px] text-muted">{ATTR_EFFECT[a]}</div>
              </div>
              {c.attrPoints > 0 && c.alive && (
                <button
                  aria-label={`提升${ATTR_LABEL[a]}`}
                  disabled={c.attrs[a] >= ATTR_MAX}
                  onClick={() => {
                    const next = reduce(g, { t: 'raiseAttr', attr: a }).character
                    act({ t: 'raiseAttr', attr: a })
                    const lines = statChanges(c, next)
                    notify({ title: `${ATTR_LABEL[a]} ${c.attrs[a]}→${next.attrs[a]}`, lines })
                  }}
                  className="flex size-11 shrink-0 items-center justify-center border border-cyan text-cyan disabled:opacity-40"
                >
                  <Plus size={18} />
                </button>
              )}
            </div>
          ))}
          <p className="m-0 px-3 pt-2 text-[13px] text-muted">屬性分配後不能退回。起始每項 3，上限 {ATTR_MAX}。</p>
        </Panel>
      )}

      {tab === 'style' && (
        <Panel innerClass="pb-2">
          <PanelHead icon={<Sparkles size={16} />} title="流派" right={<span className="text-[13px] text-muted">卡牌 {perkCount} 張</span>} />
          <div className="grid grid-cols-2 gap-2 px-3 pt-2">
            {STYLES.map((d) => {
              const Icon = STYLE_ICON[d]
              return (
                <div key={d} className="flex items-center gap-1.5 border border-line/60 px-2 py-1.5 text-[14px]">
                  <Icon size={14} className="shrink-0" style={{ color: STYLE_COLOR[d] }} />
                  <span className="min-w-0 flex-1 leading-tight">
                    {STYLE_LABEL[d]}
                    <span className="tech block text-[11px] text-muted">{STYLE_EN[d]}</span>
                  </span>
                  <b className="tech text-heading">{tally[d]}</b>
                </div>
              )
            })}
          </div>
          {perkCount === 0 && <p className="m-0 px-3 py-3 text-muted">還沒有卡牌。做委託、事件、劇情累積名聲，每升一級可以從三張卡裡挑一張。</p>}
          {Object.entries(c.perks).map(([id, lv]) => {
            const d = PERKS[id]
            return (
              <div key={id} className="flex items-center gap-2 border-b border-line/40 px-3 py-2">
                <div className="min-w-0 flex-1">
                  <b className="text-fg-list">{d.name}</b>
                  <span className="ml-2 text-[13px]" style={{ color: d.style === 'any' ? undefined : STYLE_COLOR[d.style] }}>{d.style === 'any' ? '通用' : STYLE_LABEL[d.style]}</span>
                  <div className="text-[13px] text-cyan">
                    {d.desc}
                    {lv > 1 ? ` ×${lv}` : ''}
                  </div>
                </div>
                <span className="tech text-heading">
                  Lv.{lv}/{d.max}
                </span>
              </div>
            )
          })}
          <p className="m-0 px-3 pt-2 text-[13px] text-muted">卡牌只屬於這段生涯，死亡或退休後不會帶走。拿得越多的流派越常出現；主流派有 2 張以上後，每次三選一都至少有一張，也至少有一張別的。</p>
        </Panel>
      )}

      {tab === 'gear' && (
        <Panel innerClass="pb-2">
          <PanelHead icon={<Package size={16} />} title="裝備" right={<span className={`text-[13px] ${stage === 'stable' ? 'text-muted' : 'text-red'}`}>神經餘裕 {margin}</span>} />
          {(['weapon', 'deck', 'implant'] as Slot[]).flatMap((slot) => {
            const worn = c.equipment.filter((i) => i.slot === slot)
            if (!worn.length) return [<ItemRow key={slot} slot={slot} />]
            return worn.map((it) => (
              <ItemRow key={it.id} slot={slot} item={it}>
                <SmallButton disabled={busy} onClick={() => act({ t: 'unequip', itemId: it.id })}>
                  卸下
                </SmallButton>
              </ItemRow>
            ))
          })}
          {c.stash.length > 0 && <div className="px-3 pt-2 text-[13px] font-bold text-heading">背包</div>}
          {c.stash.map((it) => {
            const lock = itemLock(c, it)
            const after = it.slot === 'implant' ? { ...c, implantLoad: c.implantLoad + it.load } : c
            const risk = neuralRisk(after)
            const note = lock ?? (it.slot === 'implant' ? `裝上後神經餘裕 ${marginOf(after)}${risk ? `・${neuralTag(after)}：任務裡要擲錯亂骰` : ''}` : undefined)
            return (
              <ItemRow key={it.id} slot={it.slot} item={it} note={note} bad={!!lock || risk}>
                <SmallButton disabled={busy || !!lock} onClick={() => act({ t: 'equip', itemId: it.id })}>
                  裝上
                </SmallButton>
              </ItemRow>
            )
          })}
          <p className="m-0 px-3 pt-2 text-[13px] text-muted">
            義體想裝多少都可以：神經餘裕＝神經容量 {cap} − 義體負荷 {c.implantLoad} − 神經壓力 {c.stress}。餘裕低於 40，任務裡的錯亂規則一階比一階重：警戒時硬撐的壓力加重、臨界時硬撐後要擲錯亂骰、失控時每個場面先擲錯亂骰（可能中斷並擲致命判定）。重武器與高階義體有屬性門檻。背包和身上的裝備都可以在黑市賣掉（售價 40%，義體當場拆）。{busy ? '節點進行中不能換裝。' : ''}
          </p>
        </Panel>
      )}
    </div>
  )
}

function SmallButton({ children, disabled, onClick }: { children: ReactNode; disabled?: boolean; onClick: () => void }) {
  return (
    <button onClick={onClick} disabled={disabled} className={`min-h-11 shrink-0 border px-3 text-[14px] font-bold ${disabled ? 'border-line/50 text-muted' : 'border-cyan text-cyan'}`}>
      {children}
    </button>
  )
}

function ItemRow({ slot, item, note, bad = true, children }: { slot: Slot; item?: Item; note?: string; bad?: boolean; children?: ReactNode }) {
  return (
    <div className="flex items-center gap-2 border-b border-line/40 px-3 py-2">
      {item && <ItemIcon item={item} />}
      <div className="min-w-0 flex-1">
        <div className="text-[13px] text-muted">
          {SLOT_LABEL[slot]}
          {item && itemStyle(item) ? `・${STYLE_LABEL[itemStyle(item)!]}` : ''}
        </div>
        {item ? (
          <>
            <b className="text-fg-list">
              {item.name}
              {(item.level ?? 1) > 1 && <span className="tech ml-1 text-heading">Lv.{item.level}（效果 ×{itemMult(item)}）</span>}
            </b>
            <div className="text-[13px] text-cyan">
              {[itemDesc(item), item.bonus ? `${DIRECTION_LABEL[item.direction]}委託 +${Math.round(item.bonus * itemMult(item) * 100)}%` : '', item.load ? `負荷 ${item.load}` : '']
                .filter(Boolean)
                .filter((t, i, xs) => xs.indexOf(t) === i)
                .join('・')}
            </div>
            <div className="text-[13px] text-muted">黑市收購 ¢{sellValue(item)}</div>
            {note && <div className={`text-[13px] ${bad ? 'text-warning' : 'text-muted'}`}>{bad ? '✖ ' : ''}{note}</div>}
          </>
        ) : (
          <div className="text-muted">— 空 —</div>
        )}
      </div>
      {children}
    </div>
  )
}
