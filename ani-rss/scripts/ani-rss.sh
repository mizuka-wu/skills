#!/usr/bin/env bash
# ani-rss.sh — internal helper for the ani-rss Codex skill
set -eo pipefail

CONFIG_DIR="${ANI_RSS_CONFIG_DIR:-$HOME/.config/ani-rss}"
CONFIG_FILE="$CONFIG_DIR/config.json"

_ensure_config_dir() { mkdir -p "$CONFIG_DIR"; }

_read_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    cat "$CONFIG_FILE"
  else
    echo "{}"
  fi
}

_write_config() {
  _ensure_config_dir
  printf '%s\n' "$1" > "$CONFIG_FILE"
}

_get() {
  python3 -c "import sys,json;print(json.loads(sys.stdin.read()).get('$1',''))"
}

_set() {
  python3 -c "import sys,json;d=json.loads(sys.stdin.read());d['$1']='$2';print(json.dumps(d,indent=2))"
}

urlencode() {
  python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$1"
}

# ─── Core API call ────────────────────────────────────────────────────
api() {
  local path="$1"
  local method="${2:-POST}"
  local body="${3:-}"
  local params="${4:-}"

  local cfg
  cfg=$(_read_config)

  local base_url api_key tok
  base_url=$(echo "$cfg" | _get base_url)
  api_key=$(echo "$cfg" | _get api_key)
  tok=$(echo "$cfg" | _get token)

  [[ -n "${ANI_RSS_URL:-}" ]] && base_url="$ANI_RSS_URL"
  [[ -n "${ANI_RSS_API_KEY:-}" ]] && api_key="$ANI_RSS_API_KEY"

  if [[ -z "$base_url" ]]; then
    echo '{"error":"not configured","hint":"run: ani-rss.sh config set --url <url> --api-key <key>"}' >&2
    return 1
  fi

  local url="${base_url}${path}"
  [[ -n "$params" ]] && url="${url}?${params}"

  local curl_args=(-s -S -X "$method" -H "Content-Type: application/json")
  [[ -n "$api_key" ]] && curl_args+=(-H "x-api-key: $api_key")
  [[ -n "$tok" ]] && curl_args+=(-H "Authorization: $tok")
  [[ -n "$body" && "$method" != "GET" ]] && curl_args+=(-d "$body")

  local result
  if ! result=$(curl "${curl_args[@]}" "$url" 2>&1); then
    echo "{\"error\":\"request failed\"}" >&2
    return 1
  fi
  echo "$result"
}

# ─── Commands ─────────────────────────────────────────────────────────

cmd_config() {
  local subcmd="${1:-show}"
  shift 2>/dev/null || true
  case "$subcmd" in
    set)
      local cfg
      cfg=$(_read_config)
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --url)     cfg=$(echo "$cfg" | _set base_url "$2"); shift 2 ;;
          --api-key) cfg=$(echo "$cfg" | _set api_key "$2"); shift 2 ;;
          --token)   cfg=$(echo "$cfg" | _set token "$2"); shift 2 ;;
          *) shift ;;
        esac
      done
      _write_config "$cfg"
      echo '{"ok":true,"config_file":"'"$CONFIG_FILE"'"}'
      ;;
    show) _read_config ;;
    *)    echo '{"error":"unknown subcommand"}'; return 1 ;;
  esac
}

cmd_login() {
  local cfg username="" password=""
  cfg=$(_read_config)
  local base_url
  base_url=$(echo "$cfg" | _get base_url)

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --username) username="$2"; shift 2 ;;
      --password) password="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$username" || -z "$password" ]]; then
    echo '{"error":"--username and --password required"}' >&2
    return 1
  fi

  local md5_pass
  md5_pass=$(echo -n "$password" | md5 -q 2>/dev/null || echo -n "$password" | md5sum | cut -d' ' -f1)

  local result
  result=$(curl -s -S -X POST -H "Content-Type: application/json" \
    -d "{\"username\":\"${username}\",\"password\":\"${md5_pass}\"}" \
    "${base_url}/api/login")

  local new_token
  new_token=$(echo "$result" | python3 -c "import sys,json;print(json.load(sys.stdin).get('data',''))" 2>/dev/null || true)

  if [[ -n "$new_token" && "$new_token" != "None" && "$new_token" != "" ]]; then
    cfg=$(echo "$cfg" | _set token "$new_token")
    _write_config "$cfg"
    echo '{"ok":true,"message":"login successful"}'
  else
    echo "$result"
    return 1
  fi
}

