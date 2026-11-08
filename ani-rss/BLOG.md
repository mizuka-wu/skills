---
title: "ani-rss-skill：AI 编程助手追番订阅管理技能"
date: "2026-09-13"
tags: ["ani-rss", "AI 编程", "技能", "追番", "自动化"]
categories: ["经验分享"]
summary: "通过 ani-rss API 管理自动追番订阅，支持 75+ 种 AI 编程工具（Codex、Claude Code、Cursor 等），自然语言控制番剧订阅、刷新、搜索。
---

# ani-rss-skill：AI 编程助手追番订阅管理技能

Codex / Claude Code / OpenCode / Cursor 通用 skill，通过 [ani-rss](https://github.com/wushuo894/ani-rss) API 管理自动追番订阅。

支持 75+ 种 AI 编程工具，由 [vercel-labs/skills](https://github.com/vercel-labs/skills) 驱动安装。

## 安装

### 方式一：npx skills（推荐）

```bash
# 安装到当前项目
npx skills add mizuka-wu/ani-rss-skill

# 全局安装（所有项目可用）
npx skills add mizuka-wu/ani-rss-skill -g

# 安装到指定 agent
npx skills add mizuka-wu/ani-rss-skill -a claude-code
npx skills add mizuka-wu/ani-rss-skill -a codex
npx skills add mizuka-wu/ani-rss-skill -a cursor

# 安装到多个 agent
npx skills add mizuka-wu/ani-rss-skill -a claude-code -a codex -a opencode
```

### 方式二：Agent 一键安装

直接告诉你的 AI agent：

> Install the skill from github.com/mizuka-wu/ani-rss-skill

或中文：

> 帮我安装 github.com/mizuka-wu/ani-rss-skill 这个 skill

### 方式三：手动安装

```bash
git clone https://github.com/mizuka-wu/ani-rss-skill.git ~/.codex/skills/ani-rss
# 或 Claude Code: ~/.claude/skills/ani-rss
# 或 OpenCode: ~/.opencode/skills/ani-rss
```

## 配置

安装后需要配置服务器地址和认证：

```bash
# API Key 认证（推荐）
bash scripts/ani-rss.sh config set --url http://your-nas-ip:7789 --api-key your-api-key

# 或用户名密码认证
bash scripts/ani-rss.sh config set --url http://your-nas-ip:7789
bash scripts/ani-rss.sh login --username admin --password your-password
```

| 项目 | 说明 |
|------|------|
| 默认端口 | **7789**（Docker 默认） |
| 配置文件 | `~/.config/ani-rss/config.json` |
| 环境变量 | `ANI_RSS_URL`、`ANI_RSS_API_KEY` |
| API Key | 在 ani-rss 管理后台 → 设置 → API Key 获取 |

## 使用

安装后直接用自然语言和你的 AI agent 对话即可：

- "帮我看看现在有哪些订阅"
- "搜索孤独摇滚，添加第一季的订阅"
- "刷新所有 RSS"
- "禁用这几个订阅"
- "看看最近的日志"
- "服务器版本是多少"

## 认证方式

| 方式 | 说明 | 推荐 |
|------|------|------|
| API Key | `x-api-key` 请求头，无过期 | ✅ |
| JWT | 用户名密码登录获取 token，有过期时间 | 需要时重新登录 |

## 支持的 Agent

通过 [npx skills](https://github.com/vercel-labs/skills) 支持以下 agent：

Codex, Claude Code, OpenCode, Cursor, Windsurf, Aider, Cline, Roo Code, Continue, Cody, PearAI, Void, Trae, Firebase Studio, IDX, Replit, Amazon Q, GitHub Copilot, JetBrains AI, Tabnine, Sourcegraph, AskCodi, Codeium, Supermaven, Refact, DeepSeek, MarsCode, Zed, Blackbox, Qodo, Mutable, Fig, Warp, Hyper, iTerm2, Kitty, Alacritty, Ghostty, Rio, WezTerm, 苕皮匠，豆包，通义灵码，文心快码，商汤代码小浣熊，CodeGeeX, Comate, Tongyi Lingma, Baidu Comate, Sensei Copilot, CodeWhisperer, and [more](https://github.com/vercel-labs/skills#supported-agents).

## 命令一览

```bash
# 配置
config set --url <url> --api-key <key>
config show
login --username <u> --password <p>

# 订阅
list | add <json> | set <json> | delete <ids> [delFiles]
refresh [id] | enable <ids> | disable <ids>
preview <json> | download-path <json> | import <json>

# 搜索
search-bgm <name> | bgm-to-ani <id> | me-bgm
mikan <text> | mikan-group <url>
anime-garden [bgmUrl] | anime-garden-group <bgmId>

# 刮削
scrape <ids> [force] | scrape-one <json> [force]
update-episodes <ids> [force]

# 合集 & 评分
collection-preview <json> | collection-start <json>
rate <json> | set-rate <json>

# 服务器
ping | about | logs | clear-logs | clear-cache
config-get | config-set <json> | test-notification <json>

# 高级
raw <path> [method] [body] [params]
```

## 项目结构

```
ani-rss-skill/
├── SKILL.md              # Skill 定义
├── agents/openai.yaml    # Codex UI 元数据
├── scripts/ani-rss.sh    # API 调用脚本
└── README.md
```

## 使用示例

### 搜索番剧

```bash
bash scripts/ani-rss.sh search-bgm "孤独摇滚"
bash scripts/ani-rss.sh mikan "孤独摇滚"
```

### 添加订阅

1. Search BGM: `bash scripts/ani-rss.sh search-bgm "<name>"`
2. Get Ani object: `bash scripts/ani-rss.sh bgm-to-ani <subject-id>`
3. Modify as needed, then add: `bash scripts/ani-rss.sh add '<json>'`

### 管理订阅

```bash
bash scripts/ani-rss.sh list
bash scripts/ani-rss.sh refresh            # all
bash scripts/ani-rss.sh refresh <id>       # one
bash scripts/ani-rss.sh enable '[\"id1\"]'
bash scripts/ani-rss.sh disable '[\"id1\"]'
bash scripts/ani-rss.sh delete '[\"id1\"]' true
bash scripts/ani-rss.sh set '{\"id\":\"xxx\",...}'
```

### 服务器状态

```bash
bash scripts/ani-rss.sh ping
bash scripts/ani-rss.sh about
bash scripts/ani-rss.sh config-get
bash scripts/ani-rss.sh logs
bash scripts/ani-rss.sh clear-cache
```

## Support

如果这个 skill 对你有帮助，可以请我喝杯咖啡 ☕

[buymeacoffee.com/mizukawu](https://buymeacoffee.com/mizukawu)

## License

MIT

---

项目地址：https://github.com/mizuka-wu/ani-rss-skill
