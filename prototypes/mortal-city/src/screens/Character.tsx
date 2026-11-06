import { ActionButton, Meter, Panel, PanelHead, Tabs } from '../components/ui'
import { useState, type ReactNode } from 'react'
import { type useGame, gearBusy } from '../game/state'
import { ITEMS, PROVENANCE, SHOPS, type Shop, itemDesc, shopPrice } from '../content/items'
import { FIXERS } from '../content/data'
import { type Look, hasLook } from '../components/CityStrip'
import { Activity, BedDouble, Cpu, Dna, Hospital, IconFence, IconTalent, Package, Plus, ShieldPlus, Stethoscope, Swords } from '../components/icons'
import { ATTRS, ATTR_EFFECT, ATTR_LABEL, ATTR_MAX, CLINIC, DIRECTION_LABEL, type Direction, HOSPITAL, NEURAL_STAGE_LABEL, PROF_MAX, REST, SEVERE_INJURY, SLOT_LABEL, type Slot, capacityOf, IMPLANT_RESERVE, type Item, implantRoom, powerOf, POLICIES, PLATINUM, policyOf, TALENTS, talentLock, hasTalent, sellValue, fightStats, injuryLabel, marginOf, neuralStage, pawnValue, xpToNext } from '../rules/core'
import { BackBar, DIR_ICON } from './Jobs'

