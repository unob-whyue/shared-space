# 共享空间 V1

面向朋友、伴侣及小型关系群体的多人共享生活记录应用（Android / iOS）。

- 产品真相：`docs/../` 根目录两份 PDF（PRD + 精简技术实施规范）
- 架构：`ARCHITECTURE.md`
- 规范：`docs/DATABASE.md` `docs/API_SERVICE.md` `docs/UI_SPEC.md` `docs/TEST_PLAN.md`
- 开发规则：`AGENTS.md`

## 仓库结构

```
shared-space/
├── app/                    # Flutter 应用（spike 阶段为最小验证 UI）
├── supabase/
│   └── migrations/         # 版本化数据库迁移（唯一 schema 真相源）
├── docs/                   # 规范文档
├── AGENTS.md
├── ARCHITECTURE.md
└── README.md
```

## 当前阶段：Spike-01

验证 Flutter + Supabase + Auth + Membership + Realtime 闭环，定义见 `docs/TEST_PLAN.md` §12。

## 连接配置（不提交仓库）

Flutter 应用通过 `--dart-define` 注入：

```
SUPABASE_URL          # 项目 URL
SUPABASE_ANON_KEY     # anon key
SUPABASE_SERVICE_ROLE_KEY  # service_role key（仅测试/管理脚本用）
```

## 数据库

在 Supabase 项目上执行 `supabase/migrations/` 中的 SQL（按序号），或使用 Supabase CLI：

```
npx supabase link --project-ref <ref>
npx supabase db push
```
