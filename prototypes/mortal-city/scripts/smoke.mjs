// L2 冒煙測試（pnpm smoke）：開 Vite dev server，用 Playwright 的手機觸控模擬跑真瀏覽器。
//   1. 360／390／430 寬 × 三個分頁：頁面不能橫向捲動（scrollWidth ≤ clientWidth）
//   2. （360 寬）加一點屬性要出現通知；地圖 → 走兩個節點（自動段、場面擲骰、選代價、戰鬥、結案、三選一都點過）→ 重新整理後存檔一致；
//      擲骰後畫面列出骰子點數，擲骰與選代價的畫面不能橫向捲動
//   3. 「清除全部存檔」按一次不會清；測試案「終電後的手提箱」走過做法的兩個場面、到危險節點：每個冒險選項寫出「致命判定・擲 N 顆」（不顯示百分比），
//      選了之後列出骰池組成，確認後擲出骰子（擲出 4～5 時選代價）
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
    const ctx = await phone(360)
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
    let rolled = 0
    let costed = 0
    let intro = 0
    const deadline = Date.now() + 120_000
    while (left < 2 && Date.now() < deadline) {
      const click = async (loc) => {
        if (await loc.count()) {
          await loc.first().click()
          return true
        }
        return false
      }
      // 第一次遇到骰池：介紹視窗（示意骰是 SVG 骰子圖）
      if (await page.locator('[data-testid=intro-ok]').count()) {
        if (!intro++) {
          check((await page.locator('[role=dialog][aria-label=骰池怎麼玩] svg[aria-label$=點]').count()) >= 4, '第一次擲骰前出現介紹，用骰子圖示範四種結果')
          await page.screenshot({ path: `${OUT}dice-intro.png`, fullPage: true })
        }
        await page.locator('[data-testid=intro-ok]').click()
        continue
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
      // 委託場面：選代價（第一個）或直接擲骰（不加骰）
      const cost = page.locator('[data-testid=beat-cost]')
      if (await cost.count()) {
        if (!costed++) {
          await page.screenshot({ path: `${OUT}beat-cost.png`, fullPage: true })
          const o = await overflow(page)
          check(o.sw <= o.cw && o.x === 0, `360px 選代價畫面不能橫向捲動（scrollWidth ${o.sw}／clientWidth ${o.cw}）`)
        }
        await cost.first().click()
        continue
      }
      const roll = page.locator('[data-testid=beat-roll]')
      if (await roll.count()) {
        if (!rolled) {
          await page.screenshot({ path: `${OUT}beat-scene.png`, fullPage: true })
          const o = await overflow(page)
          check(o.sw <= o.cw && o.x === 0, `360px 場面擲骰畫面不能橫向捲動（scrollWidth ${o.sw}／clientWidth ${o.cw}）`)
        }
        const before = await page.locator('[data-testid=dice] svg').count()
        await roll.first().click()
        if (!rolled++) {
          await page.waitForTimeout(250)
          check((await page.locator('.die-rolling').count()) > 0, '擲骰後先播擲骰動畫（骰子亂跳）')
          await page.screenshot({ path: `${OUT}beat-rolling.png`, fullPage: true })
          await page.waitForTimeout(1500)
          check((await page.locator('[data-testid=dice] svg').count()) > before && (await page.locator('.die-lit').count()) > 0, '動畫播完：骰子圖示落定，決定結果的那顆亮起')
          await page.screenshot({ path: `${OUT}beat-rolled.png`, fullPage: true })
        } else await page.waitForTimeout(1500)
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
    check(left === 2, `走完兩個節點（離開 ${left} 次、擲骰 ${rolled} 次、選代價 ${costed} 次、結案 ${claimed} 次、三選一 ${picked} 次）`)
    check(rolled > 0, '至少走過一個委託場面並擲骰')
    await ctx.close()
  }

  // 3. 測試案的危險節點（360 寬）
  {
    const ctx = await phone(360)
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
    let storyScene = 0
    while (Date.now() < deadline && !(await page.getByText(/重大危險/).count())) {
      if (await page.getByText('點一下顯示').count()) await page.getByText('點一下顯示').click()
      else if (await page.locator('[data-testid=intro-ok]').count()) await page.locator('[data-testid=intro-ok]').click()
      else if (await page.locator('[data-testid=beat-cost]').count()) await page.locator('[data-testid=beat-cost]').first().click()
      else if (await page.locator('[data-testid=beat-roll]').count()) {
        if (!storyScene++) {
          await page.screenshot({ path: `${OUT}story-scene.png`, fullPage: true })
          const o = await overflow(page)
          check(o.sw <= o.cw && o.x === 0, `360px 劇情做法的場面不能橫向捲動（scrollWidth ${o.sw}／clientWidth ${o.cw}）`)
        }
        await page.locator('[data-testid=beat-roll]').first().click()
        await page.waitForTimeout(1500)
      }
      else if (await page.getByRole('button', { name: '出發' }).count()) {
        await page.locator('button:not([disabled])', { hasText: '強行突入' }).click()
        await page.getByRole('button', { name: '出發' }).click()
      } else await page.waitForTimeout(500)
    }
    // 第一次遇到致命判定：介紹
    check((await page.locator('[role=dialog][aria-label=致命判定怎麼玩]').count()) === 1, '第一次遇到危險節點，出現致命判定的介紹')
    await page.screenshot({ path: `${OUT}lethal-intro.png`, fullPage: true })
    await page.locator('[data-testid=intro-ok]').click()
    const options = page.locator('[data-testid=danger-option]')
    const lethal = options.filter({ hasText: '致命判定' })
    const texts = await lethal.allInnerTexts()
    check(texts.length > 0 && texts.every((t) => /致命判定・擲 \d 顆/.test(t) && !/\d+%/.test(t)), `危險節點的冒險選項寫出擲幾顆、不寫百分比（${texts.length} 個）`)
    await lethal.first().click()
    const confirm = page.locator('[data-testid=danger-confirm]')
    check(/確認：擲 \d 顆/.test(await confirm.innerText()), '選了冒險選項，確認鈕寫出要擲幾顆')
    await page.screenshot({ path: `${OUT}danger.png`, fullPage: true })
    {
      const o = await overflow(page)
      check(o.sw <= o.cw && o.x === 0, `360px 危險節點（骰池組成與加骰）不能橫向捲動（scrollWidth ${o.sw}／clientWidth ${o.cw}）`)
    }
    await confirm.click()
    await page.waitForTimeout(250)
    check((await page.locator('[role=dialog][aria-label=致命判定] .die-rolling').count()) > 0, '致命判定：全螢幕揭曉，先播擲骰動畫')
    await page.screenshot({ path: `${OUT}reveal-rolling.png`, fullPage: true })
    await page.locator('[data-testid=reveal-ok]').waitFor({ timeout: 5000 })
    check((await page.locator('[role=dialog][aria-label=致命判定] .die-lit').count()) === 1, '揭曉：決定結果的那顆骰亮起，出現「繼續」')
    await page.screenshot({ path: `${OUT}reveal.png`, fullPage: true })
    await page.locator('[data-testid=reveal-ok]').click()
    await page.waitForTimeout(400)
    if (await page.locator('[data-testid=lethal-cost]').count()) {
      await page.screenshot({ path: `${OUT}danger-cost.png`, fullPage: true })
      const o = await overflow(page)
      check(o.sw <= o.cw && o.x === 0, `360px 致命判定 4～5 的二選一不能橫向捲動（scrollWidth ${o.sw}／clientWidth ${o.cw}）`)
      await page.locator('[data-testid=lethal-cost]').last().click()
    }
    await page.waitForTimeout(400)
    // 擲出 1～3 而現場有敵人：追兵逼近，打一場
    if (await page.getByText(/逼近了/).count()) {
      await page.screenshot({ path: `${OUT}chase.png`, fullPage: true })
      check(true, '致命判定失敗：追兵逼近，改成打一場（這次有觸發）')
      await page.locator('button:not([disabled])', { hasText: '正面交火' }).first().click()
      await page.getByRole('button', { name: '開打' }).click()
      const end = Date.now() + 30_000
      while (Date.now() < end && !(await page.getByText(/致命判定擲出 \d/).count())) await page.waitForTimeout(500)
    }
    check((await page.getByText(/致命判定擲出 \d/).count()) > 0, '致命判定擲完，畫面或結案寫出擲出的點數')
    await page.screenshot({ path: `${OUT}danger-done.png`, fullPage: true })
    await ctx.close()
  }
} finally {
  await browser.close()
  await server.close()
}
console.log(fails.length ? `\n${fails.length} 項失敗` : '\n全部通過')
process.exit(fails.length ? 1 : 0)
