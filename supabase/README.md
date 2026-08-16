# supabase/ — 后端接入说明

## 方案：Supabase 云端 Development 项目（规范 §60 推荐）

### 1. 项目配置（已就绪）

- 项目：`https://kawhasuhnyevrmbollpk.supabase.co`
- Authentication → Email → **Confirm email 已关闭**（autoconfirm）：Spike 测试依赖公开注册即返回会话。V1 正式上线前如需邮箱确认，需另行设计验证流程。
- 客户端只使用 `Project URL` + `publishable/anon key`，不用 service_role。

### 2. Migration（已应用）

`migrations/001_initial_schema.sql` 已通过 Dashboard → SQL Editor 执行。
后续 schema 变更继续走 `002_xxx.sql` 版本化（由你在 SQL Editor 应用）。

### 3. 运行集成测试（anon key only）

```
cd app
flutter pub get
flutter test --concurrency=1 \
  test/milestone1_test.dart test/milestone2_test.dart test/spike/spike_flow_test.dart \
  --dart-define=SUPABASE_URL=https://kawhasuhnyevrmbollpk.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key>
```

对应 TEST_PLAN.md §12.3 的 7 条成功标准。
`--concurrency=1` 串行执行各测试文件，避免多套件并行注册/订阅相互干扰（Realtime 偶发丢事件）。

### 4. 测试数据清理（无 service_role）

测试账号以 `spike-%@gmail.com` 命名。清理方式：Dashboard → SQL Editor 执行 `../tools/cleanup.sql`（删除 spike-% 用户，级联清除全部测试数据）。

### 5. 手动跑 App（真机验证）

```
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

真机双设备 Behavior Harness 见 TEST_PLAN.md §8。
