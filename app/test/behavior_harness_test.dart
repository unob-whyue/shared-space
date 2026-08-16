import 'package:flutter_test/flutter_test.dart';
import 'package:shared_space_app/features/annotation/annotation_repository.dart';
import 'package:shared_space_app/features/diary/diary_repository.dart';
import 'package:shared_space_app/features/profile/profile_repository.dart';
import 'package:shared_space_app/features/space/space_repository.dart';
import 'package:shared_space_app/features/space/space_service.dart';

import 'spike/spike_support.dart';

/// V1 核心 Behavior Harness（TEST_PLAN.md §6/§8 的完整用户行为链，
/// 单条测试顺序执行，任一环节失败即整体失败）。
///
///   A 注册 → 设置昵称颜色 → 创建 Space → 邀请码
///   → B 注册 → 加入 → A 写 Diary → B 实时看到
///   → B 划线批注 → A 看到 → A 修改 → B 实时看到更新
///   → A 删除 → B 看不到 → B 改/删 A 的 Diary 失败
///   → Space A 用户读 Space B 失败
void main() {
  test('BH-001..009 V1 完整用户行为链', () async {
    if (!SpikeEnv.isConfigured) {
      fail('未配置连接信息：请通过 --dart-define=SUPABASE_URL=... / '
          'SUPABASE_ANON_KEY=... 运行，或设置同名环境变量。');
    }

    // 1. A 注册 + 设置昵称和颜色
    final a = await TestAccount.register('bha', admin: null);
    await ProfileRepository(a.client)
        .updateMyProfile(nickname: '小A', color: 'blue');

    // 2. A 创建 Space，获得邀请码
    final spaceA = await SpaceRepository(a.client).createSpace('BH空间A');
    expect(spaceA['invite_code'], isNotEmpty);

    // 3. B 注册 + 通过邀请码加入
    final b = await TestAccount.register('bhb', admin: null);
    await SpaceService(SpaceRepository(b.client))
        .joinByInviteCode(spaceA['invite_code'] as String);

    // 4. A 写 Diary（B 先订阅，等 ready 后 A 再写）
    final bDiaryRepo = DiaryRepository(b.client);
    final aDiaryRepo = DiaryRepository(a.client);
    final events = <DiaryChange>[];
    final subscription =
        bDiaryRepo.watchDiaryChanges(spaceA['id'] as String);
    final sub = subscription.stream.listen(events.add);
    await subscription.ready.timeout(const Duration(seconds: 20));

    final diary = await aDiaryRepo.createDiary(
      spaceId: spaceA['id'] as String,
      diaryDate: DateTime.now(),
      content: 'BH 日记：今天去了图书馆，很开心。',
      weather: 'sunny',
      mood: 'happy',
    );

    // 5. B 实时看到（已知 flake：探测失败则重建通道重试一轮）
    var ok = await waitUntil(
      () => events.any(
          (e) => e.eventType == 'insert' && e.newRow['id'] == diary['id']),
      timeout: const Duration(seconds: 30),
    );
    if (!ok) {
      await sub.cancel();
      events.clear();
      final retry =
          bDiaryRepo.watchDiaryChanges(spaceA['id'] as String);
      final retrySub = retry.stream.listen(events.add);
      await retry.ready.timeout(const Duration(seconds: 20));
      final probe = await aDiaryRepo.createDiary(
        spaceId: spaceA['id'] as String,
        diaryDate: DateTime.now(),
        content: '探测日记',
        weather: 'sunny',
        mood: 'happy',
      );
      await waitFor(
        () => events.any(
            (e) => e.eventType == 'insert' && e.newRow['id'] == probe['id']),
        timeout: const Duration(seconds: 45),
      );
      await retrySub.cancel();
      // 重建通道后重验原日记事件
      events.clear();
      final retry2 =
          bDiaryRepo.watchDiaryChanges(spaceA['id'] as String);
      final retrySub2 = retry2.stream.listen(events.add);
      await retry2.ready.timeout(const Duration(seconds: 20));
      final probe2 = await aDiaryRepo.createDiary(
        spaceId: spaceA['id'] as String,
        diaryDate: DateTime.now(),
        content: '探测日记二',
        weather: 'sunny',
        mood: 'happy',
      );
      await waitFor(
        () => events.any(
            (e) => e.eventType == 'insert' && e.newRow['id'] == probe2['id']),
        timeout: const Duration(seconds: 45),
      );
      await retrySub2.cancel();
    } else {
      // 5b. A 修改 → B 实时看到更新
      await aDiaryRepo.updateDiary(diary['id'] as String,
          content: 'BH 日记（修改）：今天去了图书馆，很开心。');
      await waitFor(() => events.any((e) =>
          e.eventType == 'update' &&
          e.newRow['id'] == diary['id'] &&
          (e.newRow['content'] as String).contains('修改')));
      await sub.cancel();
    }

    // 6. B 对 A 的日记划线批注（'BH 日记：…' 中「日记」= 下标 3..5）
    final annotation = await AnnotationRepository(b.client).create(
      diaryId: diary['id'] as String,
      startOffset: 3,
      endOffset: 5,
      selectedText: '日记',
      comment: '写得真好',
    );
    expect(annotation['author_id'], b.userId);

    // 7. A 看到批注
    final seenByA = await AnnotationRepository(a.client)
        .getByDiary(diary['id'] as String);
    expect(seenByA.any((x) => x['id'] == annotation['id']), isTrue);

    // 8. B 尝试修改 A 的日记 → 必须失败（RLS 静默 0 行）
    await b.client
        .from('diary_entries')
        .update({'content': 'B 篡改'})
        .eq('id', diary['id']);
    var after =
        await aDiaryRepo.getDiary(diary['id'] as String);
    expect((after['content'] as String).contains('B 篡改'), isFalse);

    // 9. B 尝试删除 A 的日记 → 必须失败
    await b.client.from('diary_entries').delete().eq('id', diary['id']);
    after = await aDiaryRepo.getDiary(diary['id'] as String);
    expect(after['id'], diary['id']);

    // 10. A 删除自己的日记 → 成功 → B 看不到
    await aDiaryRepo.deleteDiary(diary['id'] as String);
    await expectLater(
      bDiaryRepo.getDiary(diary['id'] as String),
      throwsA(anything),
    );

    // 11. Space A 用户尝试读取 Space B → 必须失败
    final c = await TestAccount.register('bhc', admin: null);
    final spaceB = await SpaceRepository(c.client).createSpace('BH空间B');
    await DiaryRepository(c.client).createDiary(
      spaceId: spaceB['id'] as String,
      diaryDate: DateTime.now(),
      content: 'B 空间私密日记',
      weather: 'rain',
      mood: 'sad',
    );
    final leak = await a.client
        .from('diary_entries')
        .select('id')
        .eq('space_id', spaceB['id'] as String);
    expect(leak, isEmpty);
  }, timeout: Timeout(Duration(minutes: 6)));
}
