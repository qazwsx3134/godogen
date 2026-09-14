import type { Scene } from "../../types";

/**
 * Phase 1 prototype scene — 《消失的草莓牛奶》
 * See docs/gintama-like/chat-3.md:116-155 for the original brief.
 * `portrait` / `sfx` on Line are reserved fields, unused in Phase 1.
 */
export const missingStrawberryMilk: Scene = {
  id: "missing-strawberry-milk",
  title: "消失的草莓牛奶",
  start: "intro",
  beats: {
    intro: {
      id: "intro",
      type: "dialogue",
      lines: [
        { speaker: "銀時", text: "……沒了。" },
        { speaker: "銀時", text: "草莓牛奶，沒了。" },
        { speaker: "新八", text: "才一盒牛奶，用得著這種表情嗎？" },
        { speaker: "銀時", text: "新八，這是江戶最後一滴正義。" },
      ],
      next: "choice_suspect",
    },

    choice_suspect: {
      id: "choice_suspect",
      type: "choice",
      prompt: "你要先去問誰？",
      options: [
        { id: "ask_shinpachi", label: "新八", next: "suspect_shinpachi", setFlags: ["asked:shinpachi"] },
        { id: "ask_kagura", label: "神樂", next: "suspect_kagura", setFlags: ["asked:kagura"] },
        { id: "ask_landlady", label: "房東", next: "suspect_landlady", setFlags: ["asked:landlady"] },
      ],
    },

    suspect_shinpachi: {
      id: "suspect_shinpachi",
      type: "dialogue",
      lines: [
        { speaker: "新八", text: "我才不會喝那種甜死人的東西！" },
        { speaker: "銀時", text: "你嘴角有白色的東西。" },
        { speaker: "新八", text: "這是刮鬍膏！我還沒長鬍子但這是刮鬍膏！" },
      ],
      next: "convergence",
    },

    suspect_kagura: {
      id: "suspect_kagura",
      type: "dialogue",
      lines: [
        { speaker: "神樂", text: "咪呀，我對牛奶沒興趣，我只喝優格。" },
        { speaker: "銀時", text: "那你手上那個空盒是什麼？" },
        { speaker: "神樂", text: "……優格口味的牛奶盒。" },
      ],
      next: "convergence",
    },

    suspect_landlady: {
      id: "suspect_landlady",
      type: "dialogue",
      lines: [
        { speaker: "房東", text: "在問這個之前，你們這個月的房租呢？" },
        { speaker: "銀時", text: "……我們改天再聊牛奶的事。" },
      ],
      next: "convergence",
    },

    convergence: {
      id: "convergence",
      type: "dialogue",
      lines: [
        { speaker: "新八", text: "所以到底是誰喝的啊……" },
        { speaker: "銀時", text: "……那是誰。", effect: "SCREEN: 走廊盡頭閃過一道黑影" },
      ],
      next: "reveal_shadow",
    },

    reveal_shadow: {
      id: "reveal_shadow",
      type: "dialogue",
      lines: [
        {
          speaker: "神秘黑影",
          text: "█████████",
          portrait: "shadow_silhouette",
          effect: "MOSAIC",
        },
        { speaker: "新八", text: "等一下，那件斗篷……" },
        { speaker: "銀時", text: "這個剪影是不是某個動漫的人？" },
        { speaker: "新八", text: "不要講名字！！" },
      ],
      next: "tsukkomi_reveal",
    },

    tsukkomi_reveal: {
      id: "tsukkomi_reveal",
      type: "tsukkomi",
      lines: [{ speaker: "新八", text: "輪到你吐槽了，該怎麼回？" }],
      prompt: "選一句吐槽",
      timeLimitMs: 2000,
      options: [
        { id: "meta", label: "這根本是隔壁棚跑錯片場吧！", correct: true },
        { id: "scared", label: "好可怕的斗篷……", correct: false },
        { id: "deflect", label: "所以草莓牛奶到底在哪？", correct: false },
      ],
      onCorrect: "ending_success",
      onWrong: "ending_fail",
    },

    ending_success: {
      id: "ending_success",
      type: "end",
      lines: [
        { speaker: "新八", text: "你這樣講他會生氣吧！" },
        { speaker: "神秘黑影", text: "……", effect: "手一鬆，牛奶盒掉在地上，轉身跑走" },
        { speaker: "銀時", text: "找到了。", sfx: "接住牛奶盒" },
        { speaker: "新八", text: "我們為了一盒牛奶，追到了另一部作品的片場。" },
        { speaker: "銀時", text: "這就是江戶日常。" },
      ],
    },

    ending_fail: {
      id: "ending_fail",
      type: "end",
      lines: [
        { speaker: "新八", text: "這樣是要吐槽什麼啦！" },
        { speaker: "神秘黑影", text: "……", effect: "不為所動，抱著牛奶盒緩緩離開" },
        { speaker: "銀時", text: "……算了，超商應該還有。" },
        { speaker: "新八", text: "所以我們剛剛到底在幹嘛！" },
      ],
    },
  },
};
