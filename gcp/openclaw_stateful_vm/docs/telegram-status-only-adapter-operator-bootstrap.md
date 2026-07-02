# Telegram Status-Only Adapter Operator Bootstrap

**Status:** Operator preparation only; this document does not enable Telegram access.

## Purpose

This guide describes the operator-side preparation required before future enablement of the OpenClaw Telegram status-only adapter.

It covers:

- creating a Telegram bot outside the repository;
- identifying an approved Telegram chat ID;
- storing the Telegram bot token in Google Secret Manager;
- confirming non-secret operator inputs for a future tracked enablement task.

This guide must not contain real bot tokens or real Telegram chat IDs.

## Current Safety Boundary

This preparation does not enable the adapter.

Not enabled by this guide:

- Telegram polling;
- Telegram Bot API runtime calls;
- systemd service wiring;
- Terraform rollout;
- Secret Manager payload reads by the adapter;
- OpenClaw runtime configuration changes;
- GitHub PR/write mode;
- `/ask` or any mutating Telegram command.

## Planned Runtime Model

The future adapter will use this model:

```text
Google Secret Manager secret:
openclaw-telegram-bot-token
        ↓ future VM bootstrap / secret retrieval
VM-local runtime file:
/run/openclaw/secrets/TELEGRAM_BOT_TOKEN
        ↓ future Telegram adapter
adapter reads token from this local file
```

Planned non-secret configuration names:

```text
TELEGRAM_ALLOWED_CHAT_IDS=<APPROVED_CHAT_ID_1>,<APPROVED_CHAT_ID_2>
TELEGRAM_BOT_TOKEN_FILE=/run/openclaw/secrets/TELEGRAM_BOT_TOKEN
OPENCLAW_BASE_URL=http://127.0.0.1:8080
```

Port model:

```text
VM-local OpenClaw runtime port: 8080
Operator laptop IAP tunnel port: 18080
Adapter default OpenClaw URL on VM: http://127.0.0.1:8080
Laptop/IAP test override only: http://127.0.0.1:18080
```

## 1. Create the Telegram Bot

In Telegram:

1. Open `@BotFather`.
2. Send:

   ```text
   /newbot
   ```

3. Choose a display name, for example:

   ```text
   OpenClaw Status
   ```

4. Choose a bot username ending in `bot`, for example:

   ```text
   openclaw_status_example_bot
   ```

5. BotFather will return a bot token.

Store the token in a password manager or another approved secure location.

Do not paste the token into:

- Git;
- Codex prompts;
- ChatGPT conversations;
- Markdown docs;
- tickets;
- logs;
- evidence files.

Open the new bot and send it a message such as:

```text
/start
```

The bot will not reply until a backend adapter is implemented and enabled. That is expected.

## 2. Identify the Approved Telegram Chat ID

After sending `/start` to the bot, use a local helper script to call `getUpdates` and inspect the resulting update metadata.

Create a temporary file named `get_chat_id.py` outside the tracked repository, or remove it before committing anything.

```python
import getpass
import json
import re
import urllib.error
import urllib.request

raw_token = getpass.getpass("Paste Telegram bot token: ")
token = "".join(raw_token.split())

if not re.match(r"^\d+:[A-Za-z0-9_-]+$", token):
    raise SystemExit(
        "Token format looks invalid. Copy only the token from BotFather, "
        "without spaces, quotes, or extra text."
    )

url = f"https://api.telegram.org/bot{token}/getUpdates"

try:
    with urllib.request.urlopen(url, timeout=20) as response:
        data = json.loads(response.read().decode("utf-8"))
except urllib.error.HTTPError as exc:
    body = exc.read().decode("utf-8", errors="replace")
    raise SystemExit(f"Telegram API returned HTTP {exc.code}: {body}")
except urllib.error.URLError as exc:
    raise SystemExit(f"Network error: {exc}")

print(json.dumps(data, indent=2, ensure_ascii=False))
```

