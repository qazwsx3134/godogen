import { useCallback, useEffect, useReducer } from 'react'
import {
  type Character,
  type Coverage,
  type DangerOutcome,
  DEFAULT_STOP,
  type LogEvent,
  type Queue,
  type StopRules,
  grantProgress,
  hashSeed,
  payBill,
  redeem,
  isLethal,
  jobReward,
  resolveDanger,
  settleQueue,
  statusPrefix,
  weekKey,
} from '../rules/core'
import { CITY_TARGET, JOBS, QUEUE_SLOTS, STARTER_GEAR, TEST_CASE, highDanger } from '../content/data'

export type StoryStage = 'open' | 'prep' | 'auto' | 'danger' | 'done'

export interface Career {
  id: string
  name: string
  level: number
  credits: number
  diedAt: number
  cause: string
  weekPoints: number
}

export interface AwayReport {
  awayMs: number
  completed: number
  credits: number
  points: number
  injuryFrom: number
  injuryTo: number
  heatFrom: number
  heatTo: number
  stopped: string | null
  events: LogEvent[]
}

export interface Game {
  v: 1
  character: Character
  queue: Queue
  stopRules: StopRules
  coverage: Coverage
  log: LogEvent[]
  story: { stage: StoryStage; approach?: string; outcome?: DangerOutcome }
  high: { jobId: string; stage: 'auto' | 'danger' | 'done'; outcome?: DangerOutcome } | null
  highSeq: number
  careers: Career[]
  city: { supply: number }
  clock: { real: number; virtual: number; scale: number }
  away: AwayReport | null
  systemFault: boolean
  notes: string[] // 生涯紀錄裡的特殊事件（例如系統補償搶救）
}

const KEY = 'mortal-city:v3'

function newCharacter(n: number, now: number): Character {
  return {
    id: `c${now}`,
    name: n === 1 ? '無名傭兵' : `無名傭兵 #${n}`,
    alive: true,
    level: 1,
    xp: 0,
    credits: 500,
    injury: 0,
    stress: 0,
    implantLoad: STARTER_GEAR.reduce((s, i) => s + i.load, 0),
    heat: 0,
    prof: { force: { level: 0, xp: 0 }, hack: { level: 0, xp: 0 }, stealth: { level: 0, xp: 0 } },
    equipment: structuredClone(STARTER_GEAR),
    pawned: [],
    week: { key: weekKey(now), counts: {}, points: 0 },
  }
}

export function initial(now: number): Game {
  return {
    v: 1,
    character: newCharacter(1, now),
    queue: { items: [], startedAt: null, paused: false, seq: 0 },
    stopRules: DEFAULT_STOP,
    coverage: { active: false, coversZone: true, etaMin: 3 },
    log: [{ at: now, kind: 'system', text: '連線到 MORTAL CITY NETWORK。歡迎來到魔都，傭兵。' }],
    story: { stage: 'open' },
    high: null,
    highSeq: 0,
    careers: [],
    city: { supply: 41_230 },
    clock: { real: now, virtual: now, scale: 1 },
    away: null,
    systemFault: false,
    notes: [],
  }
}

export function vnow(g: Game, real = Date.now()) {
  return g.clock.virtual + (real - g.clock.real) * g.clock.scale
}

const trim = (l: LogEvent[]) => l.slice(-300)

type Action =
  | { t: 'tick'; real: number }
  | { t: 'enqueue'; jobId: string }
  | { t: 'clearQueue' }
  | { t: 'scale'; scale: number }
  | { t: 'skip'; minutes: number }
  | { t: 'dismissAway' }
  | { t: 'storyStart' }
  | { t: 'storyApproach'; id: string }
  | { t: 'storyAutoDone' }
  | { t: 'storyChoose'; optionId: string }
  | { t: 'storyClose' }
  | { t: 'highStart'; jobId: string }
  | { t: 'highAutoDone' }
  | { t: 'highChoose'; optionId: string }
  | { t: 'highClose' }
  | { t: 'buyCoverage' }
  | { t: 'treat' }
  | { t: 'redeem'; itemId: string }
  | { t: 'toggleFault' }
  | { t: 'newCharacter' }
  | { t: 'reset' }

