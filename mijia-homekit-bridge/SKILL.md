---
name: mijia-homekit-bridge
description: 把米家(Mijia)设备经 Home Assistant 桥接进 Apple Home 并治理 HomeKit 150 accessory 上限：三方设备映射、实体级白名单、bridge filter 安全修改、Apple/HA 双侧对账、Home App 批量分房(homeclaw-cli)。依赖 Home Assistant REST/WebSocket API（长期令牌）或 mcp-ha，可选 HomeClaw（MCP 读实况，CLI 兼管理员写）。Use when 米家设备要进苹果家庭、HomeKit 桥缺设备/超 150、重配 homekit 桥暴露范围、批量整理 accessory 房间归属、或做米家↔HA↔HomeKit 设备对账。
---

# 米家 → Home Assistant → Apple Home 桥接治理

米家设备经 HA（`xiaomi_home` 官方云集成 + `xiaomi_miot`）暴露进 Apple Home 的完整工作流。
核心矛盾：`xiaomi_home` 会为每台米家设备生成大量 MIoT 子属性实体（switch 域 90% 是
AI 检测/模式/童锁这类功能开关），桥进 HomeKit 会撞上 **150 accessory 硬上限**并挤掉
门锁/扫地机等真正要控的设备。本技能给出可复算的映射方法与收敛口径。

## 依赖（任选其一读侧，改 filter 需 HA 文件/重启权限）

| 层 | 必需 | 用途 |
|---|---|---|
| Home Assistant REST/WebSocket API + 长期令牌 | ✅ | 实体/设备/注册表全量读（`GET /api/states`、`/api/config/entity_registry`、`/api/config/device_registry`）、area 写（仅 WS `area_registry/update`） |
| 或 mcp-ha（`homeassistant` 源） | 等价 | `render_template` / `GetLiveContext`（注意：只见已曝光实体）/ `config` 只读 |
| HomeClaw（可选，Apple Home 侧真相 + 管理员写） | 可选 | MCP 5 工具只读实况（`homekit_status/accessories/device_map/rooms/events`）；**CLI 有管理员写权限**（批量分房/改名/场景，见「批量分房」）；没有它就用 Home App 截图/抽查对账 |
| HA 配置文件读写 + 容器重启 | ✅（改桥时） | filter 落盘在 `.storage/core.config_entries` |

安全：长期令牌只存本机（Keychain/env），不进任何提交物；米家账号 OAuth 走集成官方流程，
不要代理转发。

## 三方映射（米家 ↔ HA ↔ Apple）

join 键是**米家 did**，三处同值可对齐：

```
米家 App 视角   : HA config 目录 xiaomi_home/miot_devices/<uid>_cn.dict   # did -> name/room/home（本地缓存=米家 App 所见）
HA 设备         : device_registry, identifiers = ["xiaomi_home", "cn_<did>"]   # ⚠ did 带 cn_ 前缀
HA 实体         : entity_registry.device_id -> entity_id
HomeKit 侧      : 桥 access_filter.include_entities（写入的实体级名单）
                 + Apple 实况（HomeClaw accessories / Home App）
```

用 REST 版对账（Python + requests，令牌 env 传入）——三个注册表端点拼出
`房间(米家) | 设备 | 实体数 | filter 内实体`；无 HomeClaw 时 Apple 列留空人工抽查。

## 150 上限诊断（先定罪再动刀）

- 上游行为（HA 2024.8+，homekit 集成）：**每个 homekit 桥（controller/配对身份）
  最多 150 个 accessory**。新 exposure 顺序无保证——缺的设备往往是被子属性挤出局。
- 取证（唯一可靠证据链）：HA 日志 grep `would exceed the 150 device limit`
  （`GET /api/error_log` 或容器日志），列出被拒实体即定罪名单。
- 分桥不解决总量问题：子属性不迁走，子桥自己也会满。先收敛总量。

## 实体级白名单口径（实测：74 台设备圈出 46 个主控，全部可达）

按域 + 名称规则生成 include_entities（勿用 include_domains 圈 switch 域，必爆）：

- 全收域：`light / cover / climate / fan / humidifier / vacuum / lock`
- 排除：实体 id 或名称含 `indicator`（网关指示灯；注意 `indicator_light` 是可用指示灯要保留）
- **switch 域整体不进**：米家 switch 实体绝大多数是 MIoT 子功能开关，HomeKit 里全是噪音
- 独立设备类（电视 IR 发射器、DIY 显示器）用独立小桥（多 port），与主桥白名单互斥防重复 accessory

## 修改 bridge filter（HA 运行中改文件必被回写覆盖！）

filter 在 `.storage/core.config_entries` 的 homekit entry `options.filter`，新版 UI
存的是扁平键 `{exclude_domains, exclude_entities, include_domains, include_entities}`。

