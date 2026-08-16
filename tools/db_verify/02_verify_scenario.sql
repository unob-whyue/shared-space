-- =============================================================
-- 本地验证专用：核心业务场景断言。
-- 必须以 web_user 身份执行（RLS 才会生效）。
-- 任一断言失败会 raise exception 并以非零退出。
-- 执行顺序：00_mock → migration → 03_grants → 01_seed → 本文件
-- =============================================================

do $$
declare
  a_id  uuid := '11111111-1111-4111-8111-111111111111';
  b_id  uuid := '22222222-2222-4222-8222-222222222222';
  d_id  uuid := 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  x_id  uuid := '99999999-9999-4999-8999-999999999999';
  c_ids uuid[] := array[
    'c0000001-0000-4000-8000-000000000001','c0000002-0000-4000-8000-000000000002',
    'c0000003-0000-4000-8000-000000000003','c0000004-0000-4000-8000-000000000004',
    'c0000005-0000-4000-8000-000000000005','c0000006-0000-4000-8000-000000000006',
    'c0000007-0000-4000-8000-000000000007','c0000008-0000-4000-8000-000000000008']::uuid[];
  v_space   record;
  v_code    text;
  v_diary   record;
  v_after   record;
  v_anno    record;
  v_created timestamptz;
  v_updated timestamptz;
  n         integer;
  i         integer;