cmd_ping()       { api "/api/ping" GET; }
cmd_list()       { api "/api/listAni" POST "{}"; }
cmd_about()      { api "/api/about" POST "{}"; }
cmd_logs()       { api "/api/logs" POST "{}"; }
cmd_clear_logs() { api "/api/clearLogs" POST "{}"; }
cmd_clear_cache(){ api "/api/clearCache" POST "{}"; }
cmd_me_bgm()     { api "/api/meBgm" POST "{}"; }
cmd_config_get() { api "/api/config" POST "{}"; }

cmd_config_set_server() {
  [[ -z "${1:-}" ]] && { echo '{"error":"JSON body required"}' >&2; return 1; }
  api "/api/setConfig" POST "$1"
}

cmd_add() {
  [[ -z "${1:-}" ]] && { echo '{"error":"JSON body required"}' >&2; return 1; }
  api "/api/addAni" POST "$1"
}

cmd_set() {
  [[ -z "${1:-}" ]] && { echo '{"error":"JSON body required"}' >&2; return 1; }
  api "/api/setAni" POST "$1"
}

cmd_delete() {
  api "/api/deleteAni" POST "${1}" "deleteFiles=${2:-false}"
}

cmd_refresh() {
  if [[ -n "${1:-}" ]]; then
    api "/api/refreshAni" POST "{\"id\":\"$1\"}"
  else
    api "/api/refreshAll" POST "{}"
  fi
}

cmd_preview() {
  [[ -z "${1:-}" ]] && { echo '{"error":"JSON body required"}' >&2; return 1; }
  api "/api/previewAni" POST "$1"
}

cmd_download_path() {
  [[ -z "${1:-}" ]] && { echo '{"error":"JSON body required"}' >&2; return 1; }
  api "/api/downloadPath" POST "$1"
}

cmd_enable()  { api "/api/batchEnable" POST "$1" "value=true"; }
cmd_disable() { api "/api/batchEnable" POST "$1" "value=false"; }

cmd_search_bgm() {
  local encoded
  encoded=$(urlencode "$1")
  api "/api/searchBgm" POST "" "name=$encoded"
}

cmd_bgm_to_ani() { api "/api/getAniBySubjectId" POST "" "id=$1"; }

cmd_bgm_title() {
  [[ -z "${1:-}" ]] && { echo '{"error":"JSON body required"}' >&2; return 1; }
  api "/api/getBgmTitle" POST "$1"
}

cmd_mikan() {
  local encoded
  encoded=$(urlencode "$1")
  api "/api/mikan" POST "${2:-{}}" "text=$encoded"
}

cmd_mikan_group() {
  local encoded
  encoded=$(urlencode "$1")
  api "/api/mikanGroup" POST "" "url=$encoded"
}

cmd_anime_garden()       { api "/api/animeGardenList" POST "{}" "bgmUrl=${1:-}"; }
cmd_anime_garden_group() { api "/api/animeGardenGroup" POST "" "bgmId=$1"; }
cmd_scrape()             { api "/api/batchScrape" POST "$1" "force=${2:-false}"; }
cmd_scrape_one()         { api "/api/scrape" POST "$1" "force=${2:-false}"; }
cmd_update_episodes()    { api "/api/updateTotalEpisodeNumber" POST "$1" "force=${2:-false}"; }

cmd_import() {
  [[ -z "${1:-}" ]] && { echo '{"error":"JSON body required"}' >&2; return 1; }
  api "/api/importAni" POST "$1"
}

cmd_test_notification() {
  [[ -z "${1:-}" ]] && { echo '{"error":"JSON body required"}' >&2; return 1; }
  api "/api/testNotification" POST "$1"
}

