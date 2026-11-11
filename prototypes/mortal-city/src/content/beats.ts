// 委託的場面：一件委託拆成幾個場面，每個場面擲一次骰池（規則見 rules/core.ts「骰池判定」）。
// 文字依路線共用，不必每件委託各寫一份。
import type { Attr, CostKind, Direction, PoolResult } from '../rules/core'

export interface Beat {
  title: string
  attr: Attr
  /** 擲之前的情境。 */
  setup: string
  /** 各結果的敘述。 */
  out: Record<PoolResult, string>
  /** 「成功但付代價」時二選一。 */
  costs: [BeatCost, BeatCost]
  /** 失敗時直接吃的代價（加倍）。 */
  fail: CostKind
}
export interface BeatCost {
  kind: CostKind
  text: string
}

export const BEATS: Record<Direction, Beat[]> = {
  force: [
    {
      title: '逼近',
      attr: 'reflex',
      setup: '對方的人散在貨架之間。你得在他們排好陣形之前貼上去。',
      out: {
        crit: '你從他們的視線死角切進去，第一個人還沒轉頭就倒了。',
        clean: '你搶到了掩體，他們的第一輪射擊全打在鋼板上。',
        cost: '你搶到了位置，但過程不太漂亮。',
        fail: '他們先看到你。子彈追著你的腳跟，你是滾進掩體的。',
      },
      costs: [
        { kind: 'injury', text: '硬吃一發流彈衝過去' },
        { kind: 'heat', text: '一路開槍壓制，整條街都聽見了' },
      ],
      fail: 'injury',
    },
    {
      title: '壓制',
      attr: 'body',
      setup: '領頭的那個躲在柱子後面喊人。把他逼出來，剩下的就會亂。',
      out: {
        crit: '你一腳踹倒貨架，半排人被壓在下面。',
        clean: '你頂著火力推過去，他們開始往後退。',
        cost: '你把他們壓回去了，自己也不好受。',
        fail: '你推不動。他們的增援從側門進來了。',
      },
      costs: [
        { kind: 'injury', text: '用身體去撞開缺口' },
        { kind: 'stress', text: '把義體輸出推到紅線' },
      ],
      fail: 'injury',
    },
  ],
  hack: [
    {
      title: '接入',
      attr: 'int',
      setup: '你找到一個沒上鎖的維修埠。接上去之前，得先騙過門口那層認證。',
      out: {
        crit: '認證把你當成管理員，還順手給了你一份值班表。',
        clean: '認證通過。系統沒有任何反應，這是最好的反應。',
        cost: '你進去了，但留下了一點痕跡。',
        fail: '認證退回三次。有個程序開始記錄你的連線。',
      },
      costs: [
        { kind: 'stress', text: '用自己的神經訊號硬撐過認證' },
        { kind: 'heat', text: '借用一個有案底的身分' },
      ],
      fail: 'stress',
    },
    {
      title: '破冰',
      attr: 'tech',
      setup: '資料在第三層。中間隔著一道會回咬的防火牆。',
      out: {
        crit: '你找到一個沒補的舊漏洞，防火牆整面倒下，還多撈到一包帳本。',
        clean: '你繞開了防火牆，它連警告都沒發。',
        cost: '你鑽過去了，防火牆在你身上留了記號。',
        fail: '防火牆咬住了你。視野邊緣開始出現雜訊。',
      },
      costs: [
        { kind: 'stress', text: '讓回授電流燒過去' },
        { kind: 'pay', text: '丟掉一部分資料換時間' },
      ],
      fail: 'stress',
    },
    {
      title: '斷線',
      attr: 'cool',
      setup: '東西到手了。現在要在追蹤程式算出你的位置之前，乾淨地離開。',
      out: {
        crit: '你把追蹤導向隔壁大樓的自動販賣機，還有時間清掉紀錄。',
        clean: '你斷得很乾淨。那邊只會看到一次普通的維修連線。',
        cost: '你斷線了，但沒來得及全部收乾淨。',
        fail: '追蹤程式比你快。有人已經在往這裡趕。',
      },
      costs: [
        { kind: 'heat', text: '留下連線紀錄，先走再說' },
        { kind: 'stress', text: '強制拔線，頭痛一整晚' },
      ],
      fail: 'heat',
    },
  ],
  stealth: [
    {
      title: '潛入',
      attr: 'cool',
      setup: '後巷有一台攝影機、一個抽菸的保全。巡邏空檔大概四十秒。',
      out: {
        crit: '保全剛好轉身接電話。你進門的時候順手拿了他的門禁卡。',
        clean: '你踩著攝影機轉頭的節奏進去，沒有人抬頭。',
        cost: '你進去了，只是沒有計畫的那麼安靜。',
        fail: '攝影機轉回來的時候你還在走廊中間。',
      },
      costs: [
        { kind: 'heat', text: '被攝影機拍到半張臉' },
        { kind: 'injury', text: '翻牆時被鐵絲網劃開一道' },
      ],
      fail: 'heat',
    },
    {
      title: '得手',
      attr: 'tech',
      setup: '東西鎖在櫃子裡。鎖是新的，底下還有一片重量感應。',
      out: {
        crit: '鎖開了，感應也沒動。櫃子裡還多了一樣情報沒提到的東西。',
        clean: '你用等重的東西換走了目標，鎖在你身後自己扣上。',
        cost: '東西到手了，過程出了點狀況。',
        fail: '感應亮了一下。你聽見樓上有椅子被推開的聲音。',
      },
      costs: [
        { kind: 'pay', text: '弄壞了外殼，買家會砍價' },
        { kind: 'stress', text: '屏著呼吸硬拆，手抖了半分鐘' },
      ],
      fail: 'stress',
    },
    {
      title: '脫身',
      attr: 'reflex',
      setup: '回頭的路上多了一組巡邏。你得換一條路出去。',
      out: {
        crit: '你從通風管出去，落地的地方剛好是自己停車的那條巷子。',
        clean: '你貼著牆走完最後一段，出來的時候雨剛好下大。',
        cost: '你出來了，沒有全身而退。',
        fail: '一道手電筒的光打在你臉上：「誰在那裡？」',
      },
      costs: [
        { kind: 'injury', text: '從二樓跳下來，腳踝不太對勁' },
        { kind: 'heat', text: '撞倒一個保全才跑掉' },
      ],
      fail: 'injury',
    },
  ],
}
