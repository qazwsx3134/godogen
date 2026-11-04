import { useEffect, useRef, useState } from 'react'
import { AlertTriangle, ArrowLeft, Crosshair, Eye, Flame, Heart, MessageSquare, Pin, Swords, Terminal, Timer } from 'lucide-react'
import { ActionButton, Avatar, ListRow, Meter, Panel, PanelHead, Tabs, Tag } from '../components/ui'
import { FIXERS, JOBS, QUEUE_SLOTS, highDanger } from '../content/data'
import { CASES, CASE_BY_ID, type CaseRecord, type StoryCase, caseBody, caseReplies, caseUnlocked, optionLock } from '../content/cases'
import { type useGame, fightEnemy, storyBusy } from '../game/state'
import {
  type Enemy,
  type FightResult,
  type Tactic,
  RETREAT_HP,
  ATTR_LABEL,
  workBlock,
  fightStats,
  tacticsFor,
  approachBonus,
  attrLock,
  payable,
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
  marginOf,
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
  const [openCase, setOpenCase] = useState<string | null>(null)
  const [openJob, setOpenJob] = useState<string | null>(null)
  const { g } = game

  if (g.high) return <HighRun game={game} />
  if (openCase) return <CaseThread game={game} sc={CASE_BY_ID[openCase]} onBack={() => setOpenCase(null)} />
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
          <PanelHead icon={<Pin size={16} />} title="新宿街區・中間人看板" right={<span className="text-[13px] text-muted">{CASES.length} 件</span>} />
          {CASES.map((sc) => {
            const locked = !caseUnlocked(sc, g.cases)
            const rec = g.cases[sc.id]
            return (
              <ListRow
                key={sc.id}
                icon={<Pin size={18} />}
                prefix={sc.kind === 'test' ? '測試' : sc.id}
                title={locked ? '？？？（先完成上一案）' : `${sc.title}${sc.kind === 'draft' ? '（試讀稿）' : ''}`}
                cols={[
                  { label: '報酬', value: locked ? '—' : `¢${Math.max(...sc.danger.options.map((o) => o.reward))}` },
                  { label: '回覆', value: locked ? '—' : String(sc.replies.length) },
                ]}
                meta={`${FIXERS[sc.fixerId].name}・${caseStatus(g.story.caseId === sc.id ? g.story.stage : null, rec, locked, sc)}`}
                lethal={!locked}
                selected={g.story.caseId === sc.id}
                onClick={locked ? undefined : () => setOpenCase(sc.id)}
              />
            )
          })}
          <p className="m-0 px-3 py-3 text-[14px] text-muted">
            {g.cases['P01-02']
              ? '「終電之後」試讀稿到這裡結束。03～06 案還在寫。'
              : '劇情委託每個角色只能接一次；角色死亡後，新角色可以重新接。'}
          </p>
        </Panel>
      )}
      {tab === 'street' && <StreetList game={game} onOpen={setOpenJob} />}
      {tab === 'queue' && <QueueView game={game} />}
    </div>
  )
}

