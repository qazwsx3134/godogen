// 劇情委託（一次性、每角色一次；死亡後新角色可重玩）。
// P01 兩案是「試讀稿」：AI 初稿，作者試讀前不算可上線文本。測試案只用來驗證流程。
import { type Attr, type Character, type DangerOption, type Direction, type Enemy, type Slot, attrLock } from '../rules/core'
import { CASE_03, CASE_06 } from './cases_wangan'

export interface Reply {
  who: string
  at: string
  text: string
}

export interface Approach {
  id: string
  direction: Direction
  label: string
  summary: string
  autoLog: string[]
  /** 自動段結束時加的傷勢。 */
  injury: number
  /** 危險節點致命機率的修正（加在選項的 lethalBase 上，之後再扣裝備與熟練度）。 */
  lethalMod: number
  /** 這條路要打一場（自動戰鬥）。傷勢由戰鬥決定，不另加 injury。 */
  fight?: Enemy
  /** 打贏之後接著顯示的自動段。 */
  afterFight?: string[]
  /** 打贏這一場的後果（例如打了 MPD 巡警：通緝 +1）。 */
  fightHeat?: number
  /** 屬性門檻：不夠就不能選這個做法。 */
  needs?: { attr: Attr; min: number }
}

export interface CaseOption extends DangerOption {
  /** 不冒險（lethal=false）或冒險且生還時拿到的報酬；被救或死亡拿不到。 */
  reward: number
  heat?: number
  /** 白蛇幫你縫好傷口（傷勢歸零）。 */
  heal?: boolean
  /** 結案時多給的救命保單張數（03「不存在的保戶」）。 */
  lifeline?: number
  /** 結果畫面與紀錄的文字。 */
  text: string
  /** 只有走這個做法才會出現的選項。 */
  approach?: string
  /** 需要的裝備（欄位＋方向，抵押中就不能選）或屬性門檻（每條路線都看得到）。 */
  needs?: { slot: Slot; direction: Direction; label: string } | { attr: Attr; min: number }
  /** 不會死、而且算完成委託（屬性選項）。 */
  wins?: boolean
  /** 選了就要打一場：打贏＝生還；打輸才擲致命判定（用 lethalBase）。 */
  fight?: Enemy
}

/** 選項能不能選：不屬於這個做法就不顯示（null）；缺裝備回傳原因。 */
export function optionLock(c: Character, approach: string | undefined, o: CaseOption): string | null | undefined {
  if (o.approach && o.approach !== approach) return null
  const n = o.needs
  if (n && 'attr' in n) return attrLock(c, n)
  if (n && !c.equipment.some((i) => i.slot === n.slot && i.direction === n.direction)) return `需要${n.label}`
  return undefined
}

export interface StoryCase {
  id: string
  kind: 'test' | 'draft'
  title: string
  fixerId: string
  zone: string
  posted: string
  xp: number
  /** 要先結案（活著結案，任何結果都算）的案件；撤離也會解鎖，不軟鎖。 */
  requires?: string
  body: string
  /** 依前置案件的結果多一段內文：key 是 `variantOf` 回傳值。 */
  variants?: Record<string, string>
  /** 依前置案件走的做法多一則回覆（key＝做法 id）。 */
  approachReplies?: Record<string, Reply>
  replies: Reply[]
  approaches: Approach[]
  danger: { title: string; body: string; options: CaseOption[] }
  /** 被武裝醫療隊救出時，紀錄裡補的一句。 */
  lossText: string
  /** 活著完成（survived）時，依機率拿到的物品（種類、機率）。 */
  loot?: { kind: string; chance: number }[]
  /** 結案後夜鴉的插播：survived＝冒險成功，other＝其他結果。 */
  broadcast?: { survived: string; other: string }
}

export interface CaseRecord {
  approach: string
  optionId: string
  outcome: 'safe' | 'survived' | 'rescued' | 'rescued_system' | 'dead'
  reason: string
}

/** 前置案件的結果怎麼影響這一案的文字。 */
export function variantOf(prev: CaseRecord | undefined): string | null {
  if (!prev) return null
  return prev.outcome === 'survived' ? 'won' : 'lost'
}

const TEST_LOG = [
  '你沿著廢棄月台往下走，鐵軌間的積水映著紅色的維修燈。',
  '工程車就在 B3，車門半開，箱子還在副駕駛座上。',
  '你拿到箱子了。背後的隧道傳來無人機的螺旋槳聲，比預定的換班時間早了三分鐘。',
]

