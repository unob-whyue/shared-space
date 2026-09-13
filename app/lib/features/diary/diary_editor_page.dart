import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_kit.dart';
import '../../core/app_tokens.dart';
import 'diary_enums.dart';
import 'diary_image_repository.dart';
import 'diary_repository.dart';
import 'image_compressor.dart';

/// 新建 / 编辑日记（V1 核心页面）。
/// 日期规则：diary_date 由系统自动使用当天，V1 不提供修改 UI。
class DiaryEditorPage extends StatefulWidget {
  const DiaryEditorPage({super.key, required this.spaceId, this.existing});

  final String spaceId;
  final Map<String, dynamic>? existing;

  @override
  State<DiaryEditorPage> createState() => _DiaryEditorPageState();
}

class _DiaryEditorPageState extends State<DiaryEditorPage> {
  final _picker = ImagePicker();
  final TextEditingController _content = TextEditingController();
  WeatherKey _weather = WeatherKey.unknown;
  MoodKey _mood = MoodKey.calm;

  // 编辑模式：已有图片（storage_path 与签名 URL）
  List<Map<String, dynamic>> _existingImages = [];
  final Set<String> _removedImageIds = {};

  // 新选择、待上传的图片（已压缩字节）
  final List<Uint8List> _newImages = [];

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  DiaryRepository get _repo => DiaryRepository(Supabase.instance.client);
  DiaryImageRepository get _imageRepo =>
      DiaryImageRepository(Supabase.instance.client);

  int get _totalImages =>
      (_existingImages.length - _removedImageIds.length) + _newImages.length;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _content.text = existing?['content'] as String? ?? '';
    _weather = WeatherKeyX.fromStorage(existing?['weather'] as String? ?? '');
    _mood = MoodKeyX.fromStorage(existing?['mood'] as String? ?? '');
    if (existing != null) {
      _loadExistingImages();
    }
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _loadExistingImages() async {
    try {
      final images =
          await _imageRepo.getByDiary(widget.existing!['id'] as String);
      final withUrls = <Map<String, dynamic>>[];
      for (final image in images) {
        final url = await _imageRepo.signedUrl(image['storage_path'] as String);
        withUrls.add({...image, 'url': url});
      }
      if (mounted) setState(() => _existingImages = withUrls);
    } catch (_) {
      // 图片加载失败不阻塞编辑正文
    }
  }

  /// 选择 → 压缩 → 加入待上传列表（上限 9，集中定义于 kMaxDiaryImages）。
  Future<void> _pickImages() async {
    final remaining = kMaxDiaryImages - _totalImages;
    if (remaining <= 0) {
      _toast('单篇日记最多 $kMaxDiaryImages 张图片');
      return;
    }
    try {
      final picked = await _picker.pickMultiImage();
      if (picked.isEmpty) return;
      for (final file in picked.take(remaining)) {
        final original = await file.readAsBytes();
        final compressed = await compressDiaryImage(original);
        if (mounted) {
          setState(() => _newImages.add(compressed));
        }
      }
      if (picked.length > remaining) {
        _toast('单篇日记最多 $kMaxDiaryImages 张，已截取前 $remaining 张');
      }
    } catch (_) {
      _toast('图片选择失败，请重试');
    }
  }

  Future<void> _removeNewImage(int index) async {
    setState(() => _newImages.removeAt(index));
  }

  void _removeExistingImage(String imageId) {
    setState(() => _removedImageIds.add(imageId));
  }

