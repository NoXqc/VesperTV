import test from 'node:test';
import assert from 'node:assert/strict';
import { BUG_FORM_URL, BUG_REPLY, REPEAT_MS, createBugRedirect } from './bug-redirect.mjs';

function fixture() {
  let clock = 0;
  const replies = [];
  const redirect = createBugRedirect({
    guildId: 'server', channelId: 'bugs', now: () => clock,
    isStaff: m => m.author.id === 'mod',
  });
  const message = (overrides = {}) => ({
    guildId: 'server', channelId: 'bugs', guild: { ownerId: 'owner' },
    author: { id: 'person', bot: false }, content: '',
    reply: async data => replies.push(data), ...overrides,
  });
  return { redirect, message, replies, advance: amount => { clock += amount; } };
}

test('only new human messages in the bugs channel get the GitHub link', async () => {
  const { redirect, message, replies } = fixture();
  for (const change of [{ guildId: 'elsewhere' }, { channelId: 'general' },
    { author: { id: 'bot', bot: true } }, { webhookId: 'hook' }, { system: true },
    { author: { id: 'owner', bot: false } }, { author: { id: 'mod', bot: false } }]) {
    assert.equal(await redirect(message(change)), false);
  }
  assert.equal(replies.length, 0);
  assert.equal(await redirect(message()), true);
  assert.ok(replies[0].content.includes(BUG_FORM_URL));
  assert.match(replies[0].content, /Send log/);
  assert.deepEqual(replies[0].allowedMentions, { parse: [], repliedUser: false });
});

test('a conversation gets one reply per person until the repeat time passes', async () => {
  const { redirect, message, replies, advance } = fixture();
  assert.equal(await redirect(message()), true);
  advance(60_000);
  assert.equal(await redirect(message()), false);
  assert.equal(await redirect(message({ author: { id: 'other', bot: false } })), true);
  advance(REPEAT_MS);
  assert.equal(await redirect(message()), true);
  assert.equal(replies.length, 3);
});

test('the reply fits one Discord message and pings nobody', () => {
  assert.ok(BUG_REPLY.length < 2000);
  assert.doesNotMatch(BUG_REPLY, /@everyone|@here|<@/);
});
