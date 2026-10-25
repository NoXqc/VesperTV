// Run by the owner locally: the token is needed only to register the command.
export const command = {
  name: 'howto',
  description: 'Find VesperTV instructions in the official remote guide',
  type: 1,
  options: [{
    name: 'question', description: 'For example: hide resume reminder or move a channel',
    type: 3, required: true, autocomplete: true, max_length: 500,
  }],
};

if (!process.argv.includes('--apply')) {
  console.log(JSON.stringify(command, null, 2));
  console.log('Preview only. Use --apply after setting the Discord registration environment variables.');
} else {
  const { DISCORD_APPLICATION_ID: app, DISCORD_GUILD_ID: guild, DISCORD_BOT_TOKEN: token } = process.env;
  if (!/^\d{17,22}$/.test(app ?? '') || !/^\d{17,22}$/.test(guild ?? '') || !token) {
    throw new Error('Set DISCORD_APPLICATION_ID, DISCORD_GUILD_ID and DISCORD_BOT_TOKEN locally. Never paste the token into chat.');
  }
  // POST upserts only /howto, preserving any other commands on the application.
  const response = await fetch(`https://discord.com/api/v10/applications/${app}/guilds/${guild}/commands`, {
    method: 'POST', headers: { authorization: `Bot ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify(command), signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) throw new Error(`Discord command registration failed (HTTP ${response.status}); response body omitted.`);
  console.log('Registered /howto on the configured server.');
}
