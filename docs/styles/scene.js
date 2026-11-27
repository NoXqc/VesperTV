// VesperTV live style scenes (engine 2), the same rules as the app's
// lib/services/live_style_scene.dart and paintScene in
// lib/widgets/live_style_view.dart, for the editor and the preview player
// on vespertv.app. Keep the two in step (tools/styles_editor/scene.test.mjs
// checks the same cases as test/live_style_scene_test.dart).

export const LIMITS = {
  sprites: 12, sets: 6, frames: 8, side: 32, colors: 24,
  actors: 16, keys: 48, length: 60,
};

const EASES = new Set(['linear', 'in', 'out', 'inout']);

function num(v, fallback, min, max) {
  return typeof v === 'number' && Number.isFinite(v)
    ? Math.min(max, Math.max(min, v)) : fallback;
}

/** "#RRGGBB" / "#AARRGGBB" (Android order) -> [r, g, b, a 0..1], or null. */
export function parseColor(v) {
  if (typeof v !== 'string') return null;
  const hex = v.startsWith('#') ? v.slice(1) : v;
  if (!/^[0-9a-fA-F]+$/.test(hex)) return null;
  if (hex.length === 6) {
    return [parseInt(hex.slice(0, 2), 16), parseInt(hex.slice(2, 4), 16),
      parseInt(hex.slice(4, 6), 16), 1];
  }
  if (hex.length === 8) {
    return [parseInt(hex.slice(2, 4), 16), parseInt(hex.slice(4, 6), 16),
      parseInt(hex.slice(6, 8), 16), parseInt(hex.slice(0, 2), 16) / 255];
  }
  return null;
}

export function cssColor(c) {
  return c ? `rgba(${c[0]},${c[1]},${c[2]},${c[3]})` : 'transparent';
}

function parseSprite(json, name, note) {
  if (!json || typeof json !== 'object' || Array.isArray(json)) return null;
  const palette = {};
  if (json.palette && typeof json.palette === 'object') {
    for (const [key, value] of Object.entries(json.palette)) {
      if (key.length !== 1) {
        note(`sprite "${name}": palette key "${key}" is not one character`);
        continue;
      }
      if (Object.keys(palette).length >= LIMITS.colors) {
        note(`sprite "${name}": more than ${LIMITS.colors} colours, "${key}" left out`);
        continue;
      }
      const c = value === null || value === '' ? null : parseColor(value);
      if (!c && value !== null && value !== '') {
        note(`sprite "${name}": colour "${value}" for "${key}" not understood (use #RRGGBB or #AARRGGBB)`);
      }
      palette[key] = c;
    }
  }
  const rawSets = Array.isArray(json.frames) ? { default: json.frames }
    : (json.frames && typeof json.frames === 'object'
      ? Object.fromEntries(Object.entries(json.frames).filter(([, v]) => Array.isArray(v)))
      : {});
  const grids = {};
  let width = 0, height = 0;
  for (const [setName, list] of Object.entries(rawSets)) {
    if (Object.keys(grids).length >= LIMITS.sets) {
      note(`sprite "${name}": more than ${LIMITS.sets} frame sets, "${setName}" left out`);
      break;
    }
    const frames = [];
    for (const f of list) {
      if (frames.length >= LIMITS.frames) {
        note(`sprite "${name}" set "${setName}": more than ${LIMITS.frames} frames, the rest left out`);
        break;
      }
      const rows = typeof f === 'string' ? f.split('\n')
        : (Array.isArray(f) ? f.map((r) => `${r}`) : []);
      if (!rows.length) continue;
      if (rows.length > LIMITS.side || rows.some((r) => r.length > LIMITS.side)) {
        note(`sprite "${name}": a frame is over ${LIMITS.side} x ${LIMITS.side}, cut`);
      }
      const kept = rows.slice(0, LIMITS.side).map((r) => r.slice(0, LIMITS.side));
      height = Math.max(height, kept.length);
      for (const r of kept) width = Math.max(width, r.length);
      frames.push(kept);
    }
    if (frames.length) grids[setName] = frames;
  }
  if (!Object.keys(grids).length || !width || !height) return null;
  const unknown = new Set();
  const sets = {};
  for (const [setName, frames] of Object.entries(grids)) {
    sets[setName] = frames.map((rows) => {
      const px = [];
      for (let y = 0; y < height; y++) {
        const row = y < rows.length ? rows[y] : '';
        for (let x = 0; x < width; x++) {
          const ch = x < row.length ? row[x] : '.';
          if (ch === '.' || ch === ' ') { px.push(null); continue; }
          if (!(ch in palette)) unknown.add(ch);
          px.push(palette[ch] ?? null);
        }
      }
      return px;
    });
  }
  if (unknown.size) {
    note(`sprite "${name}": ${[...unknown].map((c) => `"${c}"`).join(', ')} not in its palette, drawn clear`);
  }
  return {
    width, height, sets, fps: num(json.fps, 6, 0, 24),
    firstSet: Object.keys(sets)[0],
  };
}

