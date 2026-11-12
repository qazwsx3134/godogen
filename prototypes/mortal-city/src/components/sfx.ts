// UI 音效：全部用 WebAudio 即時合成，不用音檔。瀏覽器要等第一次點擊後才允許發聲，所以第一次點擊時才建立 AudioContext。
// 開關記在 localStorage（只是這台裝置的偏好）。

const KEY = 'mortal-city:sfx'
let ctx: AudioContext | null = null
let master: GainNode | null = null
let rain: { src: AudioBufferSourceNode; gain: GainNode } | null = null
let enabled = (() => {
  try {
    return localStorage.getItem(KEY) !== 'off'
  } catch {
    return true
  }
})()
const listeners = new Set<() => void>()

export const sfxEnabled = () => enabled
export function onSfxChange(f: () => void) {
  listeners.add(f)
  return () => void listeners.delete(f)
}

export function setSfx(on: boolean) {
  enabled = on
  try {
    localStorage.setItem(KEY, on ? 'on' : 'off')
  } catch {
    /* 私密模式等情況忽略 */
  }
  if (on) {
    unlock()
    startRain()
  } else stopRain()
  listeners.forEach((f) => f())
}

/** 第一次使用者操作時呼叫：建立 AudioContext 並開始雨聲。 */
export function unlock() {
  if (!enabled) return
  if (!ctx) {
    const AC = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext
    if (!AC) return
    ctx = new AC()
    master = ctx.createGain()
    master.gain.value = 0.6
    master.connect(ctx.destination)
  }
  if (ctx.state === 'suspended') void ctx.resume()
  startRain()
}

function noiseBuffer(sec: number) {
  const b = ctx!.createBuffer(1, Math.floor(ctx!.sampleRate * sec), ctx!.sampleRate)
  const d = b.getChannelData(0)
  for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1
  return b
}

function tone(freq: number, dur: number, type: OscillatorType = 'square', gain = 0.05, slideTo?: number, at = 0) {
  if (!ctx || !master || !enabled) return
  const t = ctx.currentTime + at
  const o = ctx.createOscillator()
  const g = ctx.createGain()
  o.type = type
  o.frequency.setValueAtTime(freq, t)
  if (slideTo) o.frequency.exponentialRampToValueAtTime(slideTo, t + dur)
  g.gain.setValueAtTime(gain, t)
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur)
  o.connect(g).connect(master)
  o.start(t)
  o.stop(t + dur + 0.02)
}

function noise(dur: number, freq: number, gain = 0.1, kind: BiquadFilterType = 'bandpass', at = 0) {
  if (!ctx || !master || !enabled) return
  const t = ctx.currentTime + at
  const src = ctx.createBufferSource()
  src.buffer = noiseBuffer(dur)
  const f = ctx.createBiquadFilter()
  f.type = kind
  f.frequency.value = freq
  const g = ctx.createGain()
  g.gain.setValueAtTime(gain, t)
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur)
  src.connect(f).connect(g).connect(master)
  src.start(t)
}

function startRain() {
  if (!ctx || !master || rain || !enabled) return
  const src = ctx.createBufferSource()
  src.buffer = noiseBuffer(2)
  src.loop = true
  const lp = ctx.createBiquadFilter()
  lp.type = 'lowpass'
  lp.frequency.value = 900
  const hp = ctx.createBiquadFilter()
  hp.type = 'highpass'
  hp.frequency.value = 200
  const gain = ctx.createGain()
  gain.gain.value = 0.035
  src.connect(hp).connect(lp).connect(gain).connect(master)
  src.start()
  rain = { src, gain }
}

function stopRain() {
  rain?.src.stop()
  rain = null
}

/** 各種音效。 */
export const sfx = {
  click: () => tone(1900, 0.03, 'square', 0.025),
  enter: () => {
    tone(180, 0.18, 'sawtooth', 0.04, 900)
    tone(1400, 0.05, 'square', 0.03, undefined, 0.16)
  },
  hit: () => {
    noise(0.08, 1400, 0.12)
    tone(240, 0.06, 'square', 0.04, 120)
  },
  crit: () => {
    noise(0.1, 2200, 0.16)
    tone(1320, 0.14, 'triangle', 0.07, 1980)
  },
  hurt: () => {
    tone(120, 0.22, 'sine', 0.22, 50)
    noise(0.14, 500, 0.12, 'lowpass')
  },
  zap: () => {
    for (let i = 0; i < 6; i++) tone(1800 + Math.random() * 2400, 0.018, 'square', 0.03, undefined, i * 0.022)
  },
  whoosh: () => noise(0.25, 700, 0.08),
  success: () => [523, 659, 784, 1047].forEach((f, i) => tone(f, 0.16, 'triangle', 0.07, undefined, i * 0.08)),
  fail: () => tone(220, 0.4, 'sawtooth', 0.05, 90),
  /** 擲骰：一串電子雜訊的喀噠聲。 */
  dice: () => {
    for (let i = 0; i < 9; i++) {
      noise(0.025, 2600 + Math.random() * 2400, 0.07, 'bandpass', i * 0.055)
      tone(600 + Math.random() * 900, 0.015, 'square', 0.015, undefined, i * 0.055)
    }
  },
  /** 一顆骰子落定。 */
  die: () => {
    tone(1500, 0.035, 'square', 0.03, 700)
    noise(0.03, 3000, 0.05)
  },
  toast: () => {
    tone(880, 0.06, 'square', 0.035)
    tone(1320, 0.08, 'square', 0.035, undefined, 0.07)
  },
}
