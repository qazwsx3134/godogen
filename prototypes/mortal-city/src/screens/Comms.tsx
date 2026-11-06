import { ArrowLeft, Radio, Send, X } from '../components/icons'
import { useEffect, useRef, useState } from 'react'
import { ActionButton, Avatar, Meter, Panel, Tabs } from '../components/ui'
import { TypingLine, typingMs, useReveal } from '../components/reveal'
import { BROADCASTS, FIXERS } from '../content/data'
import { CONTACTS, CONTACT_BY_ID, offerOf, uniqueLock } from '../content/contacts'
import { type DmThread, type useGame, ALL_JOBS, dmAcceptBlock, dmUnread } from '../game/state'
import { DIRECTION_LABEL } from '../rules/core'

const CHAT = [
  { who: '貓與霓虹', text: '有人知道灣岸那邊的封鎖什麼時候會開嗎？' },
  { who: '鐵雨', text: '送貨工作多做一點就會開啦，大家一起推。' },
]

type G = ReturnType<typeof useGame>

export function Comms({ game, onClose }: { game: G; onClose: () => void }) {
  const [tab, setTab] = useState<'public' | 'dm'>(dmUnread(game.g) ? 'dm' : 'public')
  const [open, setOpen] = useState<string | null>(null)
  return (
    <div className="absolute inset-0 z-20 flex flex-col bg-bg/80" role="dialog" aria-label="通訊">
      <div className="mt-auto flex max-h-[88dvh] flex-col">
        <Panel tone="strong" innerClass="flex max-h-[86dvh] flex-col">
          <div className="flex items-center gap-2 border-b border-line/60 px-3 py-2">
            {open ? (
              <button onClick={() => setOpen(null)} className="grid min-h-11 min-w-11 place-items-center text-cyan" aria-label="回到私人訊息">
                <ArrowLeft size={20} />
              </button>
            ) : (
              <Radio size={16} className="text-red" />
            )}
            <b className="flex-1 text-heading">{open ? FIXERS[open].name : '通訊'}</b>
            <button onClick={onClose} className="grid min-h-11 min-w-11 place-items-center text-cyan" aria-label="關閉">
              <X size={20} />
            </button>
          </div>
          {open ? (
            <Chat key={open} game={game} id={open} />
          ) : (
            <>
              <div className="px-3 pt-2">
                <Tabs
                  value={tab}
                  onChange={setTab}
                  items={[
                    { id: 'public', label: '公共頻道' },
                    { id: 'dm', label: '私人訊息', badge: dmUnread(game.g) },
                  ]}
                />
              </div>
              {tab === 'public' ? <Public /> : <Threads game={game} onOpen={setOpen} />}
            </>
          )}
        </Panel>
      </div>
    </div>
  )
}

function Public() {
  return (
    <>
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
    </>
  )
}

function Threads({ game, onOpen }: { game: G; onOpen: (id: string) => void }) {
  const { g } = game
  const c = g.character
  return (
    <div className="space-y-2 overflow-y-auto p-3">
      <p className="m-0 text-[13px] text-muted">中間人會私下發委託，回覆就能接。信任：替他做成一件工作 +1、劇情結案 +1～3。你的街頭名聲 {c.fame}。</p>
      {CONTACTS.map((k) => {
        const th: DmThread | undefined = g.dm[k.fixerId]
        const unread = th ? th.msgs.length - th.seen : 0
        const last = th?.msgs.at(-1)
        return (
          <button key={k.fixerId} onClick={() => onOpen(k.fixerId)} className="flex w-full items-center gap-3 border border-line/60 p-2 text-left">
            <Avatar id={k.fixerId} size={44} />
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-2">
                <b className="text-heading">{FIXERS[k.fixerId].name}</b>
                <span className="text-[12px] text-muted">信任 {c.trust[k.fixerId] ?? 0}</span>
                {th?.offer && <span className="ml-auto border border-red px-1 text-[12px] text-red">委託・待回覆</span>}
              </div>
              <div className="truncate text-[14px] text-fg-list">{last ? (unread > 0 ? '（新訊息）' : `${last.from === 'me' ? '你：' : ''}${last.text}`) : '（沒有訊息）'}</div>
            </div>
            {unread > 0 && <span className="tech rounded-sm bg-red px-1 text-[12px] leading-5 text-bg">{unread}</span>}
          </button>
        )
      })}
    </div>
  )
}