export const TEST_CASE: StoryCase = {
  id: 'TEST-001',
  kind: 'test',
  title: '終電後的手提箱',
  fixerId: 'k',
  zone: '新宿・地下維修道',
  posted: '2077.11.04 01:12',
  xp: 0,
  body:
    '末班車開走之後，魔都環狀線的維修道會有一台沒有登記的工程車停在 B3。車上有一只鋁製手提箱，主人已經不需要它了，但很多人在找。\n\n把箱子帶回店裡，不要打開，不要掃描，不要賣給第一個開價的人。',
  replies: [
    { who: 'k', at: '01:14', text: '我只說一次：MPD 的無人機會在兩點換班，換班前後各有五分鐘的空檔。錯過了就別硬來。' },
    { who: 'mist', at: '01:20', text: '那只箱子我也在找。你先拿到的話，記得我的價碼永遠比老頭高。' },
    { who: 'snake', at: '01:31', text: '受傷了就往我這裡爬。保單過期的，我也收，只是比較貴。' },
  ],
  approaches: [
    { id: 'force', direction: 'force', label: '強行突入', summary: '直接從工程車正面進去，最快，但會很吵。', autoLog: TEST_LOG, injury: 18, lethalMod: 0 },
    { id: 'hack', direction: 'hack', label: '黑進號誌系統', summary: '讓維修道的燈號全部轉紅，工程車自己停下來。', autoLog: TEST_LOG, injury: 18, lethalMod: 0 },
    { id: 'stealth', direction: 'stealth', label: '換班空檔潛入', summary: '等兩點的無人機換班，五分鐘內進出。', autoLog: TEST_LOG, injury: 18, lethalMod: 0 },
  ],
  danger: {
    title: 'MPD 無人機封鎖了出口',
    body: '兩台 MPD 巡邏無人機停在唯一的出口，探照燈正往你的方向掃過來。你手上有箱子，身上的傷還在流血。',
    options: [
      { id: 'drop', label: '丟下箱子，從排水管撤離', lethal: false, lethalBase: 0, survivalWindowMin: 0, reward: 0, text: '你丟下箱子撤離。委託失敗，但你活著。' },
      { id: 'run', label: '抱著箱子衝過探照燈', lethal: true, lethalBase: 0.35, survivalWindowMin: 4, reward: 1500, heat: 1, text: '你抱著箱子衝出隧道。' },
    ],
  },
  lossText: '箱子沒了。',
}

// ---------- P01：終電之後（試讀稿） ----------

