import { DialogueManager } from "./core/DialogueManager";
import { ChoiceSystem } from "./core/ChoiceSystem";
import { TsukkomiSystem } from "./core/TsukkomiSystem";
import { missingStrawberryMilk } from "./data/scenes/missingStrawberryMilk";
import type { Beat, Scene } from "./types";

type ExpectedCase = {
  choiceFlag: string;
  tsukkomiFlag: string;
  ending: "ending_success" | "ending_fail";
};

const subjects = [
  { input: "ask_shinpachi", label: "新八", flag: "asked:shinpachi" },
  { input: "ask_kagura", label: "神樂", flag: "asked:kagura" },
  { input: "ask_landlady", label: "房東", flag: "asked:landlady" },
] as const;

const tsukkomiInputs = [
  { input: "meta", label: "meta", flag: "tsukkomi:tsukkomi_reveal:correct", ending: "ending_success" },
  { input: "scared", label: "scared", flag: "tsukkomi:tsukkomi_reveal:wrong", ending: "ending_fail" },
  { input: "deflect", label: "deflect", flag: "tsukkomi:tsukkomi_reveal:wrong", ending: "ending_fail" },
  { input: "__timeout__", label: "timeout", flag: "tsukkomi:tsukkomi_reveal:timeout", ending: "ending_fail" },
] as const;

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(`FAIL: ${message}`);
}

function expectFailure(label: string, action: () => void): void {
  let didThrow = false;
  let errorMessage = "";
  try {
    action();
  } catch (error) {
    didThrow = true;
    errorMessage = String(error);
  }
  assert(didThrow, `${label}: expected an explicit failure`);
  console.log(`OK: ${label} -> ${errorMessage}`);
}

/** Advances only automatic dialogue beats and fails on a repeated beat. */
function advanceToInteractive(dialogue: DialogueManager, visited: Set<string>, context: string): Beat {
  while (true) {
    const beat = dialogue.getCurrentBeat();
    if (visited.has(beat.id)) {
      throw new Error(`FAIL: ${context}: loop detected at beat "${beat.id}"`);
    }
    visited.add(beat.id);
    if (beat.type !== "dialogue") return beat;
    dialogue.advance(beat.next);
  }
}

function walkPath(path: readonly string[], expected: ExpectedCase, label: string): void {
  const dialogue = new DialogueManager(missingStrawberryMilk);
  const visited = new Set<string>();

  let beat = advanceToInteractive(dialogue, visited, label);
  assert(beat.type === "choice", `${label}: ended before the suspect choice`);
  const choiceInput = path[0];
  assert(choiceInput !== undefined, `${label}: ended before choosing a suspect`);
  const choice = beat.options.find((option) => option.id === choiceInput);
  assert(choice !== undefined, `${label}: unknown suspect input "${choiceInput}"`);
  dialogue.advance(ChoiceSystem.resolve(dialogue, choice));
  assert(dialogue.hasFlag(expected.choiceFlag), `${label}: missing choice Flag "${expected.choiceFlag}"`);

  beat = advanceToInteractive(dialogue, visited, label);
  assert(beat.type === "tsukkomi", `${label}: ended before the tsukkomi input`);
  const tsukkomiInput = path[1];
  assert(tsukkomiInput !== undefined, `${label}: ended before choosing a tsukkomi response`);

  if (tsukkomiInput === "__timeout__") {
    dialogue.advance(TsukkomiSystem.resolveTimeout(dialogue, beat.id, beat.onWrong));
  } else {
    const option = beat.options.find((candidate) => candidate.id === tsukkomiInput);
    assert(option !== undefined, `${label}: unknown tsukkomi input "${tsukkomiInput}"`);
    dialogue.advance(TsukkomiSystem.resolveOption(dialogue, beat.id, option, beat.onCorrect, beat.onWrong));
  }
  assert(dialogue.hasFlag(expected.tsukkomiFlag), `${label}: missing tsukkomi result Flag "${expected.tsukkomiFlag}"`);
  assert(path.length === 2, `${label}: unexpected input after the expected two choices`);

  beat = advanceToInteractive(dialogue, visited, label);
  assert(beat.type === "end", `${label}: route did not terminate at an end beat`);
  assert(beat.id === expected.ending, `${label}: expected ${expected.ending}, got ${beat.id}`);
  console.log(`OK: ${label} -> ${beat.id}; ${expected.choiceFlag}; ${expected.tsukkomiFlag}`);
}

for (const subject of subjects) {
  for (const tsukkomi of tsukkomiInputs) {
    walkPath(
      [subject.input, tsukkomi.input],
      {
        choiceFlag: subject.flag,
        tsukkomiFlag: tsukkomi.flag,
        ending: tsukkomi.ending,
      },
      `${subject.label} + ${tsukkomi.label}`,
    );
  }
}

const resetProbe = new DialogueManager(missingStrawberryMilk);
const resetVisited = new Set<string>();
let resetBeat = advanceToInteractive(resetProbe, resetVisited, "reset probe");
assert(resetBeat.type === "choice", "reset probe: expected the suspect choice");
const resetChoice = resetBeat.options.find((option) => option.id === "ask_shinpachi");
assert(resetChoice !== undefined, "reset probe: expected ask_shinpachi option");
resetProbe.advance(ChoiceSystem.resolve(resetProbe, resetChoice));
assert(resetProbe.hasFlag("asked:shinpachi"), "reset probe: expected a set choice Flag before reset");
resetProbe.setFlag("probe:extra");
assert(resetProbe.getCurrentBeat().id !== missingStrawberryMilk.start, "reset probe: expected to leave intro before reset");
resetProbe.reset();
assert(resetProbe.getCurrentBeat().id === missingStrawberryMilk.start, "reset did not return to intro");
assert(!resetProbe.hasFlag("asked:shinpachi"), "reset did not clear the choice Flag");
assert(!resetProbe.hasFlag("probe:extra"), "reset did not clear an additional Flag");
console.log("OK: reset -> intro with Flags cleared");

const unknownBeatProbe = new DialogueManager(missingStrawberryMilk);
const positionBeforeUnknownBeat = unknownBeatProbe.getCurrentBeat().id;
expectFailure("unknown beat id is rejected", () => unknownBeatProbe.advance("does-not-exist"));
assert(
  unknownBeatProbe.getCurrentBeat().id === positionBeforeUnknownBeat,
  "unknown beat rejection changed the current position",
);
console.log("OK: unknown beat id -> position preserved");

const representativeExpected: ExpectedCase = {
  choiceFlag: "asked:shinpachi",
  tsukkomiFlag: "tsukkomi:tsukkomi_reveal:correct",
  ending: "ending_success",
};
expectFailure("unknown choice input is rejected", () => {
  walkPath(["not-a-choice", "meta"], representativeExpected, "invalid choice");
});
expectFailure("early termination is rejected", () => {
  walkPath(["ask_shinpachi"], representativeExpected, "early termination");
});
expectFailure("unknown tsukkomi input is rejected", () => {
  walkPath(["ask_shinpachi", "not-a-tsukkomi"], representativeExpected, "invalid tsukkomi");
});

const loopingScene: Scene = {
  id: "walkthrough-loop-probe",
  title: "walkthrough loop probe",
  start: "loop",
  beats: {
    loop: {
      id: "loop",
      type: "dialogue",
      lines: [],
      next: "loop",
    },
  },
};
expectFailure("dialogue loop is rejected", () => {
  advanceToInteractive(new DialogueManager(loopingScene), new Set<string>(), "loop probe");
});

console.log("All 12 story combinations reached their expected ending and Flags; guard cases failed explicitly.");
