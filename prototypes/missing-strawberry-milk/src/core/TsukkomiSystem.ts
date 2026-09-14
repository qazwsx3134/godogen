import type { TsukkomiOption } from "../types";
import { DialogueManager } from "./DialogueManager";

/**
 * Phase 2 tsukkomi: a timed pick with one correct option.
 * Only 普通吐槽 (text-only effect) exists here — 戰鬥吐槽 and Narrative Break
 * both presuppose a battle/boss system this prototype doesn't have, so they're
 * deliberately deferred (see prototypes/docs/adr).
 */
export class TsukkomiSystem {
  static resolveOption(
    dialogue: DialogueManager,
    beatId: string,
    option: TsukkomiOption,
    onCorrect: string,
    onWrong: string,
  ): string {
    dialogue.setFlag(`tsukkomi:${beatId}:${option.correct ? "correct" : "wrong"}`);
    return option.correct ? onCorrect : onWrong;
  }

  /** No pick within the time limit counts as wrong, same as picking a wrong option. */
  static resolveTimeout(dialogue: DialogueManager, beatId: string, onWrong: string): string {
    dialogue.setFlag(`tsukkomi:${beatId}:timeout`);
    return onWrong;
  }
}
