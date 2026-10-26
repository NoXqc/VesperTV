import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createServer } from 'node:net';
import { generateKeyPairSync, sign } from 'node:crypto';
import { once } from 'node:events';
import { fileURLToPath } from 'node:url';
import entries from './guide.json' with { type: 'json' };

test('Node adapter serves health and verifies a signed Discord ping over HTTP', { timeout: 15000 }, async () => {
  const reservation = createServer();
  reservation.listen(0, '127.0.0.1');
  await once(reservation, 'listening');
  const port = reservation.address().port;
  await new Promise(resolve => reservation.close(resolve));
  const { publicKey, privateKey } = generateKeyPairSync('ed25519');
  const publicHex = publicKey.export({ type: 'spki', format: 'der' }).subarray(-32).toString('hex');
  const child = spawn(process.execPath, [fileURLToPath(new URL('./server.mjs', import.meta.url))], {
    env: { ...process.env, PORT: String(port), DISCORD_PUBLIC_KEY: publicHex,
      DISCORD_APPLICATION_ID: '123', DISCORD_GUILD_ID: '456' },
    stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true,
  });
  try {
    await Promise.race([
      once(child.stdout, 'data'),
      once(child, 'exit').then(([code]) => { throw new Error(`Server exited before listening (${code})`); }),
    ]);
    const endpoint = `http://127.0.0.1:${port}`;
    const health = await fetch(`${endpoint}/health`);
    assert.equal(health.status, 200);
    assert.equal((await health.json()).answers, entries.length);
    const timestamp = String(Math.floor(Date.now() / 1000));
    const body = JSON.stringify({ type: 1, application_id: '123' });
    const signature = sign(null, Buffer.from(timestamp + body), privateKey).toString('hex');
    const response = await fetch(`${endpoint}/interactions`, {
      method: 'POST', body, headers: {
        'x-signature-timestamp': timestamp, 'x-signature-ed25519': signature,
      },
    });
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { type: 1 });
  } finally {
    if (child.exitCode === null) {
      const exited = once(child, 'exit');
      child.kill();
      await exited;
    }
  }
});
