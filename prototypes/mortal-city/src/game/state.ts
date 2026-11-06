import { useCallback, useEffect, useReducer } from 'react'
import {
  type Character,
  type Coverage,
  type DangerOption,
  type DangerOutcome,
  type Enemy,
  type FightResult,
  type Tactic,
  DEFAULT_STOP,
  type LogEvent,
  type Queue,
  type StopRules,
  addXp,
  approachBonus,
  grantProgress,
  hashSeed,
  payBill,
  redeem,
  isLethal,
  jobReward,
  resolveDanger,
  resolveFight,
  tacticsFor,
  rest,
  workBlock,
  type Attr,
  ATTR_MAX,
  ATTR_LABEL,
  ATTR_START_POINTS,
  baseAttrs,
  attrLock,
  implantRoom,
  sellValue,
  type Item,
  SEVERE_INJURY,
  CLINIC,
  HOSPITAL,
  POLICIES,
  policyOf,
  settleQueue,
  statusPrefix,
  talentLock,
  TALENTS,
  weekKey,
} from '../rules/core'
import { CITY_TARGET, FIXERS, JOBS, QUEUE_SLOTS, STARTER_GEAR, highDanger } from '../content/data'

const FIXER_NAME = Object.fromEntries(Object.values(FIXERS).map((f) => [f.id, f.name]))
import { ITEMS, SHOPS, fightLoot, makeItem, rollKind, shopPrice, streetLoot } from '../content/items'
import { CONTACTS, CONTACT_BY_JOB, DM_JOBS, UNIQUE_JOBS, offerOf, uniqueLock } from '../content/contacts'

/** 排隊用的工作表：看板上的街頭工作＋私人通訊的獨特委託。 */
export const ALL_JOBS = { ...JOBS, ...UNIQUE_JOBS, ...DM_JOBS }
import { CASE_BY_ID, type CaseOption, type CaseRecord, type StoryCase, caseUnlocked, optionLock } from '../content/cases'

/** 正在進行的劇情委託的階段；結案後的結果記在 Game.cases。 */
export type StoryStage = 'open' | 'prep' | 'auto' | 'fight' | 'danger'

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
  story: { caseId: string | null; stage: StoryStage; approach?: string; fight?: FightResult; option?: string }
  /** 在公寓休養累積、還沒換成恢復的時間（毫秒）。 */
  rest: { ms: number; heatMs: number }
  /** 這個角色已結案的劇情委託（一次性；新角色清空）。 */
  cases: Record<string, CaseRecord>
  high: { jobId: string; stage: 'auto' | 'fight' | 'danger' | 'done'; outcome?: DangerOutcome; fight?: FightResult } | null
  highSeq: number
  careers: Career[]
  city: { supply: number }
  clock: { real: number; virtual: number; scale: number }
  away: AwayReport | null
  systemFault: boolean
  notes: string[] // 生涯紀錄裡的特殊事件（例如系統補償搶救）
  /** 私人通訊：中間人 id → 對話串（跟著角色，新角色清空）。 */
  dm: Record<string, DmThread>
  /** 劇情委託論壇串已經播到第幾則（案件 id → 則數），回來不重播。 */
  seen: Record<string, number>
  /** 已經追問過的問題（`案件id#第幾題`）。 */
  asked: string[]
}

export interface DmMsg {
  from: 'npc' | 'me'
  text: string
  at: number
}

export interface DmThread {
  msgs: DmMsg[]
  /** 已經播放過幾則（動畫從這裡接著播）。 */
  seen: number
  /** 等你回覆的委託（工作 id）。 */
  offer: string | null
  /** 這個遊戲時間之後才發下一件委託。 */
  nextAt: number
  /** 已經發過幾件一般委託（輪流挑）。 */
  served: number
  /** 已經說過幾句閒聊。 */
  lines: number
  /** 獨特委託的完成訊息送出了沒。 */
  uniqueDone: boolean
}

/** 接了或推掉一件私訊委託後，多久（遊戲時間）才發下一件。 */
export const DM_COOLDOWN = 10 * 60_000
/** 每條對話串最多留幾則，超過就丟掉最舊的。 */
export const DM_KEEP = 40

