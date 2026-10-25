import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../core/feedback.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../core/storage.dart';
import '../scanner/image_engine.dart';
import 'crop_screen.dart';

/// Enhance step: filter suite, brightness/contrast, perspective crop.
/// Previews render at 900px in an isolate; Save re-renders from the original at full resolution.
class EditorScreen extends ConsumerStatefulWidget {
  final String docId;
  final int index;
  const EditorScreen({super.key, required this.docId, required this.index});
  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late ScanPage page;
  late FilterType filter;
  late double brightness, contrast;
  late List<double> corners;
  Uint8List? preview;
  bool busy = false, saving = false;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    final doc =
        ref.read(docsProvider).value!.firstWhere((d) => d.id == widget.docId);
    page = doc.pages[widget.index];
    filter = page.filter;
    brightness = page.brightness;
    contrast = page.contrast;
    corners = List.of(page.corners);
    _preview();
  }

  Future<Uint8List> _readOriginal() async {
    final bytes = await ref.read(storageProvider).readFile(page.originalPath);
    if (bytes == null) throw StateError('Original image not found');
    return bytes;
  }

  Future<void> _preview() async {
    final t = ++_tick;
    setState(() => busy = true);
    final bytes = await _readOriginal();
    if (!mounted || t != _tick) return;
    final r = await ImageEngine.render(RenderParams(
        srcBytes: bytes,
        maxSide: 900,
        quality: 80,
        corners: corners,
        filter: filter,
        brightness: brightness,
        contrast: contrast));
    if (!mounted || t != _tick) return;
    setState(() {
      preview = r.bytes;
      busy = false;
    });
  }

  Future<void> _crop() async {
    final r = await Navigator.push<List<double>>(
        context,
        MaterialPageRoute(
            builder: (_) =>
                CropScreen(path: page.originalPath, initial: corners)));
    if (r != null) {
      corners = r;
      _preview();
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);
    final bytes = await _readOriginal();
    final r = await ImageEngine.render(RenderParams(
        srcBytes: bytes,
        maxSide: 2600,
        quality: 90,
        corners: corners,
        filter: filter,
        brightness: brightness,
        contrast: contrast));
    final fPath = p.join(p.dirname(page.path),
        'page_${page.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.read(storageProvider).writeFile(fPath, r.bytes);
    final oldPath = page.path;
    final doc =
        ref.read(docsProvider).value!.firstWhere((d) => d.id == widget.docId);
    final pages = [...doc.pages];
    pages[widget.index] = page.copyWith(
        path: fPath,
        width: r.width,
        height: r.height,
        filter: filter,
        brightness: brightness,
        contrast: contrast,
        corners: corners,
        clearOcr: true);
    await ref.read(docsProvider.notifier).upsert(doc.copyWith(pages: pages));
    await ref.read(storageProvider).deleteFile(oldPath);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    notify(context, 'Page saved', success: true);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('Enhance · Page ${widget.index + 1}')),
      body: Column(children: [
        SizedBox(
            height: 4,
            child: (busy || saving) ? const LinearProgressIndicator() : null),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline)),
            padding: const EdgeInsets.all(8),
            child: preview == null
                ? const SizedBox()
                : Semantics(
                    label: 'Page preview',
                    image: true,
                    child: Image.memory(preview!,
                        fit: BoxFit.contain, gaplessPlayback: true)),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            for (final f in FilterType.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f.label),
                  selected: filter == f,
                  labelStyle: TextStyle(
                      color: filter == f ? Colors.white : cs.onSurface),
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    filter = f;
                    _preview();
                  },
                ),
              ),
          ]),
        ),
        _slider('Brightness', brightness, (v) => brightness = v),
        _slider('Contrast', contrast, (v) => contrast = v),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: saving ? null : _crop,
                      icon: const Icon(Icons.crop_rounded),
                      label: const Text('Crop'))),
              const SizedBox(width: 16),
              Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                      onPressed: saving ? null : _save,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Save Page'))),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _slider(String label, double value, void Function(double) set) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          SizedBox(
              width: 88,
              child:
                  Text(label, style: Theme.of(context).textTheme.labelLarge)),
          Expanded(
            child: Semantics(
              label: label,
              child: Slider(
                min: -0.5,
                max: 0.5,
                divisions: 20,
                value: value,
                onChanged: (v) => setState(() => set(v)),
                onChangeEnd: (_) => _preview(),
              ),
            ),
          ),
        ]),
      );
}
