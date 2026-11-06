// 私人通訊：每位中間人一條對話串。訊息依信任解鎖；中間人會私下發委託，你用回覆接下或推掉。
// - 一般委託：可重複，依信任開放更多件，輪流發；接了或推了都要等一段冷卻（遊戲時間）才發下一件。
// - 獨特委託：一次性，要信任＋名聲，優先發。
// 信任：替他做成一件工作 +1、劇情結案 +1～3、獨特委託 +3；白蛇另外看診所的治療與義體。
import type { JobDef } from '../rules/core'

const j = (x: JobDef) => x

export const UNIQUE_JOBS: Record<string, JobDef> = Object.fromEntries(
  [
    j({ id: 'u-k', unique: true, direction: 'stealth', tier: 2, name: '歸還的手臂', fixerId: 'k', minutes: 5, reward: 500, xp: 30, stress: 2, heat: 0, injury: 6, blurb: '老K幫一個小鬼裝的義手，被高架橋那群人拔走、掛上黑市。偷回來，還給那孩子。' }),
    j({ id: 'u-mist', unique: true, direction: 'hack', tier: 3, name: '刪掉一個人', fixerId: 'mist', minutes: 6, reward: 900, xp: 50, stress: 5, heat: 1, injury: 4, blurb: '港務部的一名告密者想從所有資料庫裡消失：戶籍、醫療、門禁、監視畫面，一筆不剩。' }),
    j({ id: 'u-snake', unique: true, direction: 'force', tier: 3, name: '冷藏箱', fixerId: 'snake', minutes: 6, reward: 800, xp: 45, stress: 3, heat: 1, injury: 16, blurb: '診所的一批冷藏箱在半路被搶。箱子裡的東西撐不過天亮，搶的人也知道。' }),
  ].map((x) => [x.id, x]),
)

/** 私訊的一般委託：不在看板上，只能從私訊回覆接。報酬只比看板同階略高，好處是信任與故事。 */
export const DM_JOBS: Record<string, JobDef> = Object.fromEntries(
  [
    j({ id: 'r-k-1', dm: true, direction: 'stealth', tier: 1, name: '後巷的保冷箱', fixerId: 'k', minutes: 2, reward: 140, xp: 12, stress: 1, heat: 0, injury: 4, blurb: '拉麵攤後面的保冷箱，送到三丁目的洗衣店。' }),
    j({ id: 'r-k-2', dm: true, direction: 'force', tier: 1, name: '催一筆舊帳', fixerId: 'k', minutes: 3, reward: 160, xp: 14, stress: 1, heat: 1, injury: 8, blurb: '高架橋下賣零件的又賴帳了。讓他記得就好。' }),
    j({ id: 'r-k-3', dm: true, direction: 'hack', tier: 2, name: '改一台柏青哥', fixerId: 'k', minutes: 4, reward: 280, xp: 22, stress: 4, heat: 1, injury: 3, blurb: '荒井會的新店，第七排第三台，讓它整晚吐珠。' }),
    j({ id: 'r-mist-1', dm: true, direction: 'stealth', tier: 2, name: '一張照片', fixerId: 'mist', minutes: 4, reward: 280, xp: 22, stress: 2, heat: 0, injury: 5, blurb: '灣岸二號碼頭，穿灰色雨衣的人。要他的臉。' }),
    j({ id: 'r-mist-2', dm: true, direction: 'hack', tier: 2, name: '刪一段影片', fixerId: 'mist', minutes: 4, reward: 260, xp: 22, stress: 4, heat: 1, injury: 3, blurb: '便利商店監視器裡的七秒，不能存在。' }),
    j({ id: 'r-mist-3', dm: true, direction: 'hack', tier: 3, name: '替一間公司改帳', fixerId: 'mist', minutes: 5, reward: 520, xp: 36, stress: 5, heat: 1, injury: 4, blurb: '港務部外包公司的帳本裡，有一筆不該在那裡的貨。' }),
    j({ id: 'r-snake-1', dm: true, direction: 'stealth', tier: 1, name: '送藥', fixerId: 'snake', minutes: 2, reward: 130, xp: 12, stress: 1, heat: 0, injury: 3, blurb: '一個走不出家門的病人。藥沒有處方，別被攔下來。' }),
    j({ id: 'r-snake-2', dm: true, direction: 'force', tier: 2, name: '收回零件', fixerId: 'snake', minutes: 5, reward: 300, xp: 26, stress: 3, heat: 1, injury: 14, blurb: '裝了白蛇的義眼、沒付錢就跑的客人。' }),
    j({ id: 'r-snake-3', dm: true, direction: 'hack', tier: 2, name: '改一份病歷', fixerId: 'snake', minutes: 4, reward: 270, xp: 22, stress: 4, heat: 0, injury: 2, blurb: '綜合醫院的系統說那個人死了。他還活著。' }),
  ].map((x) => [x.id, x]),
)

