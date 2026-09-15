import type { ChoiceOption } from "../types";
import { DialogueManager } from "./DialogueManager";

/** Resolves a picked choice option against the DialogueManager: sets flags, returns the next beat id. */
export class ChoiceSystem {
  static resolve(dialogue: DialogueManager, option: ChoiceOption): string {
    for (const flag of option.setFlags ?? []) {
      dialogue.setFlag(flag);
    }
    return option.next;
  }
}
