import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

// The playlist editor page's Move / Copy to group (2026-11-11): the dialog
// tells the two apart, can target a custom group or any playlist's group,
// and is applied on the TV at once (not through Save).
const html = fs.readFileSync(new URL('../assets/editor/editor.html', import.meta.url), 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];

function page() {
  const nodes = new Map(), calls = [], alerts = [];
  let respond = async () => ({}), confirmed = true;
  const node = id => {
    if (!nodes.has(id)) nodes.set(id, {value: '', textContent: '', innerHTML: '', className: '', disabled: false,
      style: {}, dataset: {}, options: [], children: [], addEventListener() {}, setAttribute() {},
      classList: {on: false, toggle(_, on) { this.on = on; }}});
    return nodes.get(id);
  };
  const context = vm.createContext({document: {getElementById: node, querySelectorAll: () => []},
    window: {addEventListener() {}}, location: {hash: ''}, history: {replaceState() {}},
    setTimeout() { return 1; }, clearTimeout() {},
    alert: s => alerts.push(s), confirm: () => confirmed,
    fetch: async (path, options) => { calls.push({path, options}); const r = await respond(path, options);
      return {status: r.status || 200, ok: !r.status || r.status === 200, json: async () => r.data || r}; }});
  const run = source => vm.runInContext(source, context);
  run(script);
  run(`viewer='main'; pl='p'; edits={names:{},logos:{},hidden:[],shown:[],fallbacks:{},rules:[]};
    data={channels:[{r:'a',n:'CNN',g:'NEWS'},{r:'b',n:'CP24',g:'NEWS'},{r:'c',n:'RDS',g:'SPORTS'}]};
    sel=new Set(['a','b']);`);
  return {node, run, calls, alerts, respond: fn => respond = fn, confirm: v => confirmed = v,
    json: source => JSON.parse(run(`JSON.stringify(${source})`))};
}

const dest = path => path.includes('&to=')
  ? {groups: [{t: 'UK', n: 2}, {t: 'Hidden one', n: 0, h: 1}]}
  : {restricted: false, own: [{t: 'Picks', n: 3}], playlists: [{id: 'p', name: 'Home'}, {id: 'q', name: 'Other'}]};

test('Copy and Move are clearly different in the dialog', async () => {
  const p = page(); p.respond(async path => dest(path));
  await p.run(`openMove('copy')`);
  assert.equal(p.node('mvTitle').textContent, 'Copy 2 channels to…');
  assert.match(p.node('mvExplain').innerHTML, /stay in their current group/);
  assert.equal(p.node('mvGo').textContent, 'Copy here');
  assert.equal(p.node('mvGo').className, 'cp go');
  assert.equal(p.node('mvModal').classList.on, true);
  await p.run(`openMove('move')`);
  assert.equal(p.node('mvTitle').textContent, 'Move 2 channels to…');
  assert.match(p.node('mvExplain').innerHTML, /leave their current group/);
  assert.equal(p.node('mvGo').textContent, 'Move here');
  assert.equal(p.node('mvGo').className, 'gold');
  assert.equal(p.node('mvModal').classList.on, false);
});

test('the dialog opens on this playlist and lists its groups', async () => {
  const p = page(); p.respond(async path => dest(path));
  await p.run(`openMove('move')`);
  assert.equal(p.node('mvWhere').value, 'p');
  assert.match(p.node('mvWhere').innerHTML, /My custom groups/);
  assert.match(p.node('mvWhere').innerHTML, /Home \(this playlist\)/);
  assert.match(p.node('mvWhere').innerHTML, /Other/);
  assert.match(p.node('mvList').innerHTML, /data-t="UK"/);
  assert.match(p.node('mvList').innerHTML, /hidden · 0 ch/);
  assert.equal(p.node('mvGo').disabled, true, 'nothing picked yet');
  assert.ok(p.calls.some(c => c.path === '/api/groupdest?pl=p&to=p'));
});

test('copy into another playlist\'s group is sent and shown on the rows', async () => {
  const p = page();
  p.respond(async (path, options) => path.startsWith('/api/place')
    ? {changed: 2, skipped: 0, group: 'Other › UK', placements: {a: {cp: ['Other › UK']}, b: {cp: ['Other › UK']}}}
    : dest(path));
  await p.run(`openMove('copy')`);
  p.node('mvWhere').value = 'q';
  await p.run(`loadMvGroups()`);
  p.run(`mv.pick='UK'; updateMvGo();`);
  assert.equal(p.node('mvGo').disabled, false);
  await p.node('mvGo').onclick();
  const place = p.calls.find(c => c.path.startsWith('/api/place'));
  assert.equal(place.path, '/api/place?pl=p');
  assert.deepEqual(JSON.parse(place.options.body), {ids: ['a', 'b'], mode: 'copy', to: {playlist: 'q', group: 'UK'}});
  assert.equal(p.node('mvModal').style.display, 'none');
  assert.equal(p.node('status').textContent, 'Copied 2 channels to Other › UK (on the TV now).');
  assert.deepEqual(p.json('data.channels[0].cp'), ['Other › UK']);
  assert.equal(p.run('sel.size'), 0);
  assert.equal(p.run('dirty'), false, 'placing is not a draft edit');
  assert.match(p.node('rows').innerHTML, /copy in Other › UK/);
});