/** 把排隊結算到虛擬時間 now，並更新城市與紀錄。 */
function advance(g: Game, now: number): { g: Game; r: ReturnType<typeof settleQueue> } {
  const r = settleQueue(g.character, g.queue, now, JOBS, g.stopRules)
  const supply = Object.entries(r.cityContrib).reduce((s, [id, n]) => s + (JOBS[id].direction === 'stealth' ? n : 0), 0)
  return {
    g: {
      ...g,
      character: r.character,
      queue: r.queue,
      log: trim([...g.log, ...r.events]),
      city: { supply: Math.min(CITY_TARGET, g.city.supply + supply) },
    },
    r,
  }
}

interface LethalCtx {
  label: string
  zone: string
  safeText: string
  lossText: string
  onSurvive: (c: Character, log: LogEvent[]) => void
}

/**
 * 危險節點判定後的共用處理（劇情委託與高階工作）：
 * 生還給報酬；被救先付帳單，付不起就抵押裝備，抵押不夠就不出勤、角色死亡；死亡寫進生涯紀錄。
 * 結束後恢復排隊（死亡則清空）。
 */
function settleLethal(g: Game, now: number, first: DangerOutcome, ctx: LethalCtx): { g: Game; outcome: DangerOutcome } {
  let outcome = first
  const c = g.character
  let character: Character = structuredClone(c)
  const log: LogEvent[] = []
  const notes = [...g.notes]
  let careers = g.careers
  if (outcome.kind === 'safe') {
    log.push({ at: now, kind: 'warn', text: `${statusPrefix(c)} ${ctx.safeText}` })
  } else if (outcome.kind === 'survived') {
    ctx.onSurvive(character, log)
  } else if (outcome.kind === 'rescued') {
    const paid = payBill(c, outcome.bill)
    if (paid.ok) {
      character = { ...paid.character, injury: 70 }
      const pawnText = paid.pawned.length ? `付不起的部分抵押了：${paid.pawned.map((i) => i.name).join('、')}（可以到「角色」贖回）。` : ''
      log.push({ at: now, kind: 'hurt', text: `✚ ${outcome.reason} 帳單 ${outcome.bill} 信用點。${pawnText}${ctx.lossText}` })
    } else {
      outcome = {
        kind: 'dead',
        reason: `受了致命傷。武裝醫療隊帳單 ¢${outcome.bill}，你的現金加上全部裝備的抵押價只有 ¢${paid.total}，他們沒有出勤。`,
      }
    }
  }
  if (outcome.kind === 'rescued_system') {
    character.injury = 50
    notes.push(`${ctx.label}：武裝醫療隊緊急搶救（系統補償）`)
    log.push({ at: now, kind: 'system', text: `✚ ${outcome.reason}` })
  } else if (outcome.kind === 'dead') {
    character.alive = false
    careers = [
      ...careers,
      { id: c.id, name: c.name, level: c.level, credits: c.credits, diedAt: now, cause: outcome.reason, weekPoints: c.week.points },
    ]
    log.push({ at: now, kind: 'stop', text: `✖ 你死了：${outcome.reason}（${ctx.zone}）` })
  }
  return {
    outcome,
    g: {
      ...g,
      character,
      careers,
      notes,
      // 結束後繼續排隊；正在做的那件保留原本的開始時間，已經做完的就從現在開始下一件
      queue: character.alive
        ? { ...g.queue, paused: false, startedAt: g.queue.startedAt ?? (g.queue.items.length ? now : null) }
        : { ...g.queue, items: [], paused: false, startedAt: null },
      log: trim([...g.log, ...log]),
    },
  }
}

