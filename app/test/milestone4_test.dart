import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_space_app/features/annotation/annotation_repository.dart';
import 'package:shared_space_app/features/diary/diary_repository.dart';
import 'package:shared_space_app/features/space/space_repository.dart';
import 'package:shared_space_app/features/space/space_service.dart';

import 'spike/spike_support.dart';

/// V1 Milestone 4（划线批注）真实环境集成测试。
/// 前置：Supabase 已应用 001/002 migration（diary_annotations 在 001）。
///
/// 运行：
///   flutter test test/milestone4_test.dart \
///     --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
void main() {
  late TestAccount userA; // 日记作者
  late TestAccount userB; // 同空间成员
  late TestAccount outsider;
  late Map<String, dynamic> space;
  late Map<String, dynamic> diary;

  const content = '今天去了图书馆，读完了一本很喜欢的书，傍晚下了一场雨。';

  setUpAll(() async {
    if (!SpikeEnv.isConfigured) {
      fail('未配置连接信息：请通过 --dart-define=SUPABASE_URL=... / '
          'SUPABASE_ANON_KEY=... 运行，或设置同名环境变量。');
    }
    userA = await TestAccount.register('m4a', admin: null);
    userB = await TestAccount.register('m4b', admin: null);
    outsider = await TestAccount.register('m4x', admin: null);
    space = await SpaceRepository(userA.client).createSpace('里程碑四空间');
    await SpaceService(SpaceRepository(userB.client))
        .joinByInviteCode(space['invite_code'] as String);
    diary = await DiaryRepository(userA.client).createDiary(
      spaceId: space['id'] as String,
      diaryDate: DateTime.now(),
      content: content,
      weather: 'sunny',
      mood: 'happy',
    );
  });

  test('ANNO-001 B 对 A 的日记创建批注，A 可读（含昵称/颜色）', () async {
    final repo = AnnotationRepository(userB.client);
    final anno = await repo.create(
      diaryId: diary['id'] as String,
      startOffset: 4,
      endOffset: 7,
      selectedText: '图书馆',
      comment: '我也喜欢这里',
    );
    expect(anno['author_id'], userB.userId);
    expect(anno['start_offset'], 4);
    expect(anno['end_offset'], 7);
    expect(anno['selected_text'], '图书馆');
    expect(anno['comment'], '我也喜欢这里');
    expect(anno['created_at'], isNotNull);

    // A（作者）能看到 B 的批注，且带 B 的昵称/颜色
    final seenByA = await AnnotationRepository(userA.client)
        .getByDiary(diary['id'] as String);
    final found = seenByA.firstWhere((a) => a['id'] == anno['id']);
    final profile = found['profiles'] as Map<String, dynamic>;
    expect(profile['nickname'], isNotEmpty);
    expect(profile['color'], isNotEmpty);
  });

  test('ANNO-002 局外人创建批注 → RLS 拒绝（42501）', () async {
    await expectLater(
      AnnotationRepository(outsider.client).create(
        diaryId: diary['id'] as String,
        startOffset: 4,
        endOffset: 7,
        selectedText: '图书馆',
        comment: '入侵批注',
      ),
      throwsA(isA<PostgrestException>()
          .having((e) => e.code, 'code', '42501')
          .having((e) => e.message, 'message',
              contains('row-level security'))),
    );
    // 批注数不变
    final rows = await AnnotationRepository(userA.client)
        .getByDiary(diary['id'] as String);
    expect(rows.every((r) => r['comment'] != '入侵批注'), isTrue);
  });

  test('ANNO-003 批注作者由服务器确定（伪造 author_id 被覆盖）', () async {
    final row = await userB.client
        .from('diary_annotations')
        .insert({
          'diary_id': diary['id'],
          'start_offset': 8,
          'end_offset': 10,
          'selected_text': '读完',
          'comment': '伪造测试',
          'author_id': userA.userId, // 试图伪装成 A
        })
        .select()
        .single();
    expect(row['author_id'], userB.userId,
        reason: 'trigger 必须覆盖为实际登录用户 B');
  });

  test('ANNO-004 批注 Realtime：B 订阅，A 创建批注后 B 收到事件', () async {
    final bRepo = AnnotationRepository(userB.client);
    final aRepo = AnnotationRepository(userA.client);
    final events = <AnnotationChange>[];

    var subscription = bRepo.watchChanges(diary['id'] as String);
    var sub = subscription.stream.listen(events.add);
    await subscription.ready.timeout(const Duration(seconds: 20));

    Future<bool> probe(String tag) async {
      final anno = await aRepo.create(
        diaryId: diary['id'] as String,
        startOffset: 11,
        endOffset: 13,
        selectedText: '一本',
        comment: tag,
      );
      return waitUntil(
        () => events.any(
            (e) => e.eventType == 'insert' && e.newRow['id'] == anno['id']),
        timeout: const Duration(seconds: 30),
      );
    }

    var ok = await probe('探测1');
    if (!ok) {
      // 已知 flake：重建通道重试一轮（同 Spike 方案）
      await sub.cancel();
      events.clear();
      subscription = bRepo.watchChanges(diary['id'] as String);
      sub = subscription.stream.listen(events.add);
      await subscription.ready.timeout(const Duration(seconds: 20));
      ok = await probe('探测2');
    }
    expect(ok, isTrue, reason: '批注 Realtime 事件必须到达');
    await sub.cancel();
  }, timeout: Timeout(Duration(minutes: 4)));
}
