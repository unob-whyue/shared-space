import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_kit.dart';
import '../../core/app_tokens.dart';
import '../annotation/annotation_repository.dart';
import '../annotation/annotation_segments.dart';
import '../profile/color_keys.dart';
import 'diary_editor_page.dart';
import 'diary_enums.dart';
import 'diary_image_repository.dart';
import 'diary_photo_view_page.dart';
import 'diary_repository.dart';

/// 日记详情（UI_SPEC.md §14/§15）：
/// 作者昵称/创建时间/天气/心情/正文（可选字批注）/图片/批注卡片。
/// 作者可编辑删除；同 Space 成员可划线批注（V1 无回复/编辑/删除批注）。
class DiaryDetailPage extends StatefulWidget {
  const DiaryDetailPage({
    super.key,
    required this.diaryId,
    required this.spaceId,
    this.spaceName = '',
    this.initialAnnotationId,
  });

  final String diaryId;
  final String spaceId;

  /// 可选（我的记录入口无空间名）。
  final String spaceName;

  /// 通知跳转时传入：进入页面后定位到对应批注卡片。
  final String? initialAnnotationId;

  @override
  State<DiaryDetailPage> createState() => _DiaryDetailPageState();
}

class _DiaryDetailPageState extends State<DiaryDetailPage> {
  Map<String, dynamic>? _diary;
  List<String> _imageUrls = [];
  List<Map<String, dynamic>> _annotations = [];
  bool _loading = true;
  String? _error;

  TextSelection? _selection;
  String? _activeAnnotationId;
  final Map<String, GlobalKey> _cardKeys = {};

  StreamSubscription<AnnotationChange>? _annoSub;
  int _annoGeneration = 0;
  bool _didFocusInitialAnnotation = false;

