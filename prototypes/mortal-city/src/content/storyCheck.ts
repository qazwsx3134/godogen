// 劇情委託的機器檢查：AI（或人）寫的草稿先過這一關，再交給審查員與作者讀。
// 只檢查「遊戲讀得懂、規則上不會壞」的部分；合不合理、好不好看交給審查員（docs/story-pipeline/REVIEWER-BRIEF.md）。
// 規則都從遊戲本身的資料來（中間人、裝備、既有案子），不另抄一份清單。
import { ATTR_LABEL, DIRECTION_LABEL, type Enemy } from '../rules/core'
import { BEATS, type Beat } from './beats'
import { CASE_BY_ID, type CaseOption, type StoryCase, caseThreat } from './cases'
import { FIXERS } from './data'
import { ITEMS } from './items'

export interface StoryIssue {
  level: 'error' | 'warn'
  /** 出問題的位置，例如 danger.options[2].text。 */
  where: string
  msg: string
}

const ATTRS = Object.keys(ATTR_LABEL)
const DIRS = Object.keys(DIRECTION_LABEL)
const SLOTS = ['weapon', 'deck', 'implant']
const COSTS = ['injury', 'heat', 'stress', 'pay']

/** 一定不能出現的用語（2026-11-13 使用者：防火牆不叫黑冰、不用「咬」表示攻擊；畫面不顯示機率）。 */
const BANNED: [RegExp, string][] = [
  [/黑冰|冰鑿|破冰|Black ICE|\bICE\b/i, '用「防火牆」，不要用黑冰、ICE、冰'],
  [/\d+\s*%/, '玩家看到的文字不寫百分比（機率由骰子表現）'],
]
/** 不建議的用語：多半有更標準的說法（警告，不擋）。 */
const AVOID: [RegExp, string][] = [
  [/咬(?!牙)/, '攻擊不要寫「咬」，寫「攻擊」或具體的動作'],
  [/賽博精神病|cyberpsychosis/i, '用「神經錯亂」'],
  [/\bdebuff\b|\bbuff\b|\bperk\b|\bbuild\b|\bmerc\b/i, '不要用遊戲英文黑話'],
  [/HP|血量/, '劇情文字不要提數值'],
]

/** 字數上限（360px 手機一屏讀得完）：超過只警告。 */
const MAX = { title: 14, label: 40, summary: 60, line: 70, reply: 120, text: 220, body: 420, danger: 260, setup: 80, out: 50, cost: 24 }

function enemyIssues(e: Enemy, where: string): StoryIssue[] {
  const out: StoryIssue[] = []
  if (!e.name) out.push({ level: 'error', where, msg: '敵人沒有名字' })
  if (!(e.hp >= 20 && e.hp <= 200)) out.push({ level: 'error', where, msg: `HP ${e.hp} 不在 20～200（現有案子 45～120）` })
  if (!(e.atk >= 3 && e.atk <= 25)) out.push({ level: 'error', where, msg: `攻擊 ${e.atk} 不在 3～25` })
  if (!(e.hit >= 0.3 && e.hit <= 0.8)) out.push({ level: 'error', where, msg: `命中 ${e.hit} 不在 0.3～0.8` })
  return out
}

function beatIssues(b: Beat, where: string): StoryIssue[] {
  const out: StoryIssue[] = []
  if (!b.title) out.push({ level: 'error', where, msg: '場面沒有標題' })
  if (!ATTRS.includes(b.attr)) out.push({ level: 'error', where, msg: `屬性 ${b.attr} 不存在（${ATTRS.join('／')}）` })
  if (!b.setup) out.push({ level: 'error', where, msg: '場面沒有情境文字 setup' })
  for (const k of ['crit', 'clean', 'cost', 'fail'] as const) if (!b.out?.[k]) out.push({ level: 'error', where: `${where}.out.${k}`, msg: '四種結果都要有一句' })
  if (b.costs?.length !== 2) out.push({ level: 'error', where: `${where}.costs`, msg: '付代價要剛好兩個選項' })
  b.costs?.forEach((c, i) => {
    if (!COSTS.includes(c.kind)) out.push({ level: 'error', where: `${where}.costs[${i}]`, msg: `代價種類 ${c.kind} 不存在（injury／heat／stress／pay）` })
    if (!c.text) out.push({ level: 'error', where: `${where}.costs[${i}]`, msg: '代價沒有文字' })
  })
  if (b.costs?.length === 2 && b.costs[0].kind === b.costs[1].kind) out.push({ level: 'warn', where: `${where}.costs`, msg: '兩個代價是同一種資源，選起來沒有差別' })
  if (!COSTS.includes(b.fail) || b.fail === 'pay') out.push({ level: 'error', where: `${where}.fail`, msg: '失敗的代價要是 injury／heat／stress（報酬打折不夠痛）' })
  return out
}

