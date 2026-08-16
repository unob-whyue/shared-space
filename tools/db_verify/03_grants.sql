-- =============================================================
-- 本地验证专用：授权 web_user 角色（迁移执行后、场景执行前运行，
-- 以超级用户身份）。模拟 PostgREST 的 authenticated 角色处境：
-- 非表 owner → RLS 生效。
-- =============================================================

grant usage on schema public to web_user;
grant select, insert, update, delete on all tables in schema public to web_user;
grant execute on all functions in schema public to web_user;
grant usage on schema auth to web_user;
grant execute on function auth.uid() to web_user;
