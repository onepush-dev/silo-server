# Media server based on Silo, packaged for Railway

Self-hosted media streaming server (movies, shows, music, audiobooks, ebooks) built from the **official, unmodified Silo omnibus image** (`ghcr.io/silo-server/silo-server:build-2069`). Deploy on Railway with one click.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/_ki7HE)

> This is an unofficial community packaging. It is not made, endorsed or operated by the Silo team / Silo Media L.L.C. "Silo" is a trademark of Silo Media L.L.C. and is used here only to refer to the upstream project. Official sources: https://github.com/Silo-Server and https://siloserver.org.

## What you get

- One container running Silo with its bundled PostgreSQL 18 and Redis (s6 supervised), exactly as upstream ships them.
- A persistent Railway volume on `/config` (Silo state, database, Redis, artwork, plugins).
- **First-admin protection:** the public port stays closed (HTTP 503) until a small bootstrap step has created the administrator from per-deploy generated credentials, so nobody can claim first-run setup before you.
- Railway-safe defaults: no `NET_ADMIN`, TCP congestion/send-buffer tuning off, PostgreSQL tuned to a 2 GB budget.

## After deploy

1. Open the service's **Variables** tab and copy `SILO_ADMIN_PASSWORD`.
2. Sign in at your Railway domain as `admin` with that password, and change it in your profile.
3. Put media under `/config/media` (it is on the volume) and add it as a library in the admin UI, or point Silo at remote storage from its settings.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `SECRET_KEY` | generated (`secret(64)`) | Silo master key for at-rest credential encryption. Back it up; encrypted secrets cannot be recovered without it. |
| `SILO_ADMIN_PASSWORD` | generated | Password of the first administrator, created on first boot. |
| `SILO_ADMIN_USERNAME` | `admin` (image default) | Username of the first administrator. |
| `SILO_ADMIN_EMAIL` | `admin@example.com` (image default) | Email of the first administrator. |
| `POSTGRES_TUNE_MEMORY` | `2GB` (image default) | Memory budget for the bundled PostgreSQL auto-tuning. |
| `ENABLE_REDIS` | `true` (image default) | Bundled Redis (Watch Party rooms need it). |
| `ENABLE_MEILISEARCH` | `false` (image default) | Set `true` to start the bundled Meilisearch. |

## Notes

- Only the main web/API port is public. The Jellyfin-compatible (8096) and Audiobookshelf-compatible (13378) listeners run inside the container but are not exposed by Railway's single HTTP domain.
- Transcoding is software-only (no GPU on Railway). Size the service accordingly.
- How it works: `railway/entrypoint.sh` moves Silo to an internal port (8081); `railway/gate.js` (Node, already in the image) owns the public port 8080; `railway/bootstrap.sh` creates the admin through Silo's own `/api/v1/auth/setup` on loopback and then opens the gate.

## License

Silo is AGPL-3.0-or-later. This packaging adds only the files in this repository. Silo's source: https://github.com/Silo-Server/silo-server
