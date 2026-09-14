import { DialogueManager } from "./core/DialogueManager";
import { ChoiceSystem } from "./core/ChoiceSystem";
import { TsukkomiSystem } from "./core/TsukkomiSystem";
import { missingStrawberryMilk } from "./data/scenes/missingStrawberryMilk";

// Walks every reachable path through the scene graph to catch dead ends /
// unknown beat ids without needing a browser. Not part of the shipped app.
function walk(path: string[]) {
  const dialogue = new DialogueManager(missingStrawberryMilk);
  for (const step of path) {
    let beat = dialogue.getCurrentBeat();
    while (beat.type === "dialogue") {
      dialogue.advance(beat.next);
      beat = dialogue.getCurrentBeat();
    }
    if (beat.type === "choice") {
      const option = beat.options.find((o) => o.id === step)!;
      dialogue.advance(ChoiceSystem.resolve(dialogue, option));
    } else if (beat.type === "tsukkomi") {
      const option = beat.options.find((o) => o.id === step)!;
      dialogue.advance(TsukkomiSystem.resolve(dialogue, beat.id, option, beat.onCorrect, beat.onWrong));
    }
  }
  let beat = dialogue.getCurrentBeat();
  while (beat.type === "dialogue") {
    dialogue.advance(beat.next);
    beat = dialogue.getCurrentBeat();
  }
  if (beat.type !== "end") throw new Error(`Path ${path.join(",")} did not terminate at an end beat`);
  console.log(`OK: ${path.join(" -> ") || "(default)"} => ${beat.id}`);
}

walk(["ask_shinpachi", "meta"]);
walk(["ask_kagura", "scared"]);
walk(["ask_landlady", "deflect"]);
console.log("All paths reached a valid end beat.");
