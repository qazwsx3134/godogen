/* Pure authoring state helpers. No story/runtime schema changes. */
(function (root) {
  'use strict';
  const clone = value => JSON.parse(JSON.stringify(value));
  class History {
    constructor(initial, limit = 80) { this.limit = limit; this.reset(initial); }
    reset(initial) { this.entries = [clone(initial)]; this.index = 0; this.mergeKey = null; }
    get current() { return clone(this.entries[this.index]); }
    get canUndo() { return this.index > 0; }
    get canRedo() { return this.index < this.entries.length - 1; }
    breakMerge() { this.mergeKey = null; }
    commit(value, mergeKey = null) {
      if (JSON.stringify(value) === JSON.stringify(this.entries[this.index])) return false;
      const merge = mergeKey && mergeKey === this.mergeKey && !this.canRedo && this.index > 0;
      this.entries.splice(this.index + 1);
      if (merge) this.entries[this.index] = clone(value);
      else { this.entries.push(clone(value)); this.index++; }
      if (this.entries.length > this.limit) { this.entries.shift(); this.index--; }
      this.mergeKey = mergeKey;
      return true;
    }
    replaceCurrent(value) { this.entries[this.index] = clone(value); this.breakMerge(); }
    undo() { if (!this.canUndo) return null; this.index--; this.breakMerge(); return this.current; }
    redo() { if (!this.canRedo) return null; this.index++; this.breakMerge(); return this.current; }
  }
  function search(story, query) {
    const needle = query.trim().normalize('NFC').toLocaleLowerCase();
    if (!needle || !story) return [];
    const results = [];
    const match = (id, path, value) => {
      if (typeof value === 'string' && value.normalize('NFC').toLocaleLowerCase().includes(needle)) results.push({ node: id, path, text: value });
    };
    for (const [id, node] of Object.entries(story.nodes)) {
      match(id, 'id', id);
      const visit = (value, path) => {
        if (typeof value === 'string') match(id, path, value);
        else if (value && typeof value === 'object') for (const [key, child] of Object.entries(value)) visit(child, path ? `${path}.${key}` : key);
      };
      visit(node, '');
    }
    return results;
  }
  const api = { History, search };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  root.EditorState = api;
})(globalThis);
