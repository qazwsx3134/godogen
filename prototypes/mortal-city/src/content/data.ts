// 原型內容：中間人、街頭工作、起始裝備、廣播。劇情委託在 cases.ts。
import type { Attr, DangerOption, Direction, Enemy, JobDef } from '../rules/core'

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

export { STARTER_GEAR } from './items'
export const CITY_TARGET = 50_000 // 封鎖線「民生補給」：全服完成的潛行工作件數

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
  /** 火力方向的高階工作要先打一場。 */
  fight?: Enemy
}

const OPENING: Record<Direction, (n: string) => string[]> = {
  force: (n) => [`你把彈匣壓滿，往「${n}」的目標出發。`, '第一道門的守衛丟下菸，舉起了槍。'],
  hack: (n) => [`你接上神經線，開始「${n}」。`, '第一層防火牆像紙一樣被撕開。'],
  stealth: (n) => [`你貼著陰影移動，開始「${n}」。`, '巡邏的空檔比情報說的還長一點。'],
}

/** 高階工作的屬性選項：依方向用不同屬性，風險比硬幹低。 */
const SKILLED: Record<Direction, { attr: Attr; label: string }> = {
  force: { attr: 'body', label: '徒手扯開貨櫃的側門，從外骨骼的死角把貨拖走' },
  hack: { attr: 'int', label: '開一條假的資料流把黑冰引開，再慢慢抽資料' },
  stealth: { attr: 'cool', label: '冷靜地關掉警報，換上保全的制服走出去' },
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
    fight: job.direction === 'force' ? { name: '倉庫守衛', hp: 80 + (job.tier - 4) * 30, atk: 11, hit: 0.55 } : undefined,
    options: [
      { id: 'abort', label: '放棄這份工作，馬上撤離', lethal: false, lethalBase: 0, survivalWindowMin: 0 },
      { id: 'push', label: t.push, lethal: true, lethalBase: 0.2 + (job.tier - 4) * 0.12, survivalWindowMin: 3 },
      {
        id: 'skilled',
        label: SKILLED[job.direction].label,
        lethal: true,
        lethalBase: 0.08 + (job.tier - 4) * 0.08,
        survivalWindowMin: 3,
        attrNeeds: { attr: SKILLED[job.direction].attr, min: 7 },
      },
    ],
  }
}
