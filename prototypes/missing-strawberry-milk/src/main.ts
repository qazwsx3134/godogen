import "./style.css";
import { DialogueManager } from "./core/DialogueManager";
import { ChoiceSystem } from "./core/ChoiceSystem";
import { TsukkomiSystem } from "./core/TsukkomiSystem";
import { missingStrawberryMilk } from "./data/scenes/missingStrawberryMilk";
import type { Line } from "./types";

const app = document.querySelector<HTMLDivElement>("#app")!;
const dialogue = new DialogueManager(missingStrawberryMilk);

let lineIndex = 0;

function renderLine(line: Line): string {
  const effectTag = line.effect ? `<div class="effect">[${line.effect}]</div>` : "";
  return `${effectTag}<div class="line"><span class="speaker">${line.speaker}</span><span class="text">${line.text}</span></div>`;
}

function render() {
  const beat = dialogue.getCurrentBeat();

  if (beat.type === "dialogue" || beat.type === "end" || beat.type === "tsukkomi") {
    const lines = beat.type === "tsukkomi" ? beat.lines : beat.lines;
    const shown = lines.slice(0, lineIndex + 1);
    const isLastLine = lineIndex >= lines.length - 1;

    let footer = "";
    if (!isLastLine) {
      footer = `<button data-action="next-line">繼續 ▶</button>`;
    } else if (beat.type === "dialogue") {
      footer = `<button data-action="advance" data-next="${beat.next}">繼續 ▶</button>`;
    } else if (beat.type === "end") {
      footer = `<div class="the-end">— 完 —</div><button data-action="restart">重新開始</button>`;
    } else if (beat.type === "tsukkomi") {
      footer = `
        <div class="prompt">${beat.prompt}</div>
        <div class="options">
          ${beat.options
            .map(
              (opt) =>
                `<button data-action="tsukkomi" data-beat="${beat.id}" data-option="${opt.id}">${opt.label}</button>`,
            )
            .join("")}
        </div>
      `;
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
    const option = beat.options.find((o) => o.id === target.dataset.option);
    if (!option) return;
    const next = TsukkomiSystem.resolve(dialogue, beat.id, option, beat.onCorrect, beat.onWrong);
    dialogue.advance(next);
    lineIndex = 0;
    render();
    return;
  }

  if (action === "restart") {
    dialogue.reset();
    lineIndex = 0;
    render();
    return;
  }
});

render();
