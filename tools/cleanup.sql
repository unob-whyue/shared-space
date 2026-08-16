-- =============================================================
-- Spike 测试数据清理（无 service_role 时的兜底清理）。
-- 测试结束后，在 Supabase Dashboard → SQL Editor 粘贴执行一次。
-- 原理：删除 spike-* 测试用户 → profiles 级联 → 空间（created_by
-- 级联）→ membership / 日记 / 图片 / 批注 全部级联清除。
-- =============================================================

delete from auth.users
where email like 'spike-%@%';

-- 若测试中途异常残留了孤儿空间（创建者已删但空间仍在的情况
-- 不会发生——created_by 是级联删除），以下兜底可选择性执行：
-- delete from public.spaces where name like '测试空间%';