begin
  -- ---------- 1. A 创建空间 ----------
  perform set_config('request.jwt.claim.sub', a_id::text, true);
  select * into v_space from public.create_space('测试空间A');
  v_code := v_space.invite_code;
  if v_space.created_by <> a_id then raise exception 'FAIL 1: created_by 不是 A'; end if;
  if length(v_code) <> 8 then raise exception 'FAIL 1: 邀请码长度 %，应为 8', length(v_code); end if;
  select count(*) into n from public.space_memberships where space_id = v_space.id;
  if n <> 1 then raise exception 'FAIL 1: 创建者未自动成为第一名成员'; end if;
  raise notice 'PASS 1: create_space（空间+邀请码+创建者成员，单事务）';

  -- ---------- 2. B 邀请码加入；3. 重复加入被拒 ----------
  perform set_config('request.jwt.claim.sub', b_id::text, true);
  perform public.join_space_by_invite_code(v_code);
  select count(*) into n from public.space_memberships
  where space_id = v_space.id and user_id = b_id;
  if n <> 1 then raise exception 'FAIL 2: B 加入失败'; end if;

  begin
    perform public.join_space_by_invite_code(v_code);
    raise exception 'FAIL 3: 重复加入未报错';
  exception when raise_exception then
    if sqlerrm not like '%ALREADY_MEMBER%' then raise; end if;
  end;
  select count(*) into n from public.space_memberships
  where space_id = v_space.id and user_id = b_id;
  if n <> 1 then raise exception 'FAIL 3: 出现了第二条 membership'; end if;
  raise notice 'PASS 2/3: 邀请码加入 + 重复加入被拒（ALREADY_MEMBER）';

  -- ---------- 4. 10 人上限（SPACE-004） ----------
  for i in 1..8 loop
    perform set_config('request.jwt.claim.sub', c_ids[i]::text, true);
    perform public.join_space_by_invite_code(v_code);
  end loop;
  select count(*) into n from public.space_memberships where space_id = v_space.id;
  if n <> 10 then raise exception 'FAIL 4: 成员数应为 10，实际 %', n; end if;
  perform set_config('request.jwt.claim.sub', d_id::text, true);
  begin
    perform public.join_space_by_invite_code(v_code);
    raise exception 'FAIL 4: 第 11 人未被拒绝';
  exception when raise_exception then
    if sqlerrm not like '%SPACE_FULL%' then raise; end if;
  end;
  select count(*) into n from public.space_memberships where space_id = v_space.id;
  if n <> 10 then raise exception 'FAIL 4: 人数上限被突破（实际 %）', n; end if;
  raise notice 'PASS 4: 2–10 人上限由服务端强制（RPC 原子）';

  -- ---------- 5. 无效邀请码 ----------
  begin
    perform public.join_space_by_invite_code('00000000');
    raise exception 'FAIL 5: 无效邀请码未报错';
  exception when raise_exception then
    if sqlerrm not like '%INVITE_CODE_NOT_FOUND%' then raise; end if;
  end;
  raise notice 'PASS 5: 无效邀请码被拒（INVITE_CODE_NOT_FOUND）';

  -- ---------- 6. 伪造 author_id 被服务器覆盖 ----------
  perform set_config('request.jwt.claim.sub', a_id::text, true);
  insert into public.diary_entries (space_id, diary_date, content, weather, mood, author_id)
  values (v_space.id, '2026-08-10', 'A 的日记', 'sunny', 'happy', d_id)
  returning id, author_id, created_at into v_diary;
  if v_diary.author_id <> a_id then raise exception 'FAIL 6: 伪造的 author_id 未被覆盖为 A'; end if;
  raise notice 'PASS 6: author_id/created_at 由服务器确定（trigger 覆盖伪造值）';

  -- ---------- 7. B 可读；B 改/删被 RLS 拒绝（DIARY-005） ----------
  perform set_config('request.jwt.claim.sub', b_id::text, true);
  select count(*) into n from public.diary_entries where id = v_diary.id;
  if n <> 1 then raise exception 'FAIL 7: B 读不到共享日记'; end if;

  update public.diary_entries set content = 'B 篡改' where id = v_diary.id;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL 7: B 的 update 生效了'; end if;
  delete from public.diary_entries where id = v_diary.id;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL 7: B 的 delete 生效了'; end if;
  raise notice 'PASS 7: B 可读；B 改/删被 RLS 拒绝';

  -- ---------- 8. A 修改：created_at 不变、updated_at 变、space_id 不可改 ----------
  perform set_config('request.jwt.claim.sub', a_id::text, true);
  select created_at, updated_at into v_created, v_updated
  from public.diary_entries where id = v_diary.id;
  perform pg_sleep(0.05);
  update public.diary_entries
  set content = 'A 修改', weather = 'rain', space_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'
  where id = v_diary.id;
  select * into v_after from public.diary_entries where id = v_diary.id;
  if v_after.created_at <> v_created then raise exception 'FAIL 8: created_at 被修改'; end if;
  if not (v_after.updated_at > v_updated) then raise exception 'FAIL 8: updated_at 未更新'; end if;
  if v_after.space_id <> v_space.id then raise exception 'FAIL 8: space_id 被客户端改动了'; end if;
  if v_after.content <> 'A 修改' or v_after.weather <> 'rain' then
    raise exception 'FAIL 8: 合法字段修改未生效';
  end if;
  raise notice 'PASS 8: 修改规则（created_at 不变 / updated_at 变 / space_id 锁定）';

  -- ---------- 9. 局外人 X 完全隔离（SECURITY-001） ----------
  perform set_config('request.jwt.claim.sub', x_id::text, true);
  select count(*) into n from public.spaces;
  if n <> 0 then raise exception 'FAIL 9: 局外人能看到 spaces（实际 %）', n; end if;
  select count(*) into n from public.diary_entries where id = v_diary.id;
  if n <> 0 then raise exception 'FAIL 9: 局外人能读到他人日记'; end if;
  insert into public.diary_entries (space_id, diary_date, content, weather, mood)
  values (v_space.id, '2026-08-10', '入侵尝试', 'sunny', 'happy');
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL 9: 局外人插入日记成功了'; end if;
  select count(*) into n from public.profiles where id = a_id;
  if n <> 0 then raise exception 'FAIL 9: 局外人能读到成员 profile'; end if;
  raise notice 'PASS 9: 空间隔离（SECURITY-001：spaces/日记/profile 均不可见）';

  -- ---------- 10. weather/mood CHECK 约束 ----------
  perform set_config('request.jwt.claim.sub', a_id::text, true);
  begin
    insert into public.diary_entries (space_id, diary_date, content, weather, mood)
    values (v_space.id, '2026-08-11', 'x', 'typhoon', 'happy');
    raise exception 'FAIL 10: 非法天气未被拒绝';
  exception when check_violation then
    null;
  end;
  raise notice 'PASS 10: 枚举 CHECK 约束在数据库层兜底';

  -- ---------- 11. 同日多条日记（无 UNIQUE 限制） ----------
  for i in 1..3 loop
    insert into public.diary_entries (space_id, diary_date, content, weather, mood)
    values (v_space.id, '2026-08-12', '同日第 ' || i || ' 条', 'sunny', 'calm');
  end loop;
  select count(*) into n from public.diary_entries
  where space_id = v_space.id and author_id = a_id and diary_date = '2026-08-12';
  if n <> 3 then raise exception 'FAIL 11: 同日多条日记被限制（实际 %）', n; end if;
  raise notice 'PASS 11: 同一用户同一天可有多条日记';

  -- ---------- 12. diary_date（用户语义）与 created_at（服务器时间）分离 ----------
  insert into public.diary_entries (space_id, diary_date, content, weather, mood)
  values (v_space.id, '2026-01-01', '补写元旦日记', 'snow', 'happy')
  returning id, diary_date, created_at into v_diary;
  if v_diary.diary_date <> '2026-01-01' then raise exception 'FAIL 12: diary_date 错误'; end if;
  if v_diary.created_at < '2026-06-01' then raise exception 'FAIL 12: created_at 不是当前时间'; end if;
  select created_at into v_created from public.diary_entries where id = v_diary.id;
  update public.diary_entries set content = '补写修改' where id = v_diary.id;
  select created_at into v_updated from public.diary_entries where id = v_diary.id;
  if v_updated <> v_created then raise exception 'FAIL 12: 编辑补写日记时 created_at 变了'; end if;
  raise notice 'PASS 12: 补写过去日记（diary_date 可变 / created_at 不变）';

  -- ---------- 13. 批注：作者由服务器确定，局外人被拒 ----------
  perform set_config('request.jwt.claim.sub', b_id::text, true);
  insert into public.diary_annotations (diary_id, start_offset, end_offset, selected_text, comment, author_id)
  values (v_diary.id, 0, 4, '补写元旦', '这条写得好', a_id)
  returning id, author_id into v_anno;
  if v_anno.author_id <> b_id then raise exception 'FAIL 13: 批注作者未被覆盖为 B'; end if;

  perform set_config('request.jwt.claim.sub', x_id::text, true);
  insert into public.diary_annotations (diary_id, start_offset, end_offset, selected_text, comment)
  values (v_diary.id, 0, 4, '补写元旦', '局外人批注');
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL 13: 局外人的批注插入成功了'; end if;
  raise notice 'PASS 13: 批注作者服务器确定 + 局外人被 RLS 拒绝';

  raise notice 'ALL PASS：本地数据库层验证全部通过';
end;
$$;