/** 一件私訊委託的對話：中間人一則一則說完，你挑一個回覆，他再回一句。 */
export interface DmOffer {
  jobId: string
  /** 開放這件要的信任。 */
  trust: number
  intro: string[]
  accept: string
  acceptReply: string
  decline: string
  declineReply: string
}

export interface Contact {
  fixerId: string
  /** 依信任解鎖的閒聊（由低到高）。 */
  lines: { trust: number; text: string }[]
  requests: DmOffer[]
  unique: DmOffer & { fame: number; done: string; gift: string }
}

export const CONTACTS: Contact[] = [
  {
    fixerId: 'k',
    lines: [
      { trust: 0, text: '新來的？先把小事做好，我再看看你。' },
      { trust: 3, text: '做得還行。後巷那排貨架你可以來看了，別問貨從哪來。' },
      { trust: 6, text: '有件私事，不能掛在看板上。等你在街上再有點名氣，我就跟你說。' },
    ],
    requests: [
      { jobId: 'r-k-1', trust: 0, intro: ['喂。', '有個保冷箱放在拉麵攤後面，送到三丁目的洗衣店。', '別問裡面是什麼。問了就要加錢——我的錢。'], accept: '我去。', acceptReply: '洗衣店老闆會給你一張收據，收據拿回來才算數。', decline: '今晚沒空。', declineReply: '嘖。那我找別人。' },
      { jobId: 'r-k-2', trust: 0, intro: ['高架橋下那個賣零件的又賴帳了。', '不用打到他住院，讓他記得就好。'], accept: '交給我。', acceptReply: '記得，打臉不打手。他還要用手修東西還我錢。', decline: '這種事找別人吧。', declineReply: '行。心軟的傭兵活不久，但活得比較舒服。' },
      { jobId: 'r-k-3', trust: 4, intro: ['荒井會在歌舞伎町新開了一間柏青哥店。', '第七排第三台，讓它整晚吐珠。坐在前面的是我的人。'], accept: '第七排第三台，記住了。', acceptReply: '別讓它吐太多。吐太多，荒井會的人會開始數。', decline: '荒井會的地盤我不碰。', declineReply: '聰明。不過聰明的人通常比較窮。' },
    ],
    unique: {
      jobId: 'u-k',
      trust: 8,
      fame: 12,
      intro: ['有件私事。', '我幫一個小鬼裝過一隻義手，被高架橋那群人拔走、掛上黑市了。', '那孩子每天站在店門口等。我不想再看他等下去。'],
      accept: '我把手拿回來。',
      acceptReply: '……謝了。我不會說第二次。',
      decline: '現在不行。',
      declineReply: '我等。他也在等。',
      done: '那孩子說要請你吃拉麵。我說你沒空。……東西拿去，我用不到了。',
      gift: 'tendon',
    },
  },
  {
    fixerId: 'mist',
    lines: [
      { trust: 0, text: '我只跟付得起、也守得住嘴的人說話。' },
      { trust: 4, text: '你的名字開始在灣岸流傳了。小心，名字是會被賣的。' },
    ],
    requests: [
      { jobId: 'r-mist-1', trust: 0, intro: ['灣岸二號碼頭，凌晨三點。', '會有一個穿灰色雨衣的人上船。我要他的臉，清楚的那種。'], accept: '清楚的臉。', acceptReply: '別用閃光燈。上一個用閃光燈的，現在在海裡。', decline: '碼頭最近太多眼睛。', declineReply: '眼睛多才好賣照片。算了，下次。' },
      { jobId: 'r-mist-2', trust: 2, intro: ['有人在便利商店的監視器裡出現了七秒。', '那七秒不能存在。'], accept: '七秒，沒問題。', acceptReply: '只刪那七秒。整段消失的話，反而有人會去查。', decline: '我不碰監視網。', declineReply: '那你在魔都會很辛苦。' },
      { jobId: 'r-mist-3', trust: 6, intro: ['港務部的外包公司要報稅了。', '他們的帳本裡有一筆不該在那裡的貨。讓它變成別的東西。'], accept: '變成什麼？', acceptReply: '變成「辦公用品」。魔都的辦公用品，什麼都有可能。', decline: '企業的帳我看不懂。', declineReply: '沒有人看得懂。這才是重點。' },
    ],
    unique: {
      jobId: 'u-mist',
      trust: 8,
      fame: 25,
      intro: ['有人付錢讓自己不存在。', '港務部的告密者。戶籍、醫療、門禁、監視畫面，一筆不剩。', '這種工作，我只給我記得名字的人。'],
      accept: '我記得你的名字就好。',
      acceptReply: '……這句話我會記住。',
      decline: '我還不想碰港務部。',
      declineReply: '沒關係。她可以再存在幾天。',
      done: '她不存在了。你也從沒聽過她。很好。',
      gift: 'coproc',
    },
  },
  {
    fixerId: 'snake',
    lines: [
      { trust: 0, text: '傷口縫好就走，別在我這裡流血流到地板上。' },
      { trust: 3, text: '常客打折？不。我只是記住你的臉了。' },
    ],
    requests: [
      { jobId: 'r-snake-1', trust: 0, intro: ['有個病人走不出家門。', '藥放在櫃台，地址在袋子上。別在路上被攔下來，這些藥沒有處方。'], accept: '我送。', acceptReply: '他會說他不需要。別聽他的。', decline: '我現在走不開。', declineReply: '嗯。那他就再撐一晚。' },
      { jobId: 'r-snake-2', trust: 3, intro: ['一個客人裝了我的義眼，沒付錢就跑了。', '我不要錢了。我要我的眼睛。'], accept: '我去拿。', acceptReply: '拆的時候小心。那顆眼睛比他值錢。', decline: '這太血腥了。', declineReply: '你在診所門口說這句話，很好笑。' },
      { jobId: 'r-snake-3', trust: 5, intro: ['綜合醫院的系統裡有一份病歷寫錯了。', '上面說那個人死了。他還活著，我需要他繼續活著——在紙上。'], accept: '讓他活過來。', acceptReply: '很好。在魔都，紙上活著比真的活著難。', decline: '醫院的資料庫查得很嚴。', declineReply: '所以才找你，不是找實習生。' },
    ],
    unique: {
      jobId: 'u-snake',
      trust: 5,
      fame: 15,
      intro: ['我的冷藏箱被搶了。', '箱子裡的東西撐不過天亮，搶的人也知道。', '報警？你在說笑。'],
      accept: '地址給我。',
      acceptReply: '已經傳了。活著回來，箱子也是。',
      decline: '我現在打不過他們。',
      declineReply: '那就先活著。箱子我再想辦法。',
      done: '箱子溫度剛好。你比我想像的有用。這個你拿去裝。',
      gift: 'reflexes',
    },
  },
]

