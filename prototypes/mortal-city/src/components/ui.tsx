// 遊戲元件：依 ui-system.md v0.4（reference.JPG 論壇終端風格）
import { type ReactNode, useEffect, useState } from 'react'
import { AlertTriangle, type LucideIcon } from 'lucide-react'
import { FIXERS } from '../content/data'

export function Panel({
  children,
  tone = 'line',
  small = false,
  className = '',
  innerClass = '',
}: {
  children: ReactNode
  tone?: 'line' | 'red' | 'strong'
  small?: boolean
  className?: string
  innerClass?: string
}) {
  const t = tone === 'red' ? 'cut-red' : tone === 'strong' ? 'cut-strong' : ''
  return (
    <div className={`cut ${small ? 'cut-sm' : ''} ${t} ${className}`}>
      <div className={`cut-in ${innerClass}`}>{children}</div>
    </div>
  )
}

/** 面板標題列：左側方塊標記＋標題，右側可放動作。 */
export function PanelHead({ icon, title, right }: { icon?: ReactNode; title: string; right?: ReactNode }) {
  return (
    <div className="flex items-center gap-2 border-b border-line/60 px-3 py-2">
      {icon && <span className="text-red">{icon}</span>}
      <h2 className="m-0 flex-1 text-[16px] font-bold leading-tight text-heading">{title}</h2>
      {right}
    </div>
  )
}

/**
 * 霓虹圖示：方角描邊＋光暈，後面疊紅、青兩層錯位殘影（RGB 分離）；on 時偶爾故障抖動。
 * 用在地圖節點與底部導覽，讓通用的線條圖示有終端機的味道。
 */
export function NeonIcon({ icon: Icon, size = 18, on = false, className = '' }: { icon: LucideIcon; size?: number; on?: boolean; className?: string }) {
  const p = { size, strokeWidth: 2, strokeLinecap: 'square' as const, strokeLinejoin: 'miter' as const, 'aria-hidden': true }
  return (
    <span className={`neon-icon ${on ? 'neon-on' : ''} ${className}`}>
      <Icon {...p} className="neon-ghost neon-ghost-r" />
      <Icon {...p} className="neon-ghost neon-ghost-b" />
      <Icon {...p} className="neon-core" />
    </span>
  )
}

export function Emblem({ size = 40 }: { size?: number }) {
  // 自製 emblem：切角六邊形＋城市天際線，不使用參考圖的原作標誌
  return (
    <svg width={size} height={size} viewBox="0 0 48 48" aria-hidden className="shrink-0">
      <path d="M10 4h28l8 8v24l-8 8H10l-8-8V12z" fill="none" stroke="var(--color-cyan)" strokeWidth="2" />
      <path d="M9 34V22h5v-6h5v10h4V12h5v14h4v-8h5v16z" fill="var(--color-cyan)" opacity=".85" />
      <path d="M8 38h32" stroke="var(--color-red)" strokeWidth="2" />
    </svg>
  )
}

export function Avatar({ id, size = 44 }: { id: string; size?: number }) {
  const f = FIXERS[id]
  const [broken, setBroken] = useState(false)
  return (
    <div className="cut cut-sm shrink-0" style={{ width: size, height: size }}>
      <div className="cut-in grid place-items-center overflow-hidden bg-raised">
        {broken ? (
          <span className="tech text-[18px] font-bold text-cyan">{f?.glyph ?? '?'}</span>
        ) : (
          <img src={f?.avatar} alt={f?.name ?? ''} className="h-full w-full object-cover" onError={() => setBroken(true)} />
        )}
      </div>
    </div>
  )
}

type BtnTone = 'primary' | 'outline' | 'danger' | 'ghost'

export function ActionButton({
  children,
  onClick,
  tone = 'outline',
  disabled,
  reason,
  className = '',
  type = 'button',
  testId,
}: {
  children: ReactNode
  onClick?: () => void
  tone?: BtnTone
  disabled?: boolean
  reason?: string
  className?: string
  type?: 'button' | 'submit'
  testId?: string
}) {
  const edge =
    tone === 'primary' ? 'cut-strong' : tone === 'danger' ? 'cut-red' : tone === 'ghost' ? '' : ''
  const text =
    tone === 'primary'
      ? 'text-bg'
      : tone === 'danger'
        ? 'text-red'
        : 'text-cyan'
  const fill = tone === 'primary' ? { ['--fill' as string]: 'var(--color-cyan)' } : undefined
  return (
    <div className={className}>
      <button
        type={type}
        data-testid={testId}
        onClick={onClick}
        disabled={disabled}
        className={`cut cut-sm block w-full ${edge} ${disabled ? 'opacity-45' : 'active:brightness-125'}`}
        style={fill}
      >
        <span className={`cut-in flex min-h-12 items-center justify-center gap-2 px-4 py-2 text-[16px] font-bold ${text}`}>
          {children}
        </span>
      </button>
      {disabled && reason && <p className="mt-1 mb-0 text-[13px] text-muted">✖ {reason}</p>}
    </div>
  )
}

