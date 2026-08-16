import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_space_app/features/diary/diary_image_repository.dart';
import 'package:shared_space_app/features/diary/diary_repository.dart';
import 'package:shared_space_app/features/space/space_repository.dart';
import 'package:shared_space_app/features/space/space_service.dart';

import 'spike/spike_support.dart';

/// V1 Milestone 2（Diary 闭环 + 图片）真实环境集成测试。
/// 前置：Supabase 已应用 migrations/002_diary_images_storage.sql。
///
/// 运行：
///   flutter test test/milestone2_test.dart \
///     --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
///
/// 1x1 白色 JPEG（合法图片字节，用于上传测试）
const String _tinyJpegBase64 =
    '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJ'
    'C4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAA'
    'AAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AVN//2Q==';

void main() {
  late TestAccount userA; // 空间创建者 + 日记作者
  late TestAccount userB; // 同空间成员
  late TestAccount outsider; // 局外人
  late Map<String, dynamic> space;
  late Map<String, dynamic> diary1;

  setUpAll(() async {
    if (!SpikeEnv.isConfigured) {
      fail('未配置连接信息：请通过 --dart-define=SUPABASE_URL=... / '
          'SUPABASE_ANON_KEY=... 运行，或设置同名环境变量。');
    }
    userA = await TestAccount.register('m2a', admin: null);
    userB = await TestAccount.register('m2b', admin: null);
    outsider = await TestAccount.register('m2x', admin: null);
    space = await SpaceRepository(userA.client).createSpace('里程碑二空间');
    await SpaceService(SpaceRepository(userB.client))
        .joinByInviteCode(space['invite_code'] as String);
  });

  test('DIARY-006 diary_date 默认当天；同日多篇；我的记录读同一份数据',
      () async {
    final repo = DiaryRepository(userA.client);
    final today = DateTime.now();
    final d1 = await repo.createDiary(
      spaceId: space['id'] as String,
      diaryDate: today,
      content: '第一篇',
      weather: 'sunny',
      mood: 'happy',
    );
    diary1 = d1;
    expect(d1['diary_date'], formatDiaryDate(today));
    expect(d1['created_at'], isNotNull);
    expect(d1['updated_at'], isNotNull);

    // 同一天允许多篇
    final d2 = await repo.createDiary(
      spaceId: space['id'] as String,
      diaryDate: today,
      content: '同一天第二篇',
      weather: 'rain',
      mood: 'calm',
    );
    expect(d2['diary_date'], formatDiaryDate(today));

    // 我的记录 = 同一 DiaryEntry（同一 id，不是副本数据）
    final mine = await repo.getMyDiaries();
    final ids = mine.map((m) => m['id']).toSet();
    expect(ids.contains(d1['id']), isTrue);
    expect(ids.contains(d2['id']), isTrue);

    // B 的「我的记录」不含 A 的日记
    final bMine = await DiaryRepository(userB.client).getMyDiaries();
    expect(bMine.any((m) => m['id'] == d1['id']), isFalse);

    // 成员 B 能读到 A 的日记（同 Space 可见）
    final bView = await DiaryRepository(userB.client)
        .getDiary(d1['id'] as String);
    expect(bView['content'], '第一篇');
  });

  test('IMAGE-001/002 上传图片并建立 DiaryImage（sort_order 正确）',
      () async {
    final imageRepo = DiaryImageRepository(userA.client);
    final bytes = base64Decode(_tinyJpegBase64);
    final img1 = await imageRepo.uploadForDiary(
      spaceId: space['id'] as String,
      diaryId: diary1['id'] as String,
      bytes: bytes,
      extension: 'jpg',
      sortOrder: 0,
    );
    final img2 = await imageRepo.uploadForDiary(
      spaceId: space['id'] as String,
      diaryId: diary1['id'] as String,
      bytes: bytes,
      extension: 'jpg',
      sortOrder: 1,
    );
    expect(img1['sort_order'], 0);
    expect(img2['sort_order'], 1);

    final images = await imageRepo.getByDiary(diary1['id'] as String);
    expect(images.length, 2);

    // 成员 B 可读图片行，且能拿到签名 URL
    final bRepo = DiaryImageRepository(userB.client);
    final bImages = await bRepo.getByDiary(diary1['id'] as String);
    expect(bImages.length, 2);
    final url =
        await bRepo.signedUrl(bImages.first['storage_path'] as String);
    expect(url, isNotEmpty);
  });

  test('SECURITY-IMG-001 局外人不能上传/读取该空间图片', () async {
    final imageRepo = DiaryImageRepository(outsider.client);
    final bytes = base64Decode(_tinyJpegBase64);
    // 上传被 Storage 行级策略拒绝
    await expectLater(
      imageRepo.uploadForDiary(
        spaceId: space['id'] as String,
        diaryId: diary1['id'] as String,
        bytes: bytes,
        extension: 'jpg',
        sortOrder: 0,
      ),
      throwsA(anything),
    );
    // 行不可见
    final outsiderSees = await outsider.client
        .from('diary_images')
        .select('id')
        .eq('diary_id', diary1['id']);
    expect(outsiderSees, isEmpty);
    // 签名 URL 也拿不到（读取策略拒绝）
    final bImages = await DiaryImageRepository(userB.client)
        .getByDiary(diary1['id'] as String);
    await expectLater(
      DiaryImageRepository(outsider.client)
          .signedUrl(bImages.first['storage_path'] as String),
      throwsA(anything),
    );
  });

  test('SECURITY-IMG-002 同空间成员不能向他人 Diary 上传/删除图片',
      () async {
    final bImageRepo = DiaryImageRepository(userB.client);
    final bytes = base64Decode(_tinyJpegBase64);

    // 产品规则：Space membership 不授予他人 Diary 的 Storage 写权限。
    // B（成员、非作者）向 A 的 Diary 路径上传 → 被作者关系策略拒绝。
    await expectLater(
      bImageRepo.uploadForDiary(
        spaceId: space['id'] as String,
        diaryId: diary1['id'] as String,
        bytes: bytes,
        extension: 'jpg',
        sortOrder: 99,
      ),
      throwsA(anything),
    );
    // diary_images 行数不变（仍为 IMAGE-001 上传的 2 张）
    final rows = await bImageRepo.getByDiary(diary1['id'] as String);
    expect(rows.length, 2);

    // B 不能删除 A 的对象（DELETE 同样校验作者关系）。
    // 注：supabase-dart 的 remove() 在策略拒绝时返回空列表而非抛异常。
    final aPath = rows.first['storage_path'] as String;
    final removed = await userB.client.storage
        .from(kDiaryImagesBucket)
        .remove([aPath]);
    expect(removed, isEmpty, reason: 'B 的删除必须被 Storage 策略拒绝');
    // 对象仍在（A 自己还能拿到签名 URL）
    final url = await DiaryImageRepository(userA.client).signedUrl(aPath);
    expect(url, isNotEmpty);
  });

  test('IMAGE-003 删除日记 → 图片行级联清除 + Storage 对象清理', () async {
    final repo = DiaryRepository(userA.client);
    final imageRepo = DiaryImageRepository(userA.client);
    final temp = await repo.createDiary(
      spaceId: space['id'] as String,
      diaryDate: DateTime.now(),
      content: '带图待删',
      weather: 'sunny',
      mood: 'happy',
    );
    final img = await imageRepo.uploadForDiary(
      spaceId: space['id'] as String,
      diaryId: temp['id'] as String,
      bytes: base64Decode(_tinyJpegBase64),
      extension: 'jpg',
      sortOrder: 0,
    );
    final path = img['storage_path'] as String;

    await repo.deleteDiary(temp['id'] as String);

    // 行级联删除
    final rows = await imageRepo.getByDiary(temp['id'] as String);
    expect(rows, isEmpty);
    // Storage 对象已移除（成员 B 下载应失败）
    await expectLater(
      userB.client.storage.from(kDiaryImagesBucket).download(path),
      throwsA(anything),
    );
  });

  test('DIARY-007 局外人全程读不到空间日记', () async {
    final outsiderReads = await outsider.client
        .from('diary_entries')
        .select('id')
        .eq('space_id', space['id'] as String);
    expect(outsiderReads, isEmpty);
  });
}
