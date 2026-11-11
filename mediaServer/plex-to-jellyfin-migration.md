# Plex → Jellyfin Migration: Quadlet Breakdown

## Files Created

| File | Purpose |
|------|---------|
| [`jellyfin.container`](file:///c:/Users/brett/OneDrive/Documents/workspace/Home_Server/mediaServer/jellyFin/jellyfin.container) | Main container unit |
| [`jellyfin-config.volume`](file:///c:/Users/brett/OneDrive/Documents/workspace/Home_Server/mediaServer/jellyFin/jellyfin-config.volume) | Config/metadata persistent volume |
| [`jellyfin-cache.volume`](file:///c:/Users/brett/OneDrive/Documents/workspace/Home_Server/mediaServer/jellyFin/jellyfin-cache.volume) | Transcoding cache persistent volume |

---

## Deltas Between Plex and Jellyfin

### 1. Container Image — No More LinuxServer.io

| | Plex | Jellyfin |
|---|---|---|
| **Image** | `lscr.io/linuxserver/plex:latest` | `docker.io/jellyfin/jellyfin:latest` |
| **Maintainer** | LinuxServer.io (community wrapper) | Jellyfin project (official) |

Plex used the LinuxServer.io wrapper image, which adds a custom init system (s6-overlay) and the `PUID`/`PGID` environment variables to remap the internal user. **Jellyfin's official image does not have this.** The container runs as an internal user (UID 1000 by default). This means:

- `PUID` and `PGID` environment variables are **removed** — they'd do nothing.
- Your media bind mount (`/home/admin/media`) must be readable by the container's internal UID. Since the mount is `:ro`, this is usually fine, but if you hit permission errors you may need to either:
  - Add `--user=$(id -u):$(id -g)` to `PodmanArgs`, or
  - Use the LinuxServer.io Jellyfin image instead (`lscr.io/linuxserver/jellyfin:latest`), which supports `PUID`/`PGID` just like your Plex setup.

### 2. Environment Variables

| Variable | Plex | Jellyfin | Notes |
|----------|------|----------|-------|
| `PUID` | `0` | ❌ Removed | Not supported by official image |
| `PGID` | `0` | ❌ Removed | Not supported by official image |
| `TZ` | `America/Halifax` | `America/Halifax` | Same — sets log/schedule timezone |
| `VERSION` | `docker` | ❌ Removed | LinuxServer.io-specific; told the wrapper how to update |
| `PLEX_CLAIM` | `<claim token>` | ❌ Removed | Plex-specific auth; Jellyfin has no external claim system |

> [!NOTE]
> Jellyfin has **no cloud account requirement**. On first launch, you set up a local admin account via the web UI at `http://<host>:8096`. There is no claim token, no Plex account, no phone-home requirement.

### 3. Volumes — Two Instead of One

| | Plex | Jellyfin |
|---|---|---|
| **Config** | `plex-config.volume:/config` | `jellyfin-config.volume:/config` |
| **Cache** | *(stored inside `/config`)* | `jellyfin-cache.volume:/cache` |
| **Media** | `/home/admin/media:/media:ro,z` | `/home/admin/media:/media:ro,z` |

Jellyfin separates its **cache** (transcoder temp files, image thumbnail caches) from its **config** (database, user settings, plugins). This is a best practice because:
- You can back up `/config` without including gigabytes of throwaway transcoder artifacts.
- You can wipe the cache volume to reclaim disk space without losing settings.

### 4. Network — Same Approach, Different Ports

Both use `Network=host` for local discovery (DLNA/SSDP). The port difference:

| | Plex | Jellyfin |
|---|---|---|
| **Web UI (HTTP)** | `32400` | `8096` |
| **Web UI (HTTPS)** | N/A (handled internally) | `8920` |
| **Discovery** | GDM (port 32410-32414) | DLNA/SSDP (port 1900) |

After starting the container, access Jellyfin at: **`http://<your-server-ip>:8096`**

### 5. Hardware Transcoding — VAAPI vs QuickSync

The `PodmanArgs` line is identical (`--device=/dev/dri:/dev/dri`), but the underlying codec path differs:

| | Plex | Jellyfin |
|---|---|---|
| **API** | Intel QuickSync (via Plex's own transcoder) | **VAAPI** (VA-API Linux standard) |
| **Device** | `/dev/dri` | `/dev/dri` |
| **Setup** | Requires Plex Pass subscription | **Free** — no subscription needed |

> [!IMPORTANT]
> After first boot, you must enable hardware acceleration in the Jellyfin dashboard:
> **Dashboard → Playback → Transcoding → Hardware acceleration = VAAPI**
> and set the device to `/dev/dri/renderD128`.

Your comment about the i5-12400F lacking QuickSync still applies — you're relying on whatever GPU/iGPU is providing `/dev/dri` on the hypervisor. If this is a dedicated GPU (e.g., an NVIDIA card), you'd need the NVIDIA container toolkit instead of `/dev/dri` passthrough.

### 6. Licensing & Features

| | Plex | Jellyfin |
|---|---|---|
| **License** | Proprietary (freemium) | **GPLv2 (fully open source)** |
| **HW Transcode** | Requires Plex Pass (\$5/mo or \$120 lifetime) | **Free** |
| **Remote Access** | Built-in relay servers | Manual (reverse proxy / VPN) |
| **Live TV/DVR** | Plex Pass required | **Free** |
| **Mobile Apps** | Free (with ads) or Plex Pass | **Free** (no ads, ever) |
| **Plugins** | Limited, curated | **Open plugin system** |
| **Skip Intro** | Plex Pass | Community plugin (free) |

> [!WARNING]
> Jellyfin does **not** have Plex's built-in remote relay. If you access your media outside your LAN, you'll need to set up a **reverse proxy** (e.g., Caddy, Nginx, Traefik) and handle your own DNS/TLS. This is the biggest operational difference.

---

## What Stayed the Same

These sections are **identical** between your Plex and Jellyfin quadlet files:

- **`[Unit]`** — Same `After=` / `Wants=` pattern for `network-online.target`
- **`[Service]`** — Same restart policy (`on-failure`), cooldown (`10s`), and startup timeout (`300s`)
- **`[Install]`** — Same `WantedBy=default.target` for autostart with lingering
- **Media mount** — Same path, same `:ro,z` flags
- **Host networking** — Same `Network=host`
- **Resource limits** — Same `--memory 4g` and `--device=/dev/dri:/dev/dri`

---

## Next Steps

1. **Copy the quadlet files** to your server's `~/.config/containers/systemd/` directory
2. Run `systemctl --user daemon-reload` to pick up the new units
3. Run `systemctl --user start jellyfin` to launch
4. Open `http://<server-ip>:8096` and complete the initial setup wizard
5. Enable VAAPI hardware transcoding in the dashboard
6. Point your media libraries at `/media`
