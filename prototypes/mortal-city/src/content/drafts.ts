// AI（或人）寫的劇情委託草稿：story-drafts/*.json，審查報告 story-drafts/*.review.md。
// 只在「紀錄 → 劇情總覽 → 草稿」裡給作者讀，不會接進街區地圖。流程見 docs/story-pipeline/README.md。
import type { StoryCase } from './cases'
import { checkStory, type StoryIssue } from './storyCheck'

const cases = import.meta.glob<StoryCase>('/story-drafts/*.json', { eager: true, import: 'default' })
const reviews = import.meta.glob<string>('/story-drafts/*.review.md', { eager: true, query: '?raw', import: 'default' })

export interface Draft {
  file: string
  sc: StoryCase
  /** 機器檢查（docs/story-pipeline 的第 2 關）。 */
  issues: StoryIssue[]
  /** 審查員的報告（第 3 關）；還沒審就沒有。 */
  review?: string
}

const all = Object.values(cases)
export const DRAFTS: Draft[] = Object.entries(cases).map(([file, sc]) => ({
  file: file.replace('/story-drafts/', ''),
  sc,
  issues: checkStory(sc, all),
  review: reviews[file.replace(/\.json$/, '.review.md')],
}))
