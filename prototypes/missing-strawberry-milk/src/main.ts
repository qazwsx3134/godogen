import "./style.css";
import { DialogueManager } from "./core/DialogueManager";
import { ChoiceSystem } from "./core/ChoiceSystem";
import { TsukkomiSystem } from "./core/TsukkomiSystem";
import { missingStrawberryMilk } from "./data/scenes/missingStrawberryMilk";
import type { Beat, Line } from "./types";

type TsukkomiBeat = Extract<Beat, { type: "tsukkomi" }>;

const app = document.querySelector<HTMLDivElement>("#app")!;
const dialogue = new DialogueManager(missingStrawberryMilk);

let lineIndex = 0;

// Runtime state for the currently-active tsukkomi countdown, if any.
// null whenever we're not in the middle of a tsukkomi beat's choosing phase.
let tsukkomiRuntime: {
  beatId: string;
  phase: "announce" | "choosing" | "resolved";
  remainingMs: number;
  resolvedLabel?: string;
} | null = null;
let tsukkomiIntervalId: number | undefined;
let tsukkomiAdvanceTimeoutId: number | undefined;

function clearTsukkomiTimers() {
  if (tsukkomiIntervalId !== undefined) {
    window.clearInterval(tsukkomiIntervalId);
    tsukkomiIntervalId = undefined;
  }
  if (tsukkomiAdvanceTimeoutId !== undefined) {
    window.clearTimeout(tsukkomiAdvanceTimeoutId);
    tsukkomiAdvanceTimeoutId = undefined;
  }
}

const TICK_MS = 100;
const ANNOUNCE_MS = 500;
const RESULT_MS = 500;

function updateCountdownDisplay(remainingMs: number) {
  const el = document.getElementById("tsukkomi-countdown");
  if (el) el.textContent = `${Math.max(0, remainingMs / 1000).toFixed(1)}s`;
}

function startTsukkomiSequence(beat: TsukkomiBeat) {
  tsukkomiRuntime = { beatId: beat.id, phase: "announce", remainingMs: beat.timeLimitMs };
  tsukkomiAdvanceTimeoutId = window.setTimeout(() => {
    tsukkomiRuntime = { beatId: beat.id, phase: "choosing", remainingMs: beat.timeLimitMs };
    // Full render exactly once to build the buttons — after this, ticks only
    // touch the countdown text node so an in-flight click on a button never
    // gets its element swapped out from under it (that's what silently ate
    // clicks before: innerHTML every 100ms nuked the button mid-press).
    render();
    tsukkomiIntervalId = window.setInterval(() => {
      if (!tsukkomiRuntime || tsukkomiRuntime.phase !== "choosing") return;
      tsukkomiRuntime.remainingMs -= TICK_MS;
      if (tsukkomiRuntime.remainingMs <= 0) {
        resolveTsukkomiTimeout(beat);
      } else {
        updateCountdownDisplay(tsukkomiRuntime.remainingMs);
      }
    }, TICK_MS);
  }, ANNOUNCE_MS);
}

function resolveTsukkomiPick(beat: TsukkomiBeat, option: TsukkomiBeat["options"][number]) {
  clearTsukkomiTimers();
  const next = TsukkomiSystem.resolveOption(dialogue, beat.id, option, beat.onCorrect, beat.onWrong);
  tsukkomiRuntime = {
    beatId: beat.id,
    phase: "resolved",
    remainingMs: 0,
    resolvedLabel: option.correct ? "TSUKKOMI PERFECT" : "……",
  };
  render();
  tsukkomiAdvanceTimeoutId = window.setTimeout(() => {
    tsukkomiRuntime = null;
    dialogue.advance(next);
    lineIndex = 0;
    render();
  }, RESULT_MS);
}

function resolveTsukkomiTimeout(beat: TsukkomiBeat) {
  clearTsukkomiTimers();
  const next = TsukkomiSystem.resolveTimeout(dialogue, beat.id, beat.onWrong);
  tsukkomiRuntime = { beatId: beat.id, phase: "resolved", remainingMs: 0, resolvedLabel: "⏰ 時間到！" };
  render();
  tsukkomiAdvanceTimeoutId = window.setTimeout(() => {
    tsukkomiRuntime = null;
    dialogue.advance(next);
    lineIndex = 0;
    render();
  }, RESULT_MS);
}

