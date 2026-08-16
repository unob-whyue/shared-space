# DATABASE.md — 共享空间 V1 数据库规范

> 版本 V1.0 · 开发基线 · 依据《V1 精简技术实施规范》二
> 数据库：PostgreSQL（Supabase 托管）；认证由 Supabase Auth 管理；应用用户数据存放于 `profiles`。

## 1. 原则

1. V1 **只建 6 张核心表**：`profiles` `spaces` `space_memberships` `diary_entries` `diary_images` `diary_annotations`。
2. 不建未来功能表（书影音 / 地图 / 通知等只能出现在 PRD roadmap 中）。
3. 所有 schema 修改必须走 `supabase/migrations/` 版本化 migration，禁止手改数据库后不提交 migration。
4. 数据权限由 RLS 保证（§11），前端隐藏按钮不是权限。
5. 多空间从第一天支持：`User → SpaceMembership → 多个 Space`；V1 UI 克制，数据模型不克制。

## 2. profiles

| 字段 | 类型 | 约束 |
|---|---|---|
| id | uuid | PK，与 `auth.users.id` 一一对应 |
| nickname | text | NOT NULL |
| color | text | NOT NULL |
| created_at | timestamptz | NOT NULL |
| updated_at | timestamptz | NOT NULL |

规则：

- 昵称必填、**不要求唯一**、可修改。
- 颜色使用预设 `color_key`（如 `blue` / `red` / `green` …），**不允许任意 HEX**。
- 注册时由数据库 trigger（`auth.users` INSERT 后）自动创建 profile，默认昵称 + 默认颜色；不依赖客户端在注册后补写。
- `updated_at` 由 trigger 在 UPDATE 时刷新（服务器时钟为准）。

## 3. spaces

| 字段 | 类型 | 约束 |
|---|---|---|
| id | uuid | PK |
| name | text | NOT NULL |
| invite_code | text | UNIQUE, NOT NULL |
| created_by | uuid | FK profiles.id |
| created_at | timestamptz | NOT NULL |

规则：

- `created_by` 是空间创建者。
- **V1 不单独建立 role。空间所有权唯一来源 = `spaces.created_by`**，不得再建 `membership.role = owner`，避免两个真相来源。

## 4. space_memberships

| 字段 | 类型 | 约束 |
|---|---|---|
| id | uuid | PK |
| space_id | uuid | FK spaces.id |
| user_id | uuid | FK profiles.id |
| joined_at | timestamptz | NOT NULL |

约束：`UNIQUE(space_id, user_id)`。

**V1 不存在**：status / role / pending / banned / suspended 字段。

## 5. diary_entries

| 字段 | 类型 | 说明 |
|---|---|---|
| id | uuid | PK |
| space_id | uuid | 所属空间 |
| author_id | uuid | 作者 |
| diary_date | date | 日记所属日期（用户语义日期） |
| content | text | 正文 |
| weather | text | 固定枚举 key（§8） |
| mood | text | 固定枚举 key（§8） |
| created_at | timestamptz | 首次创建（服务器时间） |
| updated_at | timestamptz | 最后修改（trigger 维护） |

### 5.1 时间规则

必须明确区分 `diary_date` / `created_at` / `updated_at`：

- 用户 8 月 16 日补写 8 月 10 日的日记：`diary_date = 2026-08-10`，`created_at = 2026-08-16 20:32`。
- 修改内容时：`diary_date` 不变（除非用户显式改日期）、`created_at` 不变、`updated_at` 更新。
- `created_at` / `updated_at` 一律以服务器为准，客户端不得提交（见 API_SERVICE.md §9/§10）。

### 5.2 多条日记

同一个用户同一天可以有多条日记。**禁止**创建 `UNIQUE(space_id, author_id, diary_date)`。

## 6. diary_images

| 字段 | 类型 |
|---|---|
| id | uuid |
| diary_id | uuid |
| storage_path | text |
| sort_order | integer |
| created_at | timestamptz |

图片二进制存 **Supabase Storage**，数据库只存 storage path + metadata。
V1 不实现：拖拽排序、单张图片独立编辑、独立图片资源管理系统。

## 7. diary_annotations

| 字段 | 类型 |
|---|---|
| id | uuid |
| diary_id | uuid |
| author_id | uuid |
| start_offset | integer |
| end_offset | integer |
| selected_text | text |
| comment | text |
| created_at | timestamptz |

