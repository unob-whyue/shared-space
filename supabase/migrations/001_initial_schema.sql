-- =============================================================
-- 001_initial_schema.sql — 共享空间 V1 初始 schema
-- 表：profiles / spaces / space_memberships / diary_entries /
--     diary_images / diary_annotations
-- 权限：RLS（见 docs/DATABASE.md §11）
-- 原子操作：RPC create_space / join_space_by_invite_code
-- 实时：diary_entries / diary_annotations / space_memberships
-- =============================================================

create extension if not exists pgcrypto;

-- -------------------------------------------------------------
-- profiles
-- -------------------------------------------------------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  nickname   text not null default '新成员',
  color      text not null default 'blue',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 注册时自动创建 profile（不依赖客户端补写）
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, nickname, color)
  values (new.id, '新成员', 'blue')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- updated_at 由服务器维护
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- -------------------------------------------------------------
-- spaces
-- -------------------------------------------------------------
create table if not exists public.spaces (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  invite_code text not null unique,
  created_by  uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now()
);

-- -------------------------------------------------------------
-- space_memberships
-- -------------------------------------------------------------
create table if not exists public.space_memberships (
  id        uuid primary key default gen_random_uuid(),
  space_id  uuid not null references public.spaces (id) on delete cascade,
  user_id   uuid not null references public.profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  unique (space_id, user_id)
);

