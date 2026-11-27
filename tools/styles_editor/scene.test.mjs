// node tools/styles_editor/scene.test.mjs
// The site's scene maths (docs/styles/scene.js) gives the app's answers:
// the same cases as test/live_style_scene_test.dart.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { parseScene, placements } from '../../docs/styles/scene.js';

const close = (a, b, msg) => assert.ok(Math.abs(a - b) < 1e-9, `${msg}: ${a} != ${b}`);

const sceneJson = (actors) => ({
  length: 8, rest: 2, grid: 22,
  sprites: {
    dot: {
      palette: { r: '#FF0000', g: '#00FF00' },
      frames: { walk: [['rr', 'rr'], ['gg', 'gg']], still: [['gr', 'rg']] },
      fps: 2,
    },
    box: { palette: { b: '#0000FF' }, frames: [['bbb', 'b.b', 'bbb']] },
  },
  actors: actors ?? [
    { sprite: 'box', at: [0.5, 1.0] },
    {
      sprite: 'dot',
      path: [
        { t: 0, x: 0, y: 1, play: 'walk' },
        { t: 4, x: 1, y: 1, arc: 0.5 },
        { t: 6, x: 0.5, y: 0.5, play: 'still', flip: true },
      ],
    },
  ],
});

let passed = 0;
function test(name, fn) { fn(); passed++; console.log(`ok ${name}`); }

test('parse', () => {
  const notes = [];
  const s = parseScene(sceneJson(), notes);
  assert.deepEqual(notes, []);
  assert.equal(s.sprites.dot.width, 2);
  assert.deepEqual(Object.keys(s.sprites.dot.sets), ['walk', 'still']);
  assert.equal(s.sprites.box.firstSet, 'default');
  assert.equal(s.sprites.box.sets.default[0][4], null);
});

test('left out and said', () => {
  const notes = [];
  const s = parseScene(sceneJson([
    { sprite: 'ghost', at: [0.5, 1] },
    { sprite: 'box' },
    { sprite: 'dot', path: [{ t: 0, x: 0, y: 1, play: 'fly' }] },
  ]), notes);
  assert.equal(s.actors.length, 1);
  assert.ok(notes.join('\n').includes('"ghost": no such sprite'));
  assert.ok(notes.join('\n').includes('frame set "fly" not in the sprite'));
});

const scene = parseScene(sceneJson());
const dotAt = (t) => placements(scene, t).find((p) => p.sprite === 'dot');

test('timeline: straight + hop', () => {
  close(dotAt(2).x, 0.5, 'x at 2');
  close(dotAt(5).x, 0.75, 'x at 5');
  close(dotAt(5).y, 0.25, 'y at 5 (hop)');
  close(dotAt(7.9).y, 0.5, 'holds after the last point');
});

test('sets, facing, frames, loop', () => {
  assert.equal(dotAt(1).set, 'walk');
  assert.equal(dotAt(6.5).set, 'still');
  assert.equal(dotAt(6.5).flip, true);
  assert.equal(dotAt(0.6).frame, 1);
  close(placements(scene, 10).find((p) => p.sprite === 'dot').x, 0.5, 'wraps');
});

test('eases', () => {
  const eased = parseScene(sceneJson([{
    sprite: 'box',
    path: [
      { t: 0, x: 0, y: 1, ease: 'in' }, { t: 2, x: 1, y: 1, ease: 'out' },
      { t: 4, x: 0, y: 1, ease: 'inout' }, { t: 6, x: 1, y: 1 },
    ],
  }]));
  const x = (t) => placements(eased, t)[0].x;
  close(x(1), 0.25, 'in');
  close(x(3), 0.25, 'out');
  close(x(5), 0.5, 'inout');
});

test('show windows', () => {
  const s = parseScene(sceneJson([
    { sprite: 'box', at: [0.5, 1], show: [1, 2] },
    { sprite: 'box', at: [0.2, 1], show: [[7, 1]] },
  ]));
  assert.deepEqual(placements(s, 1.5).map((p) => p.x), [0.5]);
  assert.deepEqual(placements(s, 0.5).map((p) => p.x), [0.2]);
  assert.deepEqual(placements(s, 3), []);
});

test("the bank's scenes parse with no notes", () => {
  const bank = JSON.parse(readFileSync(new URL('../../docs/styles/group-styles.json', import.meta.url)));
  const scenes = bank.styles.filter((s) => s.scene);
  assert.ok(scenes.length >= 4);
  for (const st of scenes) {
    const notes = [];
    assert.ok(parseScene(st.scene, notes), st.id);
    assert.deepEqual(notes, [], st.id);
  }
});

test("make.html's example scene parses with no notes", () => {
  const page = readFileSync(new URL('../../docs/styles/make.html', import.meta.url), 'utf8');
  const pre = page.match(/<pre id="scene-example">([\s\S]*?)<\/pre>/)[1];
  const text = pre.replace(/<button[\s\S]*?<\/button>/, '')
    .replace(/&quot;/g, '"').replace(/&#x27;/g, "'").replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>').replace(/&amp;/g, '&');
  const style = JSON.parse(text);
  assert.equal(style.engine, 2);
  const notes = [];
  const s = parseScene(style.scene, notes);
  assert.ok(s);
  assert.deepEqual(notes, []);
  assert.ok(placements(s, s.rest).length > 0);
});

console.log(`${passed} passed`);