/**
 * 不可逆的操作按兩次：第一次只「上膛」（按鈕改成確認文字），3 秒內再按同一顆才執行。
 * armed 是目前上膛的那顆按鈕的 key。
 */
export function useTwoStep(ms = 3000) {
  const [armed, setArmed] = useState<string | null>(null)
  useEffect(() => {
    if (!armed) return
    const id = setTimeout(() => setArmed(null), ms)
    return () => clearTimeout(id)
  }, [armed, ms])
  return {
    armed,
    press(key: string, run: () => void) {
      if (armed === key) {
        setArmed(null)
        run()
      } else setArmed(key)
    },
  }
}

/** 論壇頁籤風格的分段切換。 */
export function Tabs<T extends string>({
  value,
  onChange,
  items,
}: {
  value: T
  onChange: (v: T) => void
  items: { id: T; label: string; badge?: number }[]
}) {
  return (
    <div className="flex gap-2" role="tablist">
      {items.map((it) => {
        const on = it.id === value
        return (
          <button
            key={it.id}
            role="tab"
            aria-selected={on}
            onClick={() => onChange(it.id)}
            className={`cut cut-sm flex-1 ${on ? 'cut-strong' : ''}`}
            style={on ? { ['--fill' as string]: 'var(--color-raised)' } : undefined}
          >
            <span
              className={`cut-in flex min-h-11 items-center justify-center gap-1 px-2 text-[15px] font-bold ${on ? 'text-cyan' : 'text-muted'}`}
            >
              {it.label}
              {it.badge ? <span className="tech rounded-sm bg-red px-1 text-[12px] leading-5 text-bg">{it.badge}</span> : null}
            </span>
          </button>
        )
      })}
    </div>
  )
}

/** 列表列：論壇主題列的手機版，右側欄位換成報酬／耗時／風險。 */
export function ListRow({
  icon,
  prefix,
  title,
  meta,
  cols,
  selected,
  onClick,
  lethal,
}: {
  icon: ReactNode
  prefix?: string
  title: string
  meta: string
  cols: { label: string; value: string }[]
  selected?: boolean
  onClick?: () => void
  lethal?: boolean
}) {
  return (
    <button onClick={onClick} className={`block w-full text-left ${selected ? 'cut cut-sm cut-red' : ''}`}>
      <div className={`${selected ? 'cut-in' : 'border-b border-line/40'} flex gap-3 px-3 py-3`}>
        <span className={`mt-1 ${prefix || selected ? 'text-red' : 'text-line'}`}>{icon}</span>
        <div className="min-w-0 flex-1">
          <div className="text-[16px] leading-snug font-medium text-fg-list">
            {prefix && <span className="mr-1 font-bold text-red">【{prefix}】</span>}
            {title}
          </div>
          <div className="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-[13px] text-muted">
            {cols.map((c) => (
              <span key={c.label}>
                {c.label} <b className="tech text-[14px] text-heading">{c.value}</b>
              </span>
            ))}
          </div>
          <div className="mt-1 flex items-center gap-2 text-[13px] text-muted">
            {lethal && (
              <span className="flex items-center gap-1 font-bold text-red">
                <AlertTriangle size={14} /> 可能永久死亡
              </span>
            )}
            <span>{meta}</span>
          </div>
        </div>
      </div>
    </button>
  )
}

export function Meter({
  label,
  value,
  max,
  tone = 'cyan',
  text,
}: {
  label: string
  value: number
  max: number
  tone?: 'cyan' | 'red' | 'warning' | 'positive'
  text?: string
}) {
  const pct = Math.max(0, Math.min(100, (value / max) * 100))
  const color = { cyan: 'bg-cyan', red: 'bg-red', warning: 'bg-warning', positive: 'bg-positive' }[tone]
  return (
    <div>
      <div className="flex justify-between text-[13px] text-muted">
        <span>{label}</span>
        <span className="tech text-[14px] text-heading">{text ?? `${value}/${max}`}</span>
      </div>
      <div className="mt-1 h-2 border border-line/70 bg-bg">
        <div className={`h-full ${color}`} style={{ width: `${pct}%` }} />
      </div>
    </div>
  )
}

export function Tag({ children, tone = 'line' }: { children: ReactNode; tone?: 'line' | 'red' | 'warning' | 'positive' }) {
  const c = {
    line: 'border-line text-cyan',
    red: 'border-red text-red',
    warning: 'border-warning text-warning',
    positive: 'border-positive text-positive',
  }[tone]
  return <span className={`inline-flex items-center gap-1 border px-1.5 text-[13px] leading-6 ${c}`}>{children}</span>
}