export function reduce(g: Game, a: Action): Game {
  const real = a.t === 'tick' ? a.real : Date.now()
  const now = vnow(g, real)
  switch (a.t) {
    case 'tick': {
      const { g: n } = advance(g, now)
      return { ...n, clock: { ...g.clock, real, virtual: now } }
    }
    case 'enqueue': {
      const job = JOBS[a.jobId]
      if (!g.character.alive || isLethal(job) || g.queue.items.length >= QUEUE_SLOTS) return g
      const startedAt = g.queue.items.length === 0 ? now : g.queue.startedAt
      return {
        ...g,
        queue: { ...g.queue, items: [...g.queue.items, job.id], startedAt },
        log: trim([...g.log, { at: now, kind: 'system', text: `排入「${job.name}」（${g.queue.items.length + 1}/${QUEUE_SLOTS}）。` }]),
      }
    }
    case 'clearQueue':
      return {
        ...g,
        queue: { ...g.queue, items: g.queue.items.slice(0, 1) },
        log: trim([...g.log, { at: now, kind: 'stop', text: '■ 你取消了排隊中還沒開始的工作（正在做的那件會做完）。' }]),
      }
    case 'scale':
      return { ...g, clock: { real, virtual: now, scale: a.scale } }
    case 'skip': {
      // 模擬離線：直接把虛擬時鐘往前推，並產生離開期間報告
      const target = now + a.minutes * 60_000
      const before = g.character
      const { g: n, r } = advance(g, target)
      const away: AwayReport = {
        awayMs: a.minutes * 60_000,
        completed: r.completed,
        credits: r.character.credits - before.credits,
        points: r.pointsGained,
        injuryFrom: before.injury,
        injuryTo: r.character.injury,
        heatFrom: before.heat,
        heatTo: r.character.heat,
        stopped: r.stopped,
        events: r.events,
      }
      return { ...n, clock: { real, virtual: target, scale: g.clock.scale }, away }
    }
    case 'dismissAway':
      return { ...g, away: null }
    case 'storyStart':
      if (g.high && g.high.stage !== 'done') return g
      // 接劇情委託：排隊中還沒開始的工作暫停
      return {
        ...g,
        story: { stage: 'prep' },
        queue: { ...g.queue, paused: g.queue.items.length > 0 },
        log: trim([
          ...g.log,
          { at: now, kind: 'system', text: `接下劇情委託「${TEST_CASE.title}」。${g.queue.items.length ? '排隊中的街頭工作已暫停。' : ''}` },
        ]),
      }
    case 'storyApproach':
      return { ...g, story: { stage: 'auto', approach: a.id } }
    case 'storyAutoDone':
      return {
        ...g,
        character: { ...g.character, injury: Math.min(100, g.character.injury + 18), stress: g.character.stress + 6 },
        story: { ...g.story, stage: 'danger' },
      }
    case 'storyChoose': {
      const opt = TEST_CASE.danger.options.find((o) => o.id === a.optionId)!
      const c = g.character
      const outcome = resolveDanger(c, opt, g.coverage, hashSeed(c.id, TEST_CASE.id, opt.id), g.systemFault)
      const r = settleLethal(g, now, outcome, {
        label: TEST_CASE.id,
        zone: TEST_CASE.zone,
        safeText: '你丟下箱子撤離。委託失敗，但你活著。',
        lossText: '箱子沒了。',
        onSurvive: (ch, log) => {
          ch.credits += TEST_CASE.reward
          ch.heat = Math.min(5, ch.heat + 1)
          log.push({ at: now, kind: 'job', text: `${statusPrefix(ch)} 你抱著箱子衝出隧道。+${TEST_CASE.reward} 信用點，通緝 +1。` })
        },
      })
      return { ...r.g, story: { ...g.story, stage: 'done', outcome: r.outcome } }
    }
    case 'highStart': {
      const job = JOBS[a.jobId]
      const busyStory = g.story.stage === 'prep' || g.story.stage === 'auto' || g.story.stage === 'danger'
      if (!g.character.alive || !isLethal(job) || busyStory || (g.high && g.high.stage !== 'done')) return g
      return {
        ...g,
        high: { jobId: job.id, stage: 'auto' },
        queue: { ...g.queue, paused: g.queue.items.length > 0 },
        log: trim([
          ...g.log,
          { at: now, kind: 'warn', text: `⚠ 接下高階工作「${job.name}」（可能永久死亡）。${g.queue.items.length ? '排隊中的街頭工作已暫停。' : ''}` },
        ]),
      }
    }
    case 'highAutoDone': {
      if (!g.high) return g
      const job = JOBS[g.high.jobId]
      return {
        ...g,
        character: { ...g.character, injury: Math.min(100, g.character.injury + Math.round(job.injury / 2)), stress: g.character.stress + job.stress },
        high: { ...g.high, stage: 'danger' },
      }
    }
    case 'highChoose': {
      if (!g.high) return g
      const job = JOBS[g.high.jobId]
      const opt = highDanger(job).options.find((o) => o.id === a.optionId)!
      const c = g.character
      const outcome = resolveDanger(c, opt, g.coverage, hashSeed(c.id, 'high', job.id, g.highSeq), g.systemFault)
      let supply = 0
      const r = settleLethal(g, now, outcome, {
        label: job.name,
        zone: '高階工作',
        safeText: `你放棄了「${job.name}」，空手撤離。`,
        lossText: '這份工作的報酬沒了。',
        onSurvive: (ch, log) => {
          const reward = jobReward(job, ch.prof[job.direction].level)
          ch.credits += reward
          ch.heat = Math.min(5, ch.heat + job.heat)
          const extra: LogEvent[] = []
          const pts = grantProgress(ch, job, true, now, extra)
          if (job.direction === 'stealth') supply = 1
          log.push({ at: now, kind: 'job', text: `${statusPrefix(ch)} 完成高階工作「${job.name}」。+${reward} 信用點，週榜 +${pts}，通緝 +${job.heat}。` }, ...extra)
        },
      })
      return {
        ...r.g,
        city: { supply: Math.min(CITY_TARGET, r.g.city.supply + supply) },
        high: { ...g.high, stage: 'done', outcome: r.outcome },
        highSeq: g.highSeq + 1,
      }
    }
    case 'highClose':
      return { ...g, high: null }
    case 'storyClose':
      return { ...g, story: { stage: g.story.outcome?.kind === 'safe' || !g.character.alive ? 'open' : 'done', outcome: g.story.outcome } }
    case 'buyCoverage': {
      if (g.coverage.active || g.character.credits < 400) return g
      return {
        ...g,
        character: { ...g.character, credits: g.character.credits - 400 },
        coverage: { ...g.coverage, active: true },
        log: trim([...g.log, { at: now, kind: 'system', text: '購買武裝醫療基本保單（-400 信用點）。覆蓋新宿街區，預估 3 分鐘抵達。' }]),
      }
    }
    case 'treat': {
      const cost = g.character.injury * 6
      if (g.character.credits < cost || g.character.injury === 0) return g
      return {
        ...g,
        character: { ...g.character, credits: g.character.credits - cost, injury: 0, stress: Math.max(0, g.character.stress - 10) },
        log: trim([...g.log, { at: now, kind: 'system', text: `白蛇的診所幫你縫好了傷口（-${cost} 信用點）。` }]),
      }
    }
    case 'redeem': {
      const c = redeem(g.character, a.itemId)
      if (!c) return g
      const item = g.character.pawned.find((p) => p.item.id === a.itemId)!
      return {
        ...g,
        character: c,
        log: trim([...g.log, { at: now, kind: 'system', text: `贖回「${item.item.name}」（-${item.redeem} 信用點）。` }]),
      }
    }
    case 'toggleFault':
      return { ...g, systemFault: !g.systemFault }
    case 'newCharacter': {
      const n = g.careers.length + 1
      const c = newCharacter(n, real)
      return {
        ...initial(real),
        character: c,
        careers: g.careers,
        city: g.city,
        clock: g.clock,
        log: [{ at: now, kind: 'system', text: `新的生涯開始：${c.name}。前一個角色的紀錄保存在「紀錄」裡。` }],
      }
    }
    case 'reset':
      return initial(real)
  }
}

function load(): Game {
  const now = Date.now()
  try {
    const raw = localStorage.getItem(KEY)
    if (raw) {
      const g = JSON.parse(raw) as Game
      if (g.v === 1) {
        // 真的離開 ≥3 分鐘：伺服器補算（這裡在本機模擬）並給報告
        const gapReal = now - g.clock.real
        if (gapReal >= 180_000 && g.queue.items.length) {
          const minutes = (gapReal * g.clock.scale) / 60_000
          return reduce({ ...g, clock: { ...g.clock, real: now } }, { t: 'skip', minutes })
        }
        return g
      }
    }
  } catch {
    /* 存檔壞掉就重來 */
  }
  return initial(now)
}

export function useGame() {
  const [g, dispatch] = useReducer(reduce, undefined, load)
  useEffect(() => {
    try {
      localStorage.setItem(KEY, JSON.stringify(g))
    } catch {
      /* 私密模式等情況忽略 */
    }
  }, [g])
  useEffect(() => {
    const id = setInterval(() => dispatch({ t: 'tick', real: Date.now() }), 1000)
    return () => clearInterval(id)
  }, [])
  const act = useCallback((a: Action) => dispatch(a), [])
  return { g, act, now: vnow(g) }
}

export { jobReward }
