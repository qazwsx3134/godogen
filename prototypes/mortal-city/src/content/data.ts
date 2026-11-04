// 原型內容。劇情案是「測試案」，只用來驗證流程，不是正式 P01 劇本。
import type { DangerOption, Direction, Item, JobDef } from '../rules/core'

export interface Fixer {
  id: string
  name: string
  role: string
  avatar: string
  glyph: string
}

export const FIXERS: Record<string, Fixer> = {
  k: { id: 'k', name: '老K', role: '義體修理店・新宿街區', avatar: '/assets/avatar_fixer_k.png', glyph: 'K' },
  mist: { id: 'mist', name: '霧', role: '情報掮客・灣岸', avatar: '/assets/avatar_fixer_mist.png', glyph: '霧' },
  crow: { id: 'crow', name: '夜鴉', role: '魔都 FM 104.9 DJ', avatar: '/assets/avatar_dj_crow.png', glyph: '鴉' },
  snake: { id: 'snake', name: '白蛇', role: '地下診所', avatar: '/assets/avatar_doc_snake.png', glyph: '蛇' },
  mpd: { id: 'mpd', name: 'MPD 巡警', role: '魔都警察', avatar: '/assets/avatar_mpd_officer.png', glyph: 'M' },
  medic: { id: 'medic', name: '武裝醫療隊', role: '緊急救援', avatar: '/assets/avatar_medic.png', glyph: '+' },
}

const j = (x: JobDef) => x

export const JOBS: Record<string, JobDef> = Object.fromEntries(
  [
    j({ id: 'stealth-1', direction: 'stealth', tier: 1, name: '雨夜送貨', fixerId: 'k', minutes: 2, reward: 120, xp: 12, stress: 1, heat: 0, injury: 4, blurb: '一個不能淋濕的盒子，送到歌舞伎町後巷。別問裡面是什麼。' }),
    j({ id: 'hack-1', direction: 'hack', tier: 1, name: '破解自販機', fixerId: 'k', minutes: 2, reward: 100, xp: 12, stress: 2, heat: 0, injury: 2, blurb: '整排販賣機都歸荒井會管，讓它們吐錢就對了。' }),
    j({ id: 'force-1', direction: 'force', tier: 1, name: '收保護費', fixerId: 'k', minutes: 3, reward: 150, xp: 14, stress: 1, heat: 1, injury: 8, blurb: '拉麵攤老闆欠了兩個月。客氣一點，但要拿到錢。' }),
    j({ id: 'stealth-2', direction: 'stealth', tier: 2, name: '跟拍外遇', fixerId: 'mist', minutes: 4, reward: 260, xp: 22, stress: 2, heat: 0, injury: 5, blurb: '港務部某課長，每週四晚上會「加班」。拍到臉就好。' }),
    j({ id: 'hack-2', direction: 'hack', tier: 2, name: '竊取監視畫面', fixerId: 'mist', minutes: 4, reward: 240, xp: 22, stress: 4, heat: 1, injury: 3, blurb: '倉庫 7 號的攝影機昨晚拍到了不該拍的東西。' }),
    j({ id: 'force-2', direction: 'force', tier: 2, name: '清空幫派據點', fixerId: 'k', minutes: 5, reward: 320, xp: 26, stress: 3, heat: 1, injury: 14, blurb: '高架橋下那群小鬼越來越囂張了。' }),
    j({ id: 'stealth-4', direction: 'stealth', tier: 4, name: '盜取原型義體', fixerId: 'mist', minutes: 6, reward: 2200, xp: 120, stress: 9, heat: 1, injury: 22, blurb: '九頭龍重工研究所三樓的展示櫃。保全每 90 秒巡一次，櫃子有重量感應。' }),
    j({ id: 'force-4', direction: 'force', tier: 4, name: '突襲企業倉庫', fixerId: 'k', minutes: 6, reward: 2600, xp: 120, stress: 8, heat: 2, injury: 30, blurb: '灣岸 7 號倉，港務部的私兵有重武裝。正面打進去，拿了貨就走。' }),
    j({ id: 'hack-4', direction: 'hack', tier: 4, name: '盜取企業伺服器', fixerId: 'mist', minutes: 6, reward: 2400, xp: 120, stress: 12, heat: 2, injury: 20, blurb: '港務部的核心機房。黑冰會反咬，一次失手就可能燒掉你的腦。' }),
  ].map((x) => [x.id, x]),
)

export const QUEUE_SLOTS = 4

/** 新角色的起始裝備（三個欄位）。抵押價＝售價 60%。 */
export const STARTER_GEAR: Item[] = [
  { id: 'gun-1', name: '舊型電磁手槍', slot: 'weapon', direction: 'force', bonus: 0.05, price: 1200, load: 0 },
  { id: 'deck-1', name: '二手駭客終端', slot: 'deck', direction: 'hack', bonus: 0.05, price: 800, load: 0 },
  { id: 'camo-1', name: '光學迷彩貼片', slot: 'implant', direction: 'stealth', bonus: 0.05, price: 1000, load: 25 },
]
export const CITY_TARGET = 50_000 // 封鎖線「民生補給」：全服完成的潛行工作件數

// ---------- 測試案 ----------

