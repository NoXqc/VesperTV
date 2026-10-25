import { readFileSync } from 'node:fs';
import { Client, Events, GatewayIntentBits, Options } from 'discord.js';
import entries from './guide.json' with { type: 'json' };
import { createAutoResponder } from './auto-reply.mjs';

const guildId = process.env.DISCORD_GUILD_ID;
const channelId = process.env.DISCORD_HELP_CHANNEL_ID;
if (!/^\d{17,22}$/.test(guildId ?? '') || !/^\d{17,22}$/.test(channelId ?? '')) {
  throw new Error('Configure a server ID and one help channel ID.');
}
// File is provisioned privately by the owner; never log its contents or errors.
let token;
try { token = readFileSync(process.env.DISCORD_TOKEN_FILE ?? '/run/secrets/discord-bot-token', 'utf8').trim(); }
catch { throw new Error('Bot token file is not available.'); }
if (!token || /\s/.test(token)) throw new Error('Bot token file is empty or invalid.');

const client = new Client({
  intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMessages, GatewayIntentBits.MessageContent],
  allowedMentions: { parse: [], repliedUser: false },
  makeCache: Options.cacheWithLimits({ ...Options.DefaultMakeCacheSettings, MessageManager: 0 }),
});
const answer = createAutoResponder({ entries, guildId, channelId });
let connected = false;
client.once(Events.ClientReady, ready => {
  if (process.env.DISCORD_APPLICATION_ID && ready.user.id !== process.env.DISCORD_APPLICATION_ID) {
    console.error('Token belongs to a different bot application.');
    client.destroy();
    process.exitCode = 1;
    return;
  }
  connected = true;
  console.log('VesperTV automatic help connected; one channel enabled.');
});
client.on(Events.MessageCreate, message => {
  if (!connected) return;
  answer(message).catch(() => console.error('Help reply failed; check channel permissions.'));
});
client.on(Events.Error, () => console.error('Discord connection error; check bot configuration.'));
client.on(Events.ShardError, () => console.error('Discord gateway error.'));
try { await client.login(token); }
catch {
  console.error('Discord login failed. Check token and Message Content Intent.');
  client.destroy();
  process.exitCode = 1;
}
for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => { client.destroy(); process.exit(0); });
