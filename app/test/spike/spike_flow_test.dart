import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_space_app/core/app_error.dart';
import 'package:shared_space_app/features/diary/diary_repository.dart';
import 'package:shared_space_app/features/space/space_repository.dart';
import 'package:shared_space_app/features/space/space_service.dart';

import 'spike_support.dart';

/// Spike-01 核心闭环验证（docs/TEST_PLAN.md §12.3 的 7 条成功标准）。
///
/// 运行方式（需要真实 Supabase 项目）：
///   flutter test test/spike/spike_flow_test.dart \
///     --dart-define=SUPABASE_URL=... \
///     --dart-define=SUPABASE_ANON_KEY=...
/// 注意：不要在这里调用 TestWidgetsFlutterBinding.ensureInitialized()——
/// 它会接管 dart:io HttpClient 并把所有真实网络请求 mock 成 400。
/// 本套件是纯网络集成测试，需要真实 HTTP/WebSocket。
void main() {

  late SupabaseClient? admin;
  late TestAccount userA;
  late TestAccount userB;
  late Map<String, dynamic> spaceA;
  late Map<String, dynamic> diaryA1;
  final cleanupUserIds = <String>{};
  final cleanupSpaceIds = <String>[];

  setUpAll(() async {
    if (!SpikeEnv.isConfigured) {
      fail('未配置连接信息：请通过 --dart-define=SUPABASE_URL=... / '
          'SUPABASE_ANON_KEY=... 运行，或设置同名环境变量。');
    }
    admin = SpikeEnv.hasServiceRole
        ? SupabaseClient(
            SpikeEnv.url,
            SpikeEnv.serviceRoleKey,
            authOptions:
                const AuthClientOptions(authFlowType: AuthFlowType.implicit),
          )
        : null;
    // 成功标准 1：两个账号可以注册（真实 signUp 流程，Confirm email 已关闭）。
    userA = await TestAccount.register('a', admin: admin);
    userB = await TestAccount.register('b', admin: admin);
    cleanupUserIds.addAll([userA.userId, userB.userId]);
  });

  tearDownAll(() async {
    if (admin != null) {
      // 完整清理：删空间（级联删除日记/成员）→ 删测试用户。
      for (final sid in cleanupSpaceIds) {
        try {
          await admin!.from('spaces').delete().eq('id', sid);
        } catch (_) {}
      }
      for (final uid in cleanupUserIds) {
        try {
          await admin!.auth.admin.deleteUser(uid);
        } catch (_) {}
      }
    } else {
      // 无 service_role：尽力删除 A/B 自己的日记，其余数据请用户跑
      // tools/cleanup.sql（删除 spike-% 用户后级联清除）。
      for (final account in [userA, userB]) {
        try {
          final mine = await account.client
              .from('diary_entries')
              .select('id')
              .eq('author_id', account.userId);
          for (final row in mine) {
            await account.client
                .from('diary_entries')
                .delete()
                .eq('id', row['id']);
          }
        } catch (_) {}
      }
      // ignore: avoid_print
      print('提示：本次测试数据未完全清理（无 service_role）。'
          '如需清空，请在 Supabase SQL Editor 执行 tools/cleanup.sql。');
    }
  });

  group('AUTH', () {
    test('AUTH-001 两个账号注册并登录成功，profile 由 DB trigger 自动创建',
        () async {
      expect(userA.client.auth.currentUser, isNotNull);
      expect(userB.client.auth.currentUser, isNotNull);

      final profileA = await userA.client
          .from('profiles')
          .select()
          .eq('id', userA.userId)
          .single();
      expect(profileA['nickname'], isNotEmpty);
      expect(profileA['color'], isNotEmpty);
    });
  });

  group('SPACE', () {
    test('SPACE-001 A 创建空间：Space + 邀请码 + 创建者成为第一名成员',
        () async {
      // 成功标准 2：A 能创建 Space。
      final repo = SpaceRepository(userA.client);
      spaceA = await repo.createSpace('测试空间A');
      cleanupSpaceIds.add(spaceA['id'] as String);

      expect(spaceA['name'], '测试空间A');
      expect(spaceA['created_by'], userA.userId);

      final code = spaceA['invite_code'] as String;
      expect(code.length, 8, reason: '邀请码应为 8 位');
      expect(RegExp(r'^[A-Z0-9]{8}$').hasMatch(code), isTrue,
          reason: '邀请码应为大写字母数字');

      final members = await repo.getMembers(spaceA['id'] as String);
      expect(members.length, 1);
      expect(members.first['id'], userA.userId);
    });

    test('SPACE-002 B 通过邀请码加入，两人同属一个 Space', () async {
      // 成功标准 3：B 能通过邀请码加入。
      final service = SpaceService(SpaceRepository(userB.client));
      final membership =
          await service.joinByInviteCode(spaceA['invite_code'] as String);
      expect(membership['space_id'], spaceA['id']);
      expect(membership['user_id'], userB.userId);

      // 成功标准 4：两个客户端（两台设备）都显示同一 Space。
      final members =
          await SpaceRepository(userA.client).getMembers(spaceA['id'] as String);
      expect(members.map((m) => m['id']).toSet(),
          {userA.userId, userB.userId});

      final aSpaces = await SpaceRepository(userA.client).getMySpaces();
      final bSpaces = await SpaceRepository(userB.client).getMySpaces();
      expect(aSpaces.any((s) => s['id'] == spaceA['id']), isTrue);
      expect(bSpaces.any((s) => s['id'] == spaceA['id']), isTrue);
    });

    test('SPACE-003 B 重复加入 → 不新增第二条 membership', () async {
      final service = SpaceService(SpaceRepository(userB.client));
      await expectLater(
        service.joinByInviteCode(spaceA['invite_code'] as String),
        throwsA(isA<SpaceJoinError>()
            .having((e) => e.kind, 'kind', SpaceJoinErrorKind.alreadyMember)),
      );
      final members =
          await SpaceRepository(userA.client).getMembers(spaceA['id'] as String);
      expect(members.length, 2);
    });

    test('SPACE-004 第 11 人加入被服务端拒绝（2–10 人限制）', () async {
      // C1..C8 公开注册并加入 → 共 10 人。
      for (var i = 1; i <= 8; i++) {
        final c = await TestAccount.register('c$i', admin: admin);
        cleanupUserIds.add(c.userId);
        await SpaceService(SpaceRepository(c.client))
            .joinByInviteCode(spaceA['invite_code'] as String);
      }
      final members =
          await SpaceRepository(userA.client).getMembers(spaceA['id'] as String);
      expect(members.length, 10);

      // 第 11 人 → SPACE_FULL。
      final d = await TestAccount.register('d', admin: admin);
      cleanupUserIds.add(d.userId);
      await expectLater(
        SpaceService(SpaceRepository(d.client))
            .joinByInviteCode(spaceA['invite_code'] as String),
        throwsA(isA<SpaceJoinError>()
            .having((e) => e.kind, 'kind', SpaceJoinErrorKind.spaceFull)),
      );
      final after =
          await SpaceRepository(userA.client).getMembers(spaceA['id'] as String);
      expect(after.length, 10, reason: '人数上限不得被突破');
    }, timeout: Timeout(Duration(minutes: 4)));
  });

  group('DIARY', () {
    test('DIARY-001 A 创建日记，作者/时间由服务器确定，B 能读到', () async {
      // 成功标准 5：A 创建 Diary。
      final repo = DiaryRepository(userA.client);
      diaryA1 = await repo.createDiary(
        spaceId: spaceA['id'] as String,
        diaryDate: DateTime.now(),
        content: '今天的测试日记',
        weather: 'sunny',
        mood: 'happy',
      );

      expect(diaryA1['author_id'], userA.userId);
      expect(diaryA1['space_id'], spaceA['id']);
      expect(diaryA1['created_at'], isNotNull);
      expect(diaryA1['updated_at'], isNotNull);
      expect(diaryA1['weather'], 'sunny');
      expect(diaryA1['mood'], 'happy');

      final bView =
          await DiaryRepository(userB.client).getDiary(diaryA1['id'] as String);
      expect(bView['content'], '今天的测试日记');
    });

    test('DIARY-002 修改日记：created_at 不变，updated_at 更新', () async {
      final repo = DiaryRepository(userA.client);
      final before = await repo.getDiary(diaryA1['id'] as String);
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      final after = await repo.updateDiary(
        diaryA1['id'] as String,
        content: '修改后的内容',
        weather: 'cloudy',
        mood: 'calm',
      );

      expect(after['created_at'], before['created_at']);
      expect(
        DateTime.parse(after['updated_at'] as String)
            .isAfter(DateTime.parse(before['updated_at'] as String)),
        isTrue,
      );
      expect(after['content'], '修改后的内容');
    });

    test('DIARY-003 补写过去日记：diary_date 可改，created_at 不变', () async {
      final repo = DiaryRepository(userA.client);
      final before = await repo.getDiary(diaryA1['id'] as String);
      final past = DateTime.now().subtract(const Duration(days: 10));

      final after = await repo.updateDiary(diaryA1['id'] as String,
          diaryDate: formatDiaryDate(past));

      expect(after['diary_date'], formatDiaryDate(past));
      expect(after['created_at'], before['created_at']);

      // getByDateRange 按新日期命中（月/周视图数据源）。
      final ranged = await repo.getByDateRange(
        spaceA['id'] as String,
        past.subtract(const Duration(days: 1)),
        past.add(const Duration(days: 1)),
      );
      expect(ranged.any((r) => r['id'] == diaryA1['id']), isTrue);
    });

    test('DIARY-004 A 删除自己的日记 → 成功', () async {
      final repo = DiaryRepository(userA.client);
      final temp = await repo.createDiary(
        spaceId: spaceA['id'] as String,
        diaryDate: DateTime.now(),
        content: '待删除的日记',
        weather: 'rain',
        mood: 'sad',
      );
      await repo.deleteDiary(temp['id'] as String);
      await expectLater(repo.getDiary(temp['id'] as String), throwsA(anything));
    });

    test('DIARY-005 B 不能修改/删除 A 的日记（RLS 拒绝）', () async {
      final aRepo = DiaryRepository(userA.client);

      // B 的 update 被 RLS 静默拒绝（0 行生效，不抛错也不改数据）。
      await userB.client
          .from('diary_entries')
          .update({'content': 'B 想篡改'})
          .eq('id', diaryA1['id']);
      var after = await aRepo.getDiary(diaryA1['id'] as String);
      expect(after['content'], '修改后的内容', reason: 'B 的修改不得生效');

      // B 的 delete 同样被 RLS 静默拒绝。
      await userB.client
          .from('diary_entries')
          .delete()
          .eq('id', diaryA1['id']);
      after = await aRepo.getDiary(diaryA1['id'] as String);
      expect(after, isNotNull, reason: 'B 的删除不得生效');
    });
  });

  group('SECURITY（空间隔离）', () {
    late Map<String, dynamic> spaceB2;

    test('SECURITY-001 Space A 用户读不到 Space B 的任何数据', () async {
      // 成功标准 7 的数据基础：B 再建一个自己的空间。
      spaceB2 = await SpaceRepository(userB.client).createSpace('测试空间B');
      cleanupSpaceIds.add(spaceB2['id'] as String);
      final diaryB = await DiaryRepository(userB.client).createDiary(
        spaceId: spaceB2['id'] as String,
        diaryDate: DateTime.now(),
        content: 'B 空间的私密日记',
        weather: 'rain',
        mood: 'sad',
      );

      // A 按空间查询 → 空。
      final aReads = await DiaryRepository(userA.client).getByDateRange(
        spaceB2['id'] as String,
        DateTime(2020),
        DateTime(2030),
      );
      expect(aReads, isEmpty);

      // A 直接查 Space B 的行 → 空。
      final aSpaces = await userA.client
          .from('spaces')
          .select()
          .eq('id', spaceB2['id'] as String);
      expect(aSpaces, isEmpty);

      // A 尝试向 Space B 插入日记 → 服务端抛 RLS 拒绝（42501）。
      // 注：PostgREST 对 INSERT 的 RLS 拒绝是显式报错，对 UPDATE/DELETE 是静默 0 行。
      await expectLater(
        userA.client.from('diary_entries').insert({
          'space_id': spaceB2['id'],
          'diary_date': '2026-08-10',
          'content': '入侵尝试',
          'weather': 'sunny',
          'mood': 'happy',
        }),
        throwsA(isA<PostgrestException>()
            .having((e) => e.code, 'code', '42501')
            .having((e) => e.message, 'message',
                contains('row-level security'))),
      );
      final count = await userB.client
          .from('diary_entries')
          .select('id')
          .eq('space_id', spaceB2['id'] as String);
      expect(count.length, 1, reason: 'Space B 仍只有 B 自己那一条日记');

      // A 也读不到那条日记。
      final leak = await userA.client
          .from('diary_entries')
          .select('id')
          .eq('id', diaryB['id'] as String);
      expect(leak, isEmpty);
    });
  });

  group('REALTIME', () {
    test('REALTIME-001/002/003 B 不手动刷新即可看到 A 的增/改/删', () async {
      // 成功标准 6：B 不手动刷新即可看到。
      final bRepo = DiaryRepository(userB.client);
      final aRepo = DiaryRepository(userA.client);

      // 订阅 + 探测，最多两轮：Supabase Realtime 偶发「channel join 成功
      // 但服务端不推送 postgres_changes 事件」（已多次实测，重建 channel
      // 后恢复）。这是服务端已知 flake，测试用重建通道重试吸收；
      // 产品侧不受影响：任何事件都会触发整页重拉，用户重进页面即恢复。
      List<DiaryChange> events = [];
      StreamSubscription<DiaryChange> sub =
          await _subscribe(bRepo, spaceA['id'] as String, events);
      var probe = await aRepo.createDiary(
        spaceId: spaceA['id'] as String,
        diaryDate: DateTime.now(),
        content: '通道预热探测1',
        weather: 'sunny',
        mood: 'happy',
      );
      var ok = await waitUntil(
        () => events.any(
            (e) => e.eventType == 'insert' && e.newRow['id'] == probe['id']),
        timeout: const Duration(seconds: 30),
      );
      if (!ok) {
        // 第一轮通道无事件：重建通道重试一轮
        await sub.cancel();
        events = [];
        sub = await _subscribe(bRepo, spaceA['id'] as String, events);
        probe = await aRepo.createDiary(
          spaceId: spaceA['id'] as String,
          diaryDate: DateTime.now(),
          content: '通道预热探测2',
          weather: 'sunny',
          mood: 'happy',
        );
        await waitFor(
          () => events.any(
              (e) => e.eventType == 'insert' && e.newRow['id'] == probe['id']),
          timeout: const Duration(seconds: 45),
        );
      }

      // INSERT
      final created = await aRepo.createDiary(
        spaceId: spaceA['id'] as String,
        diaryDate: DateTime.now(),
        content: '实时新增测试',
        weather: 'sunny',
        mood: 'happy',
      );
      await waitFor(() => events.any((e) =>
          e.eventType == 'insert' && e.newRow['id'] == created['id']));

      // UPDATE
      await aRepo.updateDiary(created['id'] as String, content: '实时修改测试');
      await waitFor(() => events.any((e) =>
          e.eventType == 'update' &&
          e.newRow['id'] == created['id'] &&
          e.newRow['content'] == '实时修改测试'));

      // DELETE
      await aRepo.deleteDiary(created['id'] as String);
      await waitFor(() => events.any((e) =>
          e.eventType == 'delete' && e.oldRow['id'] == created['id']));

      await sub.cancel();
    }, timeout: Timeout(Duration(minutes: 4)));
  });
}

/// 订阅指定空间日记事件并等待 channel ready。
Future<StreamSubscription<DiaryChange>> _subscribe(
  DiaryRepository bRepo,
  String spaceId,
  List<DiaryChange> events,
) async {
  final subscription = bRepo.watchDiaryChanges(spaceId);
  final sub = subscription.stream.listen(events.add);
  await subscription.ready.timeout(const Duration(seconds: 20));
  return sub;
}
