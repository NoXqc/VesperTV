# VesperTV guide help

A Discord `/howto` command that searches the official remote guide. No AI model,
AI API key, paid API, or outgoing answer-lookup requests are needed. HTTP mode has no runtime packages; automatic replies use the pinned discord.js dependency.
Hosting is separate: use an existing Node server or the included Cloudflare Worker
adapter. Nothing in this folder has been deployed or registered automatically.

Example: `/howto question:hide resume reminder` returns the documented setting,
the instructions, and a link to the appropriate website tab. Autocomplete suggests
guide topics. If the question has no clear match, the app links to the guide and
asks for a shorter topic. This is keyword search, so it cannot answer every
wording or questions absent from the guide. The HTTP mode does not monitor channel messages. The optional Gateway mode below answers automatically in one configured help channel.

## Maintain the answers

`docs/remote.html` is the source of truth. Edit that page first, then run from the
repository root:

```powershell
python tools/discord_help_bot/build_guide.py
python tools/discord_help_bot/build_guide.py --check
node --test tools/discord_help_bot/*.test.mjs
```

Commit `guide.json` with the website change and redeploy the bot when answers
change. The index currently contains 55 guide entries. Links use the website's
existing category fragments; publishing the website is a separate step.

## Discord setup (one time)

1. Create a separate **VesperTV Help** application in the
   [Discord Developer Portal](https://discord.com/developers/applications).
2. In General Information, copy the **Application ID** and **Public Key**. These
   are public configuration values. Get the server's ID using Discord Developer
   Mode and Copy Server ID.
3. Configure the hosting option below. Set `DISCORD_PUBLIC_KEY`,
   `DISCORD_APPLICATION_ID`, and `DISCORD_GUILD_ID` to the intended application
   and server. The HTTP runtime needs no bot token.
4. Set the application's **Interactions Endpoint URL** to the deployed HTTPS
   address ending in `/interactions`. Discord validates it with a signed PING;
   save only after the host is running.
5. Install the application on the server with the `applications.commands` scope.
   No Message Content privileged intent or channel-reading permissions are
   needed for this slash-command implementation.
6. Register `/howto` using the script below, then test in Discord.

The existing release-announcement webhook cannot be reused as an application
credential. Keep the bot token out of chat, source control, and command history.
It is needed only locally for command registration; obtain it from this new
application's Bot page. The HTTP runtime has no token-based messaging capability; Gateway mode below
uses a separate private runtime token.

From this directory, preview the command without credentials:

```powershell
node register-command.mjs
```

For registration, set the two public IDs and enter the token using a hidden
prompt in a local PowerShell terminal. Do not paste the actual token into a
command or this README:

```powershell
$env:DISCORD_APPLICATION_ID = 'YOUR_APPLICATION_ID'
$env:DISCORD_GUILD_ID = 'YOUR_SERVER_ID'
$registrationCredential = Get-Credential -UserName 'bot' -Message 'Enter the new Discord bot token as the password'
try {
    $env:DISCORD_BOT_TOKEN = $registrationCredential.GetNetworkCredential().Password
    node register-command.mjs --apply
} finally {
    Remove-Item Env:DISCORD_BOT_TOKEN -ErrorAction SilentlyContinue
    $registrationCredential = $null
}
```

Registration uses a single command POST, preserving other commands. It creates
a server command so testing does not require global command propagation.

## Existing server (Node 22.12 or newer)

Copy this directory to a dedicated application directory. Set the three public
configuration values in the service environment, then run `node server.mjs`.
No `npm install` is required. The server binds **127.0.0.1:8790** by default;
`PORT` can override the port. Put it behind an HTTPS reverse proxy forwarding
`/interactions` without modifying request bytes or signature headers. Run it as
a dedicated unprivileged service account. `/health` returns the answer count.

For this project's live VPS, follow `AGENTS.md` and the private VPS notes: prepare
the exact deployment commands for the owner before any server mutation. This
README is not authorization to modify the existing relay, nginx, or Tuliprox.

## Cloudflare Worker alternative

Use `worker.mjs` as the Worker entry point and deploy it with its local imports
and JSON bundled together. Configure the same three public variables and use
`https://YOUR_WORKER_HOST/interactions` as the Discord endpoint. No Node server
or VPS changes are needed. A Cloudflare account and a deployment setup are still
required; the adapter alone does not create them. Check the current
[Workers free-plan limits](https://developers.cloudflare.com/workers/platform/limits/)
before enabling it.

## Verification and limits

Tests use disposable signing keys and make no Discord requests. They cover
real guide searches, unknown questions, autocomplete, response length, mentions,
signature tampering, stale requests, wrong applications/servers, and body limits.
Every response disables mentions. The app does not log questions, incoming
headers, or interaction payloads. Only signed interactions are answered; replies
to valid `/howto` commands are public in the invoking channel.

An HTTP interactions app can work without a continuously connected Gateway bot;
its online presence is not a health check. Automatic answers to ordinary channel
messages would require a separate transport and explicit channel configuration.

Protocol reference:
[Discord interactions overview](https://docs.discord.com/developers/interactions/overview).

## Automatic replies in one help channel (Gateway mode)

`gateway.mjs` is a separate process; the HTTP `/howto` endpoint can stay running.
Run `npm ci --omit=dev --ignore-scripts` to install the locked discord.js dependency.
Configure these public environment variables:

- `DISCORD_APPLICATION_ID`: intended application ID (rejects a different bot).
- `DISCORD_GUILD_ID`: exactly one server ID.
- `DISCORD_HELP_CHANNEL_ID`: exactly one text channel ID.
- `DISCORD_TOKEN_FILE`: path to the private runtime token file; defaults to
  `/run/secrets/discord-bot-token`. Never commit the file or put its value in logs.

Enable **Message Content Intent** on the application's Bot page. Install the
application with both `bot` and `applications.commands` scopes. Give it View
Channel, Send Messages, and Read Message History in the help channel; restrict
its role's access to other channels if desired. No administrator permission is
needed. Start with `node gateway.mjs`.

Only new human messages in the configured server/channel are considered. The
bot answers questions or recognized guide topics, ignores bot/webhook/system
messages and slash commands, and does not fetch history. Replies mention nobody.
There is a 30-second cooldown per author and 3-second channel-wide cooldown;
no questions or message history are retained. Unknown questions receive the
same guide fallback. It uses the documented guide, so it is not a general AI
assistant and cannot diagnose accounts or undocumented app behavior.

Unlike the HTTP runtime, automatic replies require a persistent Discord token
and outbound Gateway/Discord API connectivity. Store that token on the server
in a dedicated restricted file, mounted read-only into the bot container.
Provision it through a hidden local prompt, never through chat. Routine bot
updates should preserve that file without reading or displaying it.