export const CASE_01: StoryCase = {
  id: 'P01-01',
  kind: 'draft',
  title: '終電包裹',
  fixerId: 'k',
  zone: '新宿・環狀線新宿駅 B2',
  posted: '2077.11.05 23:02',
  xp: 30,
  body:
    '今晚最後一班環狀線，00:48 發車。B2 月台第三根柱子下，會有人跟你要一個保冷箱，暗號是「明天會下雨嗎」。\n\n箱子現在在我店裡。拿去，交給對的人，回來拿錢。\n\n不准打開。不准掃描。箱子上的燈變紅之前，一定要交出去。',
  replies: [
    { who: 'k', at: '23:10', text: '燈是電池。綠的四小時，黃的一小時，紅了就沒救了。我說的是裡面的東西，不是電池。' },
    { who: 'crow', at: '23:24', text: '各位夜貓子，今晚環狀線 B2 有 MPD 臨檢，據說在找走私的義體零件。我什麼都沒說喔。' },
    { who: 'mist', at: '23:41', text: '老頭沒告訴你收件人是誰吧？我知道。價碼另談。' },
    { who: 'snake', at: '23:52', text: '……如果那個箱子是往我這裡來的，請你跑快一點。' },
  ],
  approaches: [
    {
      id: 'force',
      direction: 'force',
      label: '正面走過臨檢',
      summary: '把箱子綁在背上，誰攔就打倒誰。一定會跟臨檢的巡警打起來：打輸了就得撤退，打贏了 MPD 會記住你（通緝 +1）。',
      injury: 0,
      lethalMod: 0.04,
      fight: { name: 'MPD 臨檢巡警', hp: 50, atk: 8, hit: 0.5, ice: 3, sense: 3 },
      autoLog: [
        '你把保冷箱綁在背上，從東口的閘門直接跨過去。',
        '兩個 MPD 巡警同時轉身拔槍：「站住！箱子放下！」',
      ],
      afterFight: ['你跨過倒在閘門邊的巡警，往 B2 跑。', 'B2 月台，00:41。第三根柱子下沒有人。箱子上的燈是黃色。'],
      fightHeat: 1,
    },
    {
      id: 'hack',
      direction: 'hack',
      label: '改掉車站的掃描器',
      summary: '黑進車站監視網，讓臨檢的掃描器看不到你，順便找出收件人在哪。',
      injury: 6,
      lethalMod: 0,
      autoLog: [
        '你在置物櫃後面接上車站的維修埠，監視畫面一格一格攤開。',
        '臨檢的掃描器被你改成「維修中」，巡警罵了一聲，揮手讓所有人過。',
        'B2 月台，00:41。畫面裡，最後一節車廂旁的長椅上，有個穿白色雨衣的女孩一動也不動。',
      ],
    },
    {
      id: 'roof',
      direction: 'force',
      needs: { attr: 'body', min: 6 },
      label: '扒上進站電車的車頂',
      summary: '從地面月台扒上一列進站的電車，沿著車頂直接到 B2 正上方的通風井。沒有人會檢查車頂，但手要夠有力。',
      injury: 5,
      lethalMod: -0.04,
      autoLog: [
        '電車進站的那一刻，你抓住車廂之間的連結桿，翻上了濕滑的車頂。',
        '雨打在臉上，架空線在頭頂嗡嗡作響。臨檢的巡警在下面，一次也沒有抬頭。',
        '你在 B2 的通風井上方鬆手，落在月台的鐵架上。00:41，箱子上的燈是黃色。',
      ],
    },
    {
      id: 'stealth',
      direction: 'stealth',
      label: '走軌道旁的維修通道',
      summary: '從四號出口的鐵門繞過臨檢。慢，水很深，但幾乎不會被看見。',
      injury: 8,
      lethalMod: -0.02,
      autoLog: [
        '你從四號出口旁的鐵門鑽進維修通道，積水淹過腳踝。',
        '頭頂傳來臨檢的腳步聲和無人機的嗡鳴，沒有人往下看。',
        '你從軌道邊爬上 B2 月台，00:41。第三根柱子下沒有人。箱子上的燈是黃色。',
      ],
    },
  ],
  danger: {
    title: '箱子的主人來了',
    body:
      '末班車進站的廣播響起時，月台另一頭走來三個穿白色制服的企業保全。領頭的那個說：「那個箱子是神坂バイオテック的財產。放下，你就可以搭這班車回家。」\n\n收件人就在最後一節車廂旁的長椅上：穿白色雨衣的女孩按著腹部，血從指縫滲出來。她看著你，嘴型是「明天會下雨嗎」。箱子上的燈開始閃。',
    options: [
      {
        id: 'hand',
        label: '把箱子交給保全，搭末班車離開',
        lethal: false,
        lethalBase: 0,
        survivalWindowMin: 0,
        reward: 0,
        text: '保全收走了箱子。車門關上前，你看見他們把那個女孩架起來帶走。老K 只回了兩個字：「知道。」委託失敗，沒有報酬。',
      },
      {
        id: 'carry',
        label: '扛起女孩和箱子，跳下軌道往維修通道跑',
        lethal: true,
        lethalBase: 0.18,
        survivalWindowMin: 4,
        reward: 600,
        heat: 1,
        text: '你把女孩扛上肩，沿著軌道間的積水一路跑到四號出口。末班車替你擋住了保全。女孩昏過去之前只說了一個名字：「白蛇」。你把她和箱子一起送到地下診所。老K 的轉帳到了，沒有附言。',
      },
      {
        id: 'climb',
        approach: 'roof',
        label: '扛起女孩，從通風井爬回電車車頂',
        lethal: true,
        lethalBase: 0.06,
        survivalWindowMin: 4,
        reward: 600,
        text: '你單手扛著女孩、單手抓著鐵梯爬上通風井。末班車剛好開出，你們趴在車頂上，離開了新宿。保全在月台上找了很久，沒有人想到要往上看。',
      },
      {
        id: 'stare',
        needs: { attr: 'cool', min: 6 },
        wins: true,
        label: '不動聲色地盯著領頭的保全：「神坂付你們的錢，夠買你們三條命嗎？」',
        lethal: false,
        lethalBase: 0,
        survivalWindowMin: 0,
        reward: 600,
        text: '領頭的保全和你對看了五秒，先移開了視線。「……我們什麼都沒看到。」他們退回月台另一頭。你扶起女孩，搭上了末班車。',
      },
      {
        id: 'brawl',
        approach: 'force',
        label: '既然已經打過一場，就把三個保全也打倒',
        lethal: true,
        lethalBase: 0.3,
        survivalWindowMin: 4,
        fight: { name: '神坂保全', hp: 60, atk: 10, hit: 0.55, ice: 5, sense: 5 },
        reward: 900,
        heat: 1,
        text: '最後一個保全倒在月台邊緣。你從他們身上搜出一張神坂的通行晶片，扛起女孩走正門出站。老K 收到晶片時哼了一聲：「多的三百算你的。」',
      },
      {
        id: 'broadcast',
        approach: 'hack',
        needs: { slot: 'deck', direction: 'hack', label: '駭客終端' },
        label: '你還連在車站網路上：用月台廣播假裝 MPD 包圍了車站',
        lethal: true,
        lethalBase: 0.06,
        survivalWindowMin: 4,
        reward: 600,
        text: '「MPD 特勤，全員不要動。」廣播一響，三個保全同時摸向耳機，然後往反方向跑。你扶著女孩上了末班車。沒有人看清楚你的臉。',
      },
      {
        id: 'slip',
        approach: 'stealth',
        needs: { slot: 'implant', direction: 'stealth', label: '光學迷彩義體' },
        label: '趁末班車進站的噪音，迷彩啟動，從保全背後帶走女孩',
        lethal: true,
        lethalBase: 0.08,
        survivalWindowMin: 4,
        reward: 600,
        text: '列車進站的風把雨吹進月台。等保全回過頭，長椅上只剩一攤水。你和女孩已經在通往四號出口的維修通道裡了。',
      },
    ],
  },
  lossText: '箱子和女孩都被保全帶走了。',
  loot: [{ kind: 'smartgun', chance: 0.35 }],
  broadcast: {
    survived: '📻 夜鴉插播：昨晚環狀線 B2 有人扛著一個女孩跳下軌道，MPD 說是「失控的通勤者」。我只能說，終電之後的新宿，總有人跑得比電車還快。',
    other: '📻 夜鴉插播：神坂バイオテック的保全昨晚在環狀線 B2「尋回失物」。失物有沒有心跳？不在新聞稿裡。',
  },
}