function caseStatus(stage: string | null, rec: CaseRecord | undefined, locked: boolean, sc: StoryCase) {
  if (locked) return '未開放'
  if (stage) return { open: '可接', prep: '準備中', auto: '執行中', danger: '⚠ 等待你的選擇' }[stage] ?? stage
  if (!rec) return '可接'
  if (rec.outcome === 'safe' && sc.danger.options.find((o) => o.id === rec.optionId)?.reward) return '已結案・部分完成'
  return { safe: '已結案・撤離', survived: '已結案', rescued: '已結案・被救出', rescued_system: '已結案・緊急搶救', dead: '死亡' }[rec.outcome]
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
  const reason = workBlock(c)
    ? workBlock(c)
    : lethal
      ? undefined
      : full
        ? `排隊已滿（${QUEUE_SLOTS}/${QUEUE_SLOTS}）`
        : undefined
  const highBlock = workBlock(c)
    ? workBlock(c)
    : storyBusy(g)
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
          停止條件：傷勢 ≥ {g.stopRules.injuryAt}%、通緝 ≥ {g.stopRules.heatAt}★、神經進入臨界；重傷（傷勢 ≥ 70%）一定停。觸發時取消剩下的工作並寫明原因。
        </p>
        <div className="px-3 pt-2">
          <div className="text-[13px] text-muted">遇到打鬥時的預設戰術（火力工作每件都打；入侵、潛行失手被發現也會打）</div>
          <div className="mt-1 grid grid-cols-3 gap-2">
            {tacticsFor(g.character).map((t) => {
              const on = (g.stopRules.tactic ?? 'force') === t.id
              return (
                <button
                  key={t.id}
                  onClick={() => act({ t: 'setTactic', tactic: t.id })}
                  className={`min-h-11 border px-1 text-[13px] ${on ? 'border-red font-bold text-red' : 'border-line/70 text-fg'}`}
                >
                  {t.label}
                  {t.locked && <span className="block text-[11px] text-warning">鎖住→正面</span>}
                </button>
              )
            })}
          </div>
        </div>
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

function CaseThread({ game, sc, onBack }: { game: G; sc: StoryCase; onBack: () => void }) {
  const { g, act } = game
  const active = g.story.caseId === sc.id ? g.story.stage : null
  const rec = g.cases[sc.id]
  const fixer = FIXERS[sc.fixerId]
  const otherBusy =
    workBlock(g.character) ?? (storyBusy(g) && !active ? '另一件劇情委託進行中' : g.high && g.high.stage !== 'done' ? '高階工作進行中' : undefined)
  const replies = caseReplies(sc, g.cases)
  const visible = sc.danger.options.filter((o) => optionLock(g.character, g.story.approach, o) !== null)
  const locks = Object.fromEntries(visible.map((o) => [o.id, optionLock(g.character, g.story.approach, o) ?? '']).filter(([, v]) => v))
  const notes = Object.fromEntries(
    visible.map((o) => [
      o.id,
      [
        o.approach ? `只有走「${sc.approaches.find((x) => x.id === o.approach)!.label}」才有` : '',
        o.needs && 'attr' in o.needs ? `屬性選項：${ATTR_LABEL[o.needs.attr]} ≥ ${o.needs.min}` : '',
        o.fight ? `⚔ 要打一場（${o.fight.name} HP ${o.fight.hp}）：打贏就生還，打輸才擲致命判定` : '']
        .filter(Boolean)
        .join('・'),
    ]),
  )
  const reward = Math.max(...sc.danger.options.map((o) => o.reward))
  return (
    <div className="space-y-3">
      <BackBar onBack={onBack} label="中間人看板" />
      <Panel innerClass="p-4">
        <h1 className="m-0 text-[22px] leading-snug font-bold text-heading">{sc.title}</h1>
        <div className="mt-1 flex flex-wrap items-center gap-x-3 text-[13px] text-muted">
          <span className="tech">#{sc.id}</span>
          <span>{fixer.name}</span>
          <span className="tech">{sc.posted}</span>
          <span className="ml-auto border border-line px-1.5 text-cyan">{sc.kind === 'test' ? '測試案' : '試讀稿'}</span>
        </div>
        <div className="mt-3 flex items-start gap-3">
          <Avatar id={fixer.id} size={52} />
          <p className="m-0 flex-1 whitespace-pre-line text-fg">{caseBody(sc, g.cases)}</p>
        </div>
        <div className="mt-3 flex items-center gap-4 border-t border-line/40 pt-2 text-[14px] text-muted">
          <span className="flex items-center gap-1">
            <MessageSquare size={15} /> {replies.length}
          </span>
          <span className="tech">最高 ¢{reward}</span>
          <span>{sc.zone}</span>
          <span className="ml-auto flex items-center gap-1 text-red">
            <Heart size={15} /> 87
          </span>
        </div>
      </Panel>

      <Panel innerClass="divide-y divide-line/40">
        {replies.map((r, i) => (
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

      {!active && !rec && (
        <ActionButton
          tone="primary"
          disabled={!!otherBusy}
          reason={otherBusy}
          onClick={() => act({ t: 'storyStart', caseId: sc.id })}
        >
          接下委託
        </ActionButton>
      )}
      {active === 'prep' && <ApproachPicker game={game} sc={sc} />}
      {active === 'auto' && (
        <AutoRun lines={sc.approaches.find((x) => x.id === g.story.approach)?.autoLog ?? []} onDone={() => act({ t: 'storyAutoDone' })} />
      )}
      {active === 'fight' && !g.story.fight && (
        <TacticPicker game={game} enemy={fightEnemy(sc, g.story)} onPick={(t) => act({ t: 'storyFight', tactic: t })} />
      )}
      {active === 'fight' && g.story.fight && (
        <FightRun
          fight={g.story.fight}
          after={g.story.option ? undefined : sc.approaches.find((x) => x.id === g.story.approach)?.afterFight}
          onDone={() => act({ t: 'storyFightDone' })}
        />
      )}
      {active === 'danger' && (
        <RiskDecision
          game={game}
          title={sc.danger.title}
          body={sc.danger.body}
          options={visible}
          locks={locks}
          notes={notes}
          safeNote={(o) => {
            const r = sc.danger.options.find((x) => x.id === o.id)!.reward
            const opt = sc.danger.options.find((x) => x.id === o.id)!
            return opt.wins ? `完成委託 ¢${r}` : r ? `只拿部分報酬 ¢${r}` : '委託失敗、拿不到報酬'
          }}
          onConfirm={(id) => act({ t: 'storyChoose', optionId: id })}
        />
      )}
      {rec && (
        <>
          <Result
            outcome={{ kind: rec.outcome, reason: rec.reason, bill: 0 } as DangerOutcome}
            safeTitle={
              rec.optionId === 'retreat'
                ? '被打退・委託失敗'
                : sc.danger.options.find((o) => o.id === rec.optionId)?.reward
                  ? '部分完成'
                  : undefined
            }
          />
          {sc.kind === 'test' && g.character.alive && (
            <ActionButton tone="primary" onClick={() => act({ t: 'storyRetry', caseId: sc.id })}>
              重設測試案
            </ActionButton>
          )}
        </>
      )}
    </div>
  )
}

function ApproachPicker({ game, sc }: { game: G; sc: StoryCase }) {
  const [sel, setSel] = useState<string | null>(null)
  const c = game.g.character
  return (
    <Panel innerClass="p-3 space-y-2">
      <div className="text-[15px] font-bold text-heading">選擇做法</div>
      <p className="m-0 text-[13px] text-muted">做法決定路上的傷勢與最後關頭的風險；該方向的裝備與熟練度會降低風險。</p>
      {sc.approaches.map((a) => {
        const Icon = DIR_ICON[a.direction]
        const on = sel === a.id
        const bonus = Math.round(approachBonus(c, a.direction) * 100)
        const mod = Math.round(a.lethalMod * 100)
        const lock = attrLock(c, a.needs)
        return (
          <button
            key={a.id}
            disabled={!!lock}
            onClick={() => setSel(a.id)}
            className={`block w-full text-left ${on ? 'cut cut-sm cut-red' : 'cut cut-sm'} ${lock ? 'opacity-50' : ''}`}
          >
            <div className="cut-in flex min-h-12 gap-3 p-3">
              <Icon size={18} className={on ? 'mt-1 text-red' : 'mt-1 text-line'} />
              <div className="flex-1">
                <div className="font-bold text-fg-list">{a.label}</div>
                <div className="text-[15px] text-fg">{a.summary}</div>
                <div className="text-[13px] text-muted">
                  {DIRECTION_LABEL[a.direction]}・{a.fight ? `⚔ 要打一場（${a.fight.name}）` : `路上傷勢 +${a.injury}%`}・風險 {mod > 0 ? `+${mod}` : mod}%
                  {bonus ? `・你的裝備與熟練度 −${bonus}%` : ''}
                </div>
                {a.needs && <div className="text-[13px] text-cyan">屬性做法：{ATTR_LABEL[a.needs.attr]} ≥ {a.needs.min}</div>}
                {lock && <div className="text-[13px] text-warning">✖ {lock}</div>}
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

// ---------- 自動戰鬥 ----------

function TacticPicker({ game, enemy, onPick }: { game: G; enemy: Enemy; onPick: (t: Tactic) => void }) {
  const c = game.g.character
  const st = fightStats(c)
  const [sel, setSel] = useState<Tactic | null>(null)
  return (
    <Panel tone="red" innerClass="p-3 space-y-2">
      <div className="flex items-center gap-2 text-[18px] font-bold text-red">
        <Swords size={20} /> 遭遇戰：{enemy.name}
      </div>
      <div className="grid grid-cols-2 gap-2 text-[14px]">
        <div className="border border-line/70 p-2">
          你 <b className="tech text-heading">HP {st.hp}/{st.maxHp}</b>・攻擊 <b className="tech text-heading">{st.atk}</b>・命中 <b className="tech text-heading">{Math.round(st.hit * 100)}%</b>
          {st.armor ? <>・護甲 <b className="tech text-heading">{st.armor}</b></> : null}
          {st.crit ? <>・暴擊 <b className="tech text-heading">{Math.round(st.crit * 100)}%</b></> : null}
        </div>
        <div className="border border-red/60 p-2">
          對方 <b className="tech text-heading">HP {enemy.hp}</b>・攻擊 <b className="tech text-heading">{enemy.atk}</b>・命中 <b className="tech text-heading">{Math.round(enemy.hit * 100)}%</b>
        </div>
      </div>
      <p className="m-0 text-[13px] text-muted">
        自動戰鬥，打鬥本身不會死：HP 低於最大 HP 的 {RETREAT_HP}% 會自動撤退，這件委託就失敗。受的傷會帶到後面的危險節點。選一個戰術：
      </p>
      {tacticsFor(c).map((t) => {
        const Icon = DIR_ICON[t.id]
        const on = sel === t.id
        return (
          <button
            key={t.id}
            disabled={!!t.locked}
            onClick={() => setSel(t.id)}
            className={`block w-full text-left ${on ? 'cut cut-sm cut-red' : 'cut cut-sm'} ${t.locked ? 'opacity-50' : ''}`}
          >
            <div className="cut-in flex min-h-12 gap-3 p-3">
              <Icon size={18} className={on ? 'mt-1 text-red' : 'mt-1 text-line'} />
              <div className="flex-1">
                <div className="font-bold text-fg-list">
                  {t.label}
                  <span className="ml-2 text-[13px] font-normal text-muted">{DIRECTION_LABEL[t.id]}</span>
                </div>
                <div className="text-[14px] text-fg">{t.summary}</div>
                {t.locked && <div className="text-[13px] text-warning">✖ {t.locked}</div>}
              </div>
            </div>
          </button>
        )
      })}
      <ActionButton tone="danger" disabled={!sel} reason="先選一個戰術" onClick={() => onPick(sel!)}>
        開打
      </ActionButton>
    </Panel>
  )
}

function FightRun({ fight: f, after = [], onDone }: { fight: FightResult; after?: string[]; onDone: () => void }) {
  const [n, setN] = useState(1)
  const done = useRef(onDone)
  done.current = onDone
  const total = f.rounds.length + (f.won ? after.length : 0)
  useEffect(() => {
    if (n > total) {
      done.current()
      return
    }
    const id = setTimeout(() => setN(n + 1), n > f.rounds.length ? 1600 : 650)
    return () => clearTimeout(id)
  }, [n, total, f.rounds.length])
  const last = f.rounds[Math.min(n, f.rounds.length) - 1]
  const logRef = useRef<HTMLDivElement>(null)
  useEffect(() => {
    logRef.current?.scrollTo({ top: logRef.current.scrollHeight })
  }, [n])
  return (
    <Panel tone="red" innerClass="p-3 space-y-2">
      <div className="flex items-center gap-2 text-[15px] font-bold text-red">
        <Swords size={16} /> 戰鬥中：{f.enemy.name}
      </div>
      <Meter label="你" value={last.you} max={f.hpStart} tone={last.you < (f.maxHp * (RETREAT_HP + 10)) / 100 ? 'red' : 'positive'} text={`HP ${last.you}`} />
      <Meter label={f.enemy.name} value={last.foe} max={f.enemy.hp} tone="red" text={`HP ${last.foe}`} />
      <div ref={logRef} className="max-h-56 space-y-1 overflow-y-auto border-t border-line/40 pt-2">
        {f.rounds.slice(0, n).map((r, i) => (
          <p key={i} className={`m-0 text-[15px] ${i === f.rounds.length - 1 ? 'font-bold text-heading' : 'text-fg'}`}>
            {r.text}
          </p>
        ))}
        {f.won &&
          after.slice(0, Math.max(0, n - f.rounds.length)).map((l, i) => (
            <p key={`a${i}`} className="m-0 text-fg">
              {l}
            </p>
          ))}
      </div>
      {n <= total && (
        <button onClick={() => setN(total + 1)} className="min-h-11 w-full border border-line/70 text-[14px] text-muted">
          跳過動畫
        </button>
      )}
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
  locks = {},
  notes = {},
  onConfirm,
}: {
  game: G
  title: string
  body: string
  options: DangerOption[]
  safeNote: string | ((o: DangerOption) => string)
  locks?: Record<string, string>
  notes?: Record<string, string>
  onConfirm: (id: string) => void
}) {
  const { g } = game
  const c = g.character
  const [sel, setSel] = useState<string | null>(null)
  const margin = marginOf(c)
  const cov = g.coverage
  const canPay = payable(c)
  return (
    <Panel tone="red" innerClass="p-4 space-y-3">
      <div className="flex items-center gap-2 text-[18px] font-bold text-red">
        <AlertTriangle size={20} /> 重大危險：{title}
      </div>
      <p className="m-0 whitespace-pre-line text-fg">{body}</p>
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
          救援帳單 ¢{RESCUE_BILL}：現金不夠時，自動抵押身上的裝備；現金加抵押價（目前最多 ¢{canPay}）還不夠，救援不會出勤。
        </p>
      )}
      {options.map((o) => {
        const on = sel === o.id
        return (
          <button
            key={o.id}
            disabled={!!locks[o.id]}
            onClick={() => setSel(o.id)}
            className={`block w-full text-left cut cut-sm ${on ? 'cut-strong' : ''} ${locks[o.id] ? 'opacity-50' : ''}`}
          >
            <div className="cut-in min-h-12 p-3">
              <div className={`font-bold ${on ? 'text-cyan' : 'text-fg-list'}`}>{o.label}</div>
              {notes[o.id] && <div className="text-[13px] text-cyan">{notes[o.id]}</div>}
              {locks[o.id] && <div className="text-[13px] text-warning">✖ {locks[o.id]}</div>}
              <div className="text-[14px]">
                {o.lethal ? (
                  <span className="flex items-center gap-1 font-bold text-red">
                    <AlertTriangle size={14} /> 可能永久死亡・受致命傷後約可撐 {o.survivalWindowMin} 分鐘
                  </span>
                ) : (
                  <span className="text-positive">不會死・{typeof safeNote === 'string' ? safeNote : safeNote(o)}</span>
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

function Result({ outcome: o, doneTitle = '完成委託', safeTitle = '撤離・委託失敗' }: { outcome: DangerOutcome; doneTitle?: string; safeTitle?: string }) {
  const title = {
    safe: safeTitle,
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
      {h.stage === 'fight' && !h.fight && <TacticPicker game={game} enemy={t.fight!} onPick={(x) => act({ t: 'highFight', tactic: x })} />}
      {h.stage === 'fight' && h.fight && <FightRun fight={h.fight} onDone={() => act({ t: 'highFightDone' })} />}
      {h.stage === 'danger' && (
        <RiskDecision
          game={game}
          title={t.title}
          body={t.body}
          options={t.options}
          locks={Object.fromEntries(t.options.map((o) => [o.id, attrLock(g.character, o.attrNeeds) ?? '']).filter(([, v]) => v))}
          notes={Object.fromEntries(t.options.filter((o) => o.attrNeeds).map((o) => [o.id, `屬性選項：${ATTR_LABEL[o.attrNeeds!.attr]} ≥ ${o.attrNeeds!.min}，風險比硬幹低`]))}
          safeNote="拿不到報酬"
          onConfirm={(id) => act({ t: 'highChoose', optionId: id })}
        />
      )}
      {h.stage === 'done' && h.outcome && (
        <Result outcome={h.outcome} doneTitle="完成高階工作" safeTitle={h.fight && !h.fight.won ? '被打退・撤離' : undefined} />
      )}
    </div>
  )
}
