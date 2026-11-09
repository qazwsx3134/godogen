import { Radio, Send, X } from 'lucide-react'
import { Avatar, Panel } from '../components/ui'
import { BROADCASTS } from '../content/data'

const CHAT = [
  { who: '貓與霓虹', text: '有人知道灣岸那邊的封鎖什麼時候會開嗎？' },
  { who: '鐵雨', text: '送貨工作多做一點就會開啦，大家一起推。' },
]

/** 通訊裡有幾則訊息（入口的紅色數字）。 */
export const COMMS_COUNT = BROADCASTS.length + CHAT.length

export function Comms({ onClose }: { onClose: () => void }) {
  return (
    <div className="absolute inset-0 z-20 flex flex-col bg-bg/80" role="dialog" aria-label="通訊">
      <div className="mt-auto flex max-h-[88dvh] flex-col">
        <Panel tone="strong" innerClass="flex flex-col">
          <div className="flex items-center gap-2 border-b border-line/60 px-3 py-2">
            <Radio size={16} className="text-red" />
            <b className="flex-1 text-heading">通訊・魔都公共頻道</b>
            <button onClick={onClose} className="grid min-h-11 min-w-11 place-items-center text-cyan" aria-label="關閉">
              <X size={20} />
            </button>
          </div>
          <div className="space-y-3 overflow-y-auto p-3">
            {BROADCASTS.map((b, i) => (
              <div key={i} className="flex gap-3">
                <Avatar id="crow" size={40} />
                <div className="flex-1 border-l-2 border-red pl-2">
                  <div className="text-[13px] font-bold text-red">系統廣播・夜鴉 @ FM 104.9</div>
                  <p className="m-0 text-[15px] text-fg">{b}</p>
                </div>
              </div>
            ))}
            {CHAT.map((m, i) => (
              <div key={i} className="pl-[52px]">
                <div className="text-[13px] text-cyan">{m.who}</div>
                <p className="m-0 text-[15px] text-fg-list">{m.text}</p>
              </div>
            ))}
          </div>
          <div className="flex gap-2 border-t border-line/60 p-3">
            <input placeholder="發表回覆…（原型未連線）" className="min-h-11 flex-1 border border-line bg-raised px-2 text-[16px] text-fg outline-none" />
            <button className="grid min-h-11 min-w-11 place-items-center border border-line text-cyan" aria-label="送出">
              <Send size={18} />
            </button>
          </div>
        </Panel>
      </div>
    </div>
  )
}
