import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage.dart';

/// A widget that loads image bytes from [StorageService] and displays them.
///
/// This replaces [Image.file] so the same code works on mobile (file-system)
/// and web (shared_preferences / local-storage).
class StorageImage extends ConsumerWidget {
  final String path;
  final double? width, height;
  final BoxFit fit;
  final int? cacheWidth, cacheHeight;
  final Widget? placeholder;
  final Widget? errorWidget;

  const StorageImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.read(storageProvider);
    return FutureBuilder<Uint8List?>(
      future: storage.readFile(path),
      builder: (ctx, snap) {
        final data = snap.data;
        if (data != null) {
          return Image.memory(
            data,
            width: width,
            height: height,
            fit: fit,
            gaplessPlayback: true,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
          );
        }
        if (snap.connectionState == ConnectionState.done) {
          return errorWidget ??
              Container(
                width: width?.toDouble(),
                height: height?.toDouble(),
                color: Theme.of(context).dividerColor,
                child: const Icon(Icons.image_not_supported_outlined),
              );
        }
        return placeholder ?? const SizedBox();
      },
    );
  }
}
