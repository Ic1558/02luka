# Remote Access via Cloudflare Tunnel

This guide explains how to expose the local 02luka stack over Cloudflare Zero Trust so remote devices can reach both the API (boss-api) and the Luka UI.

## Prerequisites
- Cloudflare account with Zero Trust enabled.
- Administrative access to the local development machine.
- Homebrew (macOS) or the ability to install `cloudflared`.

## 1. Install `cloudflared`

```bash
brew install cloudflared
```

> On Linux or Windows, follow the [official Cloudflare instructions](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/).

## 2. Authenticate and create the tunnel

```bash
cloudflared login
cloudflared tunnel create 02luka
```

This creates credentials at `~/.cloudflared/02luka.json`.

## 3. Map DNS routes

```bash
cloudflared tunnel route dns 02luka api.theedges.work
cloudflared tunnel route dns 02luka luka.theedges.work
```

Both hostnames should now appear in your Cloudflare Zero Trust dashboard.

## 4. Configure ingress

Create (or update) `~/.cloudflared/config.yml` with the following contents:

```yaml
tunnel: 02luka
credentials-file: /Users/<you>/.cloudflared/02luka.json
ingress:
  - hostname: api.theedges.work
    service: http://127.0.0.1:4000
  - hostname: luka.theedges.work
    service: http://127.0.0.1:5173
  - service: http_status:404
```

Update the `credentials-file` path if your home directory differs.

## 5. Run boss-api and boss-ui locally

```bash
# Terminal 1 (API)
cd boss-api
HOST=127.0.0.1 PORT=4000 node server.cjs

# Terminal 2 (UI)
cd boss-ui
python3 -m http.server 5173
```

Ensure both services are reachable locally before proceeding.

## 6. Start the tunnel as a service

```bash
cloudflared service install
sudo launchctl start com.cloudflare.cloudflared
# or on Linux
sudo systemctl start cloudflared
```

This installs the tunnel as a background service that restarts automatically.

## 7. Enforce Zero Trust policies

In the Cloudflare Zero Trust dashboard:

1. Create an Access Application for `api.theedges.work` and `luka.theedges.work`.
2. Require sign-in via Google Workspace or enforce a PIN/one-time code policy.
3. Optionally restrict by IP ranges or device posture.

## 8. Validate remote access

1. From a remote device, browse to `https://luka.theedges.work` and authenticate.
2. The Luka UI should auto-detect the domain and call `https://api.theedges.work`.
3. Run the smoke tests locally to confirm the API behaves correctly:

```bash
bash run/smoke_api_ui.sh
```

## Troubleshooting
- **Tunnel fails to connect**: Verify `cloudflared` can reach ports 4000 and 5173 locally and that your firewall allows outbound connections.
- **UI cannot reach the API**: Ensure DNS records point to the tunnel and that HTTPS certificates are active in Cloudflare.
- **Authentication loops**: Double-check Zero Trust application policies and session durations.

With these steps completed, teammates can securely access the Luka control surface and API via the Cloudflare Tunnel endpoints.