const KEY = 'mortal-city:v9'
/** 診所治療至少花這麼多，白蛇才多信任你一點（縫一針 ¢6 不算）。 */
const CLINIC_TRUST_MIN = 100

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
    attrs: baseAttrs(),
    attrPoints: ATTR_START_POINTS,
    stash: [],
    talentPoints: 0,
    talents: [],
    fame: 0,
    trust: {},
    uniqueDone: [],
  }
}

export function initial(now: number): Game {
  return syncDm({
    v: 1,
    character: newCharacter(1, now),
    queue: { items: [], startedAt: null, paused: false, seq: 0 },
    stopRules: DEFAULT_STOP,
    coverage: { active: false, coversZone: true, etaMin: 3 },
    log: [{ at: now, kind: 'system', text: '連線到 MORTAL CITY NETWORK。歡迎來到魔都，傭兵。' }],
    story: { caseId: null, stage: 'open' },
    cases: {},
    rest: { ms: 0, heatMs: 0 },
    high: null,
    highSeq: 0,
    careers: [],
    city: { supply: 41_230 },
    clock: { real: now, virtual: now, scale: 1 },
    away: null,
    systemFault: false,
    notes: [],
    dm: {},
    seen: {},
    asked: [],
  })
}

const emptyThread = (): DmThread => ({ msgs: [], seen: 0, offer: null, nextAt: 0, served: 0, lines: 0, uniqueDone: false })

/**
 * 對話串的同步（每個動作之後跑一次，沒變化就回傳原物件）：信任到了就說閒聊、
 * 獨特委託做完就回訊息、沒有待回覆的委託而且冷卻過了就發下一件（獨特優先，一般輪流）。
 */
export function syncDm(g: Game): Game {
  const c = g.character
  if (!c.alive) return g
  let dm = g.dm
  for (const k of CONTACTS) {
    const old = dm[k.fixerId] ?? emptyThread()
    const th: DmThread = { ...old, msgs: [...old.msgs] }
    const at = g.clock.virtual
    const say = (text: string, from: DmMsg['from'] = 'npc') => th.msgs.push({ from, text, at })
    const trust = c.trust[k.fixerId] ?? 0
    while (th.lines < k.lines.length && trust >= k.lines[th.lines].trust) say(k.lines[th.lines++].text)
    if (!th.uniqueDone && c.uniqueDone.includes(k.unique.jobId)) {
      say(k.unique.done)
      th.uniqueDone = true
    }
    if (!th.offer && at >= th.nextAt) {
      const queued = (id: string) => g.queue.items.includes(id)
      const pool = k.requests.filter((r) => trust >= r.trust && !queued(r.jobId))
      const pick = !uniqueLock(c, k.unique.jobId) && !queued(k.unique.jobId) ? k.unique : pool.length ? pool[th.served++ % pool.length] : undefined
      if (pick) {
        th.offer = pick.jobId
        for (const t of pick.intro) say(t)
      }
    }
    if (th.msgs.length === old.msgs.length && th.offer === old.offer && dm[k.fixerId]) continue
    const drop = Math.max(0, th.msgs.length - DM_KEEP)
    if (drop) {
      th.msgs = th.msgs.slice(drop)
      th.seen = Math.max(0, th.seen - drop)
    }
    dm = { ...dm, [k.fixerId]: th }
  }
  return dm === g.dm ? g : { ...g, dm }
}

/** 對話串裡還沒看過的則數或待回覆的委託：通訊入口的紅點。 */
export function dmUnread(g: Game) {
  return Object.values(g.dm).filter((t) => t.seen < t.msgs.length || t.offer).length
}

/** 私訊委託為什麼現在不能接。 */
export function dmAcceptBlock(g: Game) {
  return workBlock(g.character) ?? (g.queue.items.length >= QUEUE_SLOTS ? `排隊已滿（${QUEUE_SLOTS} 件）` : undefined)
}

export function vnow(g: Game, real = Date.now()) {
  return g.clock.virtual + (real - g.clock.real) * g.clock.scale
}

const trim = (l: LogEvent[]) => l.slice(-300)

/** 劇情委託進行中（準備、自動段或等待選擇）。 */
export const storyBusy = (g: Game) => g.story.caseId !== null

/** 開打：鎖住的戰術不能用；結果一次算完（seed 決定），傷勢與壓力立刻套用，畫面再逐回合播放。 */
function startFight(c: Character, enemy: Enemy, tactic: Tactic, seed: number): { c: Character; f: FightResult } | null {
  if (tacticsFor(c, enemy).find((t) => t.id === tactic)?.locked) return null
  const f = resolveFight(c, enemy, tactic, seed)
  return { c: { ...c, injury: f.injury, stress: c.stress + f.stress }, f }
}

