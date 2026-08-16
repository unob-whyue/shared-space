# ARCHITECTURE — 共享空间 V1 技术架构

> 版本 V1.0 · 开发基线 · 对应 V1 PRD 与《V1 精简技术实施规范》
> 本文件刻意保持简短；详细规则见 `docs/` 下各文档。

## 1. 系统目标

V1 只解决一个核心问题：

> 让 2–10 个用户在同一个共享空间中稳定地记录、浏览和批注彼此的生活。

核心技术链路：

```
Flutter App
    ↓
UI / Controller
    ↓
Repository ──（只有存在明确业务规则时才引入 Service）
    ↓
Supabase（Auth · PostgreSQL · Storage · Realtime）
```

## 2. 分层

| 层 | 职责 | 禁止 |
|---|---|---|
| UI | 页面展示、用户交互、页面状态展示 | 不写数据库/SQL、不判断跨空间权限、不实现复杂业务规则 |
| Controller / ViewModel | 接收 UI 操作、调用 Repository/Service、管理页面状态、把结果转换为 UI 可显示状态 | |
| Repository | 数据访问（DiaryRepository、SpaceRepository、AnnotationRepository、ProfileRepository、DiaryImageRepository） | |
| Service | 只用于**已存在独立业务规则**的操作。V1 唯一核心 Service = `SpaceService`（通过邀请码加入：邀请码验证 / 已加入判断 / 人数限制 / Membership 创建） | 简单 CRUD 不强制套 Service |

依赖方向：`UI → Controller/ViewModel → Service/Repository → Supabase`。
禁止 `Repository → UI`、`Service → Widget`、`Database Model → Page`，禁止循环依赖。

## 3. 状态管理

全 App 统一使用 **Riverpod**（或同类成熟方案）。不得出现页面各自维护一套全局状态、静态变量共享数据、事件互相乱传。

## 4. Feature 划分

V1 Feature：`auth` `profile` `space` `diary` `annotation` `calendar`。
「图片」属于 Diary Feature，**不**建立独立 Media Feature。
V1 不建立：media / notification / analytics / chat / friends / books / movies / map。

## 5. 核心数据流

- 创建日记：`DiaryEditor → DiaryController → DiaryRepository.create() → Supabase → Realtime → 其他成员页面`
- 加入空间：`JoinSpacePage → SpaceController → SpaceService.joinByInviteCode() → Supabase RPC/transaction → Membership`
- 创建批注：`DiaryDetail → AnnotationController → AnnotationRepository.create() → Supabase → Realtime → 其他成员页面`

## 6. V1 明确不引入

私密日记、书影音、地图、评论回复、离线模式、好友系统、推送通知、回收站、管理员角色、多级权限、CRDT/协同编辑、Analytics、Feature Flag、大规模缓存、Redis、消息队列、自建后端 API Server。

## 7. 环境

- 开发：本地 Flutter App + **Supabase 云端 Development 项目**；上线前另建 Production 项目，开发数据与正式数据不得混在一起。
- 仓库结构：`app/`（Flutter）+ `supabase/`（migrations）+ `docs/` + `AGENTS.md` + `ARCHITECTURE.md` + `README.md`。
