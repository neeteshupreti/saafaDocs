import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';

// Conditional import (for use within this file) + conditional export
// (for other files that import this library).
import 'ocr_service_mobile.dart' if (dart.library.html) 'ocr_service_web.dart';
export 'ocr_service_mobile.dart' if (dart.library.html) 'ocr_service_web.dart';

/// On-device OCR service (platform-agnostic interface).
///
/// On mobile: uses Google ML Kit Text Recognition.
/// On web: no-op (text recognition not supported in the browser).
abstract class OcrService {
  Future<ScanDoc> ocrDoc(ScanDoc d, {void Function(double)? onProgress});

  /// Release any native resources (e.g. the ML Kit recognizer).
  void dispose() {}
}

/// Provider — concrete implementation is selected at compile time.
final ocrProvider = Provider<OcrService>((ref) {
  final s = createOcrService();
  ref.onDispose(s.dispose);
  return s;
});

// Each platform file defines:
//   OcrService createOcrService();