export function CharacterScreen({ game }: { game: ReturnType<typeof useGame> }) {
  const { g, act } = game
  const c = g.character
  const [shop, setShop] = useState<Shop | null>(null)
  const [tab, setTab] = useState<'status' | 'gear' | 'attrs' | 'talent'>('status')
  const room = implantRoom(c)
  const busy = gearBusy(g)
  if (shop) return <ShopScreen game={game} shop={shop} onBack={() => setShop(null)} />
  const cap = capacityOf(c)
  const margin = marginOf(c)
  const stage = neuralStage(margin)
  const treatCost = c.injury * CLINIC.perPoint
  const hospitalCost = c.injury * HOSPITAL.perPoint
  const st = fightStats(c)
  const pol = policyOf(g.coverage)
  const severe = c.injury >= SEVERE_INJURY
  // 重傷那段（≥70）用慢速，其餘用一般速度
  const restMin = Math.ceil((Math.max(0, c.injury - SEVERE_INJURY + 1) * REST.severeMsPerPoint + Math.min(c.injury, SEVERE_INJURY - 1) * REST.msPerPoint) / 60_000)
  return (
    <div className="space-y-3">
      <Panel innerClass="p-4">
        <div className="tech text-[13px] text-muted">MERC ID・{c.id.toUpperCase()}</div>
        <h1 className="my-0 text-[22px] font-bold text-heading">{c.name}</h1>
        <div className="mt-1 flex items-baseline gap-4">
          <span className="text-[14px] text-muted">
            戰力 <b className="tech text-[22px] text-cyan">{powerOf(c)}</b>
          </span>
          <span className="text-[14px] text-muted">
            街頭名聲 <b className="tech text-[18px] text-heading">{c.fame}</b>
          </span>
        </div>
        <div className="mt-1 flex items-center gap-2 text-[14px] text-muted">
          外觀
          {(['a', 'b'] as Look[]).map((k) => {
            const on = (c.look ?? 'a') === k
            const ready = hasLook(k)
            return (
              <button
                key={k}
                disabled={!ready || !c.alive}
                onClick={() => act({ t: 'setLook', look: k })}
                className={`min-h-11 border px-3 ${on ? 'border-red font-bold text-red' : 'border-line/70 text-fg'} disabled:opacity-50`}
              >
                {k === 'a' ? '女' : '男'}
                {!ready && <span className="ml-1 text-[11px]">（圖製作中）</span>}
              </button>
            )
          })}
        </div>
        <p className="mt-0 mb-1 text-[12px] text-muted">戰力看攻擊、命中、爆擊、HP 與護甲（滿血時）；名聲只從做成的任務累積，不算進戰力。</p>
        <div className="mt-2 space-y-2">
          <Meter label={`等級 Lv.${c.level}`} value={c.xp} max={xpToNext(c.level)} />
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
          { id: 'talent', label: '天賦', badge: c.talentPoints },
        ]}
      />

      {tab === 'status' && (
      <Panel tone={severe ? 'red' : 'line'} innerClass="p-3 space-y-2">
        <div className="flex items-center gap-2 font-bold text-heading">
          <Stethoscope size={16} className="text-cyan" /> 治療
          <span className={`ml-auto text-[14px] ${severe ? 'text-red' : 'text-muted'}`}>
            {injuryLabel(c.injury)}・傷勢 {c.injury}%
          </span>
        </div>
        {severe && <p className="m-0 border border-red/70 p-2 text-[14px] text-red">重傷：不能接任何工作（排隊、劇情、高階）。先休養或治療到 {SEVERE_INJURY}% 以下。</p>}
        <div className="flex gap-2 border border-line/60 p-2 text-[14px]">
          <BedDouble size={16} className="mt-0.5 shrink-0 text-line" />
          <span>
            <b className="text-fg-list">在公寓休養（免費）</b>：沒排隊、沒委託時自動恢復，每分鐘 −1%（重傷時每 2 分鐘 −1%）；每 30 分鐘通緝 −1★。
            {c.injury > 0 && <span className="text-muted"> 照現在約 {restMin} 分鐘痊癒。</span>}
          </span>
        </div>
        <ActionButton disabled={c.injury === 0 || c.credits < treatCost || !c.alive} reason={c.injury === 0 ? '沒有傷' : `需要 ¢${treatCost}`} onClick={() => act({ t: 'treat' })}>
          <Stethoscope size={16} /> 白蛇的地下診所：馬上縫好（¢{treatCost}，壓力 −{CLINIC.stress}）
        </ActionButton>
        <ActionButton
          disabled={(c.injury === 0 && c.stress === 0) || c.credits < hospitalCost || c.heat > HOSPITAL.maxHeat || !c.alive}
          reason={c.heat > HOSPITAL.maxHeat ? `通緝 ${c.heat}★：醫院會通報 MPD，先休養讓通緝降到 ${HOSPITAL.maxHeat}★` : c.injury === 0 && c.stress === 0 ? '沒有傷' : `需要 ¢${hospitalCost}`}
          onClick={() => act({ t: 'hospital' })}
        >
          <Hospital size={16} /> 魔都綜合醫院：完整治療（¢{hospitalCost}，壓力 −{HOSPITAL.stress}）
        </ActionButton>
        <p className="m-0 text-[13px] text-muted">診所便宜、不問來歷；醫院貴、會查身分，但連神經壓力一起處理。</p>
      </Panel>
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
              </div>
              <div className="text-[13px] text-muted">{ATTR_EFFECT[a]}</div>
            </div>
            {c.attrPoints > 0 && c.alive && (
              <button
                aria-label={`提升${ATTR_LABEL[a]}`}
                disabled={c.attrs[a] >= ATTR_MAX}
                onClick={() => act({ t: 'raiseAttr', attr: a })}
                className="flex size-11 shrink-0 items-center justify-center border border-cyan text-cyan disabled:opacity-40"
              >
                <Plus size={18} />
              </button>
            )}
          </div>
        ))}
        <p className="m-0 px-3 pt-2 text-[13px] text-muted">屬性是角色的打造，分配後不能退回；熟練度則是做哪一類工作就練哪一類。起始每項 3，上限 {ATTR_MAX}。</p>
      </Panel>
      )}

      {tab === 'talent' && (
      <Panel innerClass="pb-2">
        <PanelHead
          icon={<IconTalent size={16} />}
          title="天賦"
          right={<span className={c.talentPoints ? 'font-bold text-red' : 'text-[13px] text-muted'}>{c.talentPoints ? `技能點 ${c.talentPoints}` : '升級時 +1 點'}</span>}
        />
        <div className="grid grid-cols-3 gap-2 px-3 pt-3">
          {(['force', 'hack', 'stealth'] as Direction[]).map((d) => {
            const Icon = DIR_ICON[d]
            return (
              <div key={d} className="min-w-0 space-y-2">
                <div className="flex items-center gap-1 text-[13px] font-bold text-heading">
                  <Icon size={14} className="text-line" /> {DIRECTION_LABEL[d]}
                </div>
                {TALENTS.filter((t) => t.branch === d).map((t) => {
                  const own = hasTalent(c, t.id)
                  const lock = talentLock(c, t.id)
                  return (
                    <button
                      key={t.id}
                      disabled={own || !!lock || !c.alive}
                      onClick={() => act({ t: 'learnTalent', id: t.id })}
                      className={`block w-full text-left ${own ? 'cut cut-sm cut-red' : 'cut cut-sm'} ${!own && lock ? 'opacity-60' : ''}`}
                    >
                      <div className="cut-in min-h-[88px] p-2">
                        <div className={`text-[14px] font-bold ${own ? 'text-red' : 'text-fg-list'}`}>{t.name}</div>
                        <div className="text-[12px] text-fg">{t.desc}</div>
                        <div className="text-[11px] text-muted">{own ? '✔ 已學會' : lock === '沒有技能點' ? '' : !lock ? '點一下學會' : lock}</div>
                      </div>
                    </button>
                  )
                })}
              </div>
            )
          })}
        </div>
        <p className="m-0 px-3 pt-2 text-[13px] text-muted">技能點跟屬性點分開，每升一級 +1。每一支要由上往下學，學了不能退回。</p>
      </Panel>
      )}

      {tab === 'gear' && (
      <Panel innerClass="pb-2">
        <PanelHead
          icon={<Package size={16} />}
          title="裝備"
          right={<span className={`text-[13px] ${room < 0 ? 'text-red' : 'text-muted'}`}>義體空間剩 {room}</span>}
        />
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
          const noRoom = it.slot === 'implant' && room < it.load
          return (
            <ItemRow key={it.id} slot={it.slot} item={it} note={noRoom ? `義體空間不夠（需要 ${it.load}）` : undefined}>
              <SmallButton disabled={busy || noRoom} onClick={() => act({ t: 'equip', itemId: it.id })}>
                裝上
              </SmallButton>
              <SmallButton disabled={!c.alive} onClick={() => act({ t: 'sell', itemId: it.id })}>
                賣 ¢{sellValue(it)}
              </SmallButton>
            </ItemRow>
          )
        })}
        {c.pawned.map((pw) => (
          <div key={pw.item.id} className="mx-3 mt-2 flex items-center gap-2 border border-warning/70 p-2">
            <span className="flex-1 text-[14px] text-warning">抵押中：{pw.item.name}</span>
            <SmallButton disabled={c.credits < pw.redeem || !c.alive} onClick={() => act({ t: 'redeem', itemId: pw.item.id })}>
              贖回 ¢{pw.redeem}
            </SmallButton>
          </div>
        ))}
        <p className="m-0 px-3 pt-2 text-[13px] text-muted">
          義體空間＝神經容量 {cap} − 保留 {IMPLANT_RESERVE} − 已裝負荷 {c.implantLoad}。技術與等級提高容量。抵押價＝售價 60%，賣掉＝40%。{busy ? '任務進行中不能換裝。' : ''}
        </p>
        <div className="px-3 pt-2">
          <div className="space-y-2">
            {SHOPS.map((sh) => {
              const lack = sh.trust && (c.trust[sh.fixerId] ?? 0) < sh.trust ? `要 ${FIXERS[sh.fixerId].name}的信任 ${sh.trust}（現在 ${c.trust[sh.fixerId] ?? 0}）` : undefined
              return (
                <ActionButton key={sh.id} disabled={busy || !c.alive || !!lack} reason={lack ?? (busy ? '任務進行中' : '角色已死亡')} onClick={() => setShop(sh)}>
                  {sh.install ? <Stethoscope size={16} /> : <IconFence size={16} />} {sh.name}
                </ActionButton>
              )
            })}
          </div>
        </div>
      </Panel>
      )}

      {tab === 'status' && (
      <Panel innerClass="pb-3">
        <PanelHead icon={<Cpu size={16} />} title="神經負荷" right={<span className={stage === 'stable' ? 'text-positive' : 'font-bold text-warning'}>{NEURAL_STAGE_LABEL[stage]}</span>} />
        <div className="space-y-2 px-3 pt-2">
          <Meter label="抗性容量（隨等級與技術提升）" value={cap} max={cap} text={String(cap)} />
          <Meter label="義體負荷" value={c.implantLoad} max={cap} tone="warning" />
          <Meter label="神經壓力" value={c.stress} max={cap} tone="red" />
          <p className="m-0 text-[14px] text-muted">
            安全餘裕 = 容量 − 負荷 − 壓力 = <b className="tech text-heading">{margin}</b>。40 以上穩定、20～39 警戒、1～19 臨界、0 以下失控。
          </p>
        </div>
      </Panel>
      )}

      {tab === 'attrs' && (
      <Panel innerClass="pb-2">
        <PanelHead icon={<Activity size={16} />} title="熟練度（上限 100）" />
        <div className="space-y-2 px-3 pt-2">
          {(['force', 'hack', 'stealth'] as Direction[]).map((d) => {
            const Icon = DIR_ICON[d]
            return (
              <div key={d} className="flex items-center gap-2">
                <Icon size={16} className="text-line" />
                <div className="flex-1">
                  <Meter label={DIRECTION_LABEL[d]} value={c.prof[d].level} max={PROF_MAX} text={`${c.prof[d].level}/${PROF_MAX}`} />
                </div>
              </div>
            )
          })}
        </div>
      </Panel>
      )}

      {tab === 'status' && (
      <Panel innerClass="p-3 space-y-2">
        <div className="flex items-center gap-2 font-bold text-heading">
          <ShieldPlus size={16} className="text-cyan" /> 武裝醫療保單
        </div>
        <p className="m-0 text-[15px]">
          {pol ? (
            <span className="text-positive">
              {pol.name}保單有效：{pol.note}，救援帳單 ¢{pol.bill}。出勤帳單付不起時先抵押裝備，抵押不夠就不出勤。
            </span>
          ) : (
            <span className="text-red">沒有保單。受致命傷時不會有人來。</span>
          )}
        </p>
        <div className="space-y-2">
          {POLICIES.map((p) => {
            const owned = !!pol && pol.tier >= p.tier
            const cost = p.price - (pol?.price ?? 0)
            return (
              <div key={p.tier} className={`flex items-center gap-2 border px-2 py-2 ${pol?.tier === p.tier ? 'border-positive' : p.tier === PLATINUM ? 'border-warning/70' : 'border-line/50'}`}>
                <div className="min-w-0 flex-1">
                  <b className={p.tier === PLATINUM ? 'text-warning' : 'text-fg-list'}>{p.name}</b>
                  <span className="ml-2 text-[13px] text-muted">帳單 ¢{p.bill}</span>
                  <div className="text-[13px] text-fg">{p.note}</div>
                </div>
                {owned ? (
                  <span className="shrink-0 text-[13px] text-positive">{pol!.tier === p.tier ? '目前' : '已涵蓋'}</span>
                ) : (
                  <SmallButton disabled={c.credits < cost || !c.alive} onClick={() => act({ t: 'buyCoverage', tier: p.tier })}>
                    {pol ? '升級' : '購買'} ¢{cost}
                  </SmallButton>
                )}
              </div>
            )
          })}
        </div>
      </Panel>
      )}

    </div>
  )
}

