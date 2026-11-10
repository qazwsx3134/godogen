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
  /** 亮出名號：名聲要到這個等級才能選。 */
  fame?: number
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
      { id: 'name', label: '【亮出名號】報上你的代號', fame: 3, win: { text: '他聽過你的代號，二話不說把推車最底下那個盒子塞給你：「算我孝敬的，以後別找我麻煩。」', loot: 'street' } },
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
      { id: 'name', label: '【亮出名號】讓莊家看清楚是誰來了', fame: 3, win: { text: '莊家認出你，臉色一變，塞了一疊晶片給你：「你站在籠邊就好，別下場，讓他們知道今晚誰在看。」', credits: 200, fame: 5 } },
      leave('你沒興趣看別人流血。'),
    ],
  },
  {
    id: 'vending',
    title: '會吐錢的販賣機',
    body: '荒井會管的一排販賣機，有一台的面板鬆了，露出裡面的維修埠。',
    options: [
      { id: 'hack', label: '接上維修埠，讓它吐錢', needs: { attr: 'int', min: 6 }, win: { text: '整排販賣機同時吐出零錢，你在荒井會的人趕到前就走了。', credits: 260, xp: 10 } },
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
      { id: 'name', label: '【亮出名號】直接走到巡警面前，讓他掃你的臉', fame: 3, chance: 0.6, win: { text: '巡警看了一眼螢幕，手指停了兩秒，然後揮手讓你過去。他不想今晚加班。', heat: -1 }, lose: { text: '巡警看到螢幕上的名字，反而按下了通報鍵。你的臉現在在每一台 MPD 的終端上。', heat: 2 } },
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

/** 灣岸的事件（冷鏈、走私、封鎖線）。 */
export const WANGAN_EVENTS: CityEvent[] = [
  {
    id: 'reefer',
    title: '漏電的冷藏貨櫃',
    body: '一個冷藏貨櫃的電纜被老鼠咬斷了，門縫在滴水。裡面的貨是冷凍保存的義體零件，再過一小時就全壞了。',
    options: [
      { id: 'grab', label: '撬開門，挑一件還沒壞的', win: { text: '你挑走了最好的那件。貨櫃的追蹤器記下了開門時間。', loot: 'street', heat: 1 } },
      { id: 'fix', label: '接好電纜，修好溫控，向貨主收修理費', needs: { attr: 'tech', min: 7 }, win: { text: '溫控重新啟動。貨主是個走私客，他付了錢，還說會跟朋友提起你。', credits: 300, fame: 15 } },
      leave('不是你的貨，不是你的事。'),
    ],
  },
  {
    id: 'cards',
    title: '碼頭走私客的牌局',
    body: '貨運碼頭的貨櫃屋裡，四個走私客在打牌，桌上堆著信用晶片。「缺一個人，最低注 200。」',
    options: [
      { id: 'bet', label: '坐下來玩一把', cost: 200, chance: 0.45, win: { text: '你贏了。他們看你的眼神變了。', credits: 520 }, lose: { text: '你輸得很乾淨。' } },
      { id: 'cheat', label: '用義手換牌（反應要夠快）', needs: { attr: 'reflex', min: 7 }, win: { text: '沒有人看見你的手動過。你帶著一疊晶片走出貨櫃屋。', credits: 420, stress: 3 } },
      { id: 'name', label: '【亮出名號】把代號寫在籌碼上推到桌子中間', fame: 6, win: { text: '四個人互看了一眼，把桌上的晶片分了一份給你：「新宿來的那個？這局算你的，下次換個地方坐。」', credits: 350 } },
      leave('你不跟走私客賭錢。'),
    ],
  },
  {
    id: 'drone',
    title: '墜落的港務部無人機',
    body: '一台港務部的貨運無人機掉在堆場邊，螺旋槳還在轉。它的記憶體裡有今晚所有的航線。',
    options: [
      { id: 'strip', label: '拆下零件賣掉', win: { text: '零件很值錢。無人機的求救訊號在你離開前已經送出去了。', credits: 260, heat: 1 } },
      { id: 'read', label: '接上它的記憶體，讀出航線', needs: { attr: 'int', min: 7 }, win: { text: '你把航線賣給了三個不同的人。灣岸的中間人開始記住你的名字。', fame: 25, xp: 20 } },
      leave('你繞過那台還在掙扎的機器。'),
    ],
  },
  {
    id: 'refugees',
    title: '封鎖線旁的人',
    body: '封鎖線的鐵絲網旁邊擠著一群人，手上提著全部家當。他們在等一個說好會來帶路的人，已經等了兩天。',
    options: [
      { id: 'give', label: '分給他們 150', cost: 150, win: { text: '他們沒說謝謝，只是把錢分成很多份。你的心比較靜了。', fame: 15, stress: -12 } },
      { id: 'guide', label: '帶他們從排水道繞過去', needs: { attr: 'cool', min: 7 }, win: { text: '你帶著二十個人走過排水道，沒有一個人出聲。夜鴉第二天在節目裡提到了這件事，沒有說你的名字。', fame: 30, heat: 1 } },
      { id: 'name', label: '【亮出名號】放話出去：這些人，我罩的', fame: 6, win: { text: '一個小時後，那個失約的帶路人自己出現了，臉色發白。他一個一個把人帶走，沒收錢。', fame: 15, stress: -8 } },
      leave('你幫不了所有人。'),
    ],
  },
  {
    id: 'diver',
    title: '海底隧道的潛水夫',
    body: '一個剛從海底隧道浮上來的潛水夫攔住你：「我撿到一張救命保單，還沒登記。300 賣你。」',
    options: [
      { id: 'buy', label: '付 300 買下', cost: 300, win: { text: '保單是真的。', lifeline: 1 } },
      { id: 'snatch', label: '趁他不注意直接搶走', chance: 0.5, win: { text: '你搶到保單就跑，他在後面罵了你一整條街。', lifeline: 1, heat: 1 }, lose: { text: '他的潛水刀比你想的快。', injury: 16 } },
      leave('撿來的保單，誰知道是誰的。'),
    ],
  },
  {
    id: 'portcheck',
    title: '港務部的臨檢',
    body: '海岸高架上，港務部的武裝臨檢攔下了每一台車和每一個人。輪到你了。',
    options: [
      { id: 'bribe', label: '塞 300 給檢查員', cost: 300, win: { text: '檢查員收下錢，把你的資料「漏」掉了。', heat: -1 } },
      { id: 'name', label: '【亮出名號】把你的代號報給檢查員', fame: 6, chance: 0.6, win: { text: '檢查員的上司親自走過來，客氣地請你先走。港務部最近不想跟你這種人有瓜葛。', heat: -1 }, lose: { text: '檢查員笑了：「就是你？」三台無人機同時對準了你。你跑掉了，但港務部有了你的完整檔案。', heat: 2, injury: 10 } },
      { id: 'run', label: '跳下高架', chance: 0.5, win: { text: '你落在下面的貨櫃頂上，一路跑進堆場。' }, lose: { text: '你摔在貨櫃的邊角上，港務部的無人機記下了你的臉。', injury: 18, heat: 1 } },
      { id: 'wait', label: '乖乖排隊，等他們查完', win: { text: '你排了一個小時，雨一直沒停。', stress: 8 } },
    ],
  },
]

export const EVENT_BY_ID = Object.fromEntries([...EVENTS, ...WANGAN_EVENTS].map((e) => [e.id, e]))
