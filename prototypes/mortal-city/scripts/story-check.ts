// pnpm story:check [草稿.json ...]：機器檢查劇情委託草稿（沒給檔名就檢查 story-drafts/ 底下全部）。
// 有錯誤時結束碼 1；只有警告時 0。規則在 src/content/storyCheck.ts，說明見 docs/story-pipeline/README.md。
import fs from 'node:fs'
import path from 'node:path'
import { checkStory } from '../src/content/storyCheck'
import type { StoryCase } from '../src/content/cases'

const dir = path.resolve(import.meta.dirname, '../story-drafts')
const args = process.argv.slice(2)
const files = args.length ? args.map((f) => path.resolve(f)) : fs.readdirSync(dir).filter((f) => f.endsWith('.json')).map((f) => path.join(dir, f))
if (!files.length) {
  console.log('story-drafts/ 底下沒有草稿。')
  process.exit(0)
}
const drafts: [string, StoryCase][] = []
let errors = 0
for (const f of files) {
  try {
    drafts.push([f, JSON.parse(fs.readFileSync(f, 'utf8')) as StoryCase])
  } catch (e) {
    console.log(`✖ ${path.basename(f)}：不是合法的 JSON（${(e as Error).message}）`)
    errors++
  }
}
for (const [f, sc] of drafts) {
  const issues = checkStory(
    sc,
    drafts.map(([, x]) => x),
  )
  const e = issues.filter((x) => x.level === 'error')
  const w = issues.filter((x) => x.level === 'warn')
  errors += e.length
  console.log(`\n${e.length ? '✖' : '✓'} ${path.basename(f)}（${sc.id}「${sc.title}」）：錯誤 ${e.length}、警告 ${w.length}`)
  for (const x of [...e, ...w]) console.log(`  ${x.level === 'error' ? 'ERROR' : 'warn '}  ${x.where}：${x.msg}`)
}
console.log(errors ? `\n共 ${errors} 個錯誤：修好才能交給審查員。` : '\n沒有錯誤。警告請在審查報告裡說明是否要修。')
process.exit(errors ? 1 : 0)