/** 所有玩家看得到的文字（位置、內容、字數上限）。 */
function texts(sc: StoryCase): [string, string, number][] {
  const t: [string, string, number][] = [
    ['title', sc.title, MAX.title],
    ['body', sc.body, MAX.body],
    ['lossText', sc.lossText, MAX.text],
    ['danger.title', sc.danger.title, MAX.title * 2],
    ['danger.body', sc.danger.body, MAX.danger],
  ]
  Object.entries(sc.variants ?? {}).forEach(([k, v]) => t.push([`variants.${k}`, v, MAX.body]))
  sc.replies.forEach((r, i) => t.push([`replies[${i}]`, r.text, MAX.reply]))
  Object.entries(sc.approachReplies ?? {}).forEach(([k, r]) => t.push([`approachReplies.${k}`, r.text, MAX.reply]))
  sc.approaches.forEach((a, i) => {
    t.push([`approaches[${i}].label`, a.label, MAX.label], [`approaches[${i}].summary`, a.summary, MAX.summary])
    a.autoLog.forEach((l, j) => t.push([`approaches[${i}].autoLog[${j}]`, l, MAX.line]))
    a.afterFight?.forEach((l, j) => t.push([`approaches[${i}].afterFight[${j}]`, l, MAX.line]))
    a.beats?.forEach((b, j) => {
      t.push([`approaches[${i}].beats[${j}].setup`, b.setup, MAX.setup])
      Object.entries(b.out ?? {}).forEach(([k, v]) => t.push([`approaches[${i}].beats[${j}].out.${k}`, v, MAX.out]))
      b.costs?.forEach((c, k) => t.push([`approaches[${i}].beats[${j}].costs[${k}]`, c.text, MAX.cost]))
    })
  })
  sc.danger.options.forEach((o, i) => t.push([`danger.options[${i}].label`, o.label, MAX.label], [`danger.options[${i}].text`, o.text, MAX.text]))
  if (sc.broadcast) t.push(['broadcast.survived', sc.broadcast.survived, MAX.reply * 2], ['broadcast.other', sc.broadcast.other, MAX.reply * 2])
  return t
}

function optionIssues(sc: StoryCase, o: CaseOption, where: string): StoryIssue[] {
  const out: StoryIssue[] = []
  if (o.approach && !sc.approaches.some((a) => a.id === o.approach)) out.push({ level: 'error', where, msg: `限定做法 ${o.approach} 不存在` })
  if (o.needs) {
    if ('attr' in o.needs) {
      if (!ATTRS.includes(o.needs.attr)) out.push({ level: 'error', where, msg: `屬性門檻 ${o.needs.attr} 不存在` })
      if (!(o.needs.min >= 4 && o.needs.min <= 10)) out.push({ level: 'error', where, msg: `屬性門檻 ${o.needs.min} 不在 4～10` })
    } else if (!SLOTS.includes(o.needs.slot) || !DIRS.includes(o.needs.direction) || !o.needs.label) out.push({ level: 'error', where, msg: '器材門檻要有 slot（weapon／deck／implant）、direction、label' })
  }
  if (o.fight) {
    out.push(...enemyIssues(o.fight, `${where}.fight`))
    if (!o.lethal) out.push({ level: 'error', where, msg: '「打」的選項要是 lethal（打輸才擲致命判定）' })
  }
  if (o.lethal && !(o.lethalBase >= 0.02 && o.lethalBase <= 0.5)) out.push({ level: 'error', where, msg: `冒險選項的險度 lethalBase ${o.lethalBase} 不在 0.02～0.5（≥0.28 少一顆骰、≤0.1 多一顆）` })
  if (!o.lethal && o.lethalBase) out.push({ level: 'warn', where, msg: '不會死的選項寫了 lethalBase，不會用到' })
  if (!(o.reward >= 0 && o.reward <= 4000)) out.push({ level: 'error', where, msg: `報酬 ${o.reward} 不在 0～4000` })
  if (o.heat !== undefined && !(o.heat >= 0 && o.heat <= 3)) out.push({ level: 'error', where, msg: '通緝 heat 要在 0～3' })
  return out
}

