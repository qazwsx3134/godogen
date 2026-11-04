import { Activity, Cpu, Package, ShieldPlus, Stethoscope } from 'lucide-react'
import { ActionButton, Meter, Panel, PanelHead } from '../components/ui'
import type { useGame } from '../game/state'
import { DIRECTION_LABEL, type Direction, NEURAL_STAGE_LABEL, PROF_MAX, SLOT_LABEL, type Slot, neuralCapacity, neuralMargin, neuralStage, pawnValue, xpToNext } from '../rules/core'
import { DIR_ICON } from './Jobs'

export function CharacterScreen({ game }: { game: ReturnType<typeof useGame> }) {
  const { g, act } = game
  const c = g.character
  const cap = neuralCapacity(c.level)
  const margin = neuralMargin(c.level, c.implantLoad, c.stress)
  const stage = neuralStage(margin)
  const treatCost = c.injury * 6
  return (
    <div className="space-y-3">
      <Panel innerClass="p-4">
        <div className="tech text-[13px] text-muted">MERC ID・{c.id.toUpperCase()}</div>
        <h1 className="my-0 text-[22px] font-bold text-heading">{c.name}</h1>
        <div className="mt-2 space-y-2">
          <Meter label={`等級 Lv.${c.level}`} value={c.xp} max={xpToNext(c.level)} />
          <Meter label="傷勢" value={c.injury} max={100} tone={c.injury >= 60 ? 'red' : 'warning'} text={`${c.injury}%`} />
        </div>
      </Panel>

      <Panel innerClass="pb-2">
        <PanelHead icon={<Package size={16} />} title="裝備" right={<span className="text-[13px] text-muted">抵押價＝售價 60%</span>} />
        {(['weapon', 'deck', 'implant'] as Slot[]).map((slot) => {
          const it = c.equipment.find((i) => i.slot === slot)
          const pw = c.pawned.find((p) => p.item.slot === slot)
          return (
            <div key={slot} className="border-b border-line/40 px-3 py-2">
              <div className="text-[13px] text-muted">{SLOT_LABEL[slot]}</div>
              {it ? (
                <div className="flex items-center gap-2">
                  <b className="flex-1 text-fg-list">{it.name}</b>
                  <span className="text-[13px] text-cyan">{DIRECTION_LABEL[it.direction]} +{Math.round(it.bonus * 100)}%</span>
                  {it.load > 0 && <span className="text-[13px] text-warning">負荷 {it.load}</span>}
                </div>
              ) : (
                <div className="text-muted">— 空 —</div>
              )}
              {it && <div className="text-[13px] text-muted">售價 ¢{it.price}・抵押價 ¢{pawnValue(it)}</div>}
              {pw && (
                <div className="mt-2 flex items-center gap-2 border border-warning/70 p-2">
                  <span className="flex-1 text-[14px] text-warning">抵押中：{pw.item.name}</span>
                  <button
                    onClick={() => act({ t: 'redeem', itemId: pw.item.id })}
                    disabled={c.credits < pw.redeem || !c.alive}
                    className={`min-h-11 border px-3 text-[14px] font-bold ${c.credits < pw.redeem ? 'border-line/50 text-muted' : 'border-cyan text-cyan'}`}
                  >
                    贖回 ¢{pw.redeem}
                  </button>
                </div>
              )}
            </div>
          )
        })}
      </Panel>

      <Panel innerClass="pb-3">
        <PanelHead icon={<Cpu size={16} />} title="神經負荷" right={<span className={stage === 'stable' ? 'text-positive' : 'font-bold text-warning'}>{NEURAL_STAGE_LABEL[stage]}</span>} />
        <div className="space-y-2 px-3 pt-2">
          <Meter label="抗性容量（隨等級提升）" value={cap} max={cap} text={String(cap)} />
          <Meter label="義體負荷" value={c.implantLoad} max={cap} tone="warning" />
          <Meter label="神經壓力" value={c.stress} max={cap} tone="red" />
          <p className="m-0 text-[14px] text-muted">
            安全餘裕 = 容量 − 負荷 − 壓力 = <b className="tech text-heading">{margin}</b>。40 以上穩定、20～39 警戒、1～19 臨界、0 以下失控。
          </p>
        </div>
      </Panel>

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

      <Panel innerClass="p-3 space-y-2">
        <div className="flex items-center gap-2 font-bold text-heading">
          <ShieldPlus size={16} className="text-cyan" /> 武裝醫療保單
        </div>
        <p className="m-0 text-[15px]">
          {g.coverage.active ? (
            <span className="text-positive">有效：覆蓋新宿街區，預估 {g.coverage.etaMin} 分鐘抵達。只能在死亡前救人；出勤帳單付不起時先抵押裝備，抵押不夠就不出勤。</span>
          ) : (
            <span className="text-red">沒有保單。受致命傷時不會有人來。</span>
          )}
        </p>
        <ActionButton disabled={g.coverage.active || c.credits < 400 || !c.alive} reason={g.coverage.active ? '已投保' : '信用點不足 400'} onClick={() => act({ t: 'buyCoverage' })}>
          購買基本保單（¢400）
        </ActionButton>
        <ActionButton disabled={c.injury === 0 || c.credits < treatCost || !c.alive} reason={c.injury === 0 ? '沒有傷' : `需要 ¢${treatCost}`} onClick={() => act({ t: 'treat' })}>
          <Stethoscope size={16} /> 到白蛇的診所治療（¢{treatCost}）
        </ActionButton>
      </Panel>
    </div>
  )
}
