import 'package:flutter_test/flutter_test.dart';
import 'package:shared_space_app/features/profile/profile_repository.dart';
import 'package:shared_space_app/features/space/space_repository.dart';
import 'package:shared_space_app/features/space/space_service.dart';

import 'spike/spike_support.dart';

/// V1 Milestone 1（Auth + Profile + Space + Invite）真实环境集成测试。
///
/// 运行：
///   flutter test test/milestone1_test.dart \
///     --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
void main() {
  late TestAccount userA;
  late TestAccount userB;
  late TestAccount outsider;
  late Map<String, dynamic> space;

  setUpAll(() async {
    if (!SpikeEnv.isConfigured) {
      fail('未配置连接信息：请通过 --dart-define=SUPABASE_URL=... / '
          'SUPABASE_ANON_KEY=... 运行，或设置同名环境变量。');
    }
    userA = await TestAccount.register('m1a', admin: null);
    userB = await TestAccount.register('m1b', admin: null);
    outsider = await TestAccount.register('m1x', admin: null);
  });

  test('PROFILE-001 注册自动创建 profile（DB trigger）', () async {
    final profile = await ProfileRepository(userA.client).getMyProfile();
    expect(profile['id'], userA.userId);
    expect(profile['nickname'], isNotEmpty);
    expect(profile['color'], isNotEmpty);
  });

  test('PROFILE-002 修改昵称与颜色并读回', () async {
    final repo = ProfileRepository(userA.client);
    final updated = await repo.updateMyProfile(
        nickname: '里程碑一甲', color: 'orange');
    expect(updated['nickname'], '里程碑一甲');
    expect(updated['color'], 'orange');

    final read = await repo.getMyProfile();
    expect(read['nickname'], '里程碑一甲');
    expect(read['color'], 'orange');
  });

  test('PROFILE-003 同空间成员可见昵称颜色；局外人不可见', () async {
    final spaceRepo = SpaceRepository(userA.client);
    space = await spaceRepo.createSpace('里程碑一空间');
    await SpaceService(SpaceRepository(userB.client))
        .joinByInviteCode(space['invite_code'] as String);

    // 成员可见昵称/颜色
    final members = await spaceRepo.getMembers(space['id'] as String);
    final aRow = members.firstWhere((m) => m['id'] == userA.userId);
    expect(aRow['nickname'], '里程碑一甲');
    expect(aRow['color'], 'orange');

    // 局外人读不到 A 的 profile（RLS）
    final outsiderSees = await outsider.client
        .from('profiles')
        .select('id')
        .eq('id', userA.userId);
    expect(outsiderSees, isEmpty);

    // 多空间底层支持：B 的 getMySpaces 可见；A 可再建第二个空间
    final bSpaces = await SpaceRepository(userB.client).getMySpaces();
    expect(bSpaces.any((s) => s['id'] == space['id']), isTrue);

    final space2 = await spaceRepo.createSpace('里程碑一空间二');
    final aSpaces = await spaceRepo.getMySpaces();
    expect(aSpaces.any((s) => s['id'] == space2['id']), isTrue);
  });
}