V1：可创建、可阅读。**不实现**：编辑、删除、回复（也不预建 `parent_annotation_id`）。

## 8. 枚举

天气（应用只保存 key，DB 层用 CHECK 约束兜底）：

```
sunny  partly_cloudy  cloudy  rain  storm  snow  fog  unknown
```

心情：

```
happy  calm  sad  angry  excited  tired  anxious  love
```

V1 不支持自定义。未来增加自定义标签时不得破坏原有枚举结构。

## 9. 删除策略

V1 **不使用** `deleted_at`，不做回收站。删除日记 = **硬删除**，同时处理：

- DiaryImage（`diary_images` 级联 + Storage 对象清理）
- Annotation（级联）

（App/RPC 负责在删库记录的同时删除 Storage 对象，尽力而为；孤儿对象由 Storage 清理任务兜底。）

## 10. 索引

至少建立：

```
space_memberships(space_id)
space_memberships(user_id)
diary_entries(space_id)
diary_entries(author_id)
diary_entries(diary_date)
diary_entries(space_id, diary_date)
diary_images(diary_id)
diary_annotations(diary_id)
```

不要在没有查询需求的字段上提前大量加索引。

## 11. RLS

数据库权限必须由 RLS 保证。核心规则：

> 当前用户只有在属于该 Space 时，才能访问该 Space 的共享数据。

辅助函数 `is_space_member(space_id, user_id)`：判断 `space_memberships` 中是否存在对应行。

**必须声明为 `SECURITY DEFINER`**（并 `set search_path = public`）：否则 `space_memberships` 的读取策略会与辅助函数互相递归（PostgreSQL 报 `infinite recursion detected in policy`）。这是 Supabase RLS 的标准写法。

### 11.1 profiles

- 读取：本人，或与本人同属任一 Space 的成员（只暴露 nickname / color，不暴露认证敏感信息）。
- 创建/更新：仅本人（`id = auth.uid()`）。

### 11.2 Diary 读取

`auth.uid() ∈ space_memberships(user_id)` 且 `space_memberships.space_id = diary.space_id`。

### 11.3 Diary 创建

`author_id = auth.uid()` 且用户属于对应 Space。

### 11.4 Diary 修改

`author_id = auth.uid()`（with check 追加「目标 space 仍须为本人所属空间」）。

### 11.5 Diary 删除

`author_id = auth.uid()`。

### 11.6 Annotation

- 读取：同一 Space 成员均可。
- 创建：同一 Space 成员均可（`author_id = auth.uid()` 且属于 diary 所属 Space）。
- 修改/删除：V1 不提供（不建 policy）。

### 11.7 图片（diary_images）

- 读取：diary 所属 Space 成员。
- 插入/删除：仅 diary 作者。

## 12. 邀请码加入（原子性）

邀请码不能直接作为 Membership 数据的客户端写入口。正确流程：

```
客户端 → SpaceService.joinByInviteCode() → 数据库 RPC（单事务）
    → 验证 invite_code
    → 检查是否已经加入
    → 检查人数 < 10
    → 创建 membership
```

必须保证「检查人数」与「创建 membership」在同一原子业务操作中完成（RPC 内对 space 行 `FOR UPDATE` 串行化同一空间的并发加入）。

## 13. 实时

`diary_entries`、`diary_annotations`、`space_memberships` 加入 `supabase_realtime` publication。其余表默认不进实时通道。

## 14. 与 PRD 的差异裁定（以本规范为准）

| 主题 | PRD 建议 | 本规范裁定 |
|---|---|---|
| membership.role | 至少 owner / member | 删除 role；所有权唯一来源 = `spaces.created_by` |
| diary_entries.deleted_at | 保留软删除字段设计空间 | 硬删除，不加 deleted_at |
| 天气枚举 | sunny/cloudy/rainy/snowy/foggy/storm/unknown | sunny/partly_cloudy/cloudy/rain/storm/snow/fog/unknown（新增 partly_cloudy，键名统一为名词） |
| annotation.updated_at | 有 | 无（V1 批注不可编辑） |
| annotation.parent_annotation_id | 可预留 | 不预建（V1 无回复） |

## 15. 迁移约定

- 文件名：`supabase/migrations/001_initial_schema.sql`、`002_xxx.sql`…（序号递增，只追加不回改已应用的文件）。
- 每个 migration 必须可在空库上完整重建 V1 数据库。
- 变更数据模型时，必须同时修改测试（AGENTS.md 规则 5）。
