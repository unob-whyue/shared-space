# AGENTS.md — 共享空间 V1 开发规则（真人开发者与 AI Agent 通用）

> 本项目 = 《共享空间》V1（Flutter + Supabase 多人共享日记）。
> 动手前必须先读：`ARCHITECTURE.md` → `docs/DATABASE.md` → `docs/API_SERVICE.md` → `docs/UI_SPEC.md` → `docs/TEST_PLAN.md`。产品真相见 PRD（如有疑问以 docs 为准，见 DATABASE.md §14 差异裁定）。

## 一、核心原则

1. **PRD 是产品真相**：不要自己添加产品功能。
2. **最简单可行实现优先**：Prefer the simplest implementation that satisfies the current PRD. 不要因为「以后可能需要」增加抽象。
3. **不要为假想场景写代码**：当前不实现——离线冲突、多人协同编辑、评论线程、管理员、私密内容、复杂缓存、消息队列。
4. **不要过早抽象**：满足以下至少一个条件才抽象：(1) 已存在多个真实调用场景；(2) 业务规则形成稳定独立边界；(3) 测试隔离确实需要；(4) 已出现真实重复。「以后可能复用」不是理由。
5. **不要为好看加 Service 层**：简单 CRUD → Repository；存在真正业务规则 → Service。
6. **不要复制数据模型**：没有 SharedDiary / MyDiary，只有 `DiaryEntry`（「我的记录」是同一数据的视图）。
7. **UI 不直接访问数据库**：必须经过 Repository / Service。
8. **权限由数据库最终保证**：前端隐藏按钮不是权限控制，RLS 才是最终权限边界。
9. **不要绕过 Supabase 自建后端**：V1 = Flutter + Supabase，除非后续需求明确要求。
10. **数据库修改必须 Migration**：禁止手改 schema 后不提交 migration。
11. **未来功能不得进入 V1 migration**：书影音和地图现在只能留在 PRD roadmap。
12. **不要为了测试制造复杂接口**：只有一个 Supabase 实现时，直接使用 Repository；不建 RepositoryInterface / RepositoryImpl / DataSource / DataSourceImpl。
13. **不修改测试来掩盖产品 Bug**：测试失败后必须判断是代码错误、测试错误还是产品需求错误，然后解决真正的问题。
14. **每次任务都必须验证**：至少 `flutter analyze` + `flutter test`；相关功能还需要 integration / behavior test。
15. **不要顺手重构**：任务之外不重写导航、不换状态管理、不改主题系统、不重构所有 Repository，除非当前修改确实需要。
16. **发现需求矛盾先报告**：不要自己猜测产品应该怎么改。
17. **提交前输出变更说明**（格式见 §三）。

## 二、开发流程（每项任务）

1. 阅读 PRD → 2. 阅读架构规范 → 3. 阅读现有代码 → 4. 判断影响范围 → 5. 提出实现方案 → 6. 修改数据库 migration → 7. 实现 domain/model → 8. 实现 service/repository → 9. 实现 UI → 10. 添加 unit tests → 11. 添加 integration tests → 12. 运行 lint/type check → 13. 运行安全扫描 → 14. 运行 behavior harness → 15. 构建 Android/iOS → 16. 输出变更报告。

新增功能前先说明影响哪些实体和模块；修改数据模型时必须同时修改测试。
**禁止「先把页面做出来，以后再补后端」。**

## 三、变更报告格式

```
完成：
修改：
数据库：
测试：
检查：
已知限制：
```

## 四、Definition of Done

产品层（符合 PRD）、UI 层（页面可正常操作）、数据层（数据库结构正确）、权限层（非法用户无法访问数据）、测试层（相关单元测试通过）、行为层（核心用户流程通过）、静态检查（无 lint / 类型错误）、安全层（无高严重度问题）、构建层（Android / iOS 构建成功）——全部满足才算完成。

## 五、V1 最终原则

```
只做现在需要的 → 只有重复才抽象 → 只有真实问题才防御 → 只有真实需求才加表
→ 只有真实业务规则才建 Service → 只有真实用户流程才进入 Behavior Harness
```
