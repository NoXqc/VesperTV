import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const html = fs.readFileSync(new URL('../assets/editor/editor.html', import.meta.url), 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
function page() {
  const nodes = new Map(), timers = new Map(), calls = [], alerts = [];
  let timerId = 0, respond = async () => ({});
  const node = id => {
    if (!nodes.has(id)) nodes.set(id, {value:'', textContent:'', innerHTML:'', style:{}, dataset:{},
      options:[], children:[], classList:{toggle(){}}, addEventListener(){}, setAttribute(){}});
    return nodes.get(id);
  };
  const context = vm.createContext({document:{getElementById:node, querySelectorAll:()=>[]},
    window:{addEventListener(){}}, location:{hash:''}, history:{replaceState(){}},
    setTimeout(fn){ timers.set(++timerId, fn); return timerId; }, clearTimeout(id){timers.delete(id);},
    alert:s=>alerts.push(s), confirm:()=>true,
    fetch:async (path, options) => { calls.push({path, options}); const r=await respond(path, options);
      return {status:r.status||200, ok:!r.status||r.status===200, json:async()=>r.data||r}; }
  });
  const run = source => vm.runInContext(source, context);
  run(script);
  run(`viewer='main'; pl='p'; data={channels:[{r:'a',n:'Sky',g:'Sports',eo:'existing'}]};
    edits={names:{a:'My Sky'},logos:{a:'https://manual.example/old.png'},hidden:['other'],shown:[],fallbacks:{},rules:[]};
    gdFor='a'; gdPl='p';`);
  return {node, run, calls, alerts, respond:fn=>respond=fn,
    async timer() { const [id, fn]=[...timers.entries()].at(-1); timers.delete(id); await fn(); },
    json:source=>JSON.parse(run(`JSON.stringify(${source})`))};
}

test('choosing and resetting an EPG logo only changes draft branding', () => {
  const p=page();
  p.run(`gdResults=[{l:'https://custom.example/new.png'}]; chooseGuideLogo(0);`);
  assert.equal(p.json('edits').logos.a, 'https://custom.example/new.png');
  assert.equal(p.json('edits').names.a, 'My Sky');
  assert.deepEqual(p.json('edits').hidden, ['other']);
  assert.equal(p.json('data.channels[0]').eo, 'existing');
  assert.equal(p.run('dirty'), true);
  assert.equal(p.calls.length, 0);
  p.node('gdProvider').onclick();
  assert.deepEqual(p.json('edits').logos, {});
  assert.equal(p.json('edits').names.a, 'My Sky');
  assert.equal(p.json('data.channels[0]').eo, 'existing');
});

test('link changes programme mapping without overwriting the logo draft', async () => {
  const p=page(); p.respond(async()=>({ok:true}));
  await p.run(`linkGuide('new-epg')`);
  assert.equal(p.json('data.channels[0]').eo,'new-epg');
  assert.equal(p.json('edits').logos.a,'https://manual.example/old.png');
  assert.equal(p.calls[0].options.headers['X-Editor-Viewer'],'main');
});

test('source selector searches the chosen playlist and renders absent-logo states', async () => {
  const p=page(); p.node('gdQ').value='Sky'; p.node('gdSource').value='1';
  p.run(`epgTexts={'Use EPG logo':'Logo EPG localisé','No EPG logo':'Aucun logo'};`);
  p.respond(async()=>({results:[{id:'same',n:'Sky <test>',sourceName:'Extra guide 1',l:'https://custom.example/logo.png'},
    {id:'no',n:'Sky plain',sourceName:'Extra guide 1'}]}));
  p.run('gdSearch()'); await p.timer();
  assert.match(p.calls[0].path,/pl=p&source=1&q=Sky/);
  assert.match(p.node('gdResults').innerHTML,/Sky &lt;test&gt;/);
  assert.match(p.node('gdResults').innerHTML,/Logo EPG localisé/);
  assert.match(p.node('gdResults').innerHTML,/data-logo="1" disabled>Aucun logo/);
  p.run('chooseGuideLogo(1)');
  assert.equal(p.json('edits').logos.a,'https://manual.example/old.png');
});

test('old search results cannot apply after channel or playlist changes', async () => {
  const p=page(); p.node('gdQ').value='Sky';
  let finish; p.respond(()=>new Promise(r=>finish=r));
  p.run('gdSearch()'); const pending=p.timer();
  p.run(`closeGuide(); pl='different';`);
  finish({results:[{id:'same',n:'Sky',l:'https://wrong.example/logo.png'}]});
  await pending;
  assert.equal(p.node('gdResults').innerHTML,'');
  p.run('chooseGuideLogo(0)');
  assert.equal(p.json('edits').logos.a,'https://manual.example/old.png');
});

test('Save sends the combined draft and retains it if the server rejects a URL', async () => {
  const p=page();
  p.run(`gdResults=[{l:'https://custom.example/logo.png'}]; chooseGuideLogo(0);`);
  p.respond(async()=>({error:'Invalid logo'})); await p.run('save()');
  const payload=JSON.parse(p.calls[0].options.body).edits;
  assert.equal(payload.logos.a,'https://custom.example/logo.png');
  assert.equal(payload.names.a,'My Sky'); assert.deepEqual(payload.hidden,['other']);
  assert.equal(p.run('dirty'),true); assert.equal(p.node('pl').disabled,false);
  assert.match(p.alerts[0],/Invalid logo/);
});

test('viewer conflict hides the editor and preserves the unsaved draft', async () => {
  const p=page(); p.respond(async()=>({status:409}));
  await assert.rejects(p.run(`api('/api/edits?pl=p',{edits})`),/viewer/);
  assert.equal(p.node('app').style.display,'none');
  assert.equal(p.json('edits').names.a,'My Sky');
  assert.match(p.node('loginMsg').textContent,/viewer changed/);
});

test('successful Save persists logo, pending rename and hides in one document', async () => {
  const p=page(); let saved;
  p.run(`gdResults=[{l:'https://custom.example/logo.png'}]; chooseGuideLogo(0);`);
  p.respond(async (path, options) => {
    if (path.startsWith('/api/edits')) { saved=JSON.parse(options.body).edits; return {hidden:1}; }
    if (path.startsWith('/api/channels')) return {edits:saved,channels:[{r:'a',n:'Sky',g:'Sports',eo:'existing'}]};
    return {};
  });
  await p.run('save()');
  assert.equal(saved.logos.a,'https://custom.example/logo.png');
  assert.equal(saved.names.a,'My Sky'); assert.deepEqual(saved.hidden,['other']);
  assert.equal(p.run('dirty'),false);
  assert.equal(p.json('data.channels[0]').eo,'existing');
});

test('new search wins over a slower old search in the same popup', async () => {
  const p=page(); let finish;
  p.node('gdQ').value='old'; p.respond(()=>new Promise(r=>finish=r));
  p.run('gdSearch()'); const old=p.timer();
  p.node('gdQ').value='new'; p.respond(async()=>({results:[{id:'new',n:'New',sourceName:'Main guide',l:'https://new.example/logo.png'}]}));
  p.run('gdSearch()'); await p.timer();
  finish({results:[{id:'old',n:'Old',sourceName:'Main guide',l:'https://old.example/logo.png'}]}); await old;
  p.run('chooseGuideLogo(0)');
  assert.equal(p.json('edits').logos.a,'https://new.example/logo.png');
});