/** 正在打的是哪一場：危險節點選的「打」，或做法本身的遭遇戰。 */
export function fightEnemy(sc: StoryCase, st: Game['story']): Enemy {
  if (st.option) return sc.danger.options.find((o) => o.id === st.option)!.fight!
  return sc.approaches.find((x) => x.id === st.approach)!.fight!
}

/**
 * 結案：判定結果交給 settleLethal（被救的帳單、死亡）；pay 時，不冒險或生還照選項付報酬、通緝、治療與經驗。
 * 夜鴉插播，紀錄寫進 Game.cases。
 */
function closeCase(g: Game, now: number, sc: StoryCase, picked: CaseOption, outcome: DangerOutcome, pay: boolean): Game {
  const paid = (ch: Character, log: LogEvent[]) => {
    if (!pay) return
    ch.credits += picked.reward
    ch.heat = Math.min(5, ch.heat + (picked.heat ?? 0))
    if (picked.heal) ch.injury = 0
    const parts = [picked.reward ? `+${picked.reward} 信用點` : '沒有報酬', picked.heat ? `通緝 +${picked.heat}` : '', picked.heal ? '傷口縫好了' : '']
    log.push({ at: now, kind: picked.reward ? 'job' : 'warn', text: `${statusPrefix(ch)} 「${sc.title}」結案：${parts.filter(Boolean).join('，')}。` })
    addXp(ch, sc.xp, now, log)
    // 結案就有名聲與委託人的信任；冒險生還給得多
    // 測試案可以重設重玩，不給名聲與信任（不然能刷）
    const won = outcome.kind === 'survived'
    if (sc.kind !== 'test') {
      ch.fame += won ? 10 : 3
      ch.trust[sc.fixerId] = (ch.trust[sc.fixerId] ?? 0) + (won ? 3 : 1)
    }
    if (won)
      for (const l of sc.loot ?? []) stashLoot(ch, rollKind(hashSeed(ch.id, sc.id, 'reward', l.kind), l.kind, l.chance), log, now, sc.title)
  }
  const r = settleLethal(g, now, outcome, { label: sc.title, zone: sc.zone, safeText: outcome.reason, lossText: sc.lossText, onSurvive: paid })
  let next = r.g
  if (r.outcome.kind === 'safe') {
    // 不冒險也算結案；有部分報酬就照付
    const ch = structuredClone(next.character)
    const log: LogEvent[] = []
    paid(ch, log)
    next = { ...next, character: ch, log: trim([...next.log, ...log]) }
  }
  const won = r.outcome.kind === 'survived'
  if (sc.broadcast && next.character.alive)
    next = { ...next, log: trim([...next.log, { at: now, kind: 'system', text: won ? sc.broadcast.survived : sc.broadcast.other }]) }
  const record: CaseRecord = { approach: g.story.approach ?? '', optionId: picked.id, outcome: r.outcome.kind, reason: r.outcome.reason }
  return { ...next, story: { caseId: null, stage: 'open' }, cases: { ...next.cases, [sc.id]: record } }
}

/** 戰利品放進背包並寫紀錄。直接改 c。 */
function stashLoot(c: Character, item: Item | null, log: LogEvent[], at: number, from: string) {
  if (!item) return
  c.stash.push(item)
  log.push({ at, kind: 'gain', text: `◆ 戰利品（${from}）：${item.name}，放進背包。` })
}

/** 任務進行中不能換裝備或買東西。 */
export const gearBusy = (g: Game) => storyBusy(g) || !!(g.high && g.high.stage !== 'done')

/** 委託中途結束（打輸撤退）：排隊照 settleLethal 的方式恢復。 */
function resumeQueue(q: Queue, now: number): Queue {
  return { ...q, paused: false, startedAt: q.startedAt ?? (q.items.length ? now : null) }
}

/** 危險節點選項套上做法的修正：做法本身的風險，再扣掉該方向的裝備與熟練度。 */
export function caseDangerOption(c: Character, sc: StoryCase, approachId: string | undefined, optionId: string): DangerOption {
  const opt = sc.danger.options.find((o) => o.id === optionId)!
  const ap = sc.approaches.find((x) => x.id === approachId) ?? sc.approaches[0]
  if (!opt.lethal) return opt
  return { ...opt, lethalBase: Math.min(0.95, Math.max(0.02, opt.lethalBase + ap.lethalMod - approachBonus(c, ap.direction))) }
}