export const CONTACT_BY_ID: Record<string, Contact> = Object.fromEntries(CONTACTS.map((x) => [x.fixerId, x]))
export const CONTACT_BY_JOB: Record<string, Contact> = Object.fromEntries(CONTACTS.map((x) => [x.unique.jobId, x]))

/** 對話串裡那件委託的回覆文字（獨特或一般）。 */
export function offerOf(fixerId: string, jobId: string): DmOffer | undefined {
  const k = CONTACT_BY_ID[fixerId]
  return k.unique.jobId === jobId ? k.unique : k.requests.find((r) => r.jobId === jobId)
}

/** 獨特委託還不能接的原因（已做過、條件不夠）；可以接回傳 undefined。 */
export function uniqueLock(c: { trust: Record<string, number>; fame: number; uniqueDone: string[] }, jobId: string): string | undefined {
  const k = CONTACT_BY_JOB[jobId]
  if (!k) return '沒有這件委託'
  if (c.uniqueDone.includes(jobId)) return '已完成'
  const t = c.trust[k.fixerId] ?? 0
  const miss = [t < k.unique.trust ? `信任 ${t}/${k.unique.trust}` : '', c.fame < k.unique.fame ? `名聲 ${c.fame}/${k.unique.fame}` : ''].filter(Boolean)
  return miss.length ? `需要${miss.join('、')}` : undefined
}
