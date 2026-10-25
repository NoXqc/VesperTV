import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, sign } from 'node:crypto';
import entries from './guide.json' with { type: 'json' };
import { handleRequest } from './interactions.mjs';

// Disposable test identities, never Discord credentials.
const keys = generateKeyPairSync('ed25519');
const publicKey = keys.publicKey.export({ format: 'der', type: 'spki' }).subarray(-32).toString('hex');
const env = { DISCORD_PUBLIC_KEY: publicKey, DISCORD_APPLICATION_ID: '123456789012345678', DISCORD_GUILD_ID: '987654321098765432' };
const now = 1792950000000;
const question = { type: 2, application_id: env.DISCORD_APPLICATION_ID, guild_id: env.DISCORD_GUILD_ID,
  data: { name: 'howto', options: [{ name: 'question', value: 'hide resume reminder' }] } };

function request(payload, seconds = Math.floor(now / 1000), mutate = false) {
  const body = JSON.stringify(payload);
  const signature = sign(null, Buffer.from(`${seconds}${body}`), keys.privateKey).toString('hex');
  return new Request('https://help.example/interactions', {
    method: 'POST', headers: { 'x-signature-ed25519': signature, 'x-signature-timestamp': `${seconds}` },
    body: mutate ? `${body} ` : body,
  });
}

test('Discord signed ping and actual help question work without external services', async () => {
  const ping = await handleRequest(request({ type: 1, application_id: env.DISCORD_APPLICATION_ID }), env, entries, now);
  assert.deepEqual(await ping.json(), { type: 1 });
  const response = await handleRequest(request(question), env, entries, now);
  const payload = await response.json();
  assert.equal(payload.type, 4);
  assert.match(payload.data.content, /Settings → Interface → Resume reminder/);
  assert.deepEqual(payload.data.allowed_mentions, { parse: [] });
});

test('altered signatures, stale requests and different apps are rejected', async () => {
  assert.equal((await handleRequest(request(question, now / 1000, true), env, entries, now)).status, 401);
  assert.equal((await handleRequest(request(question, now / 1000 - 301), env, entries, now)).status, 401);
  assert.equal((await handleRequest(request({ ...question, application_id: 'wrong' }), env, entries, now)).status, 403);
});

test('autocomplete offers real titles and other servers receive no public reply', async () => {
  const result = await handleRequest(request({ ...question, type: 4 }), env, entries, now);
  const payload = await result.json();
  assert.equal(payload.type, 8);
  assert.equal(payload.data.choices[0].value, 'Hide the resume reminder');
  const elsewhere = await handleRequest(request({ ...question, guild_id: 'other' }), env, entries, now);
  assert.equal((await elsewhere.json()).data.flags, 64);
});

test('oversized payloads and non-command traffic cannot become public messages', async () => {
  const large = request({ ...question, padding: 'x'.repeat(70000) });
  assert.equal((await handleRequest(large, env, entries, now)).status, 413);
  const result = await handleRequest(request({ ...question, data: { name: 'different' } }), env, entries, now);
  assert.equal((await result.json()).data.flags, 64);
});
