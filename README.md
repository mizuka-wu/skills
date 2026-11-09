# skills

我的公开 [Hermes](https://hermes-agent.nousresearch.com/) agent skills 合集，每个目录一个技能
（`<skill-name>/SKILL.md` + 附带脚本），全部经过真实环境实战与脱敏审查。

| 技能 | 用途 |
|---|---|
| [ani-rss](ani-rss/) | AniRSS 追番订阅管理（CLI + AI 工作流） |
| [mijia-homekit-bridge](mijia-homekit-bridge/) | 米家设备经 Home Assistant 桥进 Apple Home，HomeKit 150 上限治理 |
| [xiaomi-nas-root-ssh](xiaomi-nas-root-ssh/) | 小米 NAS（MINAS）root/SSH/Docker 应用运维 |

## 安装

```bash
git clone https://github.com/mizuka-wu/skills.git
# Hermes：把需要的技能目录整个拷进 ~/.hermes/skills/<类别>/ 下
cp -r skills/ani-rss ~/.hermes/skills/devops/
```

其他 agent 框架：把对应 `SKILL.md` 塞进各自的项目规则/技能位置即可，附带的
`scripts/` 保持相对路径。

## 约定

- 每个技能自包含：SKILL.md（frontmatter 的 `name` = 目录名）+ `scripts/` / `references/`
- 技能都是**先实战后成文**：里面每条命令都在真机跑过
- 公开版与个人版分离：个人环境细节在私有仓，这里只有可复用的通用部分

## License

各技能自带 LICENSE 时无授权冲突（MIT）；未单独声明的技能默认 MIT。
