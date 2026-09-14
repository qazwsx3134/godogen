import type { TsukkomiOption } from "../types";
import { DialogueManager } from "./DialogueManager";

/**
 * Phase 1 tsukkomi: an untimed pick with one correct option.
 * No timer, no scoring, no tsukkomi type (普通/戰鬥/Narrative Break) —
 * those are Phase 2 additions, deliberately not built here yet
 * (see prototypes/docs/adr for why Phase 1 stays this thin).
 */
export class TsukkomiSystem {
  static resolve(
    dialogue: DialogueManager,
    beatId: string,
    option: TsukkomiOption,
    onCorrect: string,
    onWrong: string,
  ): string {
    dialogue.setFlag(`tsukkomi:${beatId}:${option.correct ? "correct" : "wrong"}`);
    return option.correct ? onCorrect : onWrong;
  }
}
