import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/constants.dart';
import '../../core/models.dart';
import '../monetization/watermark.dart';

enum PageSetup {
  a4('A4'),
  letter('Letter'),
  auto('Auto-fit');

  final String label;
  const PageSetup(this.label);
}

class PdfJob {
  final String title;
  final List<ScanPage> pages;
  final List<Uint8List> pageBytes; // parallel to pages; pageBytes[i] ↔ pages[i]
  final bool compress, searchable, watermark;
  final PageSetup setup;
  final double margin;
  const PdfJob(
      {required this.title,
      required this.pages,
      required this.pageBytes,
      required this.compress,
      required this.searchable,
      required this.watermark,
      required this.setup,
      required this.margin});
}

class JpegJob {
  final List<ScanPage> pages;
  final List<Uint8List> pageBytes; // parallel to pages
  final bool watermark;
  const JpegJob(
      {required this.pages, required this.pageBytes, required this.watermark});
}

Future<Uint8List> buildPdf(PdfJob job) => compute(_buildPdf, job);
Future<List<Uint8List>> buildJpegs(JpegJob job) => compute(_buildJpegs, job);

const double _footer = 16;

Future<Uint8List> _buildPdf(PdfJob j) async {
  final doc = pw.Document(title: j.title, creator: appName);
  for (var i = 0; i < j.pages.length; i++) {
    final p = j.pages[i];
    var bytes = j.pageBytes[i];
    var w = p.width, h = p.height;
    if (j.compress) {
      var im = img.decodeJpg(bytes)!;
      if (math.max(w, h) > 1600) {
        im = w >= h
            ? img.copyResize(im, width: 1600)
            : img.copyResize(im, height: 1600);
      }
      bytes = Uint8List.fromList(img.encodeJpg(im, quality: 60));
      w = im.width;
      h = im.height;
    }
    final image = pw.MemoryImage(bytes);
    final auto = j.setup == PageSetup.auto;
    final margin = auto ? 0.0 : j.margin;
    final format = switch (j.setup) {
      PageSetup.a4 => PdfPageFormat.a4,
      PageSetup.letter => PdfPageFormat.letter,
      PageSetup.auto =>
        PdfPageFormat(595, 595 * h / w + (j.watermark ? _footer : 0)),
    };
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(format.width, format.height, marginAll: margin),
      build: (ctx) {
        final aw = ctx.page.pageFormat.availableWidth;
        final ah =
            ctx.page.pageFormat.availableHeight - (j.watermark ? _footer : 0);
        final s = math.min(aw / w, ah / h);
        final dw = w * s, dh = h * s;
        return pw.Column(children: [
          pw.Expanded(
            child: pw.Center(
              child: pw.SizedBox(
                width: dw,
                height: dh,
                child: pw.Stack(children: [
                  pw.Image(image, width: dw, height: dh, fit: pw.BoxFit.fill),
                  if (j.searchable)
                    for (final l in p.lines)
                      pw.Positioned(
                        left: l.l * dw,
                        top: l.t * dh,
                        // Invisible text layer aligned to the recognised line, so the PDF is searchable.
                        child: pw.Opacity(
                          opacity: 0,
                          child: pw.Text(_latin(l.text),
                              style: pw.TextStyle(
                                  fontSize:
                                      math.max(4, (l.b - l.t) * dh * 0.8))),
                        ),
                      ),
                ]),
              ),
            ),
          ),
          if (j.watermark)
            pw.SizedBox(
              height: _footer,
              child: pw.Center(
                child: pw.Text(watermarkText,
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600)),
              ),
            ),
        ]);
      },
    ));
  }
  return doc.save();
}

String _latin(String s) => s.replaceAll(RegExp(r'[^\x20-\x7E]'), ' ');

List<Uint8List> _buildJpegs(JpegJob j) {
  final out = <Uint8List>[];
  for (var i = 0; i < j.pages.length; i++) {
    var im = img.decodeJpg(j.pageBytes[i])!;
    if (j.watermark) im = stampWatermark(im);
    out.add(Uint8List.fromList(img.encodeJpg(im, quality: 92)));
  }
  return out;
}