function SmallButton({ children, disabled, onClick }: { children: ReactNode; disabled?: boolean; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={`min-h-11 shrink-0 border px-3 text-[14px] font-bold ${disabled ? 'border-line/50 text-muted' : 'border-cyan text-cyan'}`}
    >
      {children}
    </button>
  )
}

function ItemRow({ slot, item, note, children }: { slot: Slot; item?: Item; note?: string; children?: ReactNode }) {
  return (
    <div className="flex items-center gap-2 border-b border-line/40 px-3 py-2">
      <div className="min-w-0 flex-1">
        <div className="text-[13px] text-muted">{SLOT_LABEL[slot]}</div>
        {item ? (
          <>
            <b className="text-fg-list">{item.name}</b>
            <div className="text-[13px] text-cyan">
              {[itemDesc(item), item.bonus ? `${DIRECTION_LABEL[item.direction]}工作 +${Math.round(item.bonus * 100)}%` : '', item.load ? `負荷 ${item.load}` : '']
                .filter(Boolean)
                .filter((t, i, xs) => xs.indexOf(t) === i)
                .join('・')}
            </div>
            <div className="text-[13px] text-muted">售價 ¢{item.price}・抵押價 ¢{pawnValue(item)}</div>
            {note && <div className="text-[13px] text-warning">✖ {note}</div>}
          </>
        ) : (
          <div className="text-muted">— 空 —</div>
        )}
      </div>
      {children}
    </div>
  )
}

