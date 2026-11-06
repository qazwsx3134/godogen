// 城市新聞跑馬燈：固定的城市雜訊，加上依你做過的事產生的新聞（通緝、劇情案結果、名聲、傳奇檔案）。
import type { Game } from '../game/state'

export type NewsTag = 'MPD' | '神坂' | 'FM104.9' | 'AD' | '港務部' | '傳說'
export interface News {
  tag: NewsTag
  text: string
}

const BASE: News[] = [
  { tag: 'AD', text: '神坂バイオテック・新一代強化肌腱，分期 0 利率，「讓你的身體追上你的野心」' },
  { tag: 'FM104.9', text: '夜鴉：今晚降雨機率 100%，酸度中等，出門記得戴面罩，也記得戴腦子' },
  { tag: '港務部', text: '灣岸物流帶「例行管制」第 41 天，民生補給延遲屬正常現象' },
  { tag: 'MPD', text: '提醒市民：未登記義體屬違法行為，檢舉有獎' },
  { tag: 'AD', text: '武裝醫療隊・白金保單，五分鐘內抵達，否則退你一半（限生前申請）' },
  { tag: '神坂', text: '神坂股價 ▲2.4%，社區診療所計畫「深受市民信賴」' },
]

/** 依目前的生涯產生新聞；同樣的狀態永遠得到同樣的清單。 */
export function newsFor(g: Game): News[] {
  const c = g.character
  const cases = g.run.cases
  const out: News[] = []
  if (c.heat >= 3) out.push({ tag: 'MPD', text: `懸賞：新宿不明傭兵，特徵已建檔，通緝等級 ${c.heat}★，提供線索者獎金 ¢5,000` })
  else if (c.heat >= 1) out.push({ tag: 'MPD', text: '新宿街區近日暴力事件增加，巡邏密度上調' })
  const c1 = cases['P01-01']
  if (c1) out.push(c1.outcome === 'survived' ? { tag: 'FM104.9', text: '夜鴉：昨晚環狀線 B2 有個保冷箱準時送到了。送貨的人，我們都不知道是誰' } : { tag: 'MPD', text: '環狀線新宿駅臨檢「順利完成」，查獲可疑保冷箱一只' })
  const c2 = cases['P01-02']
  if (c2) out.push(c2.outcome === 'survived' ? { tag: '神坂', text: '神坂股價 ▼3.1%：三丁目社區診療所「設備異常」，病歷系統暫停服務' } : { tag: '神坂', text: '神坂發言人：K 系列病歷轉移作業順利完成' })
  const c3 = cases['P01-03']
  if (c3) out.push({ tag: '港務部', text: c3.outcome === 'survived' ? '新木場冷鏈堆場「從來沒有人」，港務部否認武裝醫療隊曾降落' : '新木場 C 區冷藏貨櫃恢復正常溫度' })
  const c6 = cases['P01-06']
  if (c6) out.push({ tag: 'FM104.9', text: c6.outcome === 'survived' ? '夜鴉：灣岸封鎖前的最後一班貨運列車「準時通過」，車上載了什麼，港務部拒絕說明' : '灣岸封鎖線正式關閉，最後一班列車是空車' })
  if (c.fame.level >= 3) out.push({ tag: 'FM104.9', text: `夜鴉：最近新宿的中間人都在問同一個名字——「${c.name}」` })
  if (c.lifelines > 0) out.push({ tag: 'AD', text: '你的救命保單仍然有效。武裝醫療隊，感謝您選擇活下去' })
  const last = g.meta.legends.at(-1)
  if (last) out.push({ tag: '傳說', text: last.end === 'dead' ? `${last.name} 死在${last.district}。酒吧裡還有人在講那天晚上的事` : `${last.name} 從${last.district}退休了。沒有人知道那個人現在在哪裡` })
  return [...out, ...BASE]
}