-- -------------------------------------------------------------
-- diary_entries
-- -------------------------------------------------------------
create table if not exists public.diary_entries (
  id         uuid primary key default gen_random_uuid(),
  space_id   uuid not null references public.spaces (id) on delete cascade,
  author_id  uuid not null references public.profiles (id) on delete cascade,
  diary_date date not null,
  content    text not null default '',
  weather    text not null default 'unknown'
             check (weather in ('sunny','partly_cloudy','cloudy','rain','storm','snow','fog','unknown')),
  mood       text not null default 'calm'
             check (mood in ('happy','calm','sad','angry','excited','tired','anxious','love')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 作者与时间由服务器确定（客户端传值一律被覆盖，见 API_SERVICE.md §9）
create or replace function public.set_diary_server_defaults()
returns trigger
language plpgsql
as $$
begin
  new.author_id := auth.uid();
  new.created_at := now();
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_diary_server_defaults on public.diary_entries;
create trigger trg_diary_server_defaults
  before insert on public.diary_entries
  for each row execute function public.set_diary_server_defaults();

-- 更新时：author_id / space_id / created_at 不可改，updated_at 由服务器刷新
create or replace function public.set_diary_update_defaults()
returns trigger
language plpgsql
as $$
begin
  new.author_id := old.author_id;
  new.space_id := old.space_id;
  new.created_at := old.created_at;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_diary_update_defaults on public.diary_entries;
create trigger trg_diary_update_defaults
  before update on public.diary_entries
  for each row execute function public.set_diary_update_defaults();

-- -------------------------------------------------------------
-- diary_images
-- -------------------------------------------------------------
create table if not exists public.diary_images (
  id           uuid primary key default gen_random_uuid(),
  diary_id     uuid not null references public.diary_entries (id) on delete cascade,
  storage_path text not null,
  sort_order   integer not null default 0,
  created_at   timestamptz not null default now()
);

-- -------------------------------------------------------------
-- diary_annotations
-- -------------------------------------------------------------
create table if not exists public.diary_annotations (
  id            uuid primary key default gen_random_uuid(),
  diary_id      uuid not null references public.diary_entries (id) on delete cascade,
  author_id     uuid not null references public.profiles (id) on delete cascade,
  start_offset  integer not null check (start_offset >= 0),
  end_offset    integer not null check (end_offset >= start_offset),
  selected_text text not null,
  comment       text not null,
  created_at    timestamptz not null default now()
);

-- 批注作者与时间由服务器确定
create or replace function public.set_annotation_server_defaults()
returns trigger
language plpgsql
as $$
begin
  new.author_id := auth.uid();
  new.created_at := now();
  return new;
end;
$$;

drop trigger if exists trg_annotation_server_defaults on public.diary_annotations;
create trigger trg_annotation_server_defaults
  before insert on public.diary_annotations
  for each row execute function public.set_annotation_server_defaults();

-- -------------------------------------------------------------
-- 索引（docs/DATABASE.md §10）
-- -------------------------------------------------------------
create index if not exists idx_memberships_space   on public.space_memberships (space_id);
create index if not exists idx_memberships_user    on public.space_memberships (user_id);
create index if not exists idx_diary_space         on public.diary_entries (space_id);
create index if not exists idx_diary_author        on public.diary_entries (author_id);
create index if not exists idx_diary_date          on public.diary_entries (diary_date);
create index if not exists idx_diary_space_date    on public.diary_entries (space_id, diary_date);
create index if not exists idx_diary_images_diary  on public.diary_images (diary_id);
create index if not exists idx_diary_anno_diary    on public.diary_annotations (diary_id);

-- -------------------------------------------------------------
-- RLS 辅助函数
-- 必须 SECURITY DEFINER：否则 space_memberships 的读策略会与
-- 该函数互相递归（infinite recursion detected in policy）。
-- -------------------------------------------------------------
create or replace function public.is_space_member(p_space_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.space_memberships
    where space_id = p_space_id and user_id = p_user_id
  );
$$;

-- -------------------------------------------------------------
-- RLS：profiles
-- -------------------------------------------------------------
alter table public.profiles enable row level security;

-- 本人，或与本人同属任一 Space 的成员可读（只含 nickname/color）
drop policy if exists profiles_select_own_or_same_space on public.profiles;
create policy profiles_select_own_or_same_space
  on public.profiles for select
  using (
    id = auth.uid()
    or exists (
      select 1
      from public.space_memberships a
      join public.space_memberships b on a.space_id = b.space_id
      where a.user_id = auth.uid()
        and b.user_id = profiles.id
    )
  );

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own
  on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own
  on public.profiles for insert
  with check (id = auth.uid());

-- -------------------------------------------------------------
-- RLS：spaces（写入口一律走 RPC，见 §RPC）
-- -------------------------------------------------------------
alter table public.spaces enable row level security;

drop policy if exists spaces_select_member on public.spaces;
create policy spaces_select_member
  on public.spaces for select
  using (public.is_space_member(id, auth.uid()));

-- -------------------------------------------------------------
-- RLS：space_memberships（insert 仅经 RPC）
-- -------------------------------------------------------------
alter table public.space_memberships enable row level security;

drop policy if exists memberships_select_member on public.space_memberships;
create policy memberships_select_member
  on public.space_memberships for select
  using (public.is_space_member(space_id, auth.uid()));

-- -------------------------------------------------------------
-- RLS：diary_entries
-- -------------------------------------------------------------
alter table public.diary_entries enable row level security;

drop policy if exists diary_select_member on public.diary_entries;
create policy diary_select_member
  on public.diary_entries for select
  using (public.is_space_member(space_id, auth.uid()));

drop policy if exists diary_insert_author_member on public.diary_entries;
create policy diary_insert_author_member
  on public.diary_entries for insert
  with check (
    author_id = auth.uid()
    and public.is_space_member(space_id, auth.uid())
  );

drop policy if exists diary_update_author on public.diary_entries;
create policy diary_update_author
  on public.diary_entries for update
  using (author_id = auth.uid())
  with check (
    author_id = auth.uid()
    and public.is_space_member(space_id, auth.uid())
  );

drop policy if exists diary_delete_author on public.diary_entries;
create policy diary_delete_author
  on public.diary_entries for delete
  using (author_id = auth.uid());

-- -------------------------------------------------------------
-- RLS：diary_images
-- -------------------------------------------------------------
alter table public.diary_images enable row level security;

drop policy if exists images_select_member on public.diary_images;
create policy images_select_member
  on public.diary_images for select
  using (
    exists (
      select 1 from public.diary_entries d
      where d.id = diary_id
        and public.is_space_member(d.space_id, auth.uid())
    )
  );

drop policy if exists images_insert_diary_author on public.diary_images;
create policy images_insert_diary_author
  on public.diary_images for insert
  with check (
    exists (
      select 1 from public.diary_entries d
      where d.id = diary_id and d.author_id = auth.uid()
    )
  );

drop policy if exists images_delete_diary_author on public.diary_images;
create policy images_delete_diary_author
  on public.diary_images for delete
  using (
    exists (
      select 1 from public.diary_entries d
      where d.id = diary_id and d.author_id = auth.uid()
    )
  );

-- -------------------------------------------------------------
-- RLS：diary_annotations
-- -------------------------------------------------------------
alter table public.diary_annotations enable row level security;

drop policy if exists annotations_select_member on public.diary_annotations;
create policy annotations_select_member
  on public.diary_annotations for select
  using (
    exists (
      select 1 from public.diary_entries d
      where d.id = diary_id
        and public.is_space_member(d.space_id, auth.uid())
    )
  );

drop policy if exists annotations_insert_member on public.diary_annotations;
create policy annotations_insert_member
  on public.diary_annotations for insert
  with check (
    author_id = auth.uid()
    and exists (
      select 1 from public.diary_entries d
      where d.id = diary_id
        and public.is_space_member(d.space_id, auth.uid())
    )
  );

-- V1 批注不可修改/删除：不建 update/delete policy

-- -------------------------------------------------------------
-- RPC：create_space（创建空间 + 生成邀请码 + 创建者成为第一名成员，单事务）
-- -------------------------------------------------------------
create or replace function public.create_space(p_name text)
returns public.spaces
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code  text;
  v_space public.spaces;
begin
  if p_name is null or btrim(p_name) = '' then
    raise exception 'SPACE_NAME_REQUIRED';
  end if;

  -- 8 位大写字母数字邀请码；撞唯一约束则重试
  for i in 1..10 loop
    v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    begin
      insert into public.spaces (name, invite_code, created_by)
      values (btrim(p_name), v_code, auth.uid())
      returning * into v_space;
      exit;
    exception when unique_violation then
      if i = 10 then raise; end if;
    end;
  end loop;

  insert into public.space_memberships (space_id, user_id)
  values (v_space.id, auth.uid());

  return v_space;
end;
$$;

-- -------------------------------------------------------------
-- RPC：join_space_by_invite_code
-- 验证邀请码 → 已加入判断 → 人数 < 10 → 创建 membership（单事务）
-- FOR UPDATE 串行化同一空间的并发加入，保证人数上限不被并发击穿
-- -------------------------------------------------------------
create or replace function public.join_space_by_invite_code(p_invite_code text)
returns public.space_memberships
language plpgsql
security definer
set search_path = public
as $$
declare
  v_space        public.spaces;
  v_member_count integer;
  v_membership   public.space_memberships;
begin
  select * into v_space
  from public.spaces
  where invite_code = upper(btrim(p_invite_code))
  for update;

  if not found then
    raise exception 'INVITE_CODE_NOT_FOUND';
  end if;

  if exists (
    select 1 from public.space_memberships
    where space_id = v_space.id and user_id = auth.uid()
  ) then
    raise exception 'ALREADY_MEMBER';
  end if;

  select count(*) into v_member_count
  from public.space_memberships
  where space_id = v_space.id;

  if v_member_count >= 10 then
    raise exception 'SPACE_FULL';
  end if;

  insert into public.space_memberships (space_id, user_id)
  values (v_space.id, auth.uid())
  returning * into v_membership;

  return v_membership;
end;
$$;

-- -------------------------------------------------------------
-- Realtime
-- REPLICA IDENTITY FULL：UPDATE/DELETE 事件才能携带完整旧行数据
-- -------------------------------------------------------------
alter table public.diary_entries replica identity full;
alter table public.diary_annotations replica identity full;
alter table public.space_memberships replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.diary_entries;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.diary_annotations;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.space_memberships;
exception when duplicate_object then null;
end $$;
