import { createServer } from 'node:http';
import entries from './guide.json' with { type: 'json' };
import { handleRequest } from './interactions.mjs';

if (!/^[0-9a-f]{64}$/i.test(process.env.DISCORD_PUBLIC_KEY ?? '')) {
  throw new Error('Set DISCORD_PUBLIC_KEY to the application public key (not its bot token).');
}
const port = Number(process.env.PORT ?? 8790);
if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('Invalid PORT');

const server = createServer(async (incoming, outgoing) => {
  try {
    const chunks = [];
    let length = 0;
    for await (const chunk of incoming) {
      length += chunk.length;
      if (length > 65536) { outgoing.writeHead(413).end(); return; }
      chunks.push(chunk);
    }
    const method = incoming.method ?? 'GET';
    const request = new Request(`http://127.0.0.1${incoming.url}`, {
      method, headers: incoming.headers,
      ...(['GET', 'HEAD'].includes(method) ? {} : { body: Buffer.concat(chunks) }),
    });
    const response = await handleRequest(request, process.env, entries);
    outgoing.writeHead(response.status, Object.fromEntries(response.headers));
    outgoing.end(Buffer.from(await response.arrayBuffer()));
  } catch {
    // Never log interaction bodies, headers, tokens or users' questions.
    outgoing.writeHead(500).end('Request failed');
  }
});
server.requestTimeout = 10000;
server.headersTimeout = 10000;
server.listen(port, '127.0.0.1', () => console.log(`VesperTV help: ${entries.length} answers on loopback port ${port}`));
for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => server.close(() => process.exit(0)));