export interface Reply {
  who: string
  at: string
  text: string
}

export interface Approach {
  id: string
  direction: 'force' | 'hack' | 'stealth'
  label: string
  summary: string
  needs: string
}

export const TEST_CASE = {
  id: 'TEST-001',
  title: '終電後的手提箱',
  fixerId: 'k',
  zone: '新宿・地下維修道',
  posted: '2077.11.04 01:12',
  reward: 1500,
  body:
    '末班車開走之後，魔都環狀線的維修道會有一台沒有登記的工程車停在 B3。車上有一只鋁製手提箱，主人已經不需要它了，但很多人在找。\n\n把箱子帶回店裡，不要打開，不要掃描，不要賣給第一個開價的人。',
  replies: [
    { who: 'k', at: '01:14', text: '我只說一次：MPD 的無人機會在兩點換班，換班前後各有五分鐘的空檔。錯過了就別硬來。' },
    { who: 'mist', at: '01:20', text: '那只箱子我也在找。你先拿到的話，記得我的價碼永遠比老頭高。' },
    { who: 'snake', at: '01:31', text: '受傷了就往我這裡爬。保單過期的，我也收，只是比較貴。' },
  ] as Reply[],
  approaches: [
    { id: 'force', direction: 'force', label: '強行突入', summary: '直接從工程車正面進去，最快，但會很吵。', needs: '火力 ≥ 1' },
    { id: 'hack', direction: 'hack', label: '黑進號誌系統', summary: '讓維修道的燈號全部轉紅，工程車自己停下來。', needs: '入侵 ≥ 1' },
    { id: 'stealth', direction: 'stealth', label: '換班空檔潛入', summary: '等兩點的無人機換班，五分鐘內進出。', needs: '潛行 ≥ 1' },
  ] as Approach[],
  autoLog: [
    '你沿著廢棄月台往下走，鐵軌間的積水映著紅色的維修燈。',
    '工程車就在 B3，車門半開，箱子還在副駕駛座上。',
    '你拿到箱子了。背後的隧道傳來無人機的螺旋槳聲，比預定的換班時間早了三分鐘。',
  ],
  danger: {
    title: 'MPD 無人機封鎖了出口',
    body: '兩台 MPD 巡邏無人機停在唯一的出口，探照燈正往你的方向掃過來。你手上有箱子，身上的傷還在流血。',
    options: [
      { id: 'drop', label: '丟下箱子，從排水管撤離', lethal: false, lethalBase: 0, survivalWindowMin: 0 },
      { id: 'run', label: '抱著箱子衝過探照燈', lethal: true, lethalBase: 0.35, survivalWindowMin: 4 },
    ] as DangerOption[],
  },
}

// ---------- 廣播（DJ 夜鴉，輕佻口吻） ----------

export const BROADCASTS = [
  '這裡是魔都 FM 104.9，我是夜鴉。今晚雨很大，MPD 的心情很差，各位傭兵出門記得把通緝星星擦亮一點。',
  '插播一則好消息：灣岸封鎖線的民生補給進度又往前推了。有人在拼命送貨，我只能說，敬你們的膝蓋。',
  '聽眾來電：「夜鴉，接到會死的工作該怎麼辦？」親愛的，先看保單，再看遺囑，最後看我。',
]

// ---------- 高階街頭工作的危險節點（模板＋變數，依方向） ----------

export interface DangerTemplate {
  autoLog: string[]
  title: string
  body: string
  options: DangerOption[]
}

const OPENING: Record<Direction, (n: string) => string[]> = {
  force: (n) => [`你把彈匣壓滿，往「${n}」的目標出發。`, '第一道門很順利，守衛還在抽菸。'],
  hack: (n) => [`你接上神經線，開始「${n}」。`, '第一層防火牆像紙一樣被撕開。'],
  stealth: (n) => [`你貼著陰影移動，開始「${n}」。`, '巡邏的空檔比情報說的還長一點。'],
}

const TWIST: Record<Direction, { title: string; body: string; push: string }> = {
  force: {
    title: '對方的重裝私兵到了',
    body: '兩台外骨骼從貨櫃後面走出來，機砲已經在轉。貨就在你身後三公尺。',
    push: '頂著機砲把貨拖出去',
  },
  hack: {
    title: '黑冰鎖定了你的神經',
    body: '防火牆後面是一層會反咬的黑冰，它已經沿著神經線爬回來，你的視野開始出現雜訊。',
    push: '不斷線，硬把資料抽完',
  },
  stealth: {
    title: '重量感應觸發了警報',
    body: '櫃子的感應比情報說的靈敏，整層樓的燈全亮了，保全正在往這裡跑。',
    push: '抓了就跑，從電梯井往下跳',
  },
}

export function highDanger(job: JobDef): DangerTemplate {
  const t = TWIST[job.direction]
  return {
    autoLog: OPENING[job.direction](job.name),
    title: t.title,
    body: t.body,
    options: [
      { id: 'abort', label: '放棄這份工作，馬上撤離', lethal: false, lethalBase: 0, survivalWindowMin: 0 },
      { id: 'push', label: t.push, lethal: true, lethalBase: 0.2 + (job.tier - 4) * 0.12, survivalWindowMin: 3 },
    ],
  }
}