/** 檢查一件劇情委託。others：同一批的其他草稿（requires 可以指向它們）。 */
export function checkStory(sc: StoryCase, others: StoryCase[] = []): StoryIssue[] {
  // 先看骨架：缺必要欄位就只回報這些，不往下檢查（避免拿 undefined 去比）
  const shape: StoryIssue[] = []
  const need = (ok: boolean, where: string, msg: string) => ok || shape.push({ level: 'error', where, msg })
  need(!!sc && typeof sc === 'object', '(root)', '草稿要是一個 JSON 物件')
  if (shape.length) return shape
  for (const k of ['id', 'title', 'fixerId', 'zone', 'posted', 'body', 'lossText'] as const) need(typeof sc[k] === 'string', k, `缺少文字欄位 ${k}`)
  need(typeof sc.xp === 'number', 'xp', '缺少 xp（數字）')
  need(Array.isArray(sc.replies), 'replies', '缺少 replies（陣列）')
  need(Array.isArray(sc.approaches) && sc.approaches.every((a) => a && Array.isArray(a.autoLog)), 'approaches', '缺少 approaches（陣列，每個做法要有 autoLog 陣列）')
  need(!!sc.danger && Array.isArray(sc.danger.options), 'danger', '缺少 danger（要有 title、body、options 陣列）')
  if (shape.length) return shape
  const out: StoryIssue[] = []
  const err = (where: string, msg: string) => out.push({ level: 'error', where, msg })
  const warn = (where: string, msg: string) => out.push({ level: 'warn', where, msg })

  if (!sc.id) err('id', '沒有 id')
  if (!['test', 'draft'].includes(sc.kind)) err('kind', 'kind 要是 draft（或 test）')
  if (!FIXERS[sc.fixerId]) err('fixerId', `中間人 ${sc.fixerId} 不存在（${Object.keys(FIXERS).join('／')}）`)
  if (!sc.zone) err('zone', '沒有地點')
  if (!/^\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}$/.test(sc.posted ?? '')) err('posted', 'posted 要像「2077.11.04 01:12」')
  if (sc.kind !== 'test' && !(sc.xp >= 10 && sc.xp <= 80)) err('xp', `經驗 ${sc.xp} 不在 10～80（中段案 30、大案 40～）`)
  if (sc.requires && !CASE_BY_ID[sc.requires] && !others.some((x) => x.id === sc.requires)) err('requires', `前置案 ${sc.requires} 不存在`)
  if (sc.variants) {
    if (!sc.requires) err('variants', '有 variants 就要有 requires（依前置案的結果追加內文）')
    for (const k of Object.keys(sc.variants)) if (k !== 'won' && k !== 'lost') err(`variants.${k}`, 'variants 的 key 只能是 won／lost')
  }
  if (sc.approachReplies) {
    const prev = sc.requires ? (CASE_BY_ID[sc.requires] ?? others.find((x) => x.id === sc.requires)) : undefined
    if (!prev) err('approachReplies', '有 approachReplies 就要有 requires')
    else for (const k of Object.keys(sc.approachReplies)) if (!prev.approaches.some((a) => a.id === k)) err(`approachReplies.${k}`, `前置案沒有做法 ${k}`)
  }

  const speakers = [...sc.replies, ...Object.values(sc.approachReplies ?? {})]
  speakers.forEach((r, i) => {
    if (!FIXERS[r.who]) err(`replies[${i}].who`, `發言者 ${r.who} 不存在（${Object.keys(FIXERS).join('／')}）`)
    if (!/^\d{2}:\d{2}$/.test(r.at ?? '')) err(`replies[${i}].at`, '時間要像「01:30」')
  })
  if (!sc.replies.length) err('replies', '至少要有一則頻道回覆')
  const times = sc.replies.map((r) => r.at)
  if (times.some((t, i) => i && t < times[i - 1])) warn('replies', '回覆的時間沒有照順序（跨午夜的話請忽略）')

  if (sc.approaches.length < 2) err('approaches', '至少要有兩種做法')
  const apIds = sc.approaches.map((a) => a.id)
  if (new Set(apIds).size !== apIds.length) err('approaches', '做法 id 重複')
  sc.approaches.forEach((a, i) => {
    const w = `approaches[${i}]`
    if (!DIRS.includes(a.direction)) err(w, `路線 ${a.direction} 不存在（force／hack／stealth）`)
    if (!a.autoLog?.length) err(`${w}.autoLog`, '自動段至少一行')
    if (!(a.injury >= 0 && a.injury <= 40)) err(`${w}.injury`, `路上傷勢 ${a.injury} 不在 0～40`)
    if (!(a.lethalMod >= -0.1 && a.lethalMod <= 0.1)) err(`${w}.lethalMod`, `險度修正 ${a.lethalMod} 不在 −0.1～0.1`)
    if (a.needs && (!ATTRS.includes(a.needs.attr) || !(a.needs.min >= 4 && a.needs.min <= 10))) err(`${w}.needs`, '屬性做法要有存在的屬性、門檻 4～10')
    if (a.fight) out.push(...enemyIssues(a.fight, `${w}.fight`))
    if (a.afterFight && !a.fight) warn(`${w}.afterFight`, '沒有 fight 卻寫了 afterFight，不會顯示')
    if (a.beats) {
      if (a.beats.length !== 2) err(`${w}.beats`, '做法的場面要剛好兩個')
      a.beats.forEach((b, j) => out.push(...beatIssues(b, `${w}.beats[${j}]`)))
    } else warn(`${w}.beats`, `沒寫場面，會借用委託「${BEATS[a.direction]?.[0]?.title ?? '?'}」那套通用文字，可能和這件案子的地點對不上`)
  })

  const opts = sc.danger.options
  const optIds = opts.map((o) => o.id)
  if (!sc.danger.title || !sc.danger.body) err('danger', '危險節點要有標題與內文')
  if (opts.length < 2) err('danger.options', '危險節點至少兩個選項')
  if (new Set(optIds).size !== optIds.length) err('danger.options', '選項 id 重複')
  if (!opts.some((o) => !o.lethal && !o.fight && !o.needs && !o.approach)) err('danger.options', '一定要有一個不擲骰、不要求器材或屬性、每種做法都看得到的撤離選項')
  if (!opts.some((o) => o.lethal)) err('danger.options', '至少要有一個冒險選項（致命判定）')
  for (const a of sc.approaches) if (!opts.some((o) => o.lethal && (!o.approach || o.approach === a.id))) warn('danger.options', `走「${a.label}」時沒有任何冒險選項`)
  opts.forEach((o, i) => out.push(...optionIssues(sc, o, `danger.options[${i}]`)))
  if (sc.danger.threat) out.push(...enemyIssues(sc.danger.threat, 'danger.threat'))
  if (!caseThreat(sc)) warn('danger.threat', '沒有追兵（threat 或「打」選項）：致命判定失敗會直接是致命傷；現場明明有人的話請補 threat')

  if (!sc.lossText) err('lossText', '要寫被武裝醫療隊救出時補的一句')
  sc.loot?.forEach((l, i) => {
    if (!ITEMS[l.kind]) err(`loot[${i}]`, `物品 ${l.kind} 不存在`)
    if (!(l.chance > 0 && l.chance <= 1)) err(`loot[${i}]`, '掉落機率要在 0～1')
  })
  if (sc.broadcast && (!sc.broadcast.survived || !sc.broadcast.other)) err('broadcast', '夜鴉插播 survived 與 other 都要寫')

  for (const [where, text, max] of texts(sc)) {
    if (!text) continue
    for (const [re, msg] of BANNED) if (re.test(text)) err(where, `${msg}：「${text.slice(0, 30)}…」`)
    for (const [re, msg] of AVOID) if (re.test(text)) warn(where, `${msg}：「${text.slice(0, 30)}…」`)
    if ([...text].length > max) warn(where, `${[...text].length} 字，超過建議的 ${max} 字（手機一屏讀不完）`)
  }
  return out
}
