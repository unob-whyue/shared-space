# TEST_PLAN.md — 共享空间 V1 测试计划

> 版本 V1.0 · 开发基线 · 依据《V1 精简技术实施规范》六 + V1 PRD §53–§57

## 1. 测试目标

不是追求覆盖率数字，而是证明：**核心用户流程正确、数据不会串空间、权限不会失效、同步可靠。**

## 2. Unit Test（纯逻辑）

| 对象 | 要点 |
|---|---|
| 日期/时间 | diary_date / created_at / updated_at 语义 |
| 周视图 | 时间桶、不同成员去重、日期边界 |
| 数据解析 | weather / mood 枚举 |
| 表单 | 空内容、非法邀请码、昵称 |

## 3. Integration Test（服务端规则）

| 编号 | 场景 | 预期 |
|---|---|---|
| AUTH-001 | 输入合法邮箱密码注册 | Auth 成功（可登录） |
| SPACE-001 | 登录 → 创建空间 | Space 创建、邀请码生成、创建者进入 membership |
| SPACE-002 | A 创建 → 获取邀请码 → B 加入 | 两人都属于同一 Space |
| SPACE-003 | B 再次加入同一 Space | 不新增第二条 membership |
| SPACE-004 | 已有 10 人，第 11 人加入 | 失败（服务端拒绝，不是前端拦截） |
| DIARY-001 | 创建日记 | 产生 id / space_id / author_id / diary_date / created_at / updated_at，author_id 与时间由服务器确定 |
| DIARY-002 | 修改日记 | created_at 不变、updated_at 更新 |
| DIARY-003 | 修改过去日记 | diary_date 可以改变、created_at 不改变（Repository/DB 层规则；V1 UI 不提供修改 diary_date 的入口，Milestone 2 决定） |
| DIARY-004 | 删除自己的日记 | 成功 |
| DIARY-005 | 删除他人的日记 | RLS 拒绝 |
| SECURITY-001 | A 属 Space A、B 属 Space B，A 请求 Space B 日记 | 返回拒绝或空结果，不得泄漏任何 Space B 数据 |
| ANNO-001 | 成员 B 对 A 的日记创建批注 | 成功 |
| ANNO-002 | Space 外用户创建批注 | RLS 拒绝 |
| ANNO-003 | 批注作者身份 | annotation.author_id == auth.uid() |
| IMAGE-001 | 上传一张图片 | Storage 成功 + DiaryImage 成功 |
| IMAGE-002 | 上传多张图片 | sort_order 正确 |
| IMAGE-003 | 删除日记 | 对应图片被清理 |

## 4. Realtime Tests

| 编号 | 场景 | 预期 |
|---|---|---|
| REALTIME-001 | 设备 A 创建日记，设备 B 打开共享日记 | B 自动看到（不手动刷新） |
| REALTIME-002 | 设备 A 修改日记 | 设备 B 自动更新 |
| REALTIME-003 | 设备 B 创建批注 | 设备 A 自动看到 |

## 5. Calendar Tests

- MONTH-001：给定多个日期上的 Diary → 对应日期显示活动标记。
- MONTH-002：点击日期 → 展示该日全部成员日记。
- WEEK-001：周一 10:20 A、周一 10:40 B、周一 10:45 B、周一 14:20 A → `10:00 → 2 人`、`14:00 → 1 人`（不是 10:00 → 3 条记录）。

## 6. Behavior Harness（真实用户行为）

| 编号 | 流程 |
|---|---|
| BH-001 | 启动 App → 登录 → 创建 Space |
| BH-002 | 用户 A 创建 Space → 获取邀请码 → 用户 B 加入 |
| BH-003 | A 创建 Diary → B 看到 Diary |
| BH-004 | B 创建 Diary → A 看到 Diary |
| BH-005 | B 对 A 的 Diary 划线 → 提交批注 → A 看到 |
| BH-006 | A 修改自己的 Diary → B 看到更新 |
| BH-007 | A 删除自己的 Diary → B 看不到 |
| BH-008 | B 尝试删除 A 的 Diary → 失败 |
| BH-009 | Space A 用户尝试读取 Space B → 失败 |

## 7. UI Behavior Harness

