// #bugs-issues-report (owner, 2026-11-21): bugs now go to GitHub, where the
// issue helper answers in minutes and can read the user's Send log. The bot
// answers a new human message in the configured channel with the link,
// once per person per REPEAT_MS (a back-and-forth gets one reply), never to
// the server owner or moderators (Manage Messages). Reads no message text
// and keeps only bounded, transient per-user times.

export const BUG_FORM_URL = 'https://github.com/NoXqc/VesperTV/issues/new?template=bug.yml';
export const REPEAT_MS = 12 * 60 * 60 * 1000;

export const BUG_REPLY = [
  'Thanks for the report! 🙏 Bugs are now tracked on **GitHub**: an automatic helper answers within minutes, and the developer sees every report in one place.',
  `👉 **Report it here:** <${BUG_FORM_URL}>`,
  '**Tip:** add your log code. In VesperTV open **Settings > Help > Send log**, press Send, and put the code it shows (like `LOG-7K2QXM`) in the issue. The log stays private.',
  'No GitHub account yet? It\'s free and takes a minute.',
].join('\n\n');

export function createBugRedirect({ guildId, channelId, now = Date.now, isStaff = () => false }) {
  const users = new Map();
  return async message => {
    if (message.guildId !== guildId || message.channelId !== channelId
        || message.author?.bot || message.webhookId || message.system) return false;
    if (message.guild?.ownerId === message.author?.id || isStaff(message)) return false;
    const time = now();
    if (time - (users.get(message.author.id) ?? -Infinity) < REPEAT_MS) return false;
    for (const [id, when] of users) if (time - when >= REPEAT_MS) users.delete(id);
    // Set before awaiting so a burst of messages gets one reply.
    users.set(message.author.id, time);
    await message.reply({
      content: BUG_REPLY,
      allowedMentions: { parse: [], repliedUser: false },
      failIfNotExists: false,
    });
    return true;
  };
}
