import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/feedback.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../core/storage.dart';
import 'ocr_service.dart';

class OcrScreen extends ConsumerStatefulWidget {
  final String docId;
  const OcrScreen({super.key, required this.docId});
  @override
  ConsumerState<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends ConsumerState<OcrScreen> {
  double progress = 0;
  bool running = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  ScanDoc get _doc =>
      ref.read(docsProvider).value!.firstWhere((d) => d.id == widget.docId);

  Future<void> _run() async {
    if (_doc.pages.every((p) => p.ocrText != null)) return;
    setState(() => running = true);
    try {
      final d = await ref.read(ocrProvider).ocrDoc(_doc, onProgress: (v) {
        if (mounted) setState(() => progress = v);
      });
      await ref.read(docsProvider.notifier).upsert(d);
      if (mounted) notify(context, 'Text extracted', success: true);
    } catch (_) {
      if (mounted) notify(context, 'Text recognition failed');
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc =
        ref.watch(docsProvider).value!.firstWhere((d) => d.id == widget.docId);
    final text = doc.allText;
    final noOcrOnWeb = kIsWeb && text.isEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Extracted Text')),
      body: Column(children: [
        if (running) ...[
          LinearProgressIndicator(value: progress <= 0 ? null : progress),
          const Padding(
              padding: EdgeInsets.all(16), child: Text('Recognizing text…')),
        ],
        if (noOcrOnWeb) ...[
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Text recognition is not available on the web version.\n'
              'Open the mobile app to extract text from your documents.',
              textAlign: TextAlign.center,
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        ],
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: doc.pages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (ctx, i) {
              final t = doc.pages[i].ocrText;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Page ${i + 1}',
                            style: Theme.of(ctx).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        SelectableText(t == null
                            ? (kIsWeb
                                ? 'Text recognition not available on web.'
                                : 'Tap to enhance')
                            : (t.isEmpty ? 'No text found on this page.' : t)),
                      ]),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: text.isEmpty
                          ? null
                          : () async {
                              await Clipboard.setData(
                                  ClipboardData(text: text));
                              if (context.mounted)
                                notify(context, 'Copied to clipboard',
                                    success: true);
                            },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy OCR'))),
              const SizedBox(width: 16),
              Expanded(
                  child: FilledButton.icon(
                      onPressed: text.isEmpty
                          ? null
                          : () async {
                              final safe =
                                  doc.name.replaceAll(RegExp(r'[^\w\- ]'), '_');
                              final bytes =
                                  Uint8List.fromList(utf8.encode(text));
                              if (kIsWeb) {
                                await ref
                                    .read(storageProvider)
                                    .download('$safe.txt', bytes, 'text/plain');
                              } else {
                                final dir =
                                    await ref.read(repoProvider).exports();
                                final path = '$dir/$safe.txt';
                                await ref
                                    .read(storageProvider)
                                    .writeFile(path, bytes);
                                if (context.mounted)
                                  notify(context, 'Text file saved',
                                      success: true);
                                await SharePlus.instance
                                    .share(ShareParams(files: [XFile(path)]));
                              }
                            },
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Export TXT'))),
            ]),
          ),
        ),
      ]),
    );
  }
}
