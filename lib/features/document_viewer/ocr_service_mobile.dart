import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../core/models.dart';
import 'ocr_service.dart';

/// Mobile implementation: Google ML Kit on-device text recognition (Latin).
class _MobileOcrService implements OcrService {
  _MobileOcrService()
      : _rec = TextRecognizer(script: TextRecognitionScript.latin);
  final TextRecognizer _rec;

  @override
  Future<ScanDoc> ocrDoc(ScanDoc d, {void Function(double)? onProgress}) async {
    final out = <ScanPage>[];
    for (var i = 0; i < d.pages.length; i++) {
      out.add(await _page(d.pages[i]));
      onProgress?.call((i + 1) / d.pages.length);
    }
    return d.copyWith(pages: out);
  }

  Future<ScanPage> _page(ScanPage p) async {
    if (p.ocrText != null) return p;
    final r = await _rec.processImage(InputImage.fromFilePath(p.path));
    final lines = <OcrLine>[
      for (final b in r.blocks)
        for (final l in b.lines)
          OcrLine(
              l.text,
              l.boundingBox.left / p.width,
              l.boundingBox.top / p.height,
              l.boundingBox.right / p.width,
              l.boundingBox.bottom / p.height),
    ];
    return p.copyWith(ocrText: r.text, lines: lines);
  }

  @override
  void dispose() => _rec.close();
}

OcrService createOcrService() => _MobileOcrService();
