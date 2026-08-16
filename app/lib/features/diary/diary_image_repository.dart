import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';

/// 图片能力属于 Diary Feature（API_SERVICE.md §15）：
/// 不建立 MediaService / PhotoManager 等泛化抽象。
const String kDiaryImagesBucket = 'diary-images';

/// 单篇日记图片上限（UI_SPEC.md §13：集中定义，不得分散在多个页面）。
const int kMaxDiaryImages = 9;

class DiaryImageRepository {
  DiaryImageRepository(this._client);

  final SupabaseClient _client;

  /// 上传一张（已压缩）图片并建立 diary_images 关联。
  /// 若 Storage 成功但数据库插入失败 → 删除刚上传的对象（API_SERVICE.md §16）。
  Future<Map<String, dynamic>> uploadForDiary({
    required String spaceId,
    required String diaryId,
    required Uint8List bytes,
    required String extension,
    required int sortOrder,
  }) async {
    final name =
        '$spaceId/$diaryId/${DateTime.now().microsecondsSinceEpoch}-'
        '${Random().nextInt(0xFFFFFF).toRadixString(16)}.$extension';
    final contentType = switch (extension.toLowerCase()) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    await _client.storage.from(kDiaryImagesBucket).uploadBinary(
          name,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    try {
      return await _client
          .from('diary_images')
          .insert({
            'diary_id': diaryId,
            'storage_path': name,
            'sort_order': sortOrder,
          })
          .select()
          .single();
    } catch (_) {
      try {
        await _client.storage.from(kDiaryImagesBucket).remove([name]);
      } catch (_) {}
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getByDiary(String diaryId) async {
    return await _client
        .from('diary_images')
        .select()
        .eq('diary_id', diaryId)
        .order('sort_order');
  }

  /// 私有桶读取：签名 URL（1 小时有效）。
  Future<String> signedUrl(String storagePath) async {
    final response = await _client.storage
        .from(kDiaryImagesBucket)
        .createSignedUrl(storagePath, 60 * 60);
    return response;
  }

  /// 编辑时删除单张图片。
  /// 先删 Storage 对象（删除策略要求 diary 行仍存在，作者校验），
  /// 再删 diary_images 行；行删除失败只是留下一行失效引用，可重试。
  Future<void> removeOne(String imageId) async {
    final rows = await _client
        .from('diary_images')
        .select('storage_path')
        .eq('id', imageId);
    final path = rows.isEmpty ? null : rows.first['storage_path'] as String?;
    if (path != null) {
      try {
        await _client.storage.from(kDiaryImagesBucket).remove([path]);
      } catch (_) {}
    }
    await _client.from('diary_images').delete().eq('id', imageId);
  }

  /// 内部清理能力（删除日记时用；非用户独立管理入口）。
  /// 顺序同 removeOne：对象先删、行后删。
  Future<void> removeForDiary(String diaryId) async {
    final rows = await _client
        .from('diary_images')
        .select('storage_path')
        .eq('diary_id', diaryId);
    final paths = rows.map((r) => r['storage_path'] as String).toList();
    if (paths.isNotEmpty) {
      try {
        await _client.storage.from(kDiaryImagesBucket).remove(paths);
      } catch (_) {}
    }
    await _client.from('diary_images').delete().eq('diary_id', diaryId);
  }
}

/// 图片路径非法（服务端策略兜底，客户端几乎不会触发）。
class DiaryImageError extends AppError {
  const DiaryImageError(super.userMessage);
}
