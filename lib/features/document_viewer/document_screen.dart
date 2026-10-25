import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/feedback.dart';
import '../../core/models.dart';
import '../../core/palette.dart';
import '../../core/state.dart';
import '../../core/storage_image.dart';
import '../scanner/scanner_service.dart';
import 'editor_screen.dart';
import 'export_sheet.dart';
import 'ocr_screen.dart';

class DocumentScreen extends ConsumerWidget {
  final String docId;
  const DocumentScreen({super.key, required this.docId});

  Future<void> _rename(BuildContext context, WidgetRef ref, ScanDoc doc) async {
    final ctl = TextEditingController(text: doc.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
            controller: ctl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(docsProvider.notifier).upsert(doc.copyWith(name: name));
      if (context.mounted) notify(context, 'Renamed', success: true);
    }
  }

  Future<void> _addPages(BuildContext context, WidgetRef ref) async {
    final paths = await ref.read(scannerProvider).scan();
    if (paths.isEmpty || !context.mounted) return;
    final prog = ValueNotifier<double>(0);
    showProgress(context, prog, 'Processing pages');
    await ref
        .read(docsProvider.notifier)
        .addPages(docId, paths, onProgress: (v) => prog.value = v);
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      notify(context, '${paths.length} page(s) added', success: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc =
        ref.watch(docsProvider).value?.where((d) => d.id == docId).firstOrNull;
    if (doc == null) return const Scaffold(body: SizedBox());
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () => _rename(context, ref, doc),
          child: Semantics(
            label: 'Document name ${doc.name}. Tap to rename',
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(child: Text(doc.name, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Icon(Icons.edit_outlined, size: 18, color: cs.onSurfaceVariant),
            ]),
          ),
        ),
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.all(16),
        buildDefaultDragHandles: false,
        itemCount: doc.pages.length,
        onReorder: (a, b) {
          if (b > a) b--;
          final pages = [...doc.pages];
          pages.insert(b, pages.removeAt(a));
          HapticFeedback.selectionClick();
          ref.read(docsProvider.notifier).upsert(doc.copyWith(pages: pages));
        },
        itemBuilder: (ctx, i) {
          final p = doc.pages[i];
          return Padding(
            key: ValueKey(p.id),
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                        builder: (_) => EditorScreen(docId: docId, index: i))),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: StorageImage(
                        path: p.path,
                        width: 64,
                        height: 80,
                        fit: BoxFit.cover,
                        cacheWidth: 200,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Page ${i + 1}',
                                style: Theme.of(ctx).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Row(children: [
                              if (p.ocrText != null) ...[
                                const Icon(Icons.check_circle_rounded,
                                    size: 16, color: Palette.success),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                  p.ocrText != null
                                      ? 'Text extracted'
                                      : 'Tap to enhance',
                                  style: Theme.of(ctx).textTheme.bodySmall),
                            ]),
                          ]),
                    ),
                    IconButton(
                      tooltip: 'Delete page ${i + 1}',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: doc.pages.length == 1
                          ? null
                          : () {
                              final pages = [...doc.pages]..removeAt(i);
                              ref
                                  .read(docsProvider.notifier)
                                  .upsert(doc.copyWith(pages: pages));
                              notify(ctx, 'Page deleted');
                            },
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: Semantics(
                        label: 'Drag to reorder page ${i + 1}',
                        child: const SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(Icons.drag_handle_rounded)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: () => _addPages(context, ref),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4)),
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: const Text('Add', maxLines: 1, softWrap: false))),
            const SizedBox(width: 8),
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => OcrScreen(docId: docId))),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4)),
                    icon: const Icon(Icons.text_snippet_outlined, size: 18),
                    label: const Text('Text', maxLines: 1, softWrap: false))),
            const SizedBox(width: 8),
            Expanded(
                flex: 2,
                child: FilledButton.icon(
                    onPressed: () => showExportSheet(context, doc),
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('Export'))),
          ]),
        ),
      ),
    );
  }
}