  Future<void> _save() async {
    final content = _content.text.trim();
    if (content.isEmpty) {
      setState(() => _error = '日记内容不能为空');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        final diary = widget.existing!;
        final diaryId = diary['id'] as String;
        await _repo.updateDiary(
          diaryId,
          content: content,
          weather: _weather.storageValue,
          mood: _mood.storageValue,
        );
        for (final imageId in _removedImageIds) {
          await _imageRepo.removeOne(imageId);
        }
        final sortBase = _existingImages.length - _removedImageIds.length;
        for (var i = 0; i < _newImages.length; i++) {
          await _imageRepo.uploadForDiary(
            spaceId: widget.spaceId,
            diaryId: diaryId,
            bytes: _newImages[i],
            extension: 'jpg',
            sortOrder: sortBase + i,
          );
        }
      } else {
        // 先建日记（图片路径需要 diary_id），再上传图片
        final diary = await _repo.createDiary(
          spaceId: widget.spaceId,
          diaryDate: DateTime.now(),
          content: content,
          weather: _weather.storageValue,
          mood: _mood.storageValue,
        );
        for (var i = 0; i < _newImages.length; i++) {
          await _imageRepo.uploadForDiary(
            spaceId: widget.spaceId,
            diaryId: diary['id'] as String,
            bytes: _newImages[i],
            extension: 'jpg',
            sortOrder: i,
          );
        }
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _error = '保存失败：当前网络不可用，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final diaryDate = widget.existing?['diary_date'] as String?;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '编辑日记' : '新建日记'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中…' : '保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 40),
        children: [
          // 日期由系统确定，仅展示（V1 不提供修改）
          Row(
            children: [
              const Text(
                '日期',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                _isEdit && diaryDate != null ? diaryDate : '今天',
                style: serifStyle(size: 16),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<WeatherKey>(
                  initialValue: _weather,
                  decoration: const InputDecoration(labelText: '天气'),
                  items: WeatherKey.values
                      .map((w) => DropdownMenuItem(
                          value: w, child: Text(w.label)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _weather = v ?? WeatherKey.unknown),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<MoodKey>(
                  initialValue: _mood,
                  decoration: const InputDecoration(labelText: '心情'),
                  items: MoodKey.values
                      .map((m) => DropdownMenuItem(
                          value: m, child: Text(m.label)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _mood = v ?? MoodKey.calm),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Container(height: 0.7, color: AppColors.divider),
          const SizedBox(height: 4),
          TextField(
            controller: _content,
            autofocus: !_isEdit,
            minLines: 8,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(
              fontSize: 16,
              height: 1.95,
              letterSpacing: 0.2,
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              hintText: '写下今天的生活…',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintStyle:
                  TextStyle(fontSize: 16, color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: 4),
          Container(height: 0.7, color: AppColors.divider),
          const SizedBox(height: 30),
          SectionLabel(text: '图片 · $_totalImages/$kMaxDiaryImages'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // 已有图片（编辑模式）
              ..._existingImages
                  .where((img) => !_removedImageIds.contains(img['id']))
                  .map((img) => _ImageTile(
                        url: img['url'] as String,
                        onRemove: () =>
                            _removeExistingImage(img['id'] as String),
                      )),
              // 新选择待上传
              ...List.generate(_newImages.length, (i) {
                return _ImageTile(
                  bytes: _newImages[i],
                  onRemove: () => _removeNewImage(i),
                );
              }),
              if (_totalImages < kMaxDiaryImages)
                _AddImageTile(onTap: _saving ? null : _pickImages),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!,
                style: const TextStyle(
                    color: AppColors.error, fontSize: 13, height: 1.6)),
          ],
        ],
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({this.url, this.bytes, required this.onRemove});

  final String? url;
  final Uint8List? bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: url != null
              ? Image.network(url!, width: 84, height: 84, fit: BoxFit.cover)
              : Image.memory(bytes!, width: 84, height: 84, fit: BoxFit.cover),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
            decoration: const BoxDecoration(
                color: AppColors.scrim, shape: BoxShape.circle),
            padding: const EdgeInsets.all(2),
            child: const Icon(Icons.close,
                color: AppColors.surface, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddImageTile extends StatelessWidget {
  const _AddImageTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.8),
        ),
        child: const Icon(Icons.add_photo_alternate_outlined,
            color: AppColors.textSecondary),
      ),
    );
  }
}
