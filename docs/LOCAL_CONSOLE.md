# Local OpenRouter-Style Console

The repository ships with a lightweight web console (`run/local_ui_server.cjs`) and
supporting assets under `public/` that mimic the OpenRouter model selector and
function runner. Use this guide to launch it locally and optionally expose it on
your own domain.

## Prerequisites

- **Node.js 18+** for the HTTP server.
- **Python 3.9+** for `agent_router.py` and any skills it invokes.
- (Optional) `npm` for installing dependencies declared in `package.json`.

Install Node and Python using your preferred method (Homebrew, asdf, system
packages, etc.).

## 1. Populate Model and Function Metadata

Two JSON files define what the UI renders:

- `config/ui_models.json` &mdash; the available models with labels and capability
  badges.
- `config/ui_functions.json` &mdash; the functions that map to intents handled by
  `agent_router.py`.

Update these files to match the models you want to surface and the intents that
exist in `config/intent_map.yaml` (or `config/intent_map.json`).

## 2. Start the Automation Backend

The UI posts requests to `agent_router.py`, so ensure the intents you expose
resolve to runnable skills.

```bash
# (Optional) Launch the Boss API stub used by the status indicator
node run/boss_api_stub.cjs

# In a separate terminal, start the UI server
node run/local_ui_server.cjs
```

Key environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `PORT` | `5173` | Port the web UI listens on. |
| `HOST` | `0.0.0.0` | Bind address for the HTTP server. |
| `BOSS_STUB_URL` | `http://localhost:4000/api/status` | Endpoint the status pill polls. |

The server logs the URLs it exposes. Navigate to `http://localhost:5173/` to
load the console. Selecting a model and function, entering a prompt, and
submitting will invoke the mapped intent via `agent_router.py`.

## 3. Wiring to `www.theedges.work`

1. **Host the UI Server**: Deploy the repository (or at least the `run/`,
   `public/`, `config/`, `agent_router.py`, and `skills/` directories) on a VM or
   container reachable from the public internet. Run `node run/local_ui_server.cjs`
   with a process manager (systemd, PM2, Docker, etc.) and bind it to an
   internal port such as `5173`.
2. **Configure DNS**: Point `www.theedges.work` to the public IP of your host by
   creating an `A` record with your domain registrar or DNS provider.
3. **Add a Reverse Proxy**: Use Nginx, Caddy, or Apache to terminate TLS and
   forward traffic from port 80/443 to the Node server. Example Nginx server
   block:

   ```nginx
   server {
     listen 80;
     server_name www.theedges.work;
     return 301 https://$host$request_uri;
   }

   server {
     listen 443 ssl;
     server_name www.theedges.work;

     ssl_certificate /etc/letsencrypt/live/www.theedges.work/fullchain.pem;
     ssl_certificate_key /etc/letsencrypt/live/www.theedges.work/privkey.pem;

     location / {
       proxy_pass http://127.0.0.1:5173;
       proxy_http_version 1.1;
       proxy_set_header Host $host;
       proxy_set_header X-Real-IP $remote_addr;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       proxy_set_header X-Forwarded-Proto $scheme;
     }
   }
   ```

   Use Certbot or another ACME client to obtain TLS certificates before enabling
   the HTTPS block.
4. **Harden Access**: Because the console can trigger automation, consider
   protecting it with HTTP basic auth, VPN access, an allow-list, or an identity
   proxy such as Cloudflare Access.

Once DNS propagates and the proxy is running, visiting
`https://www.theedges.work/` should load the OpenRouter-style console served by
`run/local_ui_server.cjs`.

## 4. Troubleshooting

- **Empty dropdowns**: Verify `config/ui_models.json` and
  `config/ui_functions.json` contain valid JSON and that the server process has
  permission to read them.
- **Execution errors**: Check the console output where the UI server is running
  for stack traces originating from `agent_router.py`.
- **Status pill shows “Disconnected”**: Ensure `BOSS_STUB_URL` points to a
  reachable service returning JSON.

For deeper automation debugging, consult `agent_router.py` and the skill files
under `skills/` to confirm the intents and scripts referenced in
`config/intent_map.yaml` exist and are executable.
