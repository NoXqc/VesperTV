import { guideReply, searchGuide } from './search.mjs';

const json = (body, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { 'content-type': 'application/json; charset=utf-8' },
});
const errorReply = content => json({ type: 4, data: {
  content, flags: 64, allowed_mentions: { parse: [] },
} });
const hex = value => Uint8Array.from(value.match(/../g), part => Number.parseInt(part, 16));

async function readBody(request) {
  const reader = request.body?.getReader();
  if (!reader) return new Uint8Array();
  const chunks = [];
  let size = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.length;
    if (size > 65536) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }
  const result = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { result.set(chunk, offset); offset += chunk.length; }
  return result;
}

export async function handleRequest(request, env, entries, now = Date.now()) {
  const path = new URL(request.url).pathname;
  if (request.method === 'GET' && path === '/health') return json({ ok: true, answers: entries.length });
  if (request.method !== 'POST' || path !== '/interactions') return json({ error: 'Not found' }, 404);
  const publicKey = env.DISCORD_PUBLIC_KEY ?? '';
  if (!/^[0-9a-f]{64}$/i.test(publicKey)) return json({ error: 'Application not configured' }, 503);
  const signature = request.headers.get('x-signature-ed25519') ?? '';
  const timestamp = request.headers.get('x-signature-timestamp') ?? '';
  if (!/^[0-9a-f]{128}$/i.test(signature) || !/^\d{10,12}$/.test(timestamp)
      || Math.abs(now / 1000 - Number(timestamp)) > 300) return json({ error: 'Invalid signature' }, 401);
  const body = await readBody(request);
  if (body === null) return json({ error: 'Request too large' }, 413);
  const prefix = new TextEncoder().encode(timestamp);
  const signed = new Uint8Array(prefix.length + body.length);
  signed.set(prefix); signed.set(body, prefix.length);
  try {
    const key = await crypto.subtle.importKey('raw', hex(publicKey), 'Ed25519', false, ['verify']);
    if (!await crypto.subtle.verify('Ed25519', key, hex(signature), signed)) return json({ error: 'Invalid signature' }, 401);
  } catch {
    return json({ error: 'Invalid signature' }, 401);
  }
  let interaction;
  try { interaction = JSON.parse(new TextDecoder().decode(body)); }
  catch { return json({ error: 'Invalid JSON' }, 400); }
  if (env.DISCORD_APPLICATION_ID && interaction.application_id !== env.DISCORD_APPLICATION_ID) {
    return json({ error: 'Wrong application' }, 403);
  }
  if (interaction.type === 1) return json({ type: 1 });
  if (env.DISCORD_GUILD_ID && interaction.guild_id !== env.DISCORD_GUILD_ID) {
    return errorReply('This help app is configured for the VesperTV server.');
  }
  if (interaction.data?.name !== 'howto') return errorReply('Use /howto and a short question about VesperTV.');
  const question = interaction.data?.options?.find(option => option.name === 'question')?.value;
  if (interaction.type === 4) {
    const choices = searchGuide(entries, typeof question === 'string' ? question : '')
      .map(({ entry }) => ({ name: entry.title.slice(0, 100), value: entry.title.slice(0, 100) }));
    return json({ type: 8, data: { choices } });
  }
  if (interaction.type !== 2) return json({ error: 'Unsupported interaction' }, 400);
  if (typeof question !== 'string' || question.length > 500) return errorReply('Ask a short question, for example: /howto hide resume reminder');
  return json({ type: 4, data: guideReply(entries, question) });
}