type Action =
  | { t: 'tick'; real: number }
  | { t: 'enqueue'; jobId: string }
  | { t: 'clearQueue' }
  | { t: 'scale'; scale: number }
  | { t: 'skip'; minutes: number }
  | { t: 'dismissAway' }
  | { t: 'storyStart'; caseId: string }
  | { t: 'storyApproach'; id: string }
  | { t: 'storyAutoDone' }
  | { t: 'storyChoose'; optionId: string }
  | { t: 'storyRetry'; caseId: string }
  | { t: 'storyFight'; tactic: Tactic }
  | { t: 'storyFightDone' }
  | { t: 'highFight'; tactic: Tactic }
  | { t: 'highFightDone' }
  | { t: 'highStart'; jobId: string }
  | { t: 'highAutoDone' }
  | { t: 'highChoose'; optionId: string }
  | { t: 'highClose' }
  | { t: 'buyCoverage'; tier: number }
  | { t: 'treat' }
  | { t: 'hospital' }
  | { t: 'setTactic'; tactic: Tactic }
  | { t: 'raiseAttr'; attr: Attr }
  | { t: 'learnTalent'; id: string }
  | { t: 'setLook'; look: 'a' | 'b' }
  | { t: 'dmReply'; fixerId: string; accept: boolean }
  | { t: 'seen'; key: string; n: number }
  | { t: 'ask'; caseId: string; i: number }
  | { t: 'buy'; kind: string }
  | { t: 'equip'; itemId: string }
  | { t: 'unequip'; itemId: string }
  | { t: 'sell'; itemId: string }
  | { t: 'redeem'; itemId: string }
  | { t: 'toggleFault' }
  | { t: 'newCharacter' }
  | { t: 'reset' }