用 Flutter Integration Test（后续可加入 Maestro / Appium / Patrol）做真实 UI 行为测试。示例流程：

```
打开 App → 点击共享空间 → 点击新建日记 → 输入文字 → 点击保存 → 返回首页 → 找到今天的日记
```

目标：发现「单个函数都正常，但用户整个操作流程跑不通」。

## 8. 真机验证

最低要求：iPhone × 1 + Android × 1，使用不同账号，两台设备完成完整 Behavior Harness（§6）。

## 9. Code Gate（每次提交 / PR 至少通过）

```
Format → flutter analyze → flutter test → Integration Test → Security / dependency scan
涉及 Android → Android build；涉及 iOS → macOS 环境下 iOS build
```

任何关键阶段失败不允许进入主分支。任何 API key / service_role key / 数据库密码不得进入 Git；`.env` 等敏感配置不能提交。

## 10. 不做的测试

离线冲突、多人同时编辑正文、推送通知、书影音、地图、高并发、大规模压力测试、Kubernetes、分布式故障恢复、多区域容灾 —— 这些都不属于 V1。

## 11. Definition of Done

□ PRD 行为符合 □ 数据结构正确 □ RLS 正确 □ Repository/Service 完成 □ UI 完成
□ Unit Test 通过 □ 相关 Integration Test 通过 □ 相关 Behavior Test 通过 □ analyze 通过 □ build 通过

---

# 12. 技术 Spike（正式开发前必做）

## 12.1 Spike-01：目标

> 验证 **Flutter + Supabase + Auth + Membership + Realtime** 是否成立。

只实现：

```
注册/登录 → 创建 Space → 生成邀请码 → 另一账号输入邀请码 → 加入 Space
→ A 创建一条测试 Diary → B 自动看到
```

## 12.2 Spike-01 不实现

完整 UI、月视图、周视图、图片、批注、书影音、地图、复杂主题、发布 App Store。

## 12.3 Spike-01 成功标准（7 项）

在 iPhone + Android 两个真实设备（或两个独立客户端会话）上：

1. 两个账号可以注册；
2. A 能创建 Space；
3. B 能通过邀请码加入；
4. 两台设备都显示同一 Space；
5. A 创建 Diary；
6. B 不手动刷新即可看到；
7. Space A 和 Space B 数据不能互相读取。

**7 项全部成立，才进入 V1 正式开发。**

> ✅ **Spike-01 执行结果（2026-08-16）**：在真实 Supabase 项目上以两个独立客户端会话跑通全部 7 项
>（另验证：重复加入拒绝、10 人上限服务端强制、created_at/updated_at 规则、删除权限、批注表结构）。
> 测试：`app/test/spike/spike_flow_test.dart`（AUTH-001 / SPACE-001~004 / DIARY-001~005 /
> SECURITY-001 / REALTIME-001~003，12/12 通过）。真机双设备验证（TEST_PLAN §8）待 Phase 7 执行。

## 12.4 Spike 阶段允许修改什么

发现某种数据库设计不适合 Supabase 时，可以修改：Repository 组织、RPC 方式、RLS 写法、Realtime 监听方式、Storage 路径。

**不得**因为技术方便而擅自修改：产品权限、Space 人数（2–10）、多 Space 数据模型、Diary 核心行为。

## 12.5 Spike 阶段禁止做什么

不做完整 UI、漂亮动画、地图、书影音、完整批注、复杂状态管理、生产部署、服务器监控、未来版本功能。Spike 的目的：**验证技术闭环，而不是完成产品。**

## 12.6 Runtime Harness 结论

V1 Spike 与正式 V1 都不需要复杂 Runtime Harness（Prometheus / Grafana / tracing / K8s）。
目前只需要：真机 Behavior Harness、Flutter 测试、CI、安全扫描。
试运行后如出现真机偶发崩溃再加 Crash Reporting，出现数据同步异常再针对真实问题增加运行时观测。

## 13. 最终原则

```
只做现在需要的 → 只有重复才抽象 → 只有真实问题才防御 → 只有真实需求才加表
→ 只有真实业务规则才建 Service → 只有真实用户流程才进入 Behavior Harness
```
