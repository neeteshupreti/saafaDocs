import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/ad_manager.dart';
import '../../core/feedback.dart';
import '../../core/models.dart';
import '../../core/palette.dart';
import '../../core/state.dart';
import '../../core/storage.dart';
import 'ocr_service.dart';
import 'pdf_generator.dart';

enum ExportFormat {
  pdf('High-Res PDF'),
  pdfSmall('Compressed PDF'),
  jpeg('JPEG');

  final String label;
  const ExportFormat(this.label);
}

Future<void> showExportSheet(BuildContext context, ScanDoc doc) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ExportSheet(docId: doc.id),
    );

class ExportSheet extends ConsumerStatefulWidget {
  final String docId;
  const ExportSheet({super.key, required this.docId});
  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  ExportFormat format = ExportFormat.pdf;
  PageSetup setup = PageSetup.a4;
  double margin = 16;
  bool searchable = false, adFree = false, busy = false;
  double progress = 0;
  String status = '';

  bool get _isPdf => format != ExportFormat.jpeg;

  Future<void> _watchAd() async {
    setState(() => busy = true);
    final ok = await ref.read(adProvider).showRewarded();
    if (!mounted) return;
    setState(() {
      busy = false;
      adFree = ok;
    });
    if (ok) {
      notify(context, 'Watermark Removed!', success: true);
    } else {
      notify(context, 'Ad unavailable or not completed. Try again.');
    }
  }

  /// Read every page's image bytes so the isolate doesn't need dart:io.
  Future<List<Uint8List>> _readAllPages(ScanDoc doc) async {
    final storage = ref.read(storageProvider);
    final out = <Uint8List>[];
    for (final p in doc.pages) {
      final bytes = await storage.readFile(p.path);
      if (bytes == null) throw StateError('Image not found: ${p.path}');
      out.add(bytes);
    }
    return out;
  }

  Future<void> _export() async {
    setState(() {
      busy = true;
      progress = 0;
      status = 'Preparing…';
    });
    try {
      final notifier = ref.read(docsProvider.notifier);
      var doc =
          ref.read(docsProvider).value!.firstWhere((d) => d.id == widget.docId);
      if (searchable && _isPdf) {
        setState(() => status = 'Recognizing text…');
        doc = await ref.read(ocrProvider).ocrDoc(doc, onProgress: (v) {
          if (mounted) setState(() => progress = v);
        });
        await notifier.upsert(doc);
      }
      setState(() {
        status = 'Building file…';
        progress = 0;
      });
      final watermark = !(ref.read(proProvider) || adFree);
      final pageBytes = await _readAllPages(doc);
      final safe = doc.name.replaceAll(RegExp(r'[^\w\- ]'), '_');

      if (kIsWeb) {
        // Web: trigger browser download(s)
        if (_isPdf) {
          final bytes = await buildPdf(PdfJob(
              title: doc.name,
              pages: doc.pages,
              pageBytes: pageBytes,
              compress: format == ExportFormat.pdfSmall,
              searchable: searchable,
              watermark: watermark,
              setup: setup,
              margin: margin));
          await ref
              .read(storageProvider)
              .download('$safe.pdf', bytes, 'application/pdf');
        } else {
          final jpegs = await buildJpegs(JpegJob(
              pages: doc.pages, pageBytes: pageBytes, watermark: watermark));
          for (var i = 0; i < jpegs.length; i++) {
            final suffix = jpegs.length > 1 ? '_${i + 1}' : '';
            await ref
                .read(storageProvider)
                .download('$safe$suffix.jpg', jpegs[i], 'image/jpeg');
          }
        }
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        notify(context, _isPdf ? 'PDF downloaded' : 'JPEG downloaded',
            success: true);
      } else {
        // Mobile: write to exports dir and share
        final dir = await ref.read(repoProvider).exports();
        final files = <String>[];
        if (_isPdf) {
          final bytes = await buildPdf(PdfJob(
              title: doc.name,
              pages: doc.pages,
              pageBytes: pageBytes,
              compress: format == ExportFormat.pdfSmall,
              searchable: searchable,
              watermark: watermark,
              setup: setup,
              margin: margin));
          final path = '$dir/$safe.pdf';
          await ref.read(storageProvider).writeFile(path, bytes);
          files.add(path);
        } else {
          final jpegs = await buildJpegs(JpegJob(
              pages: doc.pages, pageBytes: pageBytes, watermark: watermark));
          for (var i = 0; i < jpegs.length; i++) {
            final suffix = jpegs.length > 1 ? '_${i + 1}' : '';
            final path = '$dir/$safe$suffix.jpg';
            await ref.read(storageProvider).writeFile(path, jpegs[i]);
            files.add(path);
          }
        }
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        notify(context, _isPdf ? 'PDF exported' : 'JPEG exported',
            success: true);
        await SharePlus.instance
            .share(ShareParams(files: [for (final f in files) XFile(f)]));
      }
    } catch (e) {
      if (mounted) notify(context, 'Export failed. Please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pro = ref.watch(proProvider);
    final clean = pro || adFree;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            24, 0, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Export', style: t.titleLarge),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final f in ExportFormat.values)
                  ChoiceChip(
                    label: Text(f.label),
                    selected: format == f,
                    labelStyle:
                        TextStyle(color: format == f ? Colors.white : null),
                    onSelected: busy ? null : (_) => setState(() => format = f),
                  ),
              ]),
              if (_isPdf) ...[
                const SizedBox(height: 24),
                Text('Page size', style: t.titleMedium),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (final s in PageSetup.values)
                    ChoiceChip(
                      label: Text(s.label),
                      selected: setup == s,
                      labelStyle:
                          TextStyle(color: setup == s ? Colors.white : null),
                      onSelected:
                          busy ? null : (_) => setState(() => setup = s),
                    ),
                ]),
                if (setup != PageSetup.auto)
                  Row(children: [
                    SizedBox(
                        width: 88,
                        child: Text('Margin ${margin.round()}',
                            style: t.labelLarge)),
                    Expanded(
                        child: Slider(
                            min: 0,
                            max: 48,
                            divisions: 12,
                            value: margin,
                            onChanged: busy
                                ? null
                                : (v) => setState(() => margin = v))),
                  ]),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Searchable text (OCR)'),
                  subtitle: const Text('Adds an invisible text layer'),
                  value: searchable,
                  onChanged:
                      busy ? null : (v) => setState(() => searchable = v),
                ),
              ],
              const SizedBox(height: 16),
              if (clean)
                Semantics(
                  liveRegion: true,
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Palette.success),
                    const SizedBox(width: 8),
                    Text(pro ? 'Watermark-free (Pro)' : 'Watermark free',
                        style: t.titleMedium?.copyWith(color: Palette.success)),
                  ]),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _watchAd,
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    label: const Text('Remove Watermark (Watch 1 Quick Ad)',
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ),
              const SizedBox(height: 24),
              if (busy) ...[
                Text(status, style: t.bodySmall),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress <= 0 ? null : progress),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : _export,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: Text(_isPdf ? 'Export PDF' : 'Export JPEG'),
                ),
              ),
            ]),
      ),
    );
  }
}
