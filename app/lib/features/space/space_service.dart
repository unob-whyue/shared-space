import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import 'space_repository.dart';

/// V1 唯一 Service：通过邀请码加入空间（API_SERVICE.md §6）。
///
/// 负责：当前用户、邀请码、Space、Membership、10 人限制。
/// 邀请码判断逻辑集中于此，不得散落在页面和 API 中。
class SpaceService {
  SpaceService(this._spaceRepository);

  final SpaceRepository _spaceRepository;

  Future<Map<String, dynamic>> joinByInviteCode(String inviteCode) async {
    try {
      return await _spaceRepository.joinByInviteCodeRpc(inviteCode);
    } on PostgrestException catch (e) {
      final msg = e.message;
      if (msg.contains('INVITE_CODE_NOT_FOUND')) {
        throw const SpaceJoinError('邀请码不正确',
            kind: SpaceJoinErrorKind.invalidCode);
      }
      if (msg.contains('ALREADY_MEMBER')) {
        throw const SpaceJoinError('你已经在这个空间里了',
            kind: SpaceJoinErrorKind.alreadyMember);
      }
      if (msg.contains('SPACE_FULL')) {
        throw const SpaceJoinError('此共享空间人数已达到上限',
            kind: SpaceJoinErrorKind.spaceFull);
      }
      rethrow;
    }
  }
}
