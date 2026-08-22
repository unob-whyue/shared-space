import 'package:flutter/material.dart';

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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
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
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Text(
                '图片加载失败',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