function renderTsukkomiFooter(beat: TsukkomiBeat): string {
  if (!tsukkomiRuntime || tsukkomiRuntime.beatId !== beat.id) {
    startTsukkomiSequence(beat);
    return `<div class="tsukkomi-announce">吐槽！</div>`;
  }
  if (tsukkomiRuntime.phase === "announce") {
    return `<div class="tsukkomi-announce">吐槽！</div>`;
  }
  if (tsukkomiRuntime.phase === "choosing") {
    const seconds = Math.max(0, tsukkomiRuntime.remainingMs / 1000).toFixed(1);
    return `
      <div class="tsukkomi-announce">吐槽！ ⏱ <span id="tsukkomi-countdown">${seconds}s</span></div>
      <div class="prompt">${beat.prompt}</div>
      <div class="options">
        ${beat.options
          .map((opt) => `<button data-action="tsukkomi" data-option="${opt.id}">${opt.label}</button>`)
          .join("")}
      </div>
    `;
  }
  return `<div class="tsukkomi-result">${tsukkomiRuntime.resolvedLabel ?? ""}</div>`;
}

function renderLine(line: Line): string {
  const effectTag = line.effect ? `<div class="effect">[${line.effect}]</div>` : "";
  return `${effectTag}<div class="line"><span class="speaker">${line.speaker}</span><span class="text">${line.text}</span></div>`;
}

function render() {
  const beat = dialogue.getCurrentBeat();

  if (beat.type === "dialogue" || beat.type === "end" || beat.type === "tsukkomi") {
    const lines = beat.lines;
    const shown = lines.slice(0, lineIndex + 1);
    const isLastLine = lineIndex >= lines.length - 1;

    let footer = "";
    if (!isLastLine) {
      footer = `<button data-action="next-line">繼續 ▶</button>`;
    } else if (beat.type === "dialogue") {
      footer = `<button data-action="advance" data-next="${beat.next}">繼續 ▶</button>`;
    } else if (beat.type === "end") {
      footer = `<div class="the-end">— 完 —</div><button data-action="restart">重新開始</button>`;
    } else {
      footer = renderTsukkomiFooter(beat);
    }

    app.innerHTML = `<div class="scene">${shown.map(renderLine).join("")}${footer}</div>`;
    return;
  }

  if (beat.type === "choice") {
    app.innerHTML = `
      <div class="scene">
        <div class="prompt">${beat.prompt}</div>
        <div class="options">
          ${beat.options.map((opt) => `<button data-action="choice" data-option="${opt.id}">${opt.label}</button>`).join("")}
        </div>
      </div>
    `;
  }
}

app.addEventListener("click", (event) => {
  const target = event.target as HTMLElement;
  const action = target.dataset.action;
  if (!action) return;

  if (action === "next-line") {
    lineIndex += 1;
    render();
    return;
  }

  if (action === "advance") {
    dialogue.advance(target.dataset.next!);
    lineIndex = 0;
    render();
    return;
  }

  if (action === "choice") {
    const beat = dialogue.getCurrentBeat();
    if (beat.type !== "choice") return;
    const option = beat.options.find((o) => o.id === target.dataset.option);
    if (!option) return;
    const next = ChoiceSystem.resolve(dialogue, option);
    dialogue.advance(next);
    lineIndex = 0;
    render();
    return;
  }

  if (action === "tsukkomi") {
    const beat = dialogue.getCurrentBeat();
    if (beat.type !== "tsukkomi") return;
    if (!tsukkomiRuntime || tsukkomiRuntime.phase !== "choosing") return;
    const option = beat.options.find((o) => o.id === target.dataset.option);
    if (!option) return;
    resolveTsukkomiPick(beat, option);
    return;
  }

  if (action === "restart") {
    clearTsukkomiTimers();
    tsukkomiRuntime = null;
    dialogue.reset();
    lineIndex = 0;
    render();
    return;
  }
});

render();