  DiaryRepository get _repo => DiaryRepository(Supabase.instance.client);
  DiaryImageRepository get _imageRepo =>
      DiaryImageRepository(Supabase.instance.client);
  AnnotationRepository get _annoRepo =>
      AnnotationRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _annoSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _load();
    await _initAnnotationRealtime();
  }

  Future<void> _load() async {
    try {
      final diary = await _repo.getDiary(widget.diaryId);
      final images = await _imageRepo.getByDiary(widget.diaryId);
      final urls = <String>[];
      for (final image in images) {
        try {
          urls.add(
              await _imageRepo.signedUrl(image['storage_path'] as String));
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _diary = diary;
        _imageUrls = urls;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '发生了一点问题，请检查网络后重试';
      });
    }
  }

  /// 批注 Realtime：订阅 → ready → 快照；事件到达仅重拉批注列表。
  Future<void> _initAnnotationRealtime() async {
    final subscription = _annoRepo.watchChanges(widget.diaryId);
    _annoSub = subscription.stream.listen((_) => _loadAnnotations());
    try {
      await subscription.ready.timeout(const Duration(seconds: 15));
    } catch (_) {}
    if (!mounted) return;
    await _loadAnnotations();
  }

  Future<void> _loadAnnotations() async {
    final generation = ++_annoGeneration;
    try {
      final rows = await _annoRepo.getByDiary(widget.diaryId);
      if (!mounted || generation != _annoGeneration) return;
      setState(() => _annotations = rows);
      final initialId = widget.initialAnnotationId;
      if (!_didFocusInitialAnnotation &&
          initialId != null &&
          rows.any((a) => a['id'] == initialId)) {
        _didFocusInitialAnnotation = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _onAnnotationTapped(initialId);
        });
      }
    } catch (_) {}
  }

  Future<void> _edit() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DiaryEditorPage(
        spaceId: widget.spaceId,
        existing: _diary,
      ),
    ));
    await _load();
    await _loadAnnotations();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这篇日记？'),
        content: const Text('删除后无法恢复（V1 没有回收站）。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteDiary(widget.diaryId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      _toast('删除失败，请重试');
    }
  }

  Future<void> _openAnnotationSheet() async {
    final selection = _selection;
    final content = _diary?['content'] as String? ?? '';
    if (selection == null || content.isEmpty) return;
    if (selection.start < 0 || selection.end > content.length) return;
    final selectedText = content.substring(selection.start, selection.end);
    if (selectedText.trim().isEmpty) return;

    final controller = TextEditingController();
    final comment = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '「$selectedText」',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: '写下你的批注…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
                    child: const Text('提交'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (comment == null || comment.isEmpty) return;
    try {
      await _annoRepo.create(
        diaryId: widget.diaryId,
        startOffset: selection.start,
        endOffset: selection.end,
        selectedText: selectedText,
        comment: comment,
      );
      setState(() => _selection = null);
      await _loadAnnotations();
    } catch (_) {
      _toast('批注提交失败，请重试');
    }
  }

  void _onAnnotationTapped(String annotationId) {
    setState(() => _activeAnnotationId = annotationId);
    final key = _cardKeys[annotationId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatCreatedAt(String? iso) {
    if (iso == null) return '';
    final t = DateTime.parse(iso).toLocal();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')} $hh:$mm';
  }

  String _formatHHmm(String? iso) {
    if (iso == null) return '';
    final t = DateTime.parse(iso).toLocal();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildContent(String content) {
    final segments = buildAnnotationSegments(content, _annotations);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText.rich(
          TextSpan(
            style: const TextStyle(
              fontSize: 16,
              height: 1.95,
              letterSpacing: 0.2,
              color: AppColors.textPrimary,
            ),
            children: segments.map((seg) {
              final annotation = seg.annotationIndex == null
                  ? null
                  : _annotations[seg.annotationIndex!];
              final colorKey =
                  annotation?['profiles'] is Map<String, dynamic>
                      ? (annotation!['profiles'] as Map)['color'] as String?
                      : null;
              return TextSpan(
                text: content.substring(seg.start, seg.end),
                style: annotation == null
                    ? null
                    : TextStyle(
                        backgroundColor:
                            colorForKey(colorKey ?? 'blue').withValues(
                          alpha: 0.18,
                        ),
                      ),
                recognizer: annotation == null
                    ? null
                    : (TapGestureRecognizer()
                      ..onTap = () =>
                          _onAnnotationTapped(annotation['id'] as String)),
              );
            }).toList(),
          ),
          onSelectionChanged: (selection, cause) {
            setState(() {
              _selection = selection.isValid && !selection.isCollapsed
                  ? selection
                  : null;
            });
          },
        ),
        if (_selection != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.mode_comment_outlined,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '「${content.substring(_selection!.start, _selection!.end)}」',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    TextButton(
                      onPressed: _openAnnotationSheet,
                      child: const Text('写批注'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAnnotationCards(String content) {
    _cardKeys.clear();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _annotations.map((ann) {
        final profile = ann['profiles'] as Map<String, dynamic>? ?? const {};
        final valid = annotationIsValid(content, ann);
        final colorKey = profile['color'];
        final accent = colorForKey(colorKey is String ? colorKey : 'blue');
        final active = _activeAnnotationId == ann['id'];
        final key = GlobalKey();
        _cardKeys[ann['id'] as String] = key;
        return Container(
          key: key,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.primarySoft : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 0.6),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: accent.withValues(alpha: 0.7)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AuthorDot(
                              colorKey: colorKey is String ? colorKey : 'blue',
                              size: 6,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              profile['nickname'] as String? ?? '未知',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatHHmm(ann['created_at'] as String?),
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '「${ann['selected_text']}」',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12.5,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ann['comment'] as String? ?? '',
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.75,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (!valid)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              '原文已修改',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = Supabase.instance.client.auth.currentUser?.id;
    final diary = _diary;
    final isMine = diary != null && diary['author_id'] == me;
    final profile = diary?['profiles'] as Map<String, dynamic>? ?? const {};
    final rawColor = profile['color'];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.spaceName.isEmpty
            ? '日记'
            : '日记 · ${widget.spaceName}'),
        actions: [
          if (isMine) ...[
            IconButton(
                tooltip: '编辑',
                onPressed: _edit,
                icon: const Icon(Icons.edit_outlined)),
            IconButton(
                tooltip: '删除',
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline)),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      TextButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                )
              : diary == null
                  ? const Center(child: Text('日记不存在或已被删除'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          children: [
                            AuthorDot(
                              colorKey: rawColor is String ? rawColor : 'blue',
                              size: 7,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              profile['nickname'] as String? ?? '未知',
                              style: serifStyle(size: 16),
                            ),
                            const Spacer(),
                            Text(
                              _formatCreatedAt(
                                  diary['created_at'] as String?),
                              style: const TextStyle(
                                fontSize: 11,
                                letterSpacing: 0.6,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${WeatherKeyX.fromStorage(diary['weather'] as String? ?? 'unknown').label} · '
                          '${MoodKeyX.fromStorage(diary['mood'] as String? ?? 'calm').label} · '
                          '${diary['diary_date']}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            letterSpacing: 0.8,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 26),
                        _buildContent(diary['content'] as String? ?? ''),
                        if (_imageUrls.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          GridView.count(
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                            children: _imageUrls
                                .map((url) => GestureDetector(
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              DiaryPhotoViewPage(imageUrl: url),
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(url,
                                            fit: BoxFit.cover),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                        if (_annotations.isNotEmpty) ...[
                          const SizedBox(height: 30),
                          SectionLabel(text: '批注 · ${_annotations.length}'),
                          _buildAnnotationCards(
                              diary['content'] as String? ?? ''),
                        ],
                      ],
                    ),
    );
  }
}
