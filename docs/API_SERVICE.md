# API_SERVICE.md — 共享空间 V1 服务层 / Repository 规范

> 版本 V1.0 · 开发基线 · 依据《V1 精简技术实施规范》三

## 1. 总原则

Supabase 本身承担：Auth、Database、Storage、Realtime。**V1 不自建 Node.js / FastAPI 后端。**

```
UI → Controller/ViewModel → Repository（有业务规则处 → Service）→ Supabase
```

## 2. Repository 清单

```
AuthRepository  ProfileRepository  SpaceRepository
DiaryRepository  DiaryImageRepository  AnnotationRepository
```

**不要**为每个 Repository 再建立 Interface + Impl 两层；只有 Supabase 一个实现就直接用 Repository。

## 3. AuthRepository

```
signUp()  signIn()  signOut()  currentUser()
```

职责仅为 Supabase Auth 的最薄封装。**不要**增加 AuthManager / AuthCoordinator / AuthUseCase。

## 4. ProfileRepository

```
getMyProfile()  updateMyProfile()
```

现在不要提前写：getAllUsers() / getProfilesBySpace() / searchProfiles()（后续某页面确实需要成员 profile 时再增加对应查询）。

## 5. SpaceRepository

```
getMySpaces()  getSpace()  getMembers()  createSpace()
```

V1 `getMySpaces()` 底层必须能返回多个 Space（数据模型支持多空间，UI 才克制）。

## 6. SpaceService —— V1 唯一 Service

核心：`joinByInviteCode(inviteCode)`。

它负责：当前用户、邀请码、Space、Membership、10 人限制。
实现走数据库 RPC（见 DATABASE.md §12），RPC 内完成验证 → 已加入判断 → 人数检查 → 创建 membership，单事务原子。

RPC 错误 → 客户端语义映射：

| 数据库消息 | 客户端语义 | UI 提示（示例） |
|---|---|---|
| INVITE_CODE_NOT_FOUND | 邀请码无效 | 邀请码不正确 |
| ALREADY_MEMBER | 已加入 | 你已经在这个空间里了 |
| SPACE_FULL | 人数已满 | 此共享空间人数已达到上限 |

邀请码判断逻辑集中在 SpaceService，不得散落在多个页面和 API 中。

## 7. createSpace

入口：`SpaceRepository.createSpace(name)` → 调用 RPC `create_space(name)`。

RPC 单事务完成：

1. 创建 Space（服务端生成唯一邀请码，如 8 位大写字母数字）；
2. 创建者成为第一名成员（Membership）。

整个过程必须保证一致性；客户端不生成邀请码、不手动拼两步写。

## 8. DiaryRepository

```
createDiary()      getDiary()      updateDiary()      deleteDiary()
getByDate()        getByDateRange()
getMyDiaries()     watchDiaryChanges()
```

`watchDiaryChanges()` 属于 DiaryRepository。**不要**建立全局 RealtimeService。

## 9. Diary Create

客户端参数：`spaceId, diaryDate, content, weather, mood`。

V1 客户端 `diaryDate` 恒为当天（不提供补写/改期 UI）；数据库与 Repository 层仍支持任意日期（未来恢复补写能力不需要改数据模型）。
服务端确定：`authorId = auth.uid()`、`createdAt = now()`、`updatedAt = now()`。
客户端不能提交任意 `authorId` / `createdAt`（服务器时间与服务器身份为准）。

## 10. Diary Update

允许修改：`diaryDate, content, weather, mood`。
不允许：`id, spaceId, authorId, createdAt`（`updated_at` 由 DB trigger 刷新）。

## 11. Diary Delete

删除前服务端确认：`auth.uid() == diary.author_id`（RLS 兜底）。
删除范围：Diary → Images（含 Storage 文件）→ Annotations，尽可能一次完成。

## 12. getByDateRange

用于月视图、周视图。输入：`spaceId, from, to`。一次获取区间数据，**月视图不得发 30 次请求**。

## 13. 周视图计算

V1 **不建立** WeeklyActivityService。数据流：

```
DiaryRepository.getByDateRange()
    ↓
calculateWeeklyActivity(entries)   // 纯函数
    ↓
WeekView
```

## 14. 周视图算法（纯函数契约）

- 默认时间桶：1 小时（`14:00–14:59 → 14:00`）。
- 计算逻辑：`(date, hour)` → 去重 `author_id` → count。
- 同一个成员在同一小时写 3 条日记，`member_count` 仍然是 1。
- 该函数必须可被单元测试独立覆盖（无 IO、无 UI 依赖）。

## 15. DiaryImageRepository

```
uploadForDiary()  removeForDiary()
```

`removeForDiary()` 是内部清理能力，不代表用户有一个独立「管理图片」的产品页面。
**不建立** ImageService / MediaService / PhotoManager。

## 16. 图片上传规则

```
选择 → 客户端压缩 → 上传 Storage → 插入 diary_images
```

- 若 Storage 成功但数据库插入失败 → 尝试删除刚上传的 Storage 文件。
- 服务端再次验证：文件类型（MIME，不信客户端扩展名）、文件大小、存储路径、用户权限。
- 支持 JPG / PNG / WebP；单篇最多 9 张（上限**集中定义**，不得分散在多个页面）。
- 不做：后台上传队列、断点续传、上传重试系统、大规模图片 CDN 架构。

## 17. AnnotationRepository

```
create()  getByDiary()  watchChanges()
```

**不实现**：update() / delete() / reply() / thread()。

## 18. Annotation 读取

读取一篇日记时：读取该日记全部 annotations；页面负责将 annotation 与原文选区（offset）关联。不能只保存评论内容，必须保存选区位置与当时的选中文本。

## 19. Realtime

- 不建立独立 Realtime Service；具体 Feature 自己监听：`DiaryRepository.watchDiaryChanges()`、`AnnotationRepository.watchChanges()`。
- 收到事件后更新**对应页面数据**；禁止「收到任何事件 → 全 App 刷新」。
- 客户端永远优先相信服务器最终状态；网络恢复后以服务器状态为准。
- **join 窗口期不补发事件**（Spike 实测）：订阅发起后、channel join 完成前发生的事件不会送达。页面初始化必须采用「**先建立订阅并确认 `ready` → 再获取全量快照**」的时序：快照会补回窗口期内的事件；`ready` 之后到达的事件触发整体重拉（列表整体替换 = 天然去重），且必须防止并发快照互相覆盖（代际收敛：旧代际结果丢弃，见 `space_detail_page._fetchGeneration`），保证重复事件不产生重复数据、不回退。`watchDiaryChanges` 返回 `(stream, ready)`。事件类型为小写 Dart 枚举名（`insert` / `update` / `delete`）。

## 20. 错误处理约定

- 所有网络操作必须具备明确状态：Loading / Success / Error / Empty。
- UI 不直接展示 PostgrestException 原文；Repository 层将底层错误映射为统一应用错误（含可显示文案），见 UI_SPEC.md §19。
