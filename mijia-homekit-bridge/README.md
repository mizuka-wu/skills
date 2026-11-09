# mijia-homekit-skill

> 把米家设备经 Home Assistant 桥进 Apple Home 的 **agent skill**：三方设备映射、HomeKit
> 150 accessory 上限治理、实体级白名单、bridge filter 安全修改、Apple/HA 双侧对账。

一个 `SKILL.md`，写给 AI agent（Hermes / Claude / Codex 等）执行，人类照着走也通。
所有内容来自一台真实 74 台米家设备的踩坑实录。

## 解决什么问题

`xiaomi_home` 官方集成会为每台米家设备生成一堆 MIoT 子属性实体（AI 检测、模式、童锁…），
桥进 HomeKit 会撞 **150 accessory 硬上限**：门锁、除湿机、扫地机被 100 多个噪音开关挤出局，
Home App 里只剩半套房子。本技能给出：

1. **三方映射**：米家 App ↔ HA 注册表 ↔ HomeKit filter 用米家 `did` 做 join，设备账本可复算
2. **150 定罪**：用 HA 日志 `would exceed the 150 device limit` 拿证据，不猜
3. **收敛口径**：实体级白名单（全收 light/cover/climate/fan/humidifier，switch 域整扔），
   实测 150 噪音 → 47 精锐
4. **安全改桥**：`.storage/core.config_entries` 的 stop→edit→start 流程与回滚代价表

## 依赖

- Home Assistant REST/WebSocket API + 长期令牌（或 [mcp-ha](https://github.com/arturslobo/mcp-ha)）
- HA 配置文件读写与重启权限（改 filter 时）
- 可选：[HomeClaw](https://github.com/brmzkk/homeclaw) MCP —— 直接读 Apple Home 实况对账

## 安装（Hermes）

```bash
# 克隆后把本目录放进 skills 目录
git clone https://github.com/mizuka-wu/mijia-homekit-skill.git
mkdir -p ~/.hermes/skills/home-automation/mijia-homekit-bridge
cp mijia-homekit-skill/SKILL.md ~/.hermes/skills/home-automation/mijia-homekit-bridge/
```

其他 agent：把 `SKILL.md` 内容塞进各自的项目规则/技能目录即可。

## 安全提醒

- HA 长期令牌只存本机环境变量或密钥管理器，**不要写进任何提交物**
- 米家账号走官方集成 OAuth 授权，不要用会保存明文账密的第三方代理
- 改 `core.config_entries` 前务必备份；HA 运行时改文件会被内存态覆盖，务必先停

## License

[MIT](LICENSE)
