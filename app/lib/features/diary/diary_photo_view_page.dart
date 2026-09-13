import 'package:flutter/material.dart';

import '../../core/app_tokens.dart';

/// 日记图片大图查看（V1.1 照片查看 Bug 修复）。
/// 复用 Flutter 内置 InteractiveViewer：双指缩放 + 拖动；AppBar 返回原页面。
/// 不改动图片上传 / 压缩 / 存储逻辑。
class DiaryPhotoViewPage extends StatelessWidget {
  const DiaryPhotoViewPage({super.key, required this.imageUrl, this.title});

  final String imageUrl;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.viewerBackground,
      appBar: AppBar(
        backgroundColor: AppColors.viewerBackground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.viewerForeground,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontFamily: kSerifFamily,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.6,
          color: AppColors.viewerForeground,
        ),
        title: Text(title ?? '照片'),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.viewerForeground,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Text(
                '图片加载失败',
                style: TextStyle(color: AppColors.viewerForeground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
