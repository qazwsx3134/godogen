import { Building2, Users } from '../components/icons'
import { Meter, Panel, PanelHead } from '../components/ui'
import { CITY_TARGET, JOBS } from '../content/data'
import { CASE_BY_ID } from '../content/cases'
import { CityStrip, type StripMode } from '../components/CityStrip'
import { SEVERE_INJURY, jobDurationMs } from '../rules/core'
import { type useGame, ALL_JOBS } from '../game/state'

const ZONES = [
  { name: '新宿街區', online: 312, done: 18_420, deaths: 7, state: '可進入' },
  { name: '灣岸物流帶', online: 0, done: 0, deaths: 0, state: '✖ 需要封鎖線開通' },
]

export function CityScreen({ game }: { game: ReturnType<typeof useGame> }) {
  const { g, now } = game
  const c = g.character
  const q = g.queue
  const queueRunning = q.items.length > 0 && !q.paused && q.startedAt !== null
  const highActive = g.high && g.high.stage !== 'done'
  const storyRunning = g.story.stage === 'auto' || g.story.stage === 'fight' || g.story.stage === 'danger'
  let mode: StripMode = 'rest'
  let label = c.injury >= SEVERE_INJURY ? '重傷休養中・新宿的公寓' : c.injury > 0 ? '休養中・新宿的公寓' : '休息中・新宿的公寓'
  let sub: string | undefined
  if (!c.alive) {
    mode = 'dead'
    label = '✖ 訊號中斷'
  } else if (highActive) {
    mode = 'run'
    label = `⚠ 高階工作：${JOBS[g.high!.jobId].name}`
    sub = g.high!.stage === 'danger' ? '等待你的選擇' : undefined
  } else if (storyRunning) {
    mode = 'run'
    label = `劇情委託：${CASE_BY_ID[g.story.caseId!].title}`
    sub = g.story.stage === 'danger' ? '等待你的選擇' : g.story.stage === 'fight' ? '戰鬥中' : undefined
  } else if (queueRunning) {
    const j = ALL_JOBS[q.items[0]]
    const left = q.startedAt! + jobDurationMs(j, c.prof[j.direction].level) - now
    const s = Math.max(0, Math.round(left / 1000))
    mode = 'run'
    label = `出任務：${j.name}`
    sub = `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}・剩 ${q.items.length} 件`
  }
  return (
    <div className="space-y-3">
      <CityStrip mode={mode} label={label} sub={sub} look={g.character.look} />
      <Panel tone="strong" innerClass="p-4">
        <div className="text-[13px] text-red">城市事件・進行中</div>
        <h1 className="my-1 text-[20px] font-bold text-heading">灣岸封鎖線</h1>
        <p className="m-0 text-fg">港務部封鎖了通往灣岸的物流出口。全服一起完成潛行送貨類工作，推進「民生補給」。</p>
        <div className="mt-3">
          <Meter label="民生補給（潛行工作件數）" value={g.city.supply} max={CITY_TARGET} text={`${g.city.supply.toLocaleString()} / ${CITY_TARGET.toLocaleString()}`} />
        </div>
        <p className="mt-2 mb-0 text-[13px] text-muted">排隊中的工作要結算後才計入。達標後永久開通灣岸路線；有效貢獻者每帳號領一次參與獎，前段貢獻只多拿稱號。</p>
      </Panel>
      <Panel innerClass="pb-1">
        <PanelHead icon={<Building2 size={16} />} title="區域動態（本週）" />
        {ZONES.map((z) => (
          <div key={z.name} className="border-b border-line/40 px-3 py-3">
            <div className="flex items-center gap-2">
              <b className="flex-1 text-fg-list">{z.name}</b>
              <span className={z.state.startsWith('✖') ? 'text-[13px] text-red' : 'text-[13px] text-positive'}>{z.state}</span>
            </div>
            <div className="mt-1 flex gap-4 text-[13px] text-muted">
              <span className="flex items-center gap-1">
                <Users size={13} /> 在這區做工作 <b className="tech text-heading">{z.online}</b>
              </span>
              <span>
                完成 <b className="tech text-heading">{z.done.toLocaleString()}</b>
              </span>
              <span>
                死亡 <b className="tech text-red">{z.deaths}</b>
              </span>
            </div>
          </div>
        ))}
        <p className="m-0 px-3 py-2 text-[13px] text-muted">每個人的工作各自結算，不會互相搶目標。（原型用假資料）</p>
      </Panel>
    </div>
  )
}
