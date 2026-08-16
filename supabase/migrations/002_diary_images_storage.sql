-- =============================================================
-- 002_diary_images_storage.sql — 日记图片 Storage 桶与权限
-- 桶：diary-images（私有；读取走签名 URL）
-- 路径约定：{space_id}/{diary_id}/{文件名}.{jpg|jpeg|png|webp}
--
-- 权限规则（产品要求）：
--   读取：同 Space 成员（Space membership 校验）
--   写入（上传/替换/删除）：仅 Diary 作者 —— 一律通过
--         diary_entries.author_id = auth.uid() 的实际关系校验，
--         绝不因属于同一 Space 而获得他人 Diary 的 Storage 写权限。
--   客户端使用 anon/publishable key 时同样成立（RLS 是最终边界）。
--
-- 依赖：001_initial_schema.sql（diary_entries / space_memberships）
-- 注意：删除对象要求 diary 行仍存在（作者校验），客户端删除日记时
--       必须先清理 Storage 对象、再删除 diary 行（代码已按此实现）。
-- =============================================================

insert into storage.buckets (id, name, public, file_size_limit)
values ('diary-images', 'diary-images', false, 5242880)
on conflict (id) do nothing;

-- -------------------------------------------------------------
-- 读取：日记所属空间成员
-- -------------------------------------------------------------
drop policy if exists diary_images_read_member on storage.objects;
create policy diary_images_read_member
  on storage.objects for select
  using (
    bucket_id = 'diary-images'
    and exists (
      select 1
      from public.space_memberships m
      where m.space_id = ((storage.foldername(name))[1])::uuid
        and m.user_id = auth.uid()
    )
  );

-- -------------------------------------------------------------
-- 上传：路径第二段（diary_id）必须指向当前用户的 Diary，
--       且第一段（space_id）与该 Diary 实际所属空间一致；
--       扩展名白名单。
-- -------------------------------------------------------------
drop policy if exists diary_images_insert_author on storage.objects;
create policy diary_images_insert_author
  on storage.objects for insert
  with check (
    bucket_id = 'diary-images'
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
    and exists (
      select 1
      from public.diary_entries d
      where d.id = ((storage.foldername(name))[2])::uuid
        and d.space_id = ((storage.foldername(name))[1])::uuid
        and d.author_id = auth.uid()
    )
  );

-- -------------------------------------------------------------
-- 替换（upsert/update 同路径覆盖）：新旧路径都必须指向当前用户
-- 的 Diary。V1 客户端主流程用「删除+上传」实现替换，本策略作为
-- 服务端兜底，不允许他人覆盖对象。
-- -------------------------------------------------------------
drop policy if exists diary_images_update_author on storage.objects;
create policy diary_images_update_author
  on storage.objects for update
  using (
    bucket_id = 'diary-images'
    and exists (
      select 1
      from public.diary_entries d
      where d.id = ((storage.foldername(name))[2])::uuid
        and d.space_id = ((storage.foldername(name))[1])::uuid
        and d.author_id = auth.uid()
    )
  )
  with check (
    bucket_id = 'diary-images'
    and exists (
      select 1
      from public.diary_entries d
      where d.id = ((storage.foldername(name))[2])::uuid
        and d.space_id = ((storage.foldername(name))[1])::uuid
        and d.author_id = auth.uid()
    )
  );

-- -------------------------------------------------------------
-- 删除：仅当路径指向的 Diary 属于当前用户。
-- （不再是 owner_id 判断：uploader 由 INSERT 策略保证即作者，
--   此处与 INSERT/UPDATE 同一套关系校验，语义一致。）
-- -------------------------------------------------------------
drop policy if exists diary_images_delete_author on storage.objects;
create policy diary_images_delete_author
  on storage.objects for delete
  using (
    bucket_id = 'diary-images'
    and exists (
      select 1
      from public.diary_entries d
      where d.id = ((storage.foldername(name))[2])::uuid
        and d.space_id = ((storage.foldername(name))[1])::uuid
        and d.author_id = auth.uid()
    )
  );
