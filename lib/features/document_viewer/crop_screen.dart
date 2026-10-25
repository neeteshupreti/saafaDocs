import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/palette.dart';
import '../../core/storage.dart';
import '../scanner/image_engine.dart';

/// Four-point perspective crop. Returns normalised corners [tl,tr,br,bl] as x,y pairs.
class CropScreen extends ConsumerStatefulWidget {
  final String path;
  final List<double> initial;
  const CropScreen({super.key, required this.path, required this.initial});
  @override
  ConsumerState<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends ConsumerState<CropScreen> {
  late List<double> c = List.of(widget.initial);
  Uint8List? imageBytes;
  Size? imageSize;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await ref.read(storageProvider).readFile(widget.path);
    if (bytes == null || bytes.isEmpty) return;
    final img = await decodeImageFromList(bytes);
    if (mounted) {
      setState(() {
        imageBytes = bytes;
        imageSize = Size(img.width.toDouble(), img.height.toDouble());
      });
    }
  }

  double _cl(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  Future<void> _snap() async {
    HapticFeedback.selectionClick();
    final bytes = imageBytes;
    if (bytes == null) return;
    final r = await ImageEngine.detectCorners(bytes);
    if (mounted) setState(() => c = r);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = imageBytes;
    final size = imageSize;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adjust Crop'),
        actions: [
          TextButton(
              onPressed: () => setState(() => c = List.of(fullFrame)),
              child: const Text('Reset'))
        ],
      ),
      body: Column(children: [
        Expanded(
          child: LayoutBuilder(builder: (ctx, cs) {
            if (bytes == null || size == null)
              return const Center(child: CircularProgressIndicator());
            final s = size;
            final k = math.min(cs.maxWidth / s.width, cs.maxHeight / s.height);
            final w = s.width * k, h = s.height * k;
            final ox = (cs.maxWidth - w) / 2, oy = (cs.maxHeight - h) / 2;
            return Stack(children: [
              Positioned(
                  left: ox,
                  top: oy,
                  width: w,
                  height: h,
                  child: Image.memory(bytes, fit: BoxFit.fill)),
              Positioned.fill(
                  child: CustomPaint(
                      painter: _QuadPainter(c, Rect.fromLTWH(ox, oy, w, h)))),
              for (var i = 0; i < 4; i++)
                Positioned(
                  left: ox + c[i * 2] * w - 24,
                  top: oy + c[i * 2 + 1] * h - 24,
                  child: Semantics(
                    label: 'Crop corner ${i + 1} of 4, drag to move',
                    child: GestureDetector(
                      onPanUpdate: (d) => setState(() {
                        c[i * 2] = _cl(c[i * 2] + d.delta.dx / w);
                        c[i * 2 + 1] = _cl(c[i * 2 + 1] + d.delta.dy / h);
                      }),
                      child: Container(
                        width: 48,
                        height: 48,
                        color: Colors.transparent,
                        alignment: Alignment.center,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Palette.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ]);
          }),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: _snap,
                      icon: const Icon(Icons.crop_free_rounded),
                      label: const Text('Auto-snap'))),
              const SizedBox(width: 16),
              Expanded(
                  child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, c),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Apply Crop'))),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _QuadPainter extends CustomPainter {
  final List<double> c;
  final Rect r;
  _QuadPainter(this.c, this.r);

  @override
  void paint(Canvas canvas, Size size) {
    final pts = [
      for (var i = 0; i < 4; i++)
        Offset(r.left + c[i * 2] * r.width, r.top + c[i * 2 + 1] * r.height)
    ];
    final path = Path()..addPolygon(pts, true);
    canvas.drawPath(
        path, Paint()..color = Palette.primary.withValues(alpha: 0.18));
    canvas.drawPath(
        path,
        Paint()
          ..color = Palette.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
  }

  @override
  bool shouldRepaint(_QuadPainter o) => true;
}