function Chat({ game, id }: { game: G; id: string }) {
  const { g, act } = game
  const c = g.character
  const k = CONTACT_BY_ID[id]
  const th = g.dm[id]
  const msgs = th?.msgs ?? []
  const r = useReveal(
    msgs.length,
    th?.seen ?? 0,
    (i) => typingMs(msgs[i]?.text ?? '', msgs[i]?.from === 'me'),
    (n) => act({ t: 'seen', key: `dm:${id}`, n }),
  )
  const end = useRef<HTMLDivElement>(null)
  useEffect(() => {
    end.current?.scrollIntoView({ block: 'nearest' })
  }, [r.n, r.typing])
  const trust = c.trust[id] ?? 0
  const offer = th?.offer ? offerOf(id, th.offer) : undefined
  const job = offer ? ALL_JOBS[offer.jobId] : undefined
  const block = dmAcceptBlock(g)
  const uLock = uniqueLock(c, k.unique.jobId)
  const next = msgs[r.n]
  return (
    <>
      <div className="border-b border-line/40 px-3 py-2">
        <Meter label={`信任・${FIXERS[id].role}`} value={Math.min(trust, k.unique.trust)} max={k.unique.trust} text={`${trust}`} />
        <div className="mt-1 text-[12px] text-muted">
          獨特委託：{c.uniqueDone.includes(k.unique.jobId) ? '已完成' : uLock ? `？？？（${uLock}）` : '已經可以接'}
        </div>
      </div>
      <div className="min-h-[200px] flex-1 space-y-2 overflow-y-auto p-3">
        {msgs.slice(0, r.n).map((m, i) =>
          m.from === 'me' ? (
            <div key={i} className="msg-in flex justify-end">
              <p className="m-0 max-w-[80%] border border-red/60 bg-red-bg px-2 py-1 text-[15px] text-fg">{m.text}</p>
            </div>
          ) : (
            <div key={i} className="msg-in flex items-end gap-2">
              <Avatar id={id} size={28} />
              <p className="m-0 max-w-[80%] border-l-2 border-cyan bg-raised px-2 py-1 text-[15px] text-fg">{m.text}</p>
            </div>
          ),
        )}
        {r.typing && next?.from === 'npc' && <TypingLine who={FIXERS[id].name} />}
        {!r.typing && offer && job && (
          <div className="msg-in space-y-2 border border-red p-2">
            <div className="text-[13px]">
              <b className="text-red">{job.unique ? '獨特委託' : '私訊委託'}</b>
              <span className="ml-2 text-muted">
                {job.name}・{DIRECTION_LABEL[job.direction]}・難度 {job.tier}・¢{job.reward}
                {job.unique ? '・附贈一件裝備・只有一次' : ''}
              </span>
            </div>
            <ActionButton tone="danger" disabled={!!block} reason={block} onClick={() => act({ t: 'dmReply', fixerId: id, accept: true })}>
              「{offer.accept}」（接下，加入排隊）
            </ActionButton>
            <ActionButton tone="ghost" onClick={() => act({ t: 'dmReply', fixerId: id, accept: false })}>
              「{offer.decline}」
            </ActionButton>
          </div>
        )}
        <div ref={end} />
      </div>
      {r.typing && (
        <div className="border-t border-line/60 p-2 text-right">
          <button onClick={r.skip} className="min-h-11 px-3 text-[14px] text-cyan">
            全部顯示 »
          </button>
        </div>
      )}
    </>
  )
}
