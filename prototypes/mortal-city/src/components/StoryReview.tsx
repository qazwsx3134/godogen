// 劇情總覽：把主線（各街區的劇情委託→劇情大案）與支線（事件、一般委託）的全部文字攤開，方便檢查合不合理。
// 直接讀 content 模組，內容改了這裡就跟著變。
import { useState, type ReactNode } from 'react'
import { X } from 'lucide-react'
import { CASES, CASE_BY_ID, type CaseOption, type StoryCase } from '../content/cases'
import { DISTRICTS } from '../content/districts'
import { EVENT_BY_ID, type Effects } from '../content/events'
import { FIXERS, JOBS } from '../content/data'
import { ATTR_LABEL, DIRECTION_LABEL } from '../rules/core'
import { Panel } from './ui'

const who = (id: string) => FIXERS[id]?.name ?? id
const pct = (x: number) => `${Math.round(x * 100)}%`

function Lines({ xs }: { xs: string[] }) {
  return <>{xs.map((t, i) => <p key={i} className="m-0 whitespace-pre-line">{t}</p>)}</>
}

function Sec({ title, children, open }: { title: string; children: ReactNode; open?: boolean }) {
  return (
    <details open={open} className="border-l-2 border-line/60 pl-2">
      <summary className="min-h-9 cursor-pointer py-1 font-bold text-cyan">{title}</summary>
      <div className="space-y-1 pb-2">{children}</div>
    </details>
  )
}

function needText(o: CaseOption) {
  const n = o.needs
  const req = !n ? '' : 'slot' in n ? `要${n.label}` : `${ATTR_LABEL[n.attr]} ≥ ${n.min}`
  return [o.approach ? `限走「${o.approach}」` : '', req].filter(Boolean).join('・')
}

function CaseView({ sc, role }: { sc: StoryCase; role: string }) {
  const prev = sc.requires ? CASE_BY_ID[sc.requires] : undefined
  return (
    <Panel innerClass="p-3 space-y-2 text-[14px] leading-6">
      <div className="text-[13px] text-muted">
        {role}・{sc.id}・{who(sc.fixerId)}・{sc.zone}・{sc.posted}
      </div>
      <div className="text-[18px] font-bold text-heading">{sc.title}</div>
      {prev && <div className="text-[13px] text-warning">接續：{prev.title}（{prev.id}）</div>}
      <Sec title="委託內容" open>
        <Lines xs={[sc.body]} />
        {sc.variants &&
          Object.entries(sc.variants).map(([k, v]) => (
            <div key={k} className="border border-line/40 p-2">
              <div className="text-[13px] text-warning">前案{k === 'won' ? '冒險成功' : '其他結果'}時追加：</div>
              <Lines xs={[v]} />
            </div>
          ))}
      </Sec>
      <Sec title={`頻道回覆（${sc.replies.length}）`}>
        {sc.approachReplies &&
          Object.entries(sc.approachReplies).map(([k, r]) => (
            <p key={k} className="m-0">
              <span className="text-warning">[前案走 {k}]</span> <b>{who(r.who)}</b> {r.at}：{r.text}
            </p>
          ))}
        {sc.replies.map((r, i) => (
          <p key={i} className="m-0">
            <b>{who(r.who)}</b> <span className="tech text-muted">{r.at}</span>：{r.text}
          </p>
        ))}
      </Sec>
      {sc.approaches.map((a) => (
        <Sec key={a.id} title={`做法「${a.label}」（${a.id}・${DIRECTION_LABEL[a.direction]}）`}>
          <p className="m-0 text-muted">
            {a.summary}
            {a.needs ? `（${ATTR_LABEL[a.needs.attr]} ≥ ${a.needs.min}）` : ''}・傷勢 +{a.injury}%・致命修正 {a.lethalMod >= 0 ? '+' : ''}
            {pct(a.lethalMod)}
          </p>
          <Lines xs={a.autoLog} />
          {a.fight && <p className="m-0 text-red">⚔ {a.fight.name}（HP {a.fight.hp}・攻擊 {a.fight.atk}・防火牆 {a.fight.ice ?? 0}・感知 {a.fight.sense ?? 0}）</p>}
          {a.afterFight && <Lines xs={a.afterFight} />}
        </Sec>
      ))}
      <Sec title={`危險：${sc.danger.title}（${sc.danger.options.length} 個選項）`}>
        <Lines xs={[sc.danger.body]} />
        {sc.danger.options.map((o) => (
          <div key={o.id} className="border border-line/40 p-2">
            <div className="font-bold text-fg-list">▸ {o.label}</div>
            <div className="text-[13px] text-muted">
              {[needText(o), o.lethal ? (o.needs ? '致命判定・有備而來 +2 顆' : `致命判定・險度 ${pct(o.lethalBase)}`) : '不會死', `報酬 ¢${o.reward}`, o.heat ? `通緝 +${o.heat}` : '', o.fight ? `⚔ ${o.fight.name}` : '']
                .filter(Boolean)
                .join('・')}
            </div>
            <Lines xs={[o.text]} />
          </div>
        ))}
      </Sec>
      <Sec title="結案">
        <p className="m-0"><span className="text-muted">被救出時：</span>{sc.lossText}</p>
        {sc.broadcast && (
          <>
            <p className="m-0"><span className="text-muted">廣播（成功）：</span>{sc.broadcast.survived}</p>
            <p className="m-0"><span className="text-muted">廣播（其他）：</span>{sc.broadcast.other}</p>
          </>
        )}
      </Sec>
    </Panel>
  )
}

