# Deploy agentmemory on Coolify

[Coolify](https://coolify.io/self-hosted) is an open-source, self-hosted
Heroku/Render alternative that you run on your own VPS. This template
deploys agentmemory as a Coolify *Application* backed by a Docker
Compose stack — Coolify handles TLS termination, persistent volume
provisioning, log aggregation, and the deploy webhook for you.

## What you get

- A public HTTPS endpoint serving the agentmemory REST API behind
  Coolify's built-in Traefik/Caddy proxy.
- An optional second public HTTPS endpoint for the **Viewer** (Web UI)
  on a separate domain — the viewer binds `0.0.0.0:3113` with bearer-auth
  and Host-header protection so Coolify's proxy can reach it.
- A persistent Docker volume backing `/data` for memories, BM25 index,
  and stream backlog. Coolify auto-prefixes the volume name with the
  application's UUID so the data survives redeploys.
- An HTTP health-check at `/agentmemory/livez` declared in the
  Dockerfile (`HEALTHCHECK` directive). Coolify reuses it for
  rolling-deploy decisions.

## One-time setup

1. **Open your Coolify dashboard** and click **+ New → Application**.
2. **Source**: pick *Public Repository*. Paste:
   ```
   https://github.com/rohitg00/agentmemory
   ```
   Branch: `main`.
3. **Build Pack**: select *Docker Compose*.
4. **Base Directory**: `deploy/coolify`
5. **Compose Path**: `docker-compose.yml`
6. Click **Save**.

### Configure the REST API domain

On the application settings screen, in the **Domains** section, add:

- **Domain**: `https://memory.domain.com.br:3111`

  The `:3111` suffix tells Coolify's proxy which container port to
  forward to; it still serves over 443/80 publicly.

7. Click **Deploy**.

Wait for the first deploy to finish before configuring the viewer
domain (the viewer needs the HMAC secret to be generated).

### Capture the HMAC secret

Once the deploy logs show the service is up, open the application's
**Logs** tab in Coolify and search for `AGENTMEMORY_SECRET=`. You will
see exactly one line of the form `AGENTMEMORY_SECRET=<64 hex chars>`.
Copy it into your client environment (`~/.bashrc`, Claude Desktop
config, etc.). The secret is never printed again on subsequent boots.

### Configure the Viewer domain

1. In the Coolify dashboard, open your **agentmemory** application.
2. Go to the **Domains** section and add a second domain:
   - **Domain**: `https://viewer.memory.domain.com.br:3113`

   The `:3113` suffix tells Coolify's proxy to route traffic for this
   domain to the container's internal port 3113 (the viewer).
3. Go to the **Environment Variables** tab and add **two** variables:

   | Key | Value | Type |
   |-----|-------|------|
   | `AGENTMEMORY_FQDN` | `memory.domain.com.br` | `literal` |
   | `VIEWER_FQDN` | `viewer.memory.domain.com.br` | `literal` |

   These replace the built-in `SERVICE_FQDN_*` variables, which Coolify
   generates once and never updates when you change domains later.
4. Click **Save** and **Redeploy**.

After redeploy, the viewer is ready at `https://viewer.memory.domain.com.br`.
Open it in a browser — the viewer HTML loads immediately. The UI will
prompt you for the HMAC secret (the same `AGENTMEMORY_SECRET` you captured
earlier) when it makes authenticated API calls.

> **How it works under the hood:** The docker-compose.yml sets
> `AGENTMEMORY_VIEWER_HOST=0.0.0.0`, which makes the viewer listen on
> all interfaces instead of just `127.0.0.1`. When the viewer binds to a
> non-loopback address, it automatically requires:
> 1. `AGENTMEMORY_SECRET` to be set (generated on first boot)
> 2. `VIEWER_ALLOWED_HOSTS` to be explicitly configured (set from
>    `VIEWER_FQDN` env var)
>
> Every proxied API request through the viewer must present
> `Authorization: Bearer <secret>`. Static HTML and the favicon are
> served unauthenticated. The browser JS handles the bearer prompt
> automatically. This is the same architecture used by the Fly.io
> deployment template.

> **Why `VIEWER_FQDN` is needed:** Coolify's Traefik proxy terminates
> TLS and then forwards HTTP to the container. When it does so, it
> strips the port from the `Host` header. The viewer receives
> `Host: viewer.memory.domain.com.br` (no `:3113`). Without the bare
> domain in `VIEWER_ALLOWED_HOSTS`, every request would get
> `403 forbidden host`. We also include `viewer.memory.domain.com.br:3113`
> (from `${VIEWER_FQDN}:3113`) for direct port-based access.

> **Why not `SERVICE_FQDN_*`?** Coolify generates `SERVICE_FQDN_*`
> automatically when you first add a domain, but **never updates them**
> if you change the domain later. The UI also doesn't let you edit or
> delete them. By using `AGENTMEMORY_FQDN` and `VIEWER_FQDN` instead,
> you keep full control of the values.

## Verify the deployment

```bash
# REST API (MCP)
curl "https://memory.domain.com.br/agentmemory/livez"
# {"status":"ok"}

# Viewer — should return HTML
curl -s "https://viewer.memory.domain.com.br/" | head -5
# <!DOCTYPE html><html ...
```

For authenticated calls, your client must send
`Authorization: Bearer <secret>`.

## Viewer security model

The viewer is protected by four layers when exposed to the network:

1. **HTTP Basic Auth** — Traefik middleware requiring a username and
   password before the request reaches the viewer (applies to **both**
   the Viewer domain and the REST API domain). Default credentials:
   `admin` / `pass`. Change the password hash in
   `docker-compose.yml` (see instructions there).
2. **Host-header allowlisting** — `VIEWER_ALLOWED_HOSTS` only accepts
   requests where the `Host` header matches the configured domain.
   This prevents DNS-rebinding attacks.
3. **Bearer authentication** — Every proxied API request must include
   `Authorization: Bearer <AGENTMEMORY_SECRET>`. The browser UI prompts
   for it on first 401 response.
4. **Origin-based CORS** — `VIEWER_ALLOWED_ORIGINS` restricts which
   origins can make cross-origin requests to the viewer.

Since Basic Auth protects both domains, your MCP client must include
the credentials in the URL:

```bash
# MCP client config
AGENTMEMORY_URL=https://admin:pass@memory.domain.com.br
```

Or use the `--secret` flag with the full URL:

```bash
AGENTMEMORY_URL=https://admin:pass@memory.domain.com.br \
AGENTMEMORY_SECRET=<hmac-secret> \
npx @agentmemory/mcp
```

The browser viewer handles Basic Auth transparently — once you log in,
the browser sends the credentials with every request, including the
JavaScript fetch calls to the API.

To change the Basic Auth password, generate a new hash:

```bash
openssl passwd -apr1 <new-password>
```

Then replace the `viewer-auth.basicauth.users` label in
`docker-compose.yml` with the new hash, remembering to double every
`$` → `$$` for Docker Compose escaping.

## Environment variables reference

Set these in Coolify's **Environment Variables** tab (all `literal` type):

| Key | Value | Purpose |
|-----|-------|---------|
| `AGENTMEMORY_FQDN` | `memory.domain.com.br` | REST API domain (no port) |
| `VIEWER_FQDN` | `viewer.memory.domain.com.br` | Viewer domain (no port) |

These are used by `docker-compose.yml` for `VIEWER_ALLOWED_HOSTS` and
`VIEWER_ALLOWED_ORIGINS`. They replace the built-in `SERVICE_FQDN_*`
variables, which Coolify generates once and never updates.

> **Note:** `COOLIFY_NETWORK` is injected automatically by Coolify — you
> don't need to set it. `AGENTMEMORY_SECRET` is generated on first boot
> and persisted to `/data/.hmac` — you don't set it either.

## Viewer access (port 3113 stays internal)

The viewer port is exposed exclusively through the Coolify proxy — it
is never bound to the host network. There are two additional ways to
reach it if needed:

**Option A — SSH tunnel from the Coolify host.** Coolify gives you SSH
access to the underlying VPS. From your laptop:

```bash
ssh -L 3113:127.0.0.1:3113 <user>@<coolify-host>
# inside the SSH session, find the container:
docker ps --filter name=agentmemory --format "{{.Names}}"
# tunnel into the container's port from the host:
docker exec -it <container-name> sh -c "curl http://localhost:3113"
```

Cleaner version: bind the container's 3113 to the host's loopback by
adding `- "127.0.0.1:3113:3113"` to the `ports:` block in
`docker-compose.yml`, redeploy, then `ssh -L 3113:127.0.0.1:3113
<user>@<host>` is enough.

**Option B — expose 3113 as a second Coolify domain protected by HTTP
basic auth.** Coolify's per-service routing supports adding a second
public endpoint with basic-auth middleware. Useful if you want to
share the viewer with a teammate without giving them SSH.

## Rotate the HMAC secret

```bash
ssh <user>@<coolify-host>
docker exec -it <container-name> sh -c "rm /data/.hmac"
exit
```

Then click **Redeploy** in the Coolify dashboard. The next boot prints
a fresh secret to the logs.

## Back up `/data`

Coolify exposes the named volume on the host filesystem under
`/var/lib/docker/volumes/<project-id>_agentmemory-data/_data`. Back it
up with your existing host-level snapshot tooling (Restic, Borg,
`rsync`, BTRFS snapshots, etc.) or via Coolify's built-in *Backups*
feature for Docker volumes.

## Cost floor and resources

- **Hardware**: the agentmemory container idles at ~150 MB RSS, climbs
  to ~400 MB under steady traffic. The bundled iii engine adds another
  ~80 MB. A 1 vCPU / 1 GB VPS is comfortably enough for a personal
  install.
- **VPS providers commonly paired with Coolify**: Hetzner CX22
  (~€3.79/month), DigitalOcean Basic Droplet ($6/month), Vultr Cloud
  Compute ($6/month). Coolify itself is free.
- **Volume storage**: tied to whatever block storage the VPS provides;
  typically pennies per GB-month.

## Known caveats

- The Dockerfile builds on the Coolify host on every deploy. First
  deploy takes ~2 minutes; cached layers shrink subsequent rebuilds to
  under 30 seconds. Pin `AGENTMEMORY_VERSION` and `III_VERSION` in
  `docker-compose.yml`'s `build.args` block to lock a specific release.
- Coolify's *Persistent Storage* tab will show `agentmemory-data` as a
  managed volume — do not delete it from the dashboard if you want
  your memories to survive a redeploy.
- arm64 hosts work — the iii binary selection in the Dockerfile uses
  `uname -m` and downloads the matching tarball.
