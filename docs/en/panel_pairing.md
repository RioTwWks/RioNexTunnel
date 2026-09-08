# RioNexGate panel pairing

RioNexTunnel can optionally pair with a [RioNexGate](https://github.com/RioTwWks/RioNexGate) panel for managed subscriptions, traffic stats, and remote commands.

## Additive integration

Panel features are **opt-in**. If you never configure a panel URL, the app behaves exactly as a standalone VPN client.

- Manual profiles (`vless://`, subscription URLs, etc.) continue to work unchanged.
- The panel adds a **RioNexGate** profile when pairing succeeds.
- **Clear registration** removes only the RioNexGate profile and panel credentials — your other profiles stay in the list.

## Pairing steps

1. Open **Settings → RioNexGate panel**.
2. Enable the panel section and enter your panel base URL (e.g. `https://panel.example.com`).
3. Paste the **pairing token** from the panel admin UI and tap **Register**.
4. The client stores a **device token** in secure storage and creates/updates the RioNexGate profile.

## What syncs automatically

| Feature | Behavior |
|---------|----------|
| Config sync | Default every **15 minutes** (configurable: 15 / 30 / 60 / 120 min). Skips rewrite when `config_hash` is unchanged. |
| Stats upload | Every **60 seconds** while connected, plus a final flush on disconnect. |
| Offline | Last good config is cached locally; stats are queued and replayed when the panel is reachable again. |

## Connect behavior

When the panel provides a full JSON `config` object, RioNexTunnel uses that cached/synced JSON for the **RioNexGate** profile on connect (instead of re-fetching the subscription URL). If no cached JSON exists, it falls back to the subscription URL pipeline.

## Security notes

- The **device token** is for panel API auth only — it is separate from transport/VLESS credentials.
- Device tokens are stored in **flutter_secure_storage**, not in SharedPreferences.
- SOCKS5 on `127.0.0.1` still requires per-session or panel-provided auth — never unauthenticated localhost proxies.

## Clearing panel registration

Use **Clear** in Settings to wipe:

- Device token (secure storage)
- Cached panel config and stats queue
- The RioNexGate profile

Manual profiles are **not** removed.