function parseActor(json, sprites, length, note) {
  if (!json || typeof json !== 'object') return null;
  const sprite = `${json.sprite ?? ''}`;
  if (!(sprite in sprites)) {
    note(`actor using sprite "${sprite}": no such sprite, left out`);
    return null;
  }
  const keys = [];
  if (Array.isArray(json.at) && json.at.length === 2) {
    keys.push({
      t: 0, x: num(json.at[0], 0.5, -1, 2), y: num(json.at[1], 1, -1, 2),
      play: null, arc: 0, ease: 'linear', flip: json.flip === true ? true : null,
    });
  }
  for (const raw of Array.isArray(json.path) ? json.path : []) {
    if (keys.length >= LIMITS.keys) {
      note(`actor "${sprite}": more than ${LIMITS.keys} path points, the rest left out`);
      break;
    }
    if (!raw || typeof raw !== 'object') continue;
    const ease = `${raw.ease ?? 'linear'}`;
    keys.push({
      t: num(raw.t, 0, 0, length), x: num(raw.x, 0.5, -1, 2),
      y: num(raw.y, 1, -1, 2),
      play: typeof raw.play === 'string' ? raw.play : null,
      arc: num(raw.arc, 0, -2, 2),
      ease: EASES.has(ease) ? ease : 'linear',
      flip: typeof raw.flip === 'boolean' ? raw.flip : null,
    });
  }
  if (!keys.length) {
    note(`actor "${sprite}": no "at" and no "path", left out`);
    return null;
  }
  keys.sort((a, b) => a.t - b.t);
  for (const k of keys) {
    if (k.play && !(k.play in sprites[sprite].sets)) {
      note(`actor "${sprite}": frame set "${k.play}" not in the sprite`);
    }
  }
  const show = [];
  const rawShow = json.show;
  const windows = Array.isArray(rawShow) && rawShow.length && typeof rawShow[0] === 'number'
    ? [rawShow] : (Array.isArray(rawShow) ? rawShow : []);
  for (const w of windows) {
    if (Array.isArray(w) && w.length === 2 && typeof w[0] === 'number' && typeof w[1] === 'number') {
      show.push([w[0], w[1]]);
    }
  }
  return {
    sprite, keys, show, play: typeof json.play === 'string' ? json.play : null,
  };
}

/** The scene of a style, or null; notes gets what was left out. */
export function parseScene(json, notes = []) {
  const note = (s) => notes.push(s);
  if (!json || typeof json !== 'object' || Array.isArray(json)) {
    if (json != null) note('scene is not an object');
    return null;
  }
  const length = num(json.length, 8, 0.5, LIMITS.length);
  const grid = Math.round(num(json.grid, 22, 8, 64));
  const sprites = {};
  if (json.sprites && typeof json.sprites === 'object') {
    for (const [name, raw] of Object.entries(json.sprites)) {
      if (Object.keys(sprites).length >= LIMITS.sprites) {
        note(`more than ${LIMITS.sprites} sprites: "${name}" and after left out`);
        break;
      }
      const s = parseSprite(raw, name, note);
      if (s) sprites[name] = s; else note(`sprite "${name}" has no frame to draw: left out`);
    }
  } else {
    note('scene has no "sprites" object');
  }
  const actors = [];
  for (const raw of Array.isArray(json.actors) ? json.actors : []) {
    if (actors.length >= LIMITS.actors) {
      note(`more than ${LIMITS.actors} actors: the rest left out`);
      break;
    }
    const a = parseActor(raw, sprites, length, note);
    if (a) actors.push(a);
  }
  if (!actors.length) {
    note('scene has no actor to draw');
    return null;
  }
  return {
    length, grid, sprites, actors,
    rest: num(json.rest, length / 2, 0, length),
  };
}