function ShopScreen({ game, shop, onBack }: { game: ReturnType<typeof useGame>; shop: Shop; onBack: () => void }) {
  const { g, act } = game
  const c = g.character
  const room = implantRoom(c)
  return (
    <div className="space-y-3">
      <BackBar onBack={onBack} label="角色" />
      <Panel innerClass="p-4">
        <div className="tech text-[12px] text-red">// PROBABLY STOLEN・來源不明・不開收據</div>
        <h1 className="m-0 text-[20px] font-bold text-heading">{shop.name}</h1>
        <p className="mt-1 mb-0 text-fg">{shop.line}</p>
        <p className="mt-2 mb-0 text-[14px] text-muted">
          {shop.install ? (
            <>
              義體空間剩 <b className="tech text-heading">{room}</b>（神經容量 {capacityOf(c)} − 保留 {IMPLANT_RESERVE} − 已裝 {c.implantLoad}）。買了直接裝上；技術每點 +3 容量。
            </>
          ) : (
            '買了放進背包，到「裝備」裝上。價錢比行情貴兩成五：贓貨也要算風險。'
          )}
        </p>
      </Panel>
      <Panel innerClass="pb-1">
        {shop.kinds.map((kind, n) => {
          const d = ITEMS[kind]
          const price = shopPrice(shop, kind)
          const after = room - d.load
          const why = c.credits < price ? `需要 ¢${price}` : shop.install && after < 0 ? `義體空間不夠（還差 ${-after}）` : undefined
          return (
            <div key={kind} className="border-b border-line/40 px-3 py-3">
              <div className="tech flex items-center gap-2 text-[11px] text-muted">
                <span>LOT #{String(n + 1).padStart(3, '0')}・{SLOT_LABEL[d.slot]}</span>
                <span className="ml-auto -rotate-3 border border-red px-1 font-bold text-red">PROBABLY STOLEN</span>
              </div>
              <div className="mt-1 flex items-center gap-2">
                <div className="min-w-0 flex-1">
                  <b className="text-fg-list">{d.name}</b>
                  <div className="text-[14px] text-cyan">{d.desc || `${DIRECTION_LABEL[d.direction]}工作 +${Math.round(d.bonus * 100)}%`}</div>
                  <div className="text-[13px] text-muted">來歷：{PROVENANCE[kind]}</div>
                  {shop.install && (
                    <div className={`text-[13px] ${after < 0 ? 'text-warning' : 'text-muted'}`}>
                      負荷 {d.load}・裝上後空間剩 {after}
                    </div>
                  )}
                  {why && <div className="text-[13px] text-warning">✖ {why}</div>}
                </div>
                <SmallButton disabled={!!why || !c.alive} onClick={() => act({ t: 'buy', kind })}>
                  ¢{price}
                </SmallButton>
              </div>
            </div>
          )
        })}
      </Panel>
    </div>
  )
}
