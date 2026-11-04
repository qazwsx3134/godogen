import { useEffect, useRef, useState } from 'react'
import { AlertTriangle, ArrowLeft, Crosshair, Eye, Flame, Heart, MessageSquare, Pin, Terminal, Timer } from 'lucide-react'
import { ActionButton, Avatar, ListRow, Panel, PanelHead, Tabs, Tag } from '../components/ui'
import { FIXERS, JOBS, QUEUE_SLOTS, TEST_CASE, highDanger } from '../content/data'
import type { useGame } from '../game/state'
import {
  type DangerOption,
  type DangerOutcome,
  DIRECTION_LABEL,
  type Direction,
  type JobDef,
  equipBonus,
  isLethal,
  jobDurationMs,
  jobReward,
  jobSuccessChance,
  neuralMargin,
  pawnValue,
  RESCUE_BILL,
} from '../rules/core'

type G = ReturnType<typeof useGame>

export const DIR_ICON: Record<Direction, typeof Flame> = { force: Crosshair, hack: Terminal, stealth: Eye }

const mmss = (ms: number) => {
  const s = Math.max(0, Math.round(ms / 1000))
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`
}

export function JobsScreen({ game }: { game: G }) {
  const [tab, setTab] = useState<'story' | 'street' | 'queue'>('story')
  const [openCase, setOpenCase] = useState(false)
  const [openJob, setOpenJob] = useState<string | null>(null)
  const { g } = game

  if (g.high) return <HighRun game={game} />
  if (openCase) return <CaseThread game={game} onBack={() => setOpenCase(false)} />
  if (openJob) return <JobDetail game={game} job={JOBS[openJob]} onBack={() => setOpenJob(null)} />

  return (
    <div className="space-y-3">
      <Tabs
        value={tab}
        onChange={setTab}
        items={[
          { id: 'story', label: '劇情委託' },
          { id: 'street', label: '街頭工作' },
          { id: 'queue', label: '排隊', badge: g.queue.items.length },
        ]}
      />
      {tab === 'story' && (
        <Panel innerClass="pb-1">
          <PanelHead icon={<Pin size={16} />} title="新宿街區・中間人看板" right={<span className="text-[13px] text-muted">1 件</span>} />
          <ListRow
            icon={<Pin size={18} />}
            prefix="置頂"
            title={`${TEST_CASE.title}（測試案）`}
            cols={[
              { label: '報酬', value: `¢${TEST_CASE.reward}` },
              { label: '回覆', value: String(TEST_CASE.replies.length) },
            ]}
            meta={`${FIXERS[TEST_CASE.fixerId].name}・${storyStatus(g.story.stage)}`}
            lethal
            selected
            onClick={() => setOpenCase(true)}
          />
          <p className="m-0 px-3 py-3 text-[14px] text-muted">
            劇情委託每個角色只能接一次。正式案件（P01 前兩案）完成試讀後放進來。
          </p>
        </Panel>
      )}
      {tab === 'street' && <StreetList game={game} onOpen={setOpenJob} />}
      {tab === 'queue' && <QueueView game={game} />}
    </div>
  )
}

function storyStatus(s: string) {
  return { open: '可接', prep: '準備中', auto: '執行中', danger: '⚠ 等待你的選擇', done: '已結案' }[s] ?? s
}

function StreetList({ game, onOpen }: { game: G; onOpen: (id: string) => void }) {
  const c = game.g.character
  const groups: Direction[] = ['stealth', 'hack', 'force']
  return (
    <div className="space-y-3">
      {groups.map((d) => {
        const Icon = DIR_ICON[d]
        const list = Object.values(JOBS).filter((j) => j.direction === d)
        return (
          <Panel key={d} innerClass="pb-1">
            <PanelHead
              icon={<Icon size={16} />}
              title={`${DIRECTION_LABEL[d]}工作`}
              right={<span className="tech text-[13px] text-muted">熟練度 {c.prof[d].level}/100</span>}
            />
            {list.map((j) => (
              <ListRow
                key={j.id}
                icon={<Icon size={18} />}
                prefix={isLethal(j) ? '高階' : undefined}
                title={j.name}
                cols={[
                  { label: '報酬', value: `¢${jobReward(j, c.prof[d].level)}` },
                  { label: '耗時', value: mmss(jobDurationMs(j, c.prof[d].level)) },
                  { label: '階級', value: String(j.tier) },
                ]}
                meta={`${FIXERS[j.fixerId].name}・${isLethal(j) ? '只能在線手動接' : '可排隊・可離線'}`}
                lethal={isLethal(j)}
                onClick={() => onOpen(j.id)}
              />
            ))}
          </Panel>
        )
      })}
    </div>
  )
}

function JobDetail({ game, job, onBack }: { game: G; job: JobDef; onBack: () => void }) {
  const { g, act } = game
  const c = g.character
  const lv = c.prof[job.direction].level
  const full = g.queue.items.length >= QUEUE_SLOTS
  const lethal = isLethal(job)
  const reason = !c.alive
    ? '角色已死亡'
    : lethal
      ? undefined
      : full
        ? `排隊已滿（${QUEUE_SLOTS}/${QUEUE_SLOTS}）`
        : undefined
  const storyBusy = g.story.stage === 'prep' || g.story.stage === 'auto' || g.story.stage === 'danger'
  const highBlock = !c.alive
    ? '角色已死亡'
    : storyBusy
      ? '劇情委託進行中，先完成它'
      : g.high && g.high.stage !== 'done'
        ? '已經有一件高階工作在進行'
        : undefined
  return (
    <div className="space-y-3">
      <BackBar onBack={onBack} label="街頭工作" />
      <Panel tone={lethal ? 'red' : 'line'} innerClass="p-4">
        <div className="text-[13px] text-muted">
          #{job.id.toUpperCase()}・{DIRECTION_LABEL[job.direction]}・階級 {job.tier}
        </div>
        <h1 className="my-1 text-[22px] leading-snug font-bold text-heading">{job.name}</h1>
        <div className="flex items-start gap-3">
          <Avatar id={job.fixerId} size={48} />
          <p className="m-0 flex-1 text-fg">{job.blurb}</p>
        </div>
        <div className="mt-3 flex flex-wrap gap-2">
          <Tag>報酬 ¢{jobReward(job, lv)}</Tag>
          <Tag>耗時 {mmss(jobDurationMs(job, lv))}</Tag>
          <Tag>成功率 {Math.round(jobSuccessChance(job, lv, equipBonus(c, job.direction)) * 100)}%</Tag>
          <Tag tone="warning">壓力 +{job.stress}</Tag>
          {lethal && (
            <Tag tone="red">
              <AlertTriangle size={13} /> 可能永久死亡
            </Tag>
          )}
        </div>
        <p className="mt-3 mb-0 text-[14px] text-muted">
          成功率來自工作階級、{DIRECTION_LABEL[job.direction]}熟練度 {lv} 與裝備加成 +{Math.round(equipBonus(c, job.direction) * 100)}%；熟練度每級 +0.05%，傷勢 −0.15%，報酬 +0.25%，耗時 −0.4%。
        </p>
      </Panel>
      {lethal ? (
        <>
          <p className="m-0 text-[14px] text-muted">第 4 階起只能在線手動接，不能排隊、不能離線。進行中排隊的工作會暫停（正在做的那件會做完）。</p>
          <ActionButton
            tone="danger"
            disabled={!!highBlock}
            reason={highBlock}
            onClick={() => (act({ t: 'highStart', jobId: job.id }), onBack())}
          >
            <AlertTriangle size={16} /> 在線手動接下
          </ActionButton>
        </>
      ) : (
        <ActionButton tone="primary" disabled={!!reason} reason={reason} onClick={() => (act({ t: 'enqueue', jobId: job.id }), onBack())}>
          排入佇列（{g.queue.items.length}/{QUEUE_SLOTS}）
        </ActionButton>
      )}
    </div>
  )
}

function QueueView({ game }: { game: G }) {
  const { g, act, now } = game
  const c = g.character
  const first = g.queue.items[0] ? JOBS[g.queue.items[0]] : null
  const dur = first ? jobDurationMs(first, c.prof[first.direction].level) : 0
  const elapsed = first && g.queue.startedAt ? now - g.queue.startedAt : 0
  return (
    <div className="space-y-3">
      <Panel innerClass="pb-2">
        <PanelHead icon={<Timer size={16} />} title={`排隊（${g.queue.items.length}/${QUEUE_SLOTS}）`} />
        {g.queue.items.length === 0 && <p className="m-0 px-3 py-3 text-muted">沒有排隊中的工作。到「街頭工作」排入最多 {QUEUE_SLOTS} 件。</p>}
        {g.queue.items.map((id, i) => {
          const j = JOBS[id]
          const Icon = DIR_ICON[j.direction]
          return (
            <div key={i} className="border-b border-line/40 px-3 py-2">
              <div className="flex items-center gap-2 text-[15px]">
                <Icon size={16} className={i === 0 ? 'text-red' : 'text-line'} />
                <span className="flex-1 text-fg-list">{j.name}</span>
                <span className="tech text-heading">{i === 0 ? mmss(dur - elapsed) : mmss(jobDurationMs(j, c.prof[j.direction].level))}</span>
              </div>
              {i === 0 && (
                <div className="mt-1 h-1.5 border border-line/60">
                  <div className="h-full bg-cyan" style={{ width: `${Math.min(100, (elapsed / dur) * 100)}%` }} />
                </div>
              )}
            </div>
          )
        })}
        <p className="m-0 px-3 pt-2 text-[13px] text-muted">
          停止條件：傷勢 ≥ {g.stopRules.injuryAt}%、通緝 ≥ {g.stopRules.heatAt}★、神經進入臨界。觸發時取消剩下的工作並寫明原因。
        </p>
      </Panel>
      <Panel innerClass="p-3">
        <div className="mb-2 text-[14px] font-bold text-heading">測試工具</div>
        <div className="flex gap-2">
          {[1, 10, 60].map((s) => (
            <button
              key={s}
              onClick={() => act({ t: 'scale', scale: s })}
              className={`tech min-h-11 flex-1 border text-[15px] ${g.clock.scale === s ? 'border-red bg-red-bg text-red' : 'border-line text-cyan'}`}
            >
              {s}×
            </button>
          ))}
        </div>
        <ActionButton className="mt-2" onClick={() => act({ t: 'skip', minutes: 30 })}>
          模擬離線 30 分鐘
        </ActionButton>
        <p className="mt-2 mb-0 text-[13px] text-muted">真的關掉網頁 3 分鐘以上再回來，也會出現離開期間報告。</p>
      </Panel>
    </div>
  )
}

export function BackBar({ onBack, label }: { onBack: () => void; label: string }) {
  return (
    <button onClick={onBack} className="flex min-h-11 items-center gap-1 text-[15px] text-cyan">
      <ArrowLeft size={18} /> {label}
    </button>
  )
}

// ---------- 劇情委託（論壇文章詳情＋回覆串） ----------

function CaseThread({ game, onBack }: { game: G; onBack: () => void }) {
  const { g, act } = game
  const st = g.story
  const fixer = FIXERS[TEST_CASE.fixerId]
  return (
    <div className="space-y-3">
      <BackBar onBack={onBack} label="中間人看板" />
      <Panel innerClass="p-4">
        <h1 className="m-0 text-[22px] leading-snug font-bold text-heading">{TEST_CASE.title}</h1>
        <div className="mt-1 flex flex-wrap items-center gap-x-3 text-[13px] text-muted">
          <span className="tech">#{TEST_CASE.id}</span>
          <span>{fixer.name}</span>
          <span className="tech">{TEST_CASE.posted}</span>
          <span className="ml-auto border border-line px-1.5 text-cyan">測試案</span>
        </div>
        <div className="mt-3 flex items-start gap-3">
          <Avatar id={fixer.id} size={52} />
          <p className="m-0 flex-1 whitespace-pre-line text-fg">{TEST_CASE.body}</p>
        </div>
        <div className="mt-3 flex items-center gap-4 border-t border-line/40 pt-2 text-[14px] text-muted">
          <span className="flex items-center gap-1">
            <MessageSquare size={15} /> {TEST_CASE.replies.length}
          </span>
          <span className="tech">¢{TEST_CASE.reward}</span>
          <span>{TEST_CASE.zone}</span>
          <span className="ml-auto flex items-center gap-1 text-red">
            <Heart size={15} /> 87
          </span>
        </div>
      </Panel>

      <Panel innerClass="divide-y divide-line/40">
        {TEST_CASE.replies.map((r, i) => (
          <div key={i} className="flex gap-3 p-3">
            <Avatar id={r.who} size={44} />
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-2 text-[14px]">
                <b className="text-heading">{FIXERS[r.who].name}</b>
                <span className="text-[12px] text-muted">{FIXERS[r.who].role}</span>
                <span className="tech ml-auto text-[13px] text-muted">{r.at}</span>
              </div>
              <p className="mt-1 mb-0 text-[16px] text-fg">{r.text}</p>
            </div>
          </div>
        ))}
      </Panel>

      {st.stage === 'open' && (
        <ActionButton tone="primary" disabled={!g.character.alive} reason="角色已死亡" onClick={() => act({ t: 'storyStart' })}>
          接下委託
        </ActionButton>
      )}
      {st.stage === 'prep' && <ApproachPicker game={game} />}
      {st.stage === 'auto' && <AutoRun lines={TEST_CASE.autoLog} onDone={() => act({ t: 'storyAutoDone' })} />}
      {st.stage === 'danger' && (
        <RiskDecision
          game={game}
          title={TEST_CASE.danger.title}
          body={TEST_CASE.danger.body}
          options={TEST_CASE.danger.options}
          safeNote="委託失敗、拿不到報酬"
          onConfirm={(id) => act({ t: 'storyChoose', optionId: id })}
        />
      )}
      {st.stage === 'done' && st.outcome && <Result outcome={st.outcome} />}
    </div>
  )
}

function ApproachPicker({ game }: { game: G }) {
  const [sel, setSel] = useState<string | null>(null)
  return (
    <Panel innerClass="p-3 space-y-2">
      <div className="text-[15px] font-bold text-heading">選擇做法</div>
      {TEST_CASE.approaches.map((a) => {
        const Icon = DIR_ICON[a.direction]
        const on = sel === a.id
        return (
          <button key={a.id} onClick={() => setSel(a.id)} className={`block w-full text-left ${on ? 'cut cut-sm cut-red' : 'cut cut-sm'}`}>
            <div className="cut-in flex min-h-12 gap-3 p-3">
              <Icon size={18} className={on ? 'mt-1 text-red' : 'mt-1 text-line'} />
              <div className="flex-1">
                <div className="font-bold text-fg-list">{a.label}</div>
                <div className="text-[15px] text-fg">{a.summary}</div>
                <div className="text-[13px] text-muted">需求：{a.needs}</div>
              </div>
            </div>
          </button>
        )
      })}
      <ActionButton tone="primary" disabled={!sel} reason="先選一種做法" onClick={() => game.act({ t: 'storyApproach', id: sel! })}>
        出發
      </ActionButton>
    </Panel>
  )
}

function AutoRun({ lines, onDone }: { lines: string[]; onDone: () => void }) {
  const [n, setN] = useState(1)
  // 父元件每秒會因時鐘重新渲染，onDone 每次都是新函式；放進 ref 才不會一直重設計時器
  const done = useRef(onDone)
  done.current = onDone
  useEffect(() => {
    if (n > lines.length) {
      done.current()
      return
    }
    const id = setTimeout(() => setN(n + 1), 1600)
    return () => clearTimeout(id)
  }, [n, lines.length])
  return (
    <Panel innerClass="p-3 space-y-2">
      <div className="text-[13px] text-muted">▶ 自動執行中（安全段）</div>
      {lines.slice(0, n).map((l, i) => (
        <p key={i} className="m-0 text-fg">
          {l}
        </p>
      ))}
    </Panel>
  )
}

function RiskDecision({
  game,
  title,
  body,
  options,
  safeNote,
  onConfirm,
}: {
  game: G
  title: string
  body: string
  options: DangerOption[]
  safeNote: string
  onConfirm: (id: string) => void
}) {
  const { g } = game
  const c = g.character
  const [sel, setSel] = useState<string | null>(null)
  const margin = neuralMargin(c.level, c.implantLoad, c.stress)
  const cov = g.coverage
  const payable = c.credits + c.equipment.reduce((s, i) => s + pawnValue(i), 0)
  return (
    <Panel tone="red" innerClass="p-4 space-y-3">
      <div className="flex items-center gap-2 text-[18px] font-bold text-red">
        <AlertTriangle size={20} /> 重大危險：{title}
      </div>
      <p className="m-0 text-fg">{body}</p>
      <div className="grid grid-cols-2 gap-2 text-[14px]">
        <div className="border border-red/60 p-2">
          傷勢 <b className="tech text-warning">{c.injury}%</b>
        </div>
        <div className="border border-red/60 p-2">
          神經餘裕 <b className="tech text-heading">{margin}</b>
        </div>
        <div className="border border-red/60 p-2">
          通緝 <b className="text-red">{'★'.repeat(c.heat) || '—'}</b>
        </div>
        <div className="border border-red/60 p-2">
          醫療保單 <b className={cov.active ? 'text-positive' : 'text-red'}>{cov.active ? `有效・約 ${cov.etaMin} 分鐘` : '無'}</b>
        </div>
      </div>
      <p className="m-0 text-[14px] text-muted">
        沒有倒數，可以先離開再回來。確認後由伺服器一次判定，重新整理不會重抽。
      </p>
      {cov.active && (
        <p className="m-0 border border-warning/70 p-2 text-[14px] text-warning">
          救援帳單 ¢{RESCUE_BILL}：現金不夠時，自動抵押身上的裝備；現金加抵押價（目前最多 ¢{payable}）還不夠，救援不會出勤。
        </p>
      )}
      {options.map((o) => {
        const on = sel === o.id
        return (
          <button key={o.id} onClick={() => setSel(o.id)} className={`block w-full text-left cut cut-sm ${on ? 'cut-strong' : ''}`}>
            <div className="cut-in min-h-12 p-3">
              <div className={`font-bold ${on ? 'text-cyan' : 'text-fg-list'}`}>{o.label}</div>
              <div className="text-[14px]">
                {o.lethal ? (
                  <span className="flex items-center gap-1 font-bold text-red">
                    <AlertTriangle size={14} /> 可能永久死亡・受致命傷後約可撐 {o.survivalWindowMin} 分鐘
                  </span>
                ) : (
                  <span className="text-positive">不會死・{safeNote}</span>
                )}
              </div>
            </div>
          </button>
        )
      })}
      <ActionButton tone="danger" disabled={!sel} reason="先選一個行動" onClick={() => onConfirm(sel!)}>
        確認這個行動
      </ActionButton>
    </Panel>
  )
}

function Result({ outcome: o, doneTitle = '完成委託' }: { outcome: DangerOutcome; doneTitle?: string }) {
  const title = {
    safe: '撤離・委託失敗',
    survived: doneTitle,
    rescued: '被武裝醫療隊救出',
    rescued_system: '緊急搶救（系統補償）',
    dead: '永久死亡',
  }[o.kind]
  const tone = o.kind === 'dead' ? 'red' : 'strong'
  return (
    <Panel tone={tone} innerClass="p-4">
      <div className={`text-[20px] font-bold ${o.kind === 'dead' ? 'text-red' : 'text-cyan'}`}>{title}</div>
      <p className="mt-1 mb-0 text-fg">{o.reason}</p>
      {o.kind === 'dead' && <p className="mt-2 mb-0 text-[14px] text-muted">生涯紀錄已保存。到「紀錄」建立新角色。</p>}
    </Panel>
  )
}

// ---------- 高階街頭工作（在線手動） ----------

function HighRun({ game }: { game: G }) {
  const { g, act } = game
  const h = g.high!
  const job = JOBS[h.jobId]
  const t = highDanger(job)
  const Icon = DIR_ICON[job.direction]
  return (
    <div className="space-y-3">
      {h.stage === 'done' && <BackBar onBack={() => act({ t: 'highClose' })} label="回到街頭工作" />}
      <Panel tone="red" innerClass="p-4">
        <div className="flex items-center gap-2 text-[13px] text-red">
          <Icon size={14} /> 高階工作・{DIRECTION_LABEL[job.direction]}・階級 {job.tier}・在線手動
        </div>
        <h1 className="my-1 text-[22px] leading-snug font-bold text-heading">{job.name}</h1>
        <div className="flex items-start gap-3">
          <Avatar id={job.fixerId} size={48} />
          <p className="m-0 flex-1 text-fg">{job.blurb}</p>
        </div>
      </Panel>
      {h.stage === 'auto' && <AutoRun lines={t.autoLog} onDone={() => act({ t: 'highAutoDone' })} />}
      {h.stage === 'danger' && (
        <RiskDecision
          game={game}
          title={t.title}
          body={t.body}
          options={t.options}
          safeNote="拿不到報酬"
          onConfirm={(id) => act({ t: 'highChoose', optionId: id })}
        />
      )}
      {h.stage === 'done' && h.outcome && <Result outcome={h.outcome} doneTitle="完成高階工作" />}
    </div>
  )
}
