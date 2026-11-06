/** 手機才震：桌面 Chromium 也有 navigator.vibrate，要連觸控一起查（見 prototypes/LESSONS.md）。 */
export function buzz(ms: number | number[]) {
  try {
    if (navigator.maxTouchPoints > 0 && typeof navigator.vibrate === 'function') navigator.vibrate(ms)
  } catch {
    /* 不支援就算了 */
  }
}

export const reducedMotion = () => !!window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
