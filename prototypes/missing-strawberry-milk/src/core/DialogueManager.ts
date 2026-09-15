import type { Beat, Scene } from "../types";

/** Owns scene position and Flag state. Rendering-agnostic. */
export class DialogueManager {
  private scene: Scene;
  private currentBeatId: string;
  private flags: Set<string> = new Set();

  constructor(scene: Scene) {
    this.scene = scene;
    this.currentBeatId = scene.start;
  }

  getCurrentBeat(): Beat {
    const beat = this.scene.beats[this.currentBeatId];
    if (!beat) {
      throw new Error(`Unknown beat id: ${this.currentBeatId}`);
    }
    return beat;
  }

  advance(nextBeatId: string): void {
    if (!this.scene.beats[nextBeatId]) {
      throw new Error(`Cannot advance to unknown beat id: ${nextBeatId}`);
    }
    this.currentBeatId = nextBeatId;
  }

  reset(): void {
    this.currentBeatId = this.scene.start;
    this.flags.clear();
  }

  setFlag(name: string): void {
    this.flags.add(name);
  }

  hasFlag(name: string): boolean {
    return this.flags.has(name);
  }
}
