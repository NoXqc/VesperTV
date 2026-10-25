import test from 'node:test';
import assert from 'node:assert/strict';
import entries from './guide.json' with { type: 'json' };
import { createAutoResponder } from './auto-reply.mjs';

function fixture() {
  let clock = 0;
  const replies = [];
  const responder = createAutoResponder({ entries, guildId: 'server', channelId: 'help', now: () => clock });
  const message = (overrides = {}) => ({
    guildId: 'server', channelId: 'help', author: { id: 'person', bot: false },
    content: 'how do I hide the resume reminder?', reply: async data => replies.push(data), ...overrides,
  });
  return { responder, message, replies, advance: amount => { clock += amount; } };
}

test('automatic help is restricted to new human messages in the configured channel', async () => {
  const { responder, message, replies } = fixture();
  for (const change of [{ guildId: 'elsewhere' }, { channelId: 'other' }, { guildId: null },
    { author: { id: 'bot', bot: true } }, { webhookId: 'webhook' }, { system: true },
    { content: 'Thanks!' }, { content: '/howto subtitles' }, { content: 'a'.repeat(501) }]) {
    assert.equal(await responder(message(change)), false);
  }
  assert.equal(replies.length, 0);
  assert.equal(await responder(message()), true);
  assert.match(replies[0].content, /Settings → Interface → Resume reminder/);
  assert.deepEqual(replies[0].allowedMentions, { parse: [], repliedUser: false });
});

test('reply bursts and repeated questions are bounded without storing question history', async () => {
  const { responder, message, replies, advance } = fixture();
  assert.equal(await responder(message()), true);
  assert.equal(await responder(message()), false);
  advance(3000);
  assert.equal(await responder(message()), false);
  assert.equal(await responder(message({ author: { id: 'other', bot: false } })), true);
  advance(27000);
  assert.equal(await responder(message()), true);
  assert.equal(replies.length, 3);
});

test('unanswered questions get a guide fallback, without invented instructions', async () => {
  const { responder, message, replies } = fixture();
  assert.equal(await responder(message({ content: 'How do I refund my subscription invoice?' })), true);
  assert.match(replies[0].content, /could not find a clear answer/);
});
