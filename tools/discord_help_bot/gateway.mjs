import { readFileSync } from 'node:fs';
import { Client, Events, GatewayIntentBits, Options, PermissionFlagsBits } from 'discord.js';
import entries from './guide.json' with { type: 'json' };
import { createAutoResponder } from './auto-reply.mjs';
import { createBugRedirect } from './bug-redirect.mjs';

// Two optional jobs, each in one channel:
// - DISCORD_HELP_CHANNEL_ID: guide answers (pulled by the owner 2026-11-11, off on the VPS).
// - DISCORD_BUGS_CHANNEL_ID: the GitHub link in #bugs-issues-report (2026-11-21).
const guildId = process.env.DISCORD_GUILD_ID;
const helpChannelId = process.env.DISCORD_HELP_CHANNEL_ID || '';
const bugsChannelId = process.env.DISCORD_BUGS_CHANNEL_ID || '';
const snowflake = id => /^\d{17,22}$/.test(id);
if (!snowflake(guildId ?? '') || (!snowflake(helpChannelId) && !snowflake(bugsChannelId))
    || (helpChannelId && !snowflake(helpChannelId)) || (bugsChannelId && !snowflake(bugsChannelId))) {
  throw new Error('Configure a server ID and a help and/or bugs channel ID.');
}
// File is provisioned privately by the owner; never log its contents or errors.
let token;
try { token = readFileSync(process.env.DISCORD_TOKEN_FILE ?? '/run/secrets/discord-bot-token', 'utf8').trim(); }
catch { throw new Error('Bot token file is not available.'); }
if (!token || /\s/.test(token)) throw new Error('Bot token file is empty or invalid.');

// Message text is only needed for guide answers; the bugs reply never reads it.
const intents = [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMessages];
if (helpChannelId) intents.push(GatewayIntentBits.MessageContent);
const client = new Client({
  intents,
  allowedMentions: { parse: [], repliedUser: false },
  makeCache: Options.cacheWithLimits({ ...Options.DefaultMakeCacheSettings, MessageManager: 0 }),
});
const handlers = [];
if (helpChannelId) handlers.push(createAutoResponder({ entries, guildId, channelId: helpChannelId }));
if (bugsChannelId) {
  handlers.push(createBugRedirect({
    guildId, channelId: bugsChannelId,
    isStaff: m => Boolean(m.member?.permissions?.has(PermissionFlagsBits.ManageMessages)),
  }));
}
let connected = false;

async function checkChannel(ready, id, label) {
  try {
    const channel = await ready.channels.fetch(id);
    if (channel?.guildId !== guildId) {
      console.error(`Configured ${label} channel does not belong to the configured server.`);
      return;
    }
    const permissions = channel.permissionsFor(ready.user);
    if (!permissions?.has([PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages,
      PermissionFlagsBits.ReadMessageHistory])) {
      console.error(`${label} channel permissions missing: View Channel, Send Messages or Read Message History.`);
      return;
    }
    console.log(`${label} channel access verified.`);
  } catch {
    console.error(`${label} channel unavailable: check channel ID and View Channel permission.`);
  }
}

client.once(Events.ClientReady, async ready => {
  if (process.env.DISCORD_APPLICATION_ID && ready.user.id !== process.env.DISCORD_APPLICATION_ID) {
    console.error('Token belongs to a different bot application.');
    client.destroy();
    process.exitCode = 1;
    return;
  }
  connected = true;
  console.log(`VesperTV bot connected; ${handlers.length} channel job(s) enabled.`);
  // Log only configuration/access status, never credentials or message content.
  if (!ready.guilds.cache.has(guildId)) {
    console.error('Configured server unavailable: install this application with the bot scope.');
    return;
  }
  if (helpChannelId) await checkChannel(ready, helpChannelId, 'Help');
  if (bugsChannelId) await checkChannel(ready, bugsChannelId, 'Bugs');
});
client.on(Events.MessageCreate, async message => {
  if (!connected) return;
  for (const handle of handlers) {
    try {
      if (await handle(message)) return;
    } catch {
      console.error('Reply failed; check channel permissions.');
      return;
    }
  }
});
client.on(Events.Error, () => console.error('Discord connection error; check bot configuration.'));
client.on(Events.ShardError, () => console.error('Discord gateway error.'));
try { await client.login(token); }
catch {
  console.error('Discord login failed. Check the token (and Message Content Intent for guide answers).');
  client.destroy();
  process.exitCode = 1;
}
for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => { client.destroy(); process.exit(0); });
