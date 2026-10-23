/* story_core.js: the story graph without any DOM, shared by the editor page and test_core.mjs.
 *
 * A plain script (not an ES module) so index.html also works when opened from file://, where
 * Chromium refuses module scripts. In a browser it defines `StoryCore` on globalThis; in Node,
 * `require()` returns it.
 *
 * Every node reference of a story is listed by edgesOf(). It follows StoryRunner's validation,
 * tools/story_build/story_builder.gd::_unreachable and TsukkomiRound.targets(), and looks at the
 * op first: `target` is a node only on `goto` (camera/move have one too, naming a stage mark),
 * v1 round `lines[].listen` is text while the v2 one is a node. test_core.mjs compares the
 * reachability this file computes with Godot's, from every node as the start.
 */
(function (root) {
  'use strict';

  // ---------------------------------------------------------------- Godot-format JSON

  const cmpCodePoints = (a, b) => {
    const x = Array.from(a);
    const y = Array.from(b);
    for (let i = 0; i < Math.min(x.length, y.length); i++) {
      const d = x[i].codePointAt(0) - y[i].codePointAt(0);
      if (d) return d;
    }
    return x.length - y.length;
  };

  // Godot prints numbers it parsed (always floats) as 8.0, never 8, in at most 14 significant digits.
  function formatNumber(n) {
    if (!Number.isFinite(n)) return 'null';
    if (n === 0) return '0.0';
    if (Number.isInteger(n) && Math.abs(n) < 1e21) return String(n) + '.0';
    let text = String(Number(n.toPrecision(14)));
    if (/e/i.test(text)) text = Number(n.toPrecision(14)).toFixed(20).replace(/0+$/, '');
    return Number.isInteger(Number(text)) && !text.includes('.') ? text + '.0' : text;
  }

  const ESCAPES = { '"': '\\"', '\\': '\\\\', '\b': '\\b', '\f': '\\f', '\n': '\\n', '\r': '\\r', '\t': '\\t' };
  // Godot writes a vertical tab as \v, which plain JSON parsers reject, so it is \u000b here (Godot reads both).
  const quote = text => '"' + text.replace(/["\\\u0000-\u001f]/g, c => ESCAPES[c] || '\\u' + c.charCodeAt(0).toString(16).padStart(4, '0')) + '"';

  /** Same text as Godot's JSON.stringify(value, "  ", true): sorted keys, 2-space indent. */
  function stringify(value, indent = '') {
    if (value === null || value === undefined) return 'null';
    if (typeof value === 'boolean') return String(value);
    if (typeof value === 'number') return formatNumber(value);
    if (typeof value === 'string') return quote(value);
    const inner = indent + '  ';
    if (Array.isArray(value)) {
      if (!value.length) return '[]';
      return '[\n' + value.map(item => inner + stringify(item, inner)).join(',\n') + '\n' + indent + ']';
    }
    const keys = Object.keys(value).filter(key => value[key] !== undefined).sort(cmpCodePoints);
    if (!keys.length) return '{}';
    return '{\n' + keys.map(key => inner + quote(key) + ': ' + stringify(value[key], inner)).join(',\n') + '\n' + indent + '}';
  }

  /** The text of a story file, as story_builder.gd::to_json writes it. */
  const exportText = story => stringify(story) + '\n';

  // ---------------------------------------------------------------- edges (node references)

  const isObject = value => value !== null && typeof value === 'object' && !Array.isArray(value);
  const asArray = value => (Array.isArray(value) ? value : []);
  const asObject = value => (isObject(value) ? value : {});
  const text = value => (value === undefined || value === null ? '' : String(value));

  // The last step decides whether the node needs `next` (StoryRunner._validate_node).
  const NEEDS_NO_NEXT = ['end', 'result', 'choice', 'goto', 'condition', 'boke_round'];
  const FORBIDS_NEXT = ['end', 'result', 'choice'];
  const finalOp = node => {
    const steps = asArray(asObject(node).steps);
    return steps.length ? text(asObject(steps[steps.length - 1]).op) : '';
  };

  /**
   * Every outgoing reference of a node, in the order the card draws its ports:
   * {key, path, target, label, kind, optional}. `path` leads from the node to the string
   * (setEdge writes through it); `target` is undefined when a field the op needs is missing.
   * kind: next, goto, choice, then, else (core, drawn solid); spot, talk, round, over (dashed).
   * optional: clearing deletes the key instead of leaving "".
   */
  function edgesOf(node) {
    node = asObject(node);
    const out = [];
    const add = (path, label, kind, optional = false) => {
      let holder = node;
      for (const part of path.slice(0, -1)) holder = holder === undefined || holder === null ? undefined : holder[part];
      const target = holder === undefined || holder === null ? undefined : holder[path[path.length - 1]];
      out.push({ key: path.join('/'), path, target: typeof target === 'string' ? target : undefined, label, kind, optional });
    };
    const addIf = (holder, key, path, label, kind) => { if (isObject(holder) && key in holder) add(path, label, kind, true); };

    asArray(node.steps).forEach((raw, i) => {
      const step = asObject(raw);
      const at = ['steps', i];
      switch (step.op) {
        case 'goto':
          add([...at, 'target'], 'goto', 'goto');
          break;
        case 'condition':
          add([...at, 'then'], `then ${text(step.flag)} = ${text(step.equals)}`, 'then');
          add([...at, 'else'], 'else', 'else');
          break;
        case 'choice':
          asArray(step.options).forEach((option, j) =>
            add([...at, 'options', j, 'next'], text(asObject(option).label || asObject(option).id), 'choice'));
          break;
        case 'investigate': {
          const reactions = (base, hotspots, talk, prefix) => {
            asArray(hotspots).forEach((spot, h) => {
              const name = prefix + text(asObject(spot).label || asObject(spot).id);
              addIf(spot, 'goto', [...base, 'hotspots', h, 'goto'], '🔍 ' + name, 'spot');
              asArray(asObject(spot).lines).forEach((_, k) =>
                add([...base, 'hotspots', h, 'lines', k], `🔍 ${name} #${k + 1}`, 'spot'));
            });
            asArray(talk).forEach((topic, t) =>
              add([...base, 'talk', t, 'goto'], '💬 ' + prefix + text(asObject(topic).label || asObject(topic).id), 'talk'));
          };
          reactions(at, step.hotspots, step.talk, '');
          asArray(step.places).forEach((place, p) =>
            reactions([...at, 'places', p], asObject(place).hotspots, asObject(place).talk,
              `[${text(asObject(place).label || asObject(place).id)}] `));
          break;
        }
        case 'boke_round': {
          const tag = text(step.id) || 'round';
          if ('mode' in step) {  // v2: StoryRunner/TsukkomiRound.is_v2
            add([...at, 'clear'], `${tag} · clear`, 'round');
            add([...at, 'game_over'], `${tag} · game over`, 'over');
            addIf(step, 'retry', [...at, 'retry'], `${tag} · retry`, 'round');
            for (const key of ['super', 'combo_bonus', 'combo_break'])
              addIf(step.rules, key, [...at, 'rules', key], `${tag} · ${key}`, 'round');
            asArray(step.lines).forEach((raw, l) => {
              const line = asObject(raw);
              const where = [...at, 'lines', l];
              const lineId = text(line.id) || `#${l + 1}`;
              for (const key of ['listen', 'whiff', 'hint']) addIf(line, key, [...where, key], `${lineId} · ${key}`, 'round');
              const slot = asObject(line.slot);
              addIf(slot, 'timeout', [...where, 'slot', 'timeout'], `${lineId} · timeout`, 'over');
              asArray(slot.options).forEach((option, o) => {
                const label = text(asObject(option).label || asObject(option).id);
                add([...where, 'slot', 'options', o, 'goto'], `${lineId} · ${label}`, 'round');
                asArray(asObject(option).when).forEach((_, c) =>
                  add([...where, 'slot', 'options', o, 'when', c, 'goto'], `${lineId} · ${label} (when)`, 'round'));
              });
              for (const key of ['censor', 'placard']) addIf(slot[key], 'goto', [...where, 'slot', key, 'goto'], `${lineId} · ${key}`, 'round');
              for (const key of ['perfect', 'early', 'late']) addIf(slot.qte, key, [...where, 'slot', 'qte', key], `${lineId} · qte ${key}`, 'round');
            });
          } else {  // v1: the options and the timeout live in `tsukkomi`; `listen` is text
            asArray(asObject(step.tsukkomi).options).forEach((option, j) =>
              add([...at, 'tsukkomi', 'options', j, 'goto'], `${tag} · ${text(asObject(option).label || asObject(option).id)}`, 'round'));
            addIf(step.tsukkomi && step.tsukkomi.timeout, 'goto', [...at, 'tsukkomi', 'timeout', 'goto'], `${tag} · timeout`, 'over');
            add([...at, 'game_over'], `${tag} · game over`, 'over');
            addIf(step, 'retry', [...at, 'retry'], `${tag} · retry`, 'round');
          }
          break;
        }
        default:
      }
    });
    if ('next' in node || !NEEDS_NO_NEXT.includes(finalOp(node))) add(['next'], 'next', 'next', true);
    return out;
  }

  const walk = (node, path) => path.reduce((holder, part) => holder[part], node);

  /** Points the reference at `target`. Creates the key when the edge was missing (edgesOf lists it). */
  function setEdge(story, nodeId, edge, target) {
    walk(story.nodes[nodeId], edge.path.slice(0, -1))[edge.path[edge.path.length - 1]] = target;
  }

  /** Cuts the reference: optional keys are removed, the others stay as "" until they are wired again. */
  function clearEdge(story, nodeId, edge) {
    const holder = walk(story.nodes[nodeId], edge.path.slice(0, -1));
    const key = edge.path[edge.path.length - 1];
    if (edge.optional) delete holder[key];
    else holder[key] = '';
  }

  // ---------------------------------------------------------------- analysis

  const isEnding = node => asArray(asObject(node).steps).some(step => ['end', 'result'].includes(asObject(step).op));

  /**
   * {edges: {nodeId: [edge]}, reachable: Set, unreachable: [id], problems: [...]}.
   * problems: {type, node, edge?, message}; type is entry | unreachable | dangling | unconnected | terminal-next | node.
   */
  function analyze(story) {
    const nodes = asObject(story.nodes);
    const ids = Object.keys(nodes);
    const edges = {};
    for (const id of ids) edges[id] = edgesOf(nodes[id]);
    const reachable = reachableFrom(story.entry, nodes, edges);
    const problems = [];
    if (!(story.entry in nodes)) problems.push({ type: 'entry', node: null, message: `entry「${text(story.entry)}」不存在` });
    const unreachable = ids.filter(id => !reachable.has(id)).sort();
    for (const id of unreachable) problems.push({ type: 'unreachable', node: id, message: '從 entry 走不到這個節點' });
    for (const id of ids) {
      const node = asObject(nodes[id]);
      if (!text(node.title)) problems.push({ type: 'node', node: id, message: 'title 不能是空的' });
      if (!asArray(node.steps).length) problems.push({ type: 'node', node: id, message: '沒有任何步驟' });
      if ('next' in node && FORBIDS_NEXT.includes(finalOp(node))) problems.push({ type: 'terminal-next', node: id, edge: 'next', message: `${finalOp(node)} 節點不能有 next` });
      for (const edge of edges[id]) {
        if (!edge.target) {
          const why = edge.key === 'next' ? '節點沒有後續（要有 next 或終止步驟）' : `出線「${edge.label}」還沒連到節點`;
          problems.push({ type: 'unconnected', node: id, edge: edge.key, message: why });
        } else if (!(edge.target in nodes)) {
          problems.push({ type: 'dangling', node: id, edge: edge.key, message: `出線「${edge.label}」指向不存在的節點「${edge.target}」` });
        }
      }
    }
    return { edges, reachable, unreachable, problems };
  }

  /** Nodes reachable from `start`; same walk as story_builder.gd::_unreachable. */
  function reachableFrom(start, nodes, edges) {
    const seen = new Set();
    const queue = [start];
    while (queue.length) {
      const id = queue.pop();
      if (seen.has(id) || !(id in nodes)) continue;
      seen.add(id);
      for (const edge of edges ? edges[id] : edgesOf(nodes[id])) if (edge.target) queue.push(edge.target);
    }
    return seen;
  }

  // ---------------------------------------------------------------- editing

  /** Renames a node and every reference to it, `entry` included. Returns an error text, or "". */
  function renameNode(story, oldId, newId) {
    if (!newId) return '節點 id 不能是空的';
    if (newId === oldId) return '';
    if (newId in story.nodes) return `已經有節點叫「${newId}」`;
    const refs = [];
    for (const id of Object.keys(story.nodes))
      for (const edge of edgesOf(story.nodes[id])) if (edge.target === oldId) refs.push([id, edge]);
    const renamed = {};
    for (const id of Object.keys(story.nodes)) renamed[id === oldId ? newId : id] = story.nodes[id];
    story.nodes = renamed;
    for (const [id, edge] of refs) setEdge(story, id === oldId ? newId : id, edge, newId);
    if (story.entry === oldId) story.entry = newId;
    return '';
  }

  /** Removes the node. References to it stay and show up as dangling, so nothing is rewired silently. */
  function deleteNode(story, id) { delete story.nodes[id]; }

  function uniqueId(story, base) {
    for (let n = 1; ; n++) if (!((base + '_' + n) in story.nodes)) return base + '_' + n;
  }

  /** A node StoryRunner accepts as it is: it ends the story until the author writes on. */
  const newNode = () => ({
    title: '新節點',
    steps: [{ op: 'say', speaker: 'narrator', text: '（新節點）' }, { op: 'end', text: '（尚未寫完）' }],
  });

  /** A story StoryRunner accepts once `check_story.gd --write` has put a real `version` in. */
  function newStory(id) {
    return {
      id, version: 's-unset', title: id, entry: 'start', initial_flags: {},
      nodes: { start: { title: '開場', steps: [{ op: 'say', speaker: 'narrator', text: '（開場）' }, { op: 'end', text: '（尚未寫完）' }] } },
    };
  }

  const TERMINAL_STEP_OPS = ['end', 'result', 'choice', 'goto', 'condition', 'boke_round'];

  /** Index for a new step: before a closing end/result/choice/goto so a new line does not land after the ending. */
  function insertIndex(node, op) {
    const steps = node.steps;
    if (TERMINAL_STEP_OPS.includes(op) || !steps.length) return steps.length;
    return TERMINAL_STEP_OPS.includes(steps[steps.length - 1].op) ? steps.length - 1 : steps.length;
  }

  // Starting points for the ops the sidebar can add. Anything else starts as {op} and is edited as JSON.
  const STEP_TEMPLATES = {
    say: () => ({ op: 'say', speaker: 'narrator', text: '' }),
    choice: () => ({ op: 'choice', prompt: '要怎麼辦？', options: [{ id: 'a', label: '選項 A', next: '' }, { id: 'b', label: '選項 B', next: '' }] }),
    goto: () => ({ op: 'goto', target: '' }),
    end: () => ({ op: 'end', text: '' }),
    comedy: () => ({ op: 'comedy', preset: 'tsukkomi_impact', speaker: 'shinpachi', text: '' }),
    condition: () => ({ op: 'condition', flag: '', equals: true, then: '', else: '' }),
    bg: () => ({ op: 'bg', id: '' }),
    char: () => ({ op: 'char', id: '' }),
    flag: () => ({ op: 'flag', key: '', value: true }),
    item: () => ({ op: 'item', id: '' }),
    se: () => ({ op: 'se', id: '' }),
    bgm: () => ({ op: 'bgm', id: '' }),
    shake: () => ({ op: 'shake', strength: 'small', duration: 0.3 }),
    flash: () => ({ op: 'flash', color: '#ffffff', duration: 0.2 }),
    cutin: () => ({ op: 'cutin', text: '' }),
    freeze: () => ({ op: 'freeze', duration: 0.3 }),
    placard: () => ({ op: 'placard', text: '' }),
  };
  const newStep = op => (STEP_TEMPLATES[op] ? STEP_TEMPLATES[op]() : { op });

  // ---------------------------------------------------------------- card content and geometry

  const GEOM = { width: 340, header: 34, summaryRow: 19, portRow: 22, pad: 8, maxRows: 4, gapX: 150, gapY: 36 };

  const OP_ICONS = {
    say: '💬', choice: '❓', condition: '🔀', goto: '↪️', investigate: '🔍', boke_round: '🎤', comedy: '💥',
    end: '🏁', result: '📊', bg: '🖼️', char: '🧍', item: '🎒', flag: '🚩', set_flag: '🚩', profile: '📇', se: '🔊',
    sound: '🔊', bgm: '🎵', shake: '📳', flash: '⚡', cutin: '🎬', freeze: '⏸️', fade: '🌗', beam: '🔆', placard: '🪧',
    wait: '⏳', show: '🧍', hide: '🫥', move: '🚶', face: '👀', expression: '🙂', camera: '🎥',
  };
  const CONTENT_OPS = ['say', 'comedy', 'choice', 'condition', 'goto', 'investigate', 'boke_round', 'end', 'result'];
  const icon = op => OP_ICONS[op] || '▫️';
  const clip = (value, max) => {
    const flat = text(value).replace(/\s+/g, ' ').trim();
    return flat.length > max ? flat.slice(0, max - 1) + '…' : flat;
  };

  function contentRow(step) {
    switch (step.op) {
      case 'say': return { op: 'say', icon: step.thought ? '💭' : '💬', text: `${step.speaker === 'narrator' ? '旁白' : text(step.speaker)}：${clip(step.text, 34)}` };
      case 'comedy': return { op: 'comedy', icon: icon('comedy'), text: `${text(step.preset)} ${text(step.speaker)}：${clip(step.text, 24)}` };
      case 'choice': return { op: 'choice', icon: icon('choice'), text: `${clip(step.prompt, 30)}（${asArray(step.options).length} 個選項）` };
      case 'condition': return { op: 'condition', icon: icon('condition'), text: `if ${text(step.flag)} == ${text(step.equals)}` };
      case 'goto': return { op: 'goto', icon: icon('goto'), text: `goto ${text(step.target)}` };
      case 'investigate': return { op: 'investigate', icon: icon('investigate'), text: `調查 ${text(step.id)}（${asArray(step.hotspots).length} 熱區）` };
      case 'boke_round': return { op: 'boke_round', icon: icon('boke_round'), text: `吐槽回合 ${text(step.id)}${'mode' in step ? '（' + text(step.mode) + '）' : ''}` };
      case 'end': return { op: 'end', icon: icon('end'), text: clip(step.text, 34) || '結局' };
      default: return { op: 'result', icon: icon('result'), text: clip(step.title, 34) || '章節結算' };
    }
  }

  /** {rows: [{op, icon, text}], chips: [{op, icon, count}]}: what a card prints under its title. */
  function summaryOf(node) {
    const steps = asArray(asObject(node).steps).map(asObject);
    let rows = steps.filter(step => CONTENT_OPS.includes(step.op)).map(contentRow);
    if (rows.length > GEOM.maxRows) {
      const rest = rows.length - (GEOM.maxRows - 1);
      rows = [...rows.slice(0, GEOM.maxRows - 1), { op: 'more', icon: '⋯', text: `另 ${rest} 項` }];
    }
    const counts = new Map();
    for (const step of steps) if (!CONTENT_OPS.includes(step.op)) counts.set(text(step.op), (counts.get(text(step.op)) || 0) + 1);
    return { rows, chips: [...counts].map(([op, count]) => ({ op, icon: icon(op), count })) };
  }

  /** Card size from the same numbers the stylesheet gets (index.html sets them as CSS variables). */
  function cardSize(node, edgeCount, layout) {
    const body = 64 + flowRows(node, layout) * 25;
    return { w: GEOM.width, h: GEOM.header + GEOM.pad + body + GEOM.pad + edgeCount * GEOM.portRow + (edgeCount ? GEOM.pad : 0), body };
  }

  /** Where output port number `index` of a card at (x, y) sits. offset: the card's top left. */
  function portOffset(size, index) {
    return { x: size.w, y: GEOM.header + GEOM.pad + size.body + GEOM.pad + index * GEOM.portRow + GEOM.portRow / 2 };
  }

  /** Where the input port sits: the middle of the title row. */
  const inPortOffset = () => ({ x: 0, y: GEOM.header / 2 });

  /**
   * Left-to-right layers from the entry (breadth-first); nodes the entry cannot reach go below,
   * one block per connected group. A child starts no higher than its first parent, which keeps
   * most lines short. Returns {id: {x, y}}.
   */
  function autoLayout(story, analysis = analyze(story), layout = {}) {
    const nodes = asObject(story.nodes);
    const sizes = {};
    for (const id of Object.keys(nodes)) sizes[id] = cardSize(nodes[id], analysis.edges[id].length, layout[id]);
    const placed = {};
    let top = 0;
    const lay = start => {
      const level = new Map([[start, 0]]);
      const parent = new Map();
      const layers = [[start]];
      for (let depth = 0; layers[depth] && layers[depth].length; depth++) {
        const next = [];
        for (const id of layers[depth])
          for (const edge of analysis.edges[id]) {
            const to = edge.target;
            if (to && to in nodes && !level.has(to) && !placed[to]) { level.set(to, depth + 1); parent.set(to, id); next.push(to); }
          }
        if (next.length) layers.push(next);
      }
      let bottom = top;
      layers.forEach((layer, depth) => {
        let cursor = top;
        for (const id of layer) {
          const y = Math.max(cursor, parent.has(id) ? placed[parent.get(id)].y : top);
          placed[id] = { x: depth * (GEOM.width + GEOM.gapX), y };
          cursor = y + sizes[id].h + GEOM.gapY;
          bottom = Math.max(bottom, y + sizes[id].h);
        }
      });
      top = bottom + GEOM.gapY * 3;
    };
    if (story.entry in nodes) lay(story.entry);
    for (const id of Object.keys(nodes)) if (!placed[id]) lay(id);
    return placed;
  }

  // ---------------------------------------------------------------- game constants

  /** The array literal of `const NAME: Array[String] = [...]` in story_runner.gd, or null. */
  function parseGdStrings(source, name) {
    const match = new RegExp('const\\s+' + name + '\\s*:\\s*Array\\[String\\]\\s*=\\s*\\[([^\\]]*)\\]').exec(source);
    return match ? Array.from(match[1].matchAll(/"([^"]*)"/g), m => m[1]) : null;
  }

  // Used when story_runner.gd cannot be fetched (file://); test_core.mjs checks them against the real file.
  const FALLBACK_ENUMS = {
    VALID_OPS: ['bg', 'char', 'say', 'choice', 'item', 'flag', 'show', 'hide', 'move', 'face', 'expression', 'camera', 'wait',
      'sound', 'end', 'result', 'set_flag', 'condition', 'goto', 'investigate', 'boke_round', 'profile', 'shake', 'flash',
      'cutin', 'comedy', 'freeze', 'fade', 'beam', 'bgm', 'se', 'placard'],
    VALID_EXPRESSIONS: ['neutral', 'smile', 'annoyed', 'surprised', 'thinking', 'sweat', 'smug', 'shout', 'broken', 'angry',
      'panic', 'nervous', 'serious', 'cry', 'nosepick', 'mock', 'sit_serious', 'sit_talking'],
    VALID_COMEDY_PRESETS: ['tsukkomi_impact', 'small_reaction', 'full_manga_panel', 'emotion_band'],
  };

  /** Where a story path of stories.json (res://data/x.json) is fetched from, relative to tools/story_editor/. */
  const projectUrl = path => path.replace(/^res:\/\//, '../../');

  // Scene presentation metadata is shared by cards and the add-step menu.
  const STEP_GROUPS = [
    { id: 'dialogue', label: '對話', ops: ['say', 'comedy'] },
    { id: 'narration', label: '旁白', ops: ['say'] },
    { id: 'character', label: '立繪', ops: ['char', 'profile'] },
    { id: 'scene', label: '背景・音樂', ops: ['bg', 'bgm'] },
    { id: 'sound', label: '音效', ops: ['se'] },
    { id: 'event', label: '事件', ops: ['choice', 'condition', 'flag', 'item', 'goto', 'investigate', 'boke_round', 'placard', 'end', 'result'] },
    { id: 'effect', label: '效果', ops: ['shake', 'flash', 'fade', 'freeze', 'cutin', 'beam'] },
    { id: 'legacy', label: '舊版', ops: ['show', 'hide', 'move', 'face', 'expression', 'camera', 'wait', 'sound', 'set_flag'] },
  ];
  const STEP_LABELS = {
    say: '台詞', comedy: '漫畫吐槽', char: '角色登場／表情', profile: '解鎖人物檔案', bg: '換背景', bgm: '背景音樂', se: '音效',
    choice: '選項', condition: '條件分歧', flag: '設定旗標', item: '取得道具', goto: '跳到場景', investigate: '調查',
    boke_round: '吐槽回合', placard: '舉牌', end: '結束', result: '章節結算', shake: '畫面震動', flash: '閃光',
    fade: '淡入淡出', freeze: '停格', cutin: '切入特寫', beam: '光束', show: '顯示角色', hide: '隱藏角色', move: '移動角色',
    face: '角色朝向', expression: '變更表情', camera: '鏡頭', wait: '等待', sound: '音效', set_flag: '設定旗標',
  };
  const stepLabel = step => step.op === 'say' && stepGroup(step).id === 'narration' ? '旁白' : STEP_LABELS[step.op] || '舊版指令';
  const foldShape = node => JSON.stringify(node.steps.map(step => stepGroup(step).id));
  function stepGroup(step) {
    if (step.op === 'say') return STEP_GROUPS[step.speaker && step.speaker !== 'narrator' ? 0 : 1];
    return STEP_GROUPS.find(g => g.ops.includes(step.op)) || STEP_GROUPS[7];
  }
  function stepRuns(node) {
    const runs = [];
    node.steps.forEach((step, index) => {
      const group = stepGroup(step);
      const last = runs[runs.length - 1];
      if (last?.group.id === group.id) last.indices.push(index);
      else runs.push({ key: `${index}:${group.id}`, group, indices: [index] });
    });
    return runs;
  }
  const runExpanded = (layout, run) => layout?.expanded?.[run.key] === true;
  function flowRows(node, layout) {
    return stepRuns(node).reduce((n, run) => n + (run.indices.length > 1 ? 1 + (runExpanded(layout, run) ? run.indices.length : 0) : 1), 0);
  }
  // Finite-set dataflow: seed only entry (including incoming loop states); unreachable cycles stay empty.
  // Every edge kind from edgesOf participates, so investigation and round reactions are included.
  function effectiveMedia(story, analysis = analyze(story)) {
    const ids = Object.keys(story.nodes);
    const result = {};
    for (const op of ['bg', 'bgm']) {
      const state = Object.fromEntries(ids.map(id => [id, new Set()]));
      let changed = true;
      while (changed) {
        changed = false;
        for (const id of ids) {
          const incoming = state[id];
          if (id === story.entry && !incoming.has('')) { incoming.add(''); changed = true; }
          if (!incoming.size) continue;
          const last = story.nodes[id].steps.filter(s => s.op === op).at(-1);
          const outgoing = last ? [last.id || ''] : incoming;
          for (const edge of analysis.edges[id]) if (state[edge.target]) for (const value of outgoing) {
            if (!state[edge.target].has(value)) { state[edge.target].add(value); changed = true; }
          }
        }
      }
      for (const id of ids) {
        const last = story.nodes[id].steps.filter(s => s.op === op).at(-1);
        const values = last ? [last.id || ''] : [...state[id]].sort();
        const status = values.length > 1 ? 'mixed' : !values.length || values[0] === '' ? 'none' : last ? 'explicit' : 'inherited';
        (result[id] ||= {})[op] = { id: values.length === 1 ? values[0] : '', status, values };
      }
    }
    return result;
  }
  function graphCopy(story, id, registry = { stories: [] }, sourceEntry = null) {
    if (!/^[A-Za-z0-9_]+$/.test(id) || id === story.id || registry.stories.some(s => s.id === id)) throw new Error('請使用未存在的新故事 id（英文、數字、底線）');
    const copy = JSON.parse(JSON.stringify(story));
    copy.id = id; copy.version = 's-unset'; delete copy.generated_from;
    const nextRegistry = JSON.parse(JSON.stringify(registry));
    const source = sourceEntry || registry.stories.find(entry => entry.id === story.id) || {};
    // A work's story is copied into the same work folder (its catalog and pack.json).
    const place = source.work ? { kind: source.kind || 'chapter', path: `res://stories/${source.work}/${id}_story.json`, save: packSave(source.work, id) }
      : { kind: 'sample', path: `res://data/${id}_story.json`, save: `user://${id}.save` };
    nextRegistry.stories.push({ ...JSON.parse(JSON.stringify(source)), id, ...place, authoring: 'graph' });
    return { story: copy, registry: nextRegistry };
  }

  // ---- story packs (IMPLEMENTATION.md「故事包」): the same rules as story_library.gd / story_runner.gd
  const packSave = (work, id) => `user://pack_${work}_${id}.save`;
  const inFolder = (folder, path) => (typeof path === 'string' && path && !path.includes('://') ? `${folder}/${path}` : path);
  /** A pack's stories as registry rows with res:// paths and their work; skin/cover stay the row's own. */
  function packEntries(pack, work) {
    return (Array.isArray(pack?.stories) ? pack.stories : []).filter(e => e && typeof e === 'object' && e.id && e.path)
      .map(e => ({ ...JSON.parse(JSON.stringify(e)), kind: e.kind || 'sample', path: inFolder(`res://stories/${work}`, e.path),
        save: packSave(work, e.id), work, work_title: String(pack.title || work) }));
  }
  /** StoryRunner.read_catalog: asset paths relative to the catalog's folder, laid over what it `extends`. */
  function resolveCatalog(own, folder, base = null) {
    const result = JSON.parse(JSON.stringify(own || {}));
    for (const collection of ['backgrounds', 'characters', 'items', 'sounds', 'music']) {
      for (const entry of Object.values(result[collection] || {})) {
        if (!entry || typeof entry !== 'object') continue;
        for (const field of ['path', 'scene']) if (field in entry) entry[field] = inFolder(folder, entry[field]);
        if (entry.expressions && typeof entry.expressions === 'object')
          for (const key of Object.keys(entry.expressions)) entry.expressions[key] = inFolder(folder, entry.expressions[key]);
      }
    }
    if (!('extends' in result)) return result;
    const merged = JSON.parse(JSON.stringify(base || {}));
    for (const [key, value] of Object.entries(result)) {
      if (key === 'extends') continue;
      if (merged[key] && typeof merged[key] === 'object' && !Array.isArray(merged[key]) && value && typeof value === 'object' && !Array.isArray(value))
        Object.assign(merged[key], value);
      else merged[key] = value;
    }
    return merged;
  }
  function availableExpressions(catalog, id) {
    const c = catalog?.characters?.[id];
    if (!c) return [];
    return [...(c.path ? ['neutral'] : []), ...Object.keys(c.expressions || {}).filter(k => c.expressions[k])].filter((v, i, a) => a.indexOf(v) === i);
  }

  const api = {
    STEP_GROUPS, STEP_LABELS, stepLabel, foldShape, stepGroup, stepRuns, runExpanded, flowRows, effectiveMedia, graphCopy, availableExpressions,
    packEntries, resolveCatalog,
    stringify, exportText, formatNumber, edgesOf, setEdge, clearEdge, analyze, reachableFrom, isEnding, renameNode, deleteNode,
    uniqueId, newNode, newStory, newStep, insertIndex, STEP_TEMPLATES, GEOM, OP_ICONS, icon, summaryOf, cardSize, portOffset,
    inPortOffset, autoLayout, parseGdStrings, FALLBACK_ENUMS, projectUrl, finalOp, NEEDS_NO_NEXT, FORBIDS_NEXT,
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  root.StoryCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