/** 把排隊結算到虛擬時間 now，並更新城市與紀錄。 */
function advance(g: Game, now: number): { g: Game; r: ReturnType<typeof settleQueue> } {
  // 休養：沒有排隊、沒有委託進行中的時間才算。ponytail: 只看這段開始時是否閒著，排隊中途做完後剩下的時間不算休養
  const idle = g.character.alive && g.queue.items.length === 0 && !storyBusy(g) && !(g.high && g.high.stage !== 'done')
  let character = g.character
  let restCarry = g.rest
  const restLog: LogEvent[] = []
  if (idle && (character.injury > 0 || character.heat > 0)) {
    character = structuredClone(character)
    const before = { injury: character.injury, heat: character.heat }
    restCarry = rest(character, g.rest, Math.max(0, now - g.clock.virtual))
    if (before.injury >= SEVERE_INJURY && character.injury < SEVERE_INJURY)
      restLog.push({ at: now, kind: 'system', text: `${statusPrefix(character)} 休養到能下床了，可以再接工作。` })
    if (character.heat < before.heat) restLog.push({ at: now, kind: 'system', text: `${statusPrefix(character)} 你低調了一陣子，MPD 的注意力移開了（通緝 −${before.heat - character.heat}）。` })
  } else if (!idle) restCarry = { ms: 0, heatMs: 0 }
  const r = settleQueue(character, g.queue, now, ALL_JOBS, g.stopRules, streetLoot)
  // 獨特委託做成：中間人送一件東西＋私人訊息
  for (const id of r.character.uniqueDone) {
    if (character.uniqueDone.includes(id)) continue
    const k = CONTACT_BY_JOB[id]
    const gift = makeItem(k.unique.gift, `${id}-gift`)
    r.character.stash.push(gift)
    const at = r.events.find((e) => e.kind === 'job' && e.text.includes(`「${UNIQUE_JOBS[id].name}」`))?.at ?? now
    r.events.push({ at, kind: 'gain', text: `◆ ${FIXER_NAME[k.fixerId]}傳來私訊，附上一件「${gift.name}」，放進背包。` })
  }
  const supply = Object.entries(r.cityContrib).reduce((s, [id, n]) => s + (ALL_JOBS[id].direction === 'stealth' ? n : 0), 0)
  return {
    g: {
      ...g,
      rest: restCarry,
      character: r.character,
      queue: r.queue,
      log: trim([...g.log, ...restLog, ...r.events]),
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
  const n = reduceCore(g, a)
  return n === g ? g : syncDm(n)
}

function reduceCore(g: Game, a: Action): Game {
  const real = a.t === 'tick' ? a.real : Date.now()
  const now = vnow(g, real)
  switch (a.t) {
    case 'tick': {
      const { g: n } = advance(g, now)
      return { ...n, clock: { ...g.clock, real, virtual: now } }
    }
    case 'enqueue': {
      const job = ALL_JOBS[a.jobId]
      // 私訊的委託只能從私訊回覆接（dmReply），看板這條路不收
      if (!job || job.dm || job.unique || workBlock(g.character) || isLethal(job) || g.queue.items.length >= QUEUE_SLOTS) return g
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
    case 'storyStart': {
      const sc = CASE_BY_ID[a.caseId]
      if (!sc || workBlock(g.character) || storyBusy(g) || (g.high && g.high.stage !== 'done')) return g
      if (g.cases[sc.id] || !caseUnlocked(sc, g.cases)) return g
      // 接劇情委託：排隊中還沒開始的工作暫停
      return {
        ...g,
        story: { caseId: sc.id, stage: 'prep' },
        queue: { ...g.queue, paused: g.queue.items.length > 0 },
        log: trim([
          ...g.log,
          { at: now, kind: 'system', text: `接下劇情委託「${sc.title}」。${g.queue.items.length ? '排隊中的街頭工作已暫停。' : ''}` },
        ]),
      }
    }
    case 'storyApproach': {
      if (g.story.stage !== 'prep') return g
      const ap = CASE_BY_ID[g.story.caseId!].approaches.find((x) => x.id === a.id)
      if (!ap || attrLock(g.character, ap.needs)) return g
      return { ...g, story: { ...g.story, stage: 'auto', approach: a.id } }
    }
    case 'storyAutoDone': {
      if (g.story.stage !== 'auto') return g
      const sc = CASE_BY_ID[g.story.caseId!]
      const ap = sc.approaches.find((x) => x.id === g.story.approach) ?? sc.approaches[0]
      return {
        ...g,
        character: { ...g.character, injury: Math.min(100, g.character.injury + ap.injury), stress: g.character.stress + 6 },
        story: { ...g.story, stage: ap.fight ? 'fight' : 'danger' },
      }
    }
    case 'storyFight': {
      if (g.story.stage !== 'fight' || g.story.fight) return g
      const sc = CASE_BY_ID[g.story.caseId!]
      const enemy = fightEnemy(sc, g.story)
      const r = startFight(g.character, enemy, a.tactic, hashSeed(g.character.id, sc.id, 'fight', g.story.option ?? ''))
      if (!r) return g
      return { ...g, character: r.c, story: { ...g.story, fight: r.f } }
    }
    case 'storyFightDone': {
      const f = g.story.fight
      if (g.story.stage !== 'fight' || !f) return g
      const sc = CASE_BY_ID[g.story.caseId!]
      if (f.won) {
        // 打贏的戰利品（自己的 seed）
        const c = structuredClone(g.character)
        const log: LogEvent[] = []
        stashLoot(c, fightLoot(hashSeed(c.id, sc.id, 'loot', g.story.option ?? 'approach')), log, now, f.enemy.name)
        g = { ...g, character: c, log: trim([...g.log, ...log]) }
      }
      if (g.story.option) {
        // 危險節點選了「打」：打贏＝生還；打輸才擲致命判定，沒死也只是被打退、沒有報酬
        const picked = sc.danger.options.find((o) => o.id === g.story.option)!
        if (f.won) return closeCase(g, now, sc, picked, { kind: 'survived', reason: picked.text }, true)
        const c = g.character
        const opt = caseDangerOption(c, sc, g.story.approach, picked.id)
        const o = resolveDanger(c, opt, g.coverage, hashSeed(c.id, sc.id, opt.id), g.systemFault)
        const lost = `你被${f.enemy.name}打倒在地，最後只能拖著傷撤退。委託失敗，沒有報酬。`
        return closeCase(g, now, sc, picked, o.kind === 'survived' ? { kind: 'safe', reason: lost } : o, false)
      }
      const ap = sc.approaches.find((x) => x.id === g.story.approach)!
      if (f.won) {
        const heat = ap.fightHeat ?? 0
        const c = { ...g.character, heat: Math.min(5, g.character.heat + heat) }
        const log = heat ? [{ at: now, kind: 'warn' as const, text: `${statusPrefix(c)} 你打倒了${f.enemy.name}，MPD 記住了你的臉（通緝 +${heat}）。` }] : []
        return { ...g, character: c, log: trim([...g.log, ...log]), story: { ...g.story, stage: 'danger', fight: undefined } }
      }
      const reason = `你被${f.enemy.name}打退了，只能先撤。委託失敗，沒有報酬。`
      const record: CaseRecord = { approach: g.story.approach ?? '', optionId: 'retreat', outcome: 'safe', reason }
      return {
        ...g,
        story: { caseId: null, stage: 'open' },
        cases: { ...g.cases, [sc.id]: record },
        queue: resumeQueue(g.queue, now),
        log: trim([...g.log, { at: now, kind: 'warn', text: `${statusPrefix(g.character)} 「${sc.title}」：${reason}` }]),
      }
    }
    case 'storyChoose': {
      if (g.story.stage !== 'danger') return g
      const sc = CASE_BY_ID[g.story.caseId!]
      const picked = sc.danger.options.find((o) => o.id === a.optionId)
      if (!picked || optionLock(g.character, g.story.approach, picked) !== undefined) return g
      if (picked.fight) return { ...g, story: { ...g.story, stage: 'fight', option: picked.id, fight: undefined } }
      const c = g.character
      const opt = caseDangerOption(c, sc, g.story.approach, picked.id)
      let outcome = resolveDanger(c, opt, g.coverage, hashSeed(c.id, sc.id, opt.id), g.systemFault)
      if (outcome.kind === 'safe' || outcome.kind === 'survived') outcome = { kind: picked.wins ? 'survived' : outcome.kind, reason: picked.text }
      return closeCase(g, now, sc, picked, outcome, true)
    }
    case 'storyRetry': {
      // 只有測試案可以重來；正式案一個角色一次
      if (CASE_BY_ID[a.caseId]?.kind !== 'test' || !g.cases[a.caseId]) return g
      const { [a.caseId]: _, ...rest } = g.cases
      return { ...g, cases: rest }
    }
    case 'highStart': {
      const job = JOBS[a.jobId]
      if (workBlock(g.character) || !isLethal(job) || storyBusy(g) || (g.high && g.high.stage !== 'done')) return g
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
      const fight = highDanger(job).fight
      return {
        ...g,
        character: {
          ...g.character,
          injury: fight ? g.character.injury : Math.min(100, g.character.injury + Math.round(job.injury / 2)),
          stress: g.character.stress + job.stress,
        },
        high: { ...g.high, stage: fight ? 'fight' : 'danger' },
      }
    }
    case 'highFight': {
      if (!g.high || g.high.stage !== 'fight' || g.high.fight) return g
      const job = JOBS[g.high.jobId]
      const r = startFight(g.character, highDanger(job).fight!, a.tactic, hashSeed(g.character.id, 'high-fight', job.id, g.highSeq))
      if (!r) return g
      return { ...g, character: r.c, high: { ...g.high, fight: r.f } }
    }
    case 'highFightDone': {
      const f = g.high?.fight
      if (!g.high || g.high.stage !== 'fight' || !f) return g
      if (f.won) {
        const c = structuredClone(g.character)
        const log: LogEvent[] = []
        stashLoot(c, fightLoot(hashSeed(c.id, 'high-loot', g.high.jobId, g.highSeq)), log, now, f.enemy.name)
        return { ...g, character: c, log: trim([...g.log, ...log]), high: { ...g.high, stage: 'danger' } }
      }
      const job = JOBS[g.high.jobId]
      const reason = `你被${f.enemy.name}打退了，只能撤離。這份工作沒有報酬。`
      return {
        ...g,
        high: { ...g.high, stage: 'done', outcome: { kind: 'safe', reason } },
        highSeq: g.highSeq + 1,
        queue: resumeQueue(g.queue, now),
        log: trim([...g.log, { at: now, kind: 'warn', text: `${statusPrefix(g.character)} 「${job.name}」：${reason}` }]),
      }
    }
    case 'highChoose': {
      if (!g.high) return g
      const job = JOBS[g.high.jobId]
      const opt = highDanger(job).options.find((o) => o.id === a.optionId)
      if (!opt || attrLock(g.character, opt.attrNeeds)) return g
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
          stashLoot(ch, fightLoot(hashSeed(ch.id, 'high-reward', job.id, g.highSeq)), extra, now, job.name)
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
    case 'buyCoverage': {
      // 買或升級保單：只付跟目前級別的差額
      const pol = POLICIES[a.tier - 1]
      const cur = policyOf(g.coverage)
      if (!pol || (cur && cur.tier >= pol.tier)) return g
      const cost = pol.price - (cur?.price ?? 0)
      if (g.character.credits < cost) return g
      return {
        ...g,
        character: { ...g.character, credits: g.character.credits - cost },
        coverage: { ...g.coverage, active: true, tier: pol.tier, etaMin: pol.eta },
        log: trim([...g.log, { at: now, kind: 'system', text: `${cur ? '升級' : '購買'}武裝醫療${pol.name}保單（-${cost} 信用點）：${pol.note}，救援帳單 ¢${pol.bill}。` }]),
      }
    }
    case 'treat': {
      const cost = g.character.injury * CLINIC.perPoint
      if (!g.character.alive || g.character.credits < cost || g.character.injury === 0) return g
      return {
        ...g,
        character: { ...g.character, credits: g.character.credits - cost, injury: 0, stress: Math.max(0, g.character.stress - CLINIC.stress), trust: { ...g.character.trust, snake: (g.character.trust.snake ?? 0) + (cost >= CLINIC_TRUST_MIN ? 1 : 0) } },
        log: trim([...g.log, { at: now, kind: 'system', text: `白蛇的診所幫你縫好了傷口（-${cost} 信用點）。` }]),
      }
    }
    case 'hospital': {
      const c = g.character
      const cost = c.injury * HOSPITAL.perPoint
      if (!c.alive || c.credits < cost || c.heat > HOSPITAL.maxHeat || (c.injury === 0 && c.stress === 0)) return g
      return {
        ...g,
        character: { ...c, credits: c.credits - cost, injury: 0, stress: Math.max(0, c.stress - HOSPITAL.stress) },
        log: trim([...g.log, { at: now, kind: 'system', text: `魔都綜合醫院：傷口與神經都做了完整處理（-${cost} 信用點，神經壓力 −${HOSPITAL.stress}）。` }]),
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
    case 'buy': {
      // 白蛇的診所：買了直接裝上（裝不下就不賣）；老K的貨架：放進背包，要先有信任
      const c = g.character
      const shop = SHOPS.find((x) => x.kinds.includes(a.kind))
      if (!shop || !c.alive || gearBusy(g)) return g
      const def = ITEMS[a.kind]
      const price = shopPrice(shop, a.kind)
      if (c.credits < price || (shop.trust && (c.trust[shop.fixerId] ?? 0) < shop.trust)) return g
      if (shop.install && implantRoom(c) < def.load) return g
      const item = makeItem(a.kind, now)
      const character = shop.install
        ? { ...c, credits: c.credits - price, equipment: [...c.equipment, item], implantLoad: c.implantLoad + item.load, trust: { ...c.trust, snake: (c.trust.snake ?? 0) + 1 } }
        : { ...c, credits: c.credits - price, stash: [...c.stash, item] }
      const text = shop.install
        ? `白蛇幫你裝上了「${item.name}」（-${price} 信用點，義體負荷 +${item.load}）。`
        : `你在老K的後巷貨架買了「${item.name}」（-${price} 信用點），放進背包。`
      return { ...g, character, log: trim([...g.log, { at: now, kind: 'system', text }]) }
    }
    case 'equip': {
      // 從背包裝上：義體要裝得下；武器與駭客終端一次一件，換下來的放回背包
      const c = g.character
      const item = c.stash.find((i) => i.id === a.itemId)
      if (!c.alive || gearBusy(g) || !item) return g
      if (item.slot === 'implant' && implantRoom(c) < item.load) return g
      const swapped = item.slot === 'implant' ? [] : c.equipment.filter((i) => i.slot === item.slot)
      return {
        ...g,
        character: {
          ...c,
          stash: [...c.stash.filter((i) => i.id !== item.id), ...swapped],
          equipment: [...c.equipment.filter((i) => !swapped.includes(i)), item],
          implantLoad: c.implantLoad + item.load,
        },
        log: trim([...g.log, { at: now, kind: 'system', text: `裝上「${item.name}」${swapped.length ? `，換下「${swapped[0].name}」` : ''}。` }]),
      }
    }
    case 'unequip': {
      const c = g.character
      const item = c.equipment.find((i) => i.id === a.itemId)
      if (!c.alive || gearBusy(g) || !item) return g
      return {
        ...g,
        character: { ...c, equipment: c.equipment.filter((i) => i.id !== item.id), stash: [...c.stash, item], implantLoad: c.implantLoad - item.load },
        log: trim([...g.log, { at: now, kind: 'system', text: `卸下「${item.name}」，放進背包。` }]),
      }
    }
    case 'sell': {
      const c = g.character
      const item = c.stash.find((i) => i.id === a.itemId)
      if (!c.alive || !item) return g
      return {
        ...g,
        character: { ...c, stash: c.stash.filter((i) => i.id !== item.id), credits: c.credits + sellValue(item) },
        log: trim([...g.log, { at: now, kind: 'system', text: `賣掉「${item.name}」（+${sellValue(item)} 信用點）。` }]),
      }
    }
    case 'raiseAttr': {
      // 分配屬性點：不能退回
      const c = g.character
      if (!c.alive || c.attrPoints <= 0 || c.attrs[a.attr] >= ATTR_MAX) return g
      return {
        ...g,
        character: { ...c, attrs: { ...c.attrs, [a.attr]: c.attrs[a.attr] + 1 }, attrPoints: c.attrPoints - 1 },
        log: trim([...g.log, { at: now, kind: 'level', text: `★ ${ATTR_LABEL[a.attr]}提升到 ${c.attrs[a.attr] + 1}。` }]),
      }
    }
    case 'setLook':
      return g.character.alive ? { ...g, character: { ...g.character, look: a.look } } : g
    case 'learnTalent': {
      const c = g.character
      const t = TALENTS.find((x) => x.id === a.id)
      if (!c.alive || !t || talentLock(c, a.id)) return g
      return {
        ...g,
        character: { ...c, talents: [...c.talents, t.id], talentPoints: c.talentPoints - 1 },
        log: trim([...g.log, { at: now, kind: 'level', text: `★ 學會天賦「${t.name}」：${t.desc}。` }]),
      }
    }
    case 'dmReply': {
      const th = g.dm[a.fixerId]
      const offer = th?.offer ? offerOf(a.fixerId, th.offer) : undefined
      if (!th || !offer || !g.character.alive) return g
      const job = ALL_JOBS[offer.jobId]
      if (a.accept && (dmAcceptBlock(g) || (job.unique && uniqueLock(g.character, job.id)))) return g
      const msgs: DmMsg[] = [
        ...th.msgs,
        { from: 'me', text: a.accept ? offer.accept : offer.decline, at: now },
        { from: 'npc', text: a.accept ? offer.acceptReply : offer.declineReply, at: now },
      ]
      const dm = { ...g.dm, [a.fixerId]: { ...th, msgs, offer: null, nextAt: now + DM_COOLDOWN } }
      if (!a.accept) return { ...g, dm }
      const startedAt = g.queue.items.length === 0 ? now : g.queue.startedAt
      return {
        ...g,
        dm,
        queue: { ...g.queue, items: [...g.queue.items, job.id], startedAt },
        log: trim([...g.log, { at: now, kind: 'system', text: `接下${FIXER_NAME[a.fixerId]}的私訊委託「${job.name}」，加入排隊（${g.queue.items.length + 1}/${QUEUE_SLOTS}）。` }]),
      }
    }
    case 'seen': {
      if (a.key.startsWith('dm:')) {
        const id = a.key.slice(3)
        const th = g.dm[id]
        const n = Math.max(0, Math.min(th?.msgs.length ?? 0, a.n))
        if (!th || n <= th.seen) return g
        return { ...g, dm: { ...g.dm, [id]: { ...th, seen: n } } }
      }
      if ((g.seen[a.key] ?? 0) >= a.n) return g
      return { ...g, seen: { ...g.seen, [a.key]: a.n } }
    }
    case 'ask': {
      const key = `${a.caseId}#${a.i}`
      if (!CASE_BY_ID[a.caseId]?.asks?.[a.i] || g.asked.includes(key)) return g
      return { ...g, asked: [...g.asked, key] }
    }
    case 'setTactic':
      return { ...g, stopRules: { ...g.stopRules, tactic: a.tactic } }
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