const fx = (e: Effects) =>
  [e.credits ? `¢${e.credits > 0 ? '+' : ''}${e.credits}` : '', e.injury ? `傷勢 ${e.injury > 0 ? '+' : ''}${e.injury}%` : '', e.heat ? `通緝 ${e.heat > 0 ? '+' : ''}${e.heat}` : '', e.stress ? `壓力 ${e.stress > 0 ? '+' : ''}${e.stress}` : '', e.loot ? '掉寶' : '', e.lifeline ? '救命保單' : '']
    .filter(Boolean)
    .join('・')

function SideView() {
  const jobs = Object.values(JOBS)
  return (
    <div className="space-y-3">
      {DISTRICTS.map((d) => (
        <Panel key={d.id} innerClass="p-3 space-y-2 text-[14px] leading-6">
          <div className="text-[18px] font-bold text-heading">{d.name}・事件（{d.events.length}）</div>
          {d.events.map((id) => {
            const e = EVENT_BY_ID[id]
            return (
              <Sec key={id} title={e.title}>
                <Lines xs={[e.body]} />
                {e.options.map((o) => (
                  <div key={o.id} className="border border-line/40 p-2">
                    <div className="font-bold text-fg-list">
                      ▸ {o.label}
                      <span className="text-[13px] font-normal text-muted">
                        {[o.needs ? `${ATTR_LABEL[o.needs.attr]} ≥ ${o.needs.min}` : '', o.cost ? `付 ¢${o.cost}` : '', o.check ? (o.check.attr ? `擲骰：${ATTR_LABEL[o.check.attr]}` : `擲骰：運氣 ${o.check.dice ?? 1} 顆`) : ''].filter(Boolean).map((t) => `・${t}`).join('')}
                      </span>
                    </div>
                    <p className="m-0">{o.lose ? '成功：' : ''}{o.win.text} <span className="text-[13px] text-cyan">{fx(o.win)}</span></p>
                    {o.lose && <p className="m-0">失敗：{o.lose.text} <span className="text-[13px] text-red">{fx(o.lose)}</span></p>}
                  </div>
                ))}
              </Sec>
            )
          })}
        </Panel>
      ))}
      <Panel innerClass="p-3 space-y-1 text-[14px] leading-6">
        <div className="text-[18px] font-bold text-heading">一般／精英委託（{jobs.length}）</div>
        {jobs.map((j) => (
          <p key={j.id} className="m-0 border-b border-line/40 pb-1">
            <b className="text-fg-list">{j.name}</b>
            <span className="text-[13px] text-muted">
              ・{DIRECTION_LABEL[j.direction]}・難度 {j.tier}・{who(j.fixerId)}・¢{j.reward}
            </span>
            <br />
            {j.blurb}
          </p>
        ))}
      </Panel>
    </div>
  )
}

export function StoryReview({ onClose }: { onClose: () => void }) {
  const [tab, setTab] = useState<'main' | 'side'>('main')
  const wired = new Set(DISTRICTS.flatMap((d) => [d.story, d.boss]))
  const loose = CASES.filter((c) => !wired.has(c.id))
  return (
    <div className="absolute inset-0 z-30 flex flex-col bg-bg/90 p-2" role="dialog" aria-label="劇情總覽">
      <Panel tone="strong" className="min-h-0 flex-1" innerClass="flex h-full flex-col">
        <div className="flex items-center gap-1 border-b border-line/60 px-2 py-1">
          {(['main', 'side'] as const).map((t) => (
            <button key={t} onClick={() => setTab(t)} className={`min-h-11 border px-3 font-bold ${tab === t ? 'border-cyan text-cyan' : 'border-line/50 text-muted'}`}>
              {t === 'main' ? '主線' : '支線'}
            </button>
          ))}
          <b className="flex-1 px-1 text-heading">劇情總覽</b>
          <button onClick={onClose} className="grid min-h-11 min-w-11 place-items-center text-cyan" aria-label="關閉">
            <X size={20} />
          </button>
        </div>
        <div className="min-h-0 flex-1 space-y-3 overflow-y-auto p-2">
          {tab === 'main' ? (
            <>
              {DISTRICTS.map((d, i) => (
                <div key={d.id} className="space-y-2">
                  <div className="text-[13px] font-bold text-warning">
                    第 {i + 1} 街區：{d.name}・委託難度 {d.tiers.join('→')}・精英 {d.eliteTier}
                  </div>
                  <CaseView sc={CASE_BY_ID[d.story]} role="中段劇情委託" />
                  <CaseView sc={CASE_BY_ID[d.boss]} role="終點劇情大案" />
                  <p className="m-0 px-1 text-[14px] text-muted">安全屋：{d.safehouse}</p>
                </div>
              ))}
              {loose.length > 0 && <p className="m-0 px-1 text-[13px] text-muted">沒接進街區的案件：{loose.map((c) => `${c.title}（${c.id}）`).join('、')}</p>}
            </>
          ) : (
            <SideView />
          )}
        </div>
      </Panel>
    </div>
  )
}
