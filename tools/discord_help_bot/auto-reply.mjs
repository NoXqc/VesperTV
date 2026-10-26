import { guideReply, searchGuide } from './search.mjs';

// Inspect only new human messages in the single explicitly configured channel.
// Keep bounded, transient cooldowns, never message text or user history.
export function createAutoResponder({ entries, guildId, channelId, now = Date.now }) {
  const users = new Map();
  let lastReply = -Infinity;
  return async message => {
    if (message.guildId !== guildId || message.channelId !== channelId
        || message.author?.bot || message.webhookId || message.system) return false;
    const text = message.content?.trim() ?? '';
    if (!text || text.length > 500 || text.startsWith('/')) return false;
    const question = /\?|^(how|where|can|could|does|do|is|why|what|comment|ou|où)\b/i.test(text);
    if (!question && !searchGuide(entries, text).length) return false;
    const time = now();
    if (time - lastReply < 3000 || time - (users.get(message.author.id) ?? -Infinity) < 30000) return false;
    for (const [id, when] of users) if (time - when >= 30000) users.delete(id);
    // Set before awaiting so a burst cannot send parallel duplicate replies.
    users.set(message.author.id, time);
    lastReply = time;
    const answer = guideReply(entries, text);
    await message.reply({
      content: answer.content,
      allowedMentions: { parse: [], repliedUser: false },
      failIfNotExists: false,
    });
    return true;
  };
}