export const CASE_02: StoryCase = {
  id: 'P01-02',
  kind: 'draft',
  title: '診所不收現金',
  fixerId: 'snake',
  zone: '歌舞伎町・神坂社區診療所',
  posted: '2077.11.06 01:30',
  xp: 40,
  requires: 'P01-01',
  body:
    '我這裡今晚不收現金。\n\n三丁目有一間神坂バイオテック的「社區診療所」，地下二樓的病歷庫裡有一份編號 K-0413 的病歷。我要那份病歷，完整的，不是摘要。\n\n神坂今晚 03:00 要把它轉到本社，在那之前拿出來。\n\n你拿到它，我付你錢，再把你身上的洞縫好，不收費。拿不到，你身上的洞就自己想辦法。',
  variants: {
    won: '順帶一提，你昨晚扛來的那個女孩還活著。K-0413 就是她。神坂在她身體裡裝了不該裝的東西，我得知道那是什麼，才知道怎麼拿出來。',
    lost: '昨晚有個女孩沒能走到我這裡。K-0413 就是她。她現在在神坂手上，我至少要知道，他們打算對她做什麼。',
  },
  approachReplies: {
    force: { who: 'mpd', at: '01:12', text: '【MPD 通報】昨晚環狀線新宿駅有不明傭兵毆打執勤巡警兩名，特徵已建檔。提供線索者有獎。' },
    hack: { who: 'mist', at: '01:20', text: '昨晚車站的掃描器是你改的吧？手法還行。這次的班表，算我請客。' },
    roof: { who: 'crow', at: '01:18', text: '插播：昨晚有乘客說，末班車的車頂上趴著兩個人。MPD 說是雨太大看錯了。我說，魔都的雨從來不會讓人看錯。' },
    stealth: { who: 'crow', at: '01:25', text: '聽眾來電說，昨晚環狀線 B2 有個女孩憑空消失了。我說親愛的，這座城市每天都有人消失，只是很少消失得這麼漂亮。' },
  },
  replies: [
    { who: 'mist', at: '01:34', text: '神坂的病歷庫是離線的，從外面黑不進去，得有人親自接上。我可以賣你夜班清潔隊的班表，看在醫生的面子上，打八折。' },
    { who: 'k', at: '01:40', text: '診所後門的鎖是舊型的，我修過。用力踹三下就開。別跟醫生說是我講的。' },
    { who: 'crow', at: '01:52', text: '三丁目今晚停電，官方說是「例行維護」。神坂的維護，總是剛好排在半夜。' },
    { who: 'mpd', at: '02:05', text: '【MPD 公告】歌舞伎町三丁目實施臨時管制。非法侵入企業設施者，執勤人員得當場制止，包含致命武力。' },
  ],
  approaches: [
    {
      id: 'force',
      direction: 'force',
      label: '踹開後門',
      summary: '老K 說的那扇門。三下就開，但整棟樓都會聽見，得先打倒一樓的保全。',
      injury: 0,
      lethalMod: 0.05,
      fight: { name: '診療所保全', hp: 70, atk: 9, hit: 0.55, ice: 4, sense: 3 },
      autoLog: ['你在停電的巷子裡數到三。第三腳，門框整個飛了進去。', '一樓的三個保全打開手電筒，槍口全對著你。'],
      afterFight: ['你踩過碎掉的手電筒，下到地下二樓。', '病歷庫的門開著。你在檔案目錄裡找到 K-0413，開始下載。'],
    },
    {
      id: 'hack',
      direction: 'hack',
      label: '直接接上離線病歷庫',
      summary: '從停電的配電箱繞進地下室，把神經線插進病歷庫的主機。黑冰會醒，你得比它快。',
      injury: 5,
      lethalMod: 0.02,
      autoLog: [
        '你沿著配電箱的備用線路摸進地下室，緊急照明是紅色的。',
        '病歷庫的終端機沒有連網，你把神經線直接插上去，一層黑冰慢慢醒過來。',
        '你在黑冰咬到你之前找到 K-0413，開始下載。',
      ],
    },
    {
      id: 'node',
      direction: 'hack',
      needs: { attr: 'int', min: 6 },
      label: '連上街角的存取點，遠端控制整棟樓',
      summary: '診療所的備用電源還連著街區的存取點。從對街的拉麵攤就能接進去，不用走進大樓一步——前提是你算得夠快。',
      injury: 2,
      lethalMod: -0.04,
      autoLog: [
        '你在對街拉麵攤的角落坐下，點了一碗不打算吃的麵，接上存取點。',
        '診療所的門禁、電梯、監視器一個一個在你的視野裡亮起來。',
        '你讓地下二樓的病歷庫主機自己開機，開始把 K-0413 傳到你手上。',
      ],
    },
    {
      id: 'stealth',
      direction: 'stealth',
      label: '混進夜班清潔隊',
      summary: '用霧賣的班表，推著清潔車跟著隊伍進去。最安靜，但從此欠霧一個人情。',
      injury: 4,
      lethalMod: -0.03,
      autoLog: [
        '你推著清潔車跟在隊伍最後面，沒有人多看你一眼。',
        '地下二樓的病歷庫只有一個值班的護理師，她在打瞌睡。',
        'K-0413 的檔案櫃上貼著一張紙：「轉移至本社，今晚 03:00」。你開始下載。',
      ],
    },
  ],
  danger: {
    title: '神坂的回收小組提早到了',
    body:
      '03:00 還沒到，四個穿白色防護衣的回收人員走進病歷庫，帶頭的那個手上拿著一張清單，第一行就是 K-0413。\n\n資料有一半已經在你手上，另一半還在跑進度條：還要九十秒。他們還沒看見你。',
    options: [
      {
        id: 'half',
        label: '只帶走已經拿到的一半，從通風管撤離',
        lethal: false,
        lethalBase: 0,
        survivalWindowMin: 0,
        reward: 400,
        heal: true,
        text: '你帶著半份病歷爬出通風管。白蛇看完之後沉默了很久：「一半。夠我知道它在哪裡，不夠我知道怎麼拿出來。」她付了一半的錢，傷口照縫。',
      },
      {
        id: 'full',
        label: '躲在檔案櫃後面，等進度條跑完',
        lethal: true,
        lethalBase: 0.22,
        survivalWindowMin: 3,
        reward: 900,
        heat: 1,
        heal: true,
        text: '九十秒。你在檔案櫃後面數完每一秒，在他們轉身前把資料抽走。回收小組的槍聲一路追你出了後門。白蛇拿到完整的 K-0413，第一次對你笑了一下：「傷口我縫。以後在我這裡，你可以賒帳。」',
      },
      {
        id: 'sprinkler',
        approach: 'node',
        label: '讓整棟樓的灑水系統同時啟動，趁亂把資料抽完',
        lethal: true,
        lethalBase: 0.05,
        survivalWindowMin: 3,
        reward: 900,
        heal: true,
        text: '整棟樓的灑水頭同時打開，回收小組的防護衣在水裡什麼也看不見。進度條跑完時，你的麵還是熱的。白蛇拿到完整的 K-0413：「你連門都沒進？……我開始有點怕你了。」',
      },
      {
        id: 'lockdown',
        needs: { attr: 'tech', min: 6 },
        wins: true,
        label: '拆開病歷庫的門禁面板，把回收小組鎖在走廊上',
        lethal: false,
        lethalBase: 0,
        survivalWindowMin: 0,
        reward: 900,
        heal: true,
        text: '你剪斷兩條線、接上第三條，防爆門在回收小組面前落下。他們在門外敲了九十秒，你在門內等完了進度條，從另一側的貨梯離開。白蛇拿到完整的 K-0413：「你的手很穩。這種人我會記得。」',
      },
      {
        id: 'charge',
        approach: 'force',
        label: '反正後門已經踹爛了：先把回收小組打倒，再慢慢等資料',
        lethal: true,
        lethalBase: 0.35,
        survivalWindowMin: 3,
        fight: { name: '神坂回收小組', hp: 80, atk: 11, hit: 0.55, ice: 6, sense: 6 },
        reward: 1200,
        heat: 1,
        heal: true,
        text: '四套白色防護衣倒在檔案櫃之間。進度條跑完時，你還順手拿走了他們的回收清單。白蛇看著清單上的其他編號，很久沒有說話：「K-0413 不是第一個。多的錢，拿去買子彈。」',
      },
      {
        id: 'swap',
        approach: 'hack',
        needs: { slot: 'deck', direction: 'hack', label: '駭客終端' },
        label: '你已經在主機裡：把回收清單上的 K-0413 換成另一份空白病歷',
        lethal: true,
        lethalBase: 0.08,
        survivalWindowMin: 3,
        reward: 900,
        heal: true,
        text: '回收小組照著清單，收走了一份空白的病歷，然後離開。進度條跑完時，病歷庫只剩你和打瞌睡的護理師。白蛇拿到完整的 K-0413：「神坂要過好幾天才會發現。夠了。」',
      },
      {
        id: 'wall',
        approach: 'stealth',
        needs: { slot: 'implant', direction: 'stealth', label: '光學迷彩義體' },
        label: '迷彩啟動，貼著牆站在他們身後，等進度條跑完',
        lethal: true,
        lethalBase: 0.1,
        survivalWindowMin: 3,
        reward: 900,
        heal: true,
        text: '他們在你面前翻了九十秒的檔案櫃，有一個人的手肘離你的臉不到十公分。進度條跑完，你拔掉線，跟著他們一起走出病歷庫。白蛇拿到完整的 K-0413：「下次別讓我知道細節。」',
      },
    ],
  },
  lossText: '病歷沒拿到，白蛇也不會付錢。',
  loot: [{ kind: 'coproc', chance: 0.5 }],
  broadcast: {
    survived: '📻 夜鴉插播：三丁目的神坂診療所昨晚「設備異常」，後門飛到了對街。如果你是那扇門的主人，我建議下次換一把老K 修不到的鎖。',
    other: '📻 夜鴉插播：神坂的回收小組今早宣布「病歷轉移順利完成」。順利得很，只是少了一半。',
  },
}

/** 全部的劇情委託：新宿 01、02，灣岸 03、06，測試案。 */
export const CASES: StoryCase[] = [CASE_01, CASE_02, CASE_03, CASE_06, TEST_CASE]
export const CASE_BY_ID: Record<string, StoryCase> = Object.fromEntries(CASES.map((c) => [c.id, c]))

/** 依前置案件結果組出這一案的內文。 */
/** 依前置案件走的做法多一則回覆。 */
export function caseReplies(sc: StoryCase, done: Record<string, CaseRecord>): Reply[] {
  const extra = sc.requires ? sc.approachReplies?.[done[sc.requires]?.approach ?? ''] : undefined
  return extra ? [extra, ...sc.replies] : sc.replies
}

export function caseBody(sc: StoryCase, done: Record<string, CaseRecord>): string {
  const v = sc.requires ? variantOf(done[sc.requires]) : null
  return v && sc.variants?.[v] ? `${sc.body}\n\n${sc.variants[v]}` : sc.body
}

export function caseUnlocked(sc: StoryCase, done: Record<string, CaseRecord>): boolean {
  return !sc.requires || !!done[sc.requires]
}