Run it locally:

```bash
python ./get_chat_id.py
```

Find the private chat ID in the output:

```json
"chat": {
  "id": 123456789,
  "type": "private"
}
```

Record the chat ID privately as an approved operator input.

Do not publish real chat IDs in public docs if avoidable.

Remove the helper script after use:

```bash
rm -f get_chat_id.py
```

## 3. Create the Secret Manager Secret

Run these commands from Git Bash.

Set variables:

```bash
export PROJECT_ID="ai-agent-host-497515"
export SECRET_NAME="openclaw-telegram-bot-token"
```

Select the project:

```bash
gcloud config set project "$PROJECT_ID"
gcloud config get-value project
```

Enable the Secret Manager API if needed:

```bash
gcloud services enable secretmanager.googleapis.com \
  --project="$PROJECT_ID"
```

Create the secret metadata container:

```bash
gcloud secrets create "$SECRET_NAME" \
  --project="$PROJECT_ID" \
  --replication-policy="automatic" \
  --labels="component=openclaw,phase=7d,purpose=telegram-status-only"
```

If the secret already exists, keep the existing secret and continue to adding a new version only when intentional.

## 4. Add the Bot Token as a Secret Version

Do not put the token directly into a shell command.

Use an interactive hidden prompt:

```bash
read -rsp "Paste Telegram bot token: " TELEGRAM_TOKEN
echo
```

Optionally verify only the token length, not the token value:

```bash
echo "Token length: ${#TELEGRAM_TOKEN}"
```

Add a new secret version from stdin:

```bash
printf '%s' "$TELEGRAM_TOKEN" | gcloud secrets versions add "$SECRET_NAME" \
  --project="$PROJECT_ID" \
  --data-file=-
```

Clear the token from the current shell session:

```bash
unset TELEGRAM_TOKEN
```

## 5. Verify Metadata Without Reading the Secret Payload

Safe metadata checks:

```bash
gcloud secrets describe "$SECRET_NAME" \
  --project="$PROJECT_ID"
```

```bash
gcloud secrets versions list "$SECRET_NAME" \
  --project="$PROJECT_ID"
```

Expected result: at least one enabled secret version exists.

Do not run `gcloud secrets versions access` during routine evidence capture because it returns the secret payload.

## 6. Confirm Nothing Was Added to Git

From the repository root:

```bash
git status --short
```

Expected: no token files and no temporary helper scripts are tracked.

Remove any temporary helper file if needed:

```bash
rm -f get_chat_id.py
```

## 7. Operator Decision Record

Record only non-secret completion status, for example:

```text
Bot created: yes
Bot username recorded privately: yes
Approved chat ID known: yes
Secret name: openclaw-telegram-bot-token
Token version added: yes
Token file path: /run/openclaw/secrets/TELEGRAM_BOT_TOKEN
OpenClaw base URL: http://127.0.0.1:8080
Validation window: 30 minutes
Rollback owner: <operator name>
```

Do not include:

- the bot token;
- real chat IDs;
- Secret Manager payloads;
- gateway token values;
- model API keys;
- GitHub tokens.

## 8. Next Gate

A separate approved implementation task is required before adding:

- token file reader;
- real HTTP transport;
- polling loop;
- systemd service;
- Secret Manager mapping into the VM runtime;
- Terraform/runtime wiring;
- live VM validation.

Until that future task is approved and rolled out, the Telegram bot will not respond to `/start`, `/status`, or other commands.

## References

- Telegram Bot API: https://core.telegram.org/bots/api
- Telegram BotFather tutorial: https://core.telegram.org/bots/tutorial
- Google Secret Manager create and access secrets: https://cloud.google.com/secret-manager/docs/creating-and-accessing-secrets
- `gcloud secrets create`: https://cloud.google.com/sdk/gcloud/reference/secrets/create
- `gcloud secrets versions add`: https://cloud.google.com/sdk/gcloud/reference/secrets/versions/add