function shownAt(actor, t) {
  if (!actor.show.length) return true;
  return actor.show.some(([a, b]) => (a <= b ? t >= a && t < b : t >= a || t < b));
}

function placementOf(actor, t, s) {
  if (!s || !shownAt(actor, t)) return null;
  const keys = actor.keys;
  let play = actor.play;
  let flip = false;
  for (const k of keys) {
    if (k.t > t) break;
    if (k.play) play = k.play;
    if (k.flip !== null) flip = k.flip;
  }
  let x, y;
  if (t <= keys[0].t || keys.length === 1) {
    x = keys[0].x; y = keys[0].y;
  } else if (t >= keys[keys.length - 1].t) {
    x = keys[keys.length - 1].x; y = keys[keys.length - 1].y;
  } else {
    let i = 0;
    while (keys[i + 1].t <= t) i++;
    const a = keys[i], b = keys[i + 1];
    const span = b.t - a.t;
    const raw = span <= 0 ? 1 : (t - a.t) / span;
    const p = a.ease === 'in' ? raw * raw
      : a.ease === 'out' ? 1 - (1 - raw) * (1 - raw)
        : a.ease === 'inout' ? raw * raw * (3 - 2 * raw) : raw;
    x = a.x + (b.x - a.x) * p;
    y = a.y + (b.y - a.y) * p - a.arc * 4 * raw * (1 - raw);
  }
  const set = play && s.sets[play] ? play : s.firstSet;
  const frames = s.sets[set];
  const frame = s.fps <= 0 || frames.length === 1 ? 0 : Math.floor(t * s.fps) % frames.length;
  return { sprite: actor.sprite, set, frame, x, y, flip };
}

/** Every actor shown at t seconds into the loop, back to front. */
export function placements(scene, t) {
  const time = scene.length <= 0 ? 0 : t - Math.floor(t / scene.length) * scene.length;
  const out = [];
  for (const actor of scene.actors) {
    const p = placementOf(actor, time, scene.sprites[actor.sprite]);
    if (p) out.push(p);
  }
  return out;
}

/** The fade behind the row (left to right). */
export function drawFade(ctx, fade, w, h, pulseAlpha = 1) {
  const colors = (fade || []).map(parseColor).filter(Boolean);
  if (!colors.length) return;
  const stops = colors.length === 1 ? [colors[0], [...colors[0].slice(0, 3), 0]] : colors;
  const g = ctx.createLinearGradient(0, 0, w, 0);
  stops.forEach((c, i) => g.addColorStop(i / (stops.length - 1),
    cssColor([c[0], c[1], c[2], c[3] * pulseAlpha])));
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, w, h);
}

/**
 * Draws the scene at t on a canvas of w x h CSS pixels at dpr: each sprite
 * pixel whole device pixels, positions snapped, no smoothing (like the app).
 */
export function drawScene(ctx, scene, t, w, h, dpr = 1) {
  const unitDevice = Math.max(1, Math.round(h * dpr / scene.grid));
  const unit = unitDevice / dpr;
  const snap = (v) => Math.round(v * dpr) / dpr;
  for (const p of placements(scene, t)) {
    const s = scene.sprites[p.sprite];
    const sw = s.width * unit, sh = s.height * unit;
    const left = snap(p.x * w - sw / 2);
    const top = snap(p.y * h - sh);
    const px = s.sets[p.set][p.frame];
    ctx.save();
    ctx.translate(left, top);
    if (p.flip) { ctx.translate(sw, 0); ctx.scale(-1, 1); }
    for (let y = 0; y < s.height; y++) {
      for (let x = 0; x < s.width; x++) {
        const c = px[y * s.width + x];
        if (!c || c[3] === 0) continue;
        ctx.fillStyle = cssColor(c);
        ctx.fillRect(x * unit, y * unit, unit, unit);
      }
    }
    ctx.restore();
  }
}