test('move into a custom group, existing or new', async () => {
  const p = page();
  p.respond(async path => path.startsWith('/api/place')
    ? {changed: 2, skipped: 0, group: 'Picks (my group)', placements: {a: {mv: 'Picks (my group)'}, b: {mv: 'Picks (my group)'}}}
    : dest(path));
  await p.run(`openMove('move')`);
  p.node('mvWhere').value = '';
  await p.run(`loadMvGroups()`);
  assert.match(p.node('mvList').innerHTML, /data-t="Picks"/);
  assert.equal(p.node('mvNewRow').style.display, '');
  p.run(`mv.pick='Picks'; updateMvGo();`);
  await p.node('mvGo').onclick();
  let place = p.calls.filter(c => c.path.startsWith('/api/place')).at(-1);
  assert.deepEqual(JSON.parse(place.options.body).to, {own: 'Picks'});
  assert.equal(p.node('status').textContent, 'Moved 2 channels to Picks (my group) (on the TV now).');
  assert.match(p.node('rows').innerHTML, /moved to Picks \(my group\)/);

  p.run(`sel=new Set(['c']);`);
  await p.run(`openMove('move')`);
  p.node('mvWhere').value = '';
  await p.run(`loadMvGroups()`);
  p.node('mvNew').value = 'Weekend sports';
  p.node('mvNew').oninput();
  assert.equal(p.node('mvGo').disabled, false, 'a typed name is enough');
  await p.node('mvGo').onclick();
  place = p.calls.filter(c => c.path.startsWith('/api/place')).at(-1);
  assert.deepEqual(JSON.parse(place.options.body).to, {newOwn: 'Weekend sports'});
});

test('the server\'s refusal stays in the dialog and keeps the selection', async () => {
  const p = page();
  p.respond(async path => path.startsWith('/api/place') ? {error: 'That group no longer exists.'} : dest(path));
  await p.run(`openMove('move')`);
  p.run(`mv.pick='UK'; updateMvGo();`);
  await p.node('mvGo').onclick();
  assert.equal(p.node('mvMsg').textContent, 'That group no longer exists.');
  assert.notEqual(p.node('mvModal').style.display, 'none');
  assert.equal(p.run('sel.size'), 2);
});

test('nothing selected asks first and sends nothing; kids profiles get a note, not a refusal', async () => {
  const p = page(); p.respond(async path => dest(path));
  p.run(`sel=new Set();`);
  await p.run(`openMove('copy')`);
  assert.deepEqual(p.alerts, ['Select channels first (tick the boxes).']);
  assert.equal(p.calls.length, 0);
  p.run(`sel=new Set(['a']);`);
  await p.run(`openMove('move')`);
  assert.equal(p.node('mvKid').style.display, 'none');
  p.respond(async path => path.includes('&to=') ? dest(path) : {...dest(path), restricted: true});
  await p.run(`openMove('move')`);
  assert.equal(p.node('mvModal').style.display, 'flex');
  assert.equal(p.node('mvKid').style.display, '');
  assert.match(p.node('mvWhere').innerHTML, /My custom groups/);
  assert.equal(p.alerts.length, 1);
});

test('Reset group asks, then puts the selection back and clears the tags', async () => {
  const p = page();
  p.run(`data.channels[0].mv='Picks (my group)'; data.channels[1].cp=['Other › UK'];`);
  p.respond(async () => ({changed: 2, placements: {}}));
  p.confirm(false);
  await p.node('bPut').onclick();
  assert.equal(p.calls.length, 0, 'declined');
  p.confirm(true);
  await p.node('bPut').onclick();
  assert.equal(p.calls[0].path, '/api/unplace?pl=p');
  assert.deepEqual(JSON.parse(p.calls[0].options.body), {ids: ['a', 'b']});
  assert.equal(p.run('data.channels[0].mv'), undefined);
  assert.equal(p.run('data.channels[1].cp'), undefined);
  assert.equal(p.node('status').textContent, '2 channel(s) back in their own groups.');
});
