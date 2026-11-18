import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

// Playlist editor page (2026-11-14, Reddit request): Shift-click ticks a
// range, and dragging groups (ticked ones together) reorders them.
const html = fs.readFileSync(new URL('../assets/editor/editor.html', import.meta.url), 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];

function page() {
  const nodes = new Map();
  const node = id => {
    if (!nodes.has(id)) nodes.set(id, {value: '', textContent: '', innerHTML: '', style: {}, dataset: {},
      options: [], children: [], addEventListener() {}, setAttribute() {}, classList: {toggle() {}}});
    return nodes.get(id);
  };
  const context = vm.createContext({document: {getElementById: node, querySelectorAll: () => []},
    window: {addEventListener() {}}, location: {hash: ''}, history: {replaceState() {}},
    setTimeout() { return 1; }, clearTimeout() {}, alert() {}, confirm: () => true, fetch: async () => ({})});
  vm.runInContext(script, context);
  return source => JSON.parse(vm.runInContext(`JSON.stringify(${source})`, context));
}

test('Shift range ticks every item between the two clicks, both ways', () => {
  const run = page();
  assert.deepEqual(run(`(() => { const s = new Set(); rangeTick(['a','b','c','d','e'], 'b', 'd', true, x => s.add(x), x => s.delete(x)); return [...s]; })()`), ['b', 'c', 'd']);
  assert.deepEqual(run(`(() => { const s = new Set(['a','b','c','d']); rangeTick(['a','b','c','d'], 'd', 'b', false, x => s.add(x), x => s.delete(x)); return [...s]; })()`), ['a']);
  // The last click is no longer listed (search changed): no range.
  assert.equal(run(`rangeTick(['a','b'], 'z', 'b', true, () => {}, () => {})`), false);
});

test('dragging moves one or several groups before or after the target', () => {
  const run = page();
  assert.deepEqual(run(`movedGroups(['A','B','C','D'], ['D'], 'A', false)`), ['D', 'A', 'B', 'C']);
  assert.deepEqual(run(`movedGroups(['A','B','C','D'], ['A'], 'D', true)`), ['B', 'C', 'D', 'A']);
  assert.deepEqual(run(`movedGroups(['A','B','C','D','E'], ['B','D'], 'E', true)`), ['A', 'C', 'E', 'B', 'D']);
  assert.deepEqual(run(`movedGroups(['A','B','C','D','E'], ['A','E'], 'C', false)`), ['B', 'A', 'E', 'C', 'D']);
});

// Hidden groups at the bottom + Keep only these countries (Discord, 2026-11-18).
test('hidden groups go after the shown ones, each part in its order', () => {
  const run = page();
  assert.deepEqual(run(`hiddenLast(['A','B','C','D','E'], new Set(['A','D']))`), ['B', 'C', 'E', 'A', 'D']);
  assert.deepEqual(run(`hiddenLast(['A','B'], new Set())`), ['A', 'B']);
});

test('keep only: picked groups shown on top, every other one hidden', () => {
  const run = page();
  assert.deepEqual(run(`(() => { const r = keepOnly(['AR 1','UK News','AR 2','UK Sport','Kids'], new Set(['UK News','UK Sport'])); return {o: r.order, h: [...r.hidden]}; })()`),
    {o: ['UK News', 'UK Sport', 'AR 1', 'AR 2', 'Kids'], h: ['AR 1', 'AR 2', 'Kids']});
});