cmd_collection_preview() {
  [[ -z "${1:-}" ]] && { echo '{"error":"JSON body required"}' >&2; return 1; }
  api "/api/previewCollection" POST "$1"
}

cmd_collection_start() {
  [[ -z "${1:-}" ]] && { echo '{"error":"JSON body required"}' >&2; return 1; }
  api "/api/startCollection" POST "$1"
}

cmd_rate() {
  [[ -z "${1:-}" ]] && { echo '{"error":"JSON body required"}' >&2; return 1; }
  api "/api/rate" POST "$1"
}

cmd_set_rate() {
  [[ -z "${1:-}" ]] && { echo '{"error":"JSON body required"}' >&2; return 1; }
  api "/api/setRate" POST "$1"
}

cmd_about_update() { api "/api/update" POST "{}"; }

cmd_raw() {
  api "$1" "${2:-POST}" "${3:-}" "${4:-}"
}

# ─── Main ─────────────────────────────────────────────────────────────
main() {
  local cmd="${1:-help}"
  shift 2>/dev/null || true

  case "$cmd" in
    config)             cmd_config "$@" ;;
    login)              cmd_login "$@" ;;
    ping)               cmd_ping ;;
    list)               cmd_list ;;
    about)              cmd_about ;;
    logs)               cmd_logs ;;
    clear-logs)         cmd_clear_logs ;;
    clear-cache)        cmd_clear_cache ;;
    config-get)         cmd_config_get ;;
    config-set)         cmd_config_set_server "$@" ;;
    add)                cmd_add "$@" ;;
    set)                cmd_set "$@" ;;
    delete)             cmd_delete "$@" ;;
    refresh)            cmd_refresh "$@" ;;
    preview)            cmd_preview "$@" ;;
    download-path)      cmd_download_path "$@" ;;
    enable)             cmd_enable "$@" ;;
    disable)            cmd_disable "$@" ;;
    search-bgm)         cmd_search_bgm "$@" ;;
    bgm-to-ani)         cmd_bgm_to_ani "$@" ;;
    bgm-title)          cmd_bgm_title "$@" ;;
    me-bgm)             cmd_me_bgm ;;
    mikan)              cmd_mikan "$@" ;;
    mikan-group)        cmd_mikan_group "$@" ;;
    anime-garden)       cmd_anime_garden "$@" ;;
    anime-garden-group) cmd_anime_garden_group "$@" ;;
    scrape)             cmd_scrape "$@" ;;
    scrape-one)         cmd_scrape_one "$@" ;;
    import)             cmd_import "$@" ;;
    test-notification)  cmd_test_notification "$@" ;;
    update-episodes)    cmd_update_episodes "$@" ;;
    collection-preview) cmd_collection_preview "$@" ;;
    collection-start)   cmd_collection_start "$@" ;;
    rate)               cmd_rate "$@" ;;
    set-rate)           cmd_set_rate "$@" ;;
    about-update)       cmd_about_update ;;
    raw)                cmd_raw "$@" ;;
    help|*)
      cat <<'EOF'
Usage: ani-rss.sh <command> [args...]

Config:
  config set --url <url> --api-key <key>
  config show
  login --username <u> --password <p>

Subscriptions:
  list | add <json> | set <json> | delete <ids> [delFiles]
  refresh [id] | enable <ids> | disable <ids>
  preview <json> | download-path <json> | import <json>

Search:
  search-bgm <name> | bgm-to-ani <id> | bgm-title <json> | me-bgm
  mikan <text> [season] | mikan-group <url>
  anime-garden [bgmUrl] | anime-garden-group <bgmId>

Scrape:
  scrape <ids> [force] | scrape-one <json> [force]
  update-episodes <ids> [force]

Collection:
  collection-preview <json> | collection-start <json>

Rating:
  rate <json> | set-rate <json>

Server:
  ping | about | logs | clear-logs | clear-cache
  config-get | config-set <json> | test-notification <json>

Advanced:
  raw <path> [method] [body] [params]
EOF
      ;;
  esac
}

main "$@"