```python
# 白名单写回 filter —— 在 HA 停止后执行（容器/服务 stop 之后、start 之前）
import json, sys

PATH = "/PATH/TO/config/.storage/core.config_entries"   # ← 你的 HA config 目录
BRIDGE_TITLE = "HASS Bridge"                             # ← 要改的桥的 title
whitelist = [l.strip() for l in open("whitelist.txt") if l.strip()]

data = json.load(open(PATH))
hit = 0
for entry in data["data"]["entries"]:
    if entry["domain"] == "homekit" and entry.get("title") == BRIDGE_TITLE:
        f = entry["options"].setdefault("filter", {})
        assert len(whitelist) < 150, f"白名单 {len(whitelist)} 个，超 150 上限"
        f["include_entities"] = sorted(whitelist)
        f["exclude_domains"] = []
        f["exclude_entities"] = []
        f["include_domains"] = []
        hit += 1
assert hit == 1, f"命中 {hit} 个桥（应为 1），检查 BRIDGE_TITLE"
json.dump(data, open(PATH, "w"), indent=4)
print("filter 已写入", len(whitelist), "个实体；现在可以 start HA")
```

要点：
- **必须 stop 后编辑**（HA 用内存态回写会覆盖你的修改）
- 改前 `cp` 带时间戳备份；改错可 stop→还原→start 秒回滚
- include 列表只增不减时，被移除实体在 Home App 变「找不到 accessories 的孤立砖」——
  收敛操作后要在 Home App 删孤立 accessory，或整桥重扫（见下「回滚代价」）
- 全量重建 filter 会换 accessory 身份，自动化/房间归属全部重来——优先增量

## 双侧对账验收

1. HA 侧：`GET /api/error_log` 无 `exceed the 150` 新增；homekit 桥实体数 == 白名单数
2. Apple 侧（HomeClaw）：`homekit_accessories list` 计数 == 预期；category 分布核对
   （门锁=lock、扫地机常显示为 switch 类 accessory 属正常表示法）；reachable 全绿
3. 无 HomeClaw：Home App 抽查 + 「我的家 → 家庭设置 → 配件与传感器」数总数

## 已知边界与坑

- **米家门锁进不了 HomeKit**：`xiaomi_home` 不建 `lock.*` 实体（云端 API 不下发放锁
  指令）。要门锁只能 `xiaomi_miot` 单配该设备，云解锁延迟大，慎选。
- **房间归属**：房间写入在 Apple 侧（桥无权指定），但**不必手拖**——批量分房见下文
  「批量分房」一节；HA `area` 与米家房间是两套体系（米家房间 → HA area 同步走 WS API
  脚本），已同步好的 area 表就是分房映射的真相源。
- HomeClaw `accessories list` 输出可达数十 KB，agent 场景走 spillover 文件解析，勿重复拉取。
- HA Jinja 无 `zip` filter；`GetLiveContext` 只查已曝光实体，全量状态用 template。
- 电视类走 `remote` 域，HomeKit 支持弱（能开不能选台）；米家云播放/音量指令对电视不可用，
  需要播放控制选 `tobtdto/ha_multibra`（MiTV 原生 MQTT token）或 homebridge-miot。

## 批量分房（homeclaw-cli = Apple 侧管理员钥匙）

MCP 的 5 个工具只读，管理员写权限在 HomeClaw.app 自带 CLI 里（`Contents/MacOS/homeclaw-cli`，
assign-rooms / rename / create-room / scenes 等全套）——Home App 里几十台逐个拖的活可以脚本化：

```bash
# 映射表真相源 = HA：render_template 拉 entity_id|friendly_name|area
# join 键：HomeKit accessory name == HA friendly_name（含双空格，全等精确匹配）
cat assignments.json | homeclaw-cli assign-rooms - --dry-run   # 先预览
cat assignments.json | homeclaw-cli assign-rooms - --json      # 执行，读 assigned/not_found
```

- JSON：`{"assignments":[{"uuid":"<list 输出的 id>","room":"房间名"}]}`——
  **必须 `uuid` 键名**；写成 `{"accessory":...}` 配 UUID 值会全量 not_found。
- 沙箱版（App Store）CLI 读不了容器外文件，JSON 一律走 stdin `-`。
- 目标房间须已存在（缺的先 `create-room`）；跑完用 homekit_rooms MCP 读回，
  按房间计数核对预期。实测（2026-11，47 accessory）：41 台搬迁 assigned 41 / not_found 0。

## 回滚代价表（动手前告知用户）

| 操作 | 代价 |
|---|---|
| 白名单移除实体 | Home App 留孤立砖，需手动删 |
| 全量重建 include | accessory 身份全变，自动化/房间全部重配 |
| 删桥重配 | Home App 手动删桥 + 全屋重扫码，自动化全断 —— 最后手段 |
