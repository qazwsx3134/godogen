/**
 * Data shapes for a Phase 1 text scene, per prototypes/CONTEXT.md.
 * `portrait` and `sfx` are reserved for Phase 2/3 — Phase 1 renders text only.
 */

export interface Line {
  speaker: string;
  text: string;
  portrait?: string;
  sfx?: string;
  effect?: string;
}

export interface ChoiceOption {
  id: string;
  label: string;
  next: string;
  setFlags?: string[];
}

export interface TsukkomiOption {
  id: string;
  label: string;
  correct: boolean;
}

export type Beat =
  | { id: string; type: "dialogue"; lines: Line[]; next: string }
  | { id: string; type: "choice"; prompt: string; options: ChoiceOption[] }
  | {
      id: string;
      type: "tsukkomi";
      lines: Line[];
      prompt: string;
      options: TsukkomiOption[];
      onCorrect: string;
      onWrong: string;
    }
  | { id: string; type: "end"; lines: Line[] };

export interface Scene {
  id: string;
  title: string;
  start: string;
  beats: Record<string, Beat>;
}
