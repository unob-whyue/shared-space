-- =============================================================
-- 003_annotation_notifications.sql — V1.1 批注通知（App 内部）
-- 表：notifications
-- 触发：他人给「我的日记」创建批注时，为日记作者生成一条通知
-- RLS：用户只能读取 / 更新发给自己的通知；客户端不可直接 insert
-- 实时：notifications 加入 supabase_realtime（recipient 过滤）
-- =============================================================

create table if not exists public.notifications (
  id                 uuid primary key default gen_random_uuid(),
  recipient_user_id  uuid not null
                     constraint notifications_recipient_user_id_fkey
                     references public.profiles (id) on delete cascade,
  actor_user_id      uuid not null
                     constraint notifications_actor_user_id_fkey
                     references public.profiles (id) on delete cascade,
  diary_id           uuid not null
                     constraint notifications_diary_id_fkey
                     references public.diary_entries (id) on delete cascade,
  annotation_id      uuid not null
                     constraint notifications_annotation_id_fkey
                     references public.diary_annotations (id) on delete cascade,
  type               text not null default 'annotation',
  created_at         timestamptz not null default now(),
  read_at            timestamptz
);

create index if not exists idx_notifications_recipient_created
  on public.notifications (recipient_user_id, created_at desc);

-- -------------------------------------------------------------
-- 触发：他人批注我的日记 → 生成通知（不给自己发；一个批注一条）
-- -------------------------------------------------------------
create or replace function public.notify_diary_author_on_annotation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_diary_author uuid;
begin
  select author_id into v_diary_author
  from public.diary_entries
  where id = new.diary_id;

  if v_diary_author is not null and v_diary_author <> new.author_id then
    insert into public.notifications
      (recipient_user_id, actor_user_id, diary_id, annotation_id, type)
    values
      (v_diary_author, new.author_id, new.diary_id, new.id, 'annotation');
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_annotation on public.diary_annotations;
create trigger trg_notify_annotation
  after insert on public.diary_annotations
  for each row execute function public.notify_diary_author_on_annotation();

-- -------------------------------------------------------------
-- RLS：仅收件人可读 / 更新；无 insert policy（仅 trigger 可写）
-- -------------------------------------------------------------
alter table public.notifications enable row level security;

drop policy if exists notifications_select_recipient on public.notifications;
create policy notifications_select_recipient
  on public.notifications for select
  using (recipient_user_id = auth.uid());

drop policy if exists notifications_update_recipient on public.notifications;
create policy notifications_update_recipient
  on public.notifications for update
  using (recipient_user_id = auth.uid())
  with check (recipient_user_id = auth.uid());

-- -------------------------------------------------------------
-- Realtime
-- -------------------------------------------------------------
alter table public.notifications replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception when duplicate_object then null;
end $$;
