// Curated search only: no model, paid API, account data, or generated advice.
const STOP = new Set('a an and are can could do does for from get go how i in is it me my of on please the this to use we what where with you your'.split(' '));
const ALIASES = new Map(Object.entries({
  favourites: 'favorite', favourite: 'favorite', favorites: 'favorite',
  reminders: 'reminder', remindee: 'reminder', pill: 'reminder',
  channels: 'channel', groups: 'group', subtitles: 'subtitle',
  program: 'programme', programs: 'programme', programmes: 'programme', restart: 'start', access: 'watch',
  shows: 'show', movies: 'movie', episodes: 'episode',
  disable: 'hide', disabled: 'hide', remove: 'hide',
  recording: 'record', recordings: 'record',
  cacher: 'hide', rappel: 'reminder', reprise: 'resume',
}));

function words(value) {
  return String(value).normalize('NFKD').replace(/[\u0300-\u036f]/g, '')
    .toLowerCase().replace(/\bcatch[\s\u2010-\u2015-]*up\b/g, 'catchup')
    .replace(/turn\s+off/g, 'hide')
    .replace(/[^a-z0-9]+/g, ' ').trim().split(/\s+/)
    .filter(word => word && !STOP.has(word)).map(word => ALIASES.get(word) ?? word);
}

export function searchGuide(entries, question, limit = 3) {
  const query = [...new Set(words(String(question).slice(0, 500)))];
  if (!query.length) return [];
  return entries.map(entry => {
    const title = words(entry.title);
    const controls = new Set(words(entry.controls));
    const body = new Set(words(entry.answer));
    let score = 0, hits = 0;
    for (const word of query) {
      const weight = title.includes(word) ? 5 : controls.has(word) ? 2 : body.has(word) ? 1 : 0;
      score += weight;
      if (weight) hits++;
    }
    if (query.join(' ') === title.join(' ')) score += 10;
    return { entry, score, coverage: hits / query.length };
  }).filter(result => result.score > 0 && result.coverage >= 0.6)
    .sort((a, b) => b.score - a.score || b.coverage - a.coverage || a.entry.id.localeCompare(b.entry.id))
    .slice(0, Math.min(3, Math.max(1, limit)));
}

export function guideReply(entries, question) {
  const results = searchGuide(entries, question);
  if (!results.length) {
    return {
      content: 'I could not find a clear answer in the VesperTV remote guide. Try a short topic such as “hide resume reminder”, “subtitles”, or “move a channel”.\n<https://vespertv.app/remote.html>',
      allowed_mentions: { parse: [] },
    };
  }
  const first = results[0].entry;
  let content = `**${first.title}**\n${first.controls}\n\n${first.answer}\n\nGuide: <${first.url}>`;
  const more = results.slice(1).map(({ entry }) => `• [${entry.title}](${entry.url})`).join('\n');
  if (more && content.length + more.length < 1850) content += `\n\nOther guide matches:\n${more}`;
  if (content.length > 1950) {
    content = `**${first.title}**\n${first.answer.slice(0, 1400)}…\n\nFull instructions: <${first.url}>`;
  }
  return { content, allowed_mentions: { parse: [] } };
}
