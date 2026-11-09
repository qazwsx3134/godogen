// L2 冒煙測試（pnpm smoke）：開 Vite dev server，用 Playwright 的手機觸控模擬跑真瀏覽器。
//   1. 360／390／430 寬 × 三個分頁：頁面不能橫向捲動（scrollWidth ≤ clientWidth）
//   2. 加一點屬性要出現通知；地圖 → 走兩個節點（自動段、戰鬥、結案、三選一都點過）→ 重新整理後存檔一致
//   3. 「清除全部存檔」按一次不會清；測試案「終電後的手提箱」走到危險節點：每個冒險選項都寫出死亡與重傷機率
// 失敗時結束碼 1，並列出哪一步。截圖存在 smoke-out/（已在 .gitignore）。
import { createServer } from 'vite'
import { chromium } from 'playwright'
import fs from 'node:fs'

const OUT = new URL('../smoke-out/', import.meta.url).pathname
fs.mkdirSync(OUT, { recursive: true })
const fails = []
const check = (ok, what) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${what}`)
  if (!ok) fails.push(what)
}

const server = await createServer({ root: new URL('..', import.meta.url).pathname, server: { port: 0, host: '127.0.0.1' }, logLevel: 'error' })
await server.listen()
const url = server.resolvedUrls.local[0]
const browser = await chromium.launch()
const phone = (width) => browser.newContext({ viewport: { width, height: 800 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 })
const tab = (page, label) => page.locator('nav button', { hasText: label }).click()
// 新傭兵先挑起始裝備（三選一視窗蓋住整個畫面）
const start = async (page) => {
  await page.goto(url)
  await page.locator('[role=dialog][aria-label=三選一] button').first().click()
}
const overflow = (page) =>
  page.evaluate(() => {
    const el = document.scrollingElement
    window.scrollTo(200, window.scrollY)
    const x = window.scrollX
    window.scrollTo(0, window.scrollY)
    return { sw: el.scrollWidth, cw: el.clientWidth, x }
  })

try {
  // 1. 版面寬度
  for (const w of [360, 390, 430]) {
    const ctx = await phone(w)
    const page = await ctx.newPage()
    await start(page)
    for (const label of ['街區', '角色', '紀錄']) {
      await tab(page, label)
      await page.waitForTimeout(400) // 故障轉場跑完
      const o = await overflow(page)
      check(o.sw <= o.cw && o.x === 0, `${w}px「${label}」不能橫向捲動（scrollWidth ${o.sw}／clientWidth ${o.cw}／scrollX ${o.x}）`)
    }
    await ctx.close()
  }

  // 2. 走兩個節點
  {
    const ctx = await phone(390)
    const page = await ctx.newPage()
    await start(page)
    // 新傭兵有 4 點屬性：加一點後要出現通知，寫出哪些數值變了
    await tab(page, '角色')
    await page.locator('main button', { hasText: '屬性' }).first().click()
    await page.locator('button[aria-label="提升反應"]').click()
    check(/命中/.test(await page.locator('[data-testid=notice]').innerText()), '加屬性後出現通知（反應 → 命中變化）')
    await tab(page, '街區')
    let left = 0
    let claimed = 0
    let picked = 0
    const deadline = Date.now() + 120_000
    while (left < 2 && Date.now() < deadline) {
      const click = async (loc) => {
        if (await loc.count()) {
          await loc.first().click()
          return true
        }
        return false
      }
      if (await click(page.locator('.claim-toast'))) continue
      if (await click(page.getByRole('button', { name: /^繼續/ }))) {
        claimed++
        continue
      }
      if (await click(page.locator('[role=dialog][aria-label=三選一] button'))) {
        picked++
        if (picked === 1) check((await page.locator('[data-testid=notice]').count()) > 0, '挑完三選一，畫面下方出現通知')
        continue
      }
      if (await click(page.getByRole('button', { name: '離開，回到地圖' }))) {
        left++
        if (left === 1) {
          const before = await page.evaluate(() => JSON.stringify(Object.fromEntries(Object.entries(localStorage))))
          await page.reload()
          await page.waitForTimeout(500)
          const after = await page.evaluate(() => JSON.stringify(Object.fromEntries(Object.entries(localStorage))))
          check(before === after, '重新整理後存檔不變')
        }
        continue
      }
      // 戰術：選第一個能用的再按「開打」
      const tactic = page.locator('button:not([disabled])', { hasText: '正面交火' })
      if (await tactic.count()) {
        await tactic.first().click()
        await page.getByRole('button', { name: '開打' }).click()
        continue
      }
      // 事件：第一個能選的選項
      if (await click(page.locator('[data-testid=event-option]:not([disabled])'))) continue
      // 地圖：優先走委託
      const next = page.locator('[data-testid=next-node]')
      if (await next.count()) {
        const job = next.filter({ hasText: '委託・' })
        await ((await job.count()) ? job.first() : next.first()).click()
        continue
      }
      await page.waitForTimeout(500) // 自動段、戰鬥播放中
    }
    await page.screenshot({ path: `${OUT}walk.png` })
    check(left === 2, `走完兩個節點（離開 ${left} 次、結案 ${claimed} 次、三選一 ${picked} 次）`)
    await ctx.close()
  }

  // 3. 測試案的危險節點
  {
    const ctx = await phone(390)
    const page = await ctx.newPage()
    await start(page)
    await tab(page, '紀錄')
    const save = () => page.evaluate(() => JSON.stringify(Object.fromEntries(Object.entries(localStorage))))
    const before = await save()
    await page.getByRole('button', { name: /清除全部存檔/ }).click()
    check((await save()) === before && (await page.getByRole('button', { name: /再按一次/ }).count()) === 1, '「清除全部存檔」按一次只換成確認文字，不會清掉')
    await page.waitForTimeout(3200) // 確認狀態逾時，按鈕恢復
    await page.getByRole('button', { name: /跑一次測試案/ }).click()
    await tab(page, '街區')
    const deadline = Date.now() + 60_000
    while (Date.now() < deadline && !(await page.getByText(/重大危險/).count())) {
      if (await page.getByText('點一下顯示').count()) await page.getByText('點一下顯示').click()
      else if (await page.getByRole('button', { name: '出發' }).count()) {
        await page.locator('button:not([disabled])', { hasText: '強行突入' }).click()
        await page.getByRole('button', { name: '出發' }).click()
      } else await page.waitForTimeout(500)
    }
    const lethal = await page.locator('button', { hasText: '重傷' }).allInnerTexts()
    await page.screenshot({ path: `${OUT}danger.png`, fullPage: true })
    check(lethal.length > 0 && lethal.every((t) => /死亡\s*\d+%/.test(t) && /重傷\s*\d+%/.test(t)), `危險節點的冒險選項都寫出死亡與重傷機率（${lethal.length} 個）`)
    await ctx.close()
  }
} finally {
  await browser.close()
  await server.close()
}
console.log(fails.length ? `\n${fails.length} 項失敗` : '\n全部通過')
process.exit(fails.length ? 1 : 0)
