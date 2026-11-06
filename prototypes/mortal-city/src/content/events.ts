// 事件節點：一段短文字加上 2～3 個選項。有 chance 的選項用節點自己的 seed 擲一次（重整不重抽）。
// 每則至少有一個不花錢、不要求屬性的選項，不會卡住。
import type { Attr } from '../rules/core'

export interface Effects {
  text: string
  credits?: number
  injury?: number
  heat?: number
  stress?: number
  fame?: number
  xp?: number
  /** 掉寶三選一（一般表或稀有表）。 */
  loot?: 'street' | 'rare'
  lifeline?: number
}

export interface EventOption {
  id: string
  label: string
  needs?: { attr: Attr; min: number }
  /** 要先付的信用點（不夠就不能選）。 */
  cost?: number
  /** 成功機率；沒寫＝一定成功。 */
  chance?: number
  win: Effects
  lose?: Effects
}

export interface CityEvent {
  id: string
  title: string
  body: string
  options: EventOption[]
}

const leave = (text: string): EventOption => ({ id: 'leave', label: '不關你的事，走開', win: { text } })

export const EVENTS: CityEvent[] = [
  {
    id: 'vendor',
    title: '雨中的義體販子',
    body: '高架橋下，一個穿雨衣的男人掀開推車的帆布，底下全是還沾著血的義體零件。「便宜賣，不問來路。盲盒一個 150。」',
    options: [
      { id: 'buy', label: '買一個盲盒', cost: 150, win: { text: '你打開油膩的紙盒，裡面不只一樣東西。', loot: 'street' } },
      { id: 'scare', label: '冷冷地盯著他，直到他自己把貨交出來', needs: { attr: 'cool', min: 6 }, win: { text: '他的手在發抖，把最好的那幾件推到你面前。有人看到了這一幕。', loot: 'street', heat: 1 } },
      leave('你拉上兜帽，繼續往前走。'),
    ],
  },
  {
    id: 'courier',
    title: '倒在巷子裡的快遞員',
    body: '一個快遞員倒在歌舞伎町的後巷，背包拉鍊開著，裡面露出一疊信用晶片。他還有呼吸。',
    options: [
      { id: 'loot', label: '把晶片拿走', win: { text: '你拿走了晶片。巷口的監視器紅燈閃了一下。', credits: 220, heat: 1 } },
      { id: 'help', label: '打給白蛇，讓她派人來', win: { text: '白蛇的人十分鐘就到了。「你欠我一次，也算有人欠你一次。」街上有人記住了你的名字。', fame: 15, stress: -5 } },
      leave('你跨過他，雨水沖淡了地上的血。'),
    ],
  },
  {
    id: 'pit',
    title: '地下拳賽',
    body: '停車場最底層圍了一圈人，中間的鐵籠裡正缺一個對手。莊家朝你招手：「打一場 300，輸了自己去找醫生。」',
    options: [
      { id: 'fight', label: '下場打', chance: 0.55, win: { text: '你把對手的義眼打飛了出去。觀眾在吼你的名字。', credits: 300, fame: 15 }, lose: { text: '你被打得撞上鐵籠，最後是被人拖出去的。', injury: 22 } },
      { id: 'bet', label: '押 100 在看起來比較狠的那個', cost: 100, chance: 0.5, win: { text: '你押對了。', credits: 250 }, lose: { text: '你押的那個第二回合就倒了。' } },
      leave('你沒興趣看別人流血。'),
    ],
  },
  {
    id: 'vending',
    title: '會吐錢的自販機',
    body: '荒井會管的一排自販機，有一台的面板鬆了，露出裡面的維修埠。',
    options: [
      { id: 'hack', label: '接上維修埠，讓它吐錢', needs: { attr: 'int', min: 6 }, win: { text: '整排自販機同時吐出零錢，你在荒井會的人趕到前就走了。', credits: 260, xp: 10 } },
      { id: 'kick', label: '用力踹', chance: 0.4, win: { text: '它吐出了一把硬幣。', credits: 120 }, lose: { text: '警報響了。荒井會的人記下了你的臉。', heat: 1 } },
      leave('你不想惹荒井會。'),
    ],
  },
  {
    id: 'checkpoint',
    title: 'MPD 臨檢站',
    body: '靖國通被 MPD 的臨檢站封住了，每個人都要掃描身分。你身上的東西經不起掃描。',
    options: [
      { id: 'bribe', label: '塞 200 的「罰款」給巡警', cost: 200, win: { text: '巡警收下了，順手把你的紀錄刪了一筆。', heat: -1 } },
      { id: 'run', label: '趁亂衝過去', chance: 0.6, win: { text: '你衝過去了，沒有人追上來。' }, lose: { text: '電擊槍打中了你的背，你還是逃掉了，但 MPD 有了你的影像。', injury: 15, heat: 1 } },
      { id: 'detour', label: '繞遠路', win: { text: '你繞了一大圈，雨一直沒停，心情很差。', stress: 6 } },
    ],
  },
  {
    id: 'radio',
    title: '夜鴉的點播熱線',
    body: '魔都 FM 104.9 正在開放 call-in：「今晚誰幹了最瘋的事？打進來，我讓全城聽見你。」',
    options: [
      { id: 'call', label: '打進去吹噓你的戰績', win: { text: '夜鴉笑到差點把咖啡噴在麥克風上。全城都聽到了你的代號，MPD 也是。', fame: 25, heat: 1 } },
      leave('你轉台了。'),
    ],
  },
  {
    id: 'stim',
    title: '試驗針劑',
    body: '一個沒有執照的醫生攔住你：「新配方，免費。幫我記錄副作用就好。」針筒裡的液體在發光。',
    options: [
      { id: 'take', label: '打一針', chance: 0.6, win: { text: '傷口在幾分鐘內就收口了，腦子也清楚得可怕。', injury: -30, xp: 20 }, lose: { text: '你的神經整夜都在尖叫。', stress: 22 } },
      leave('你沒那麼想當白老鼠。'),
    ],
  },
  {
    id: 'intel',
    title: '霧的情報包',
    body: '霧傳來一則訊息：「我手上有一份新宿各路人馬的名單，誰欠誰、誰在找人。200，要不要？」',
    options: [
      { id: 'buy', label: '付 200 買下', cost: 200, win: { text: '名單比你想的還長。你知道接下來該去敲誰的門了。', fame: 30 } },
      { id: 'peek', label: '趁她傳預覽檔時，順著連線把整份抓下來', needs: { attr: 'tech', min: 6 }, win: { text: '你拿到了完整名單。霧發現之後只回了一個笑臉，那比罵人還可怕。', fame: 30, stress: 4 } },
      leave('情報這種東西，買了就脫不了身。'),
    ],
  },
  {
    id: 'rooftop',
    title: '屋頂上的流浪駭客',
    body: '你翻上屋頂躲雨，發現一個老駭客在架天線。他說他以前幫荒井會做事，現在只想看星星。',
    options: [
      { id: 'pay', label: '給他 100，聽他講以前的事', cost: 100, win: { text: '他講了一整晚。你學到了一些書上沒有的東西，心也靜下來了。', xp: 25, stress: -15 } },
      { id: 'spar', label: '跟他比快手（他說贏了就把舊裝備給你）', needs: { attr: 'reflex', min: 6 }, win: { text: '你贏了。他從天線底下翻出一個布包，裡面有好東西。', loot: 'street' } },
      leave('你等雨小了就走。'),
    ],
  },
  {
    id: 'medkit',
    title: '被丟下的武裝醫療箱',
    body: '一台武裝醫療隊的飛行器剛從這裡起飛，地上留著一個沒關好的箱子。箱子上有防盜鎖，指示燈在閃。',
    options: [
      { id: 'open', label: '撬開它', chance: 0.5, win: { text: '裡面有一張還沒啟用的救命保單。你把它塞進口袋。', lifeline: 1 }, lose: { text: '防盜鎖噴出電流，你的手麻了半小時。', injury: 12 } },
      leave('跟武裝醫療隊搶東西，太蠢了。'),
    ],
  },
]

export const EVENT_BY_ID = Object.fromEntries(EVENTS.map((e) => [e.id, e]))
