-- =============================================================
-- 本地验证专用：模拟 Supabase 环境的最小部件。
-- 仅用于 tools/db_verify 的本地 Postgres 验证，
-- 严禁在真实 Supabase 项目执行本文件。
-- =============================================================

create schema if not exists auth;

create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text
);

-- 模拟 Supabase 的 auth.uid()：从会话 GUC 读取当前用户
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

-- 模拟 Supabase 默认存在的 realtime publication
do $$
begin
  create publication supabase_realtime;
exception when duplicate_object then null;
end $$;

-- 模拟 PostgREST 的数据库角色（非表 owner，RLS 对其生效）
do $$
begin
  if not exists (select from pg_roles where rolname = 'web_user') then
    create role web_user login;
  end if;
end $$;
