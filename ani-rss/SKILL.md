---
name: ani-rss
description: "Manage anime RSS subscriptions via ani-rss. Use when the user wants to list, add, delete, search, or manage anime subscriptions, or interact with an ani-rss server. Works with Codex, Claude Code, OpenCode, Cursor, and 75+ agents."
---

# Ani RSS

Manage anime subscriptions via [ani-rss](https://github.com/wushuo894/ani-rss) API.

## Setup

Configure the server URL and auth:

```bash
# API key (recommended)
bash scripts/ani-rss.sh config set --url http://your-host:7789 --api-key <key>

# Or JWT login
bash scripts/ani-rss.sh config set --url http://your-host:7789
bash scripts/ani-rss.sh login --username admin --password <password>
```

Config saved to `~/.config/ani-rss/config.json`. Override with `ANI_RSS_URL` / `ANI_RSS_API_KEY` env vars.

Default port: **7789** (Docker default). API Key is in the web UI → Settings → API Key.

## Script

All interactions go through `scripts/ani-rss.sh` (relative to this skill directory). Output is JSON. Errors to stderr, non-zero exit on failure.

## Workflow

### Browse & search

```bash
bash scripts/ani-rss.sh list
bash scripts/ani-rss.sh search-bgm "孤独摇滚"
bash scripts/ani-rss.sh bgm-to-ani 395855
bash scripts/ani-rss.sh mikan "孤独摇滚"
bash scripts/ani-rss.sh mikan-group "https://mikanani.me/Bangumi/xxx"
```

### Add subscription

1. Search BGM: `bash scripts/ani-rss.sh search-bgm "<name>"`
2. Get Ani object: `bash scripts/ani-rss.sh bgm-to-ani <subject-id>`
3. Modify as needed, then add: `bash scripts/ani-rss.sh add '<json>'`

Or from RSS URL:
```bash
bash scripts/ani-rss.sh add '{"url":"https://mikanime.tv/RSS/Bangumi?bangumiId=123&subgroupid=456","title":"Example"}'
```

### Manage

```bash
bash scripts/ani-rss.sh list
bash scripts/ani-rss.sh refresh            # all
bash scripts/ani-rss.sh refresh <id>       # one
bash scripts/ani-rss.sh enable '["id1"]'
bash scripts/ani-rss.sh disable '["id1"]'
bash scripts/ani-rss.sh delete '["id1"]' true
bash scripts/ani-rss.sh set '{"id":"xxx",...}'
```

### Server

```bash
bash scripts/ani-rss.sh ping
bash scripts/ani-rss.sh about
bash scripts/ani-rss.sh config-get
bash scripts/ani-rss.sh logs
bash scripts/ani-rss.sh clear-cache
```

### Raw API

```bash
bash scripts/ani-rss.sh raw /endpoint POST '{"k":"v"}' "param=val"
```

## Auth

| Method | Header | Notes |
|--------|--------|-------|
| API Key | `x-api-key` | Recommended, no expiry |
| JWT | `Authorization` | Login via `/api/login`, password is MD5 |

## API reference

All endpoints prefixed with `/api`. Default port: 7789.

| Endpoint | Description |
|----------|-------------|
| `GET /api/ping` | Health check |
| `POST /api/login` | Login (body: `{username, password}`) |
| `POST /api/listAni` | List subscriptions |
| `POST /api/addAni` | Add subscription |
| `POST /api/setAni` | Update subscription |
| `POST /api/deleteAni` | Delete (body: ids[], ?deleteFiles) |
| `POST /api/refreshAll` | Refresh all RSS |
| `POST /api/refreshAni` | Refresh one (body: {id}) |
| `POST /api/batchEnable` | Enable/disable (body: ids[], ?value) |
| `POST /api/searchBgm?name=` | Search Bangumi |
| `POST /api/getAniBySubjectId?id=` | BGM → Ani |
| `POST /api/config` | Get server config |
| `POST /api/setConfig` | Update config |
| `POST /api/scrape` | Scrape metadata |
| `POST /api/logs` | Get logs |
| `POST /api/about` | Version info |
| `POST /api/mikan?text=` | Search Mikan |
| `POST /api/animeGardenList` | AnimeGarden list |
