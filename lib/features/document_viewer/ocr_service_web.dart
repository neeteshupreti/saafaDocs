import '../../core/models.dart';
import 'ocr_service.dart';

/// Web implementation: text recognition is not available in the browser
/// (ML Kit does not support web).  The service is a no-op — pages are
/// returned unchanged.  The UI shows a friendly message instead.
class _WebOcrService implements OcrService {
  @override
  Future<ScanDoc> ocrDoc(ScanDoc d, {void Function(double)? onProgress}) =>
      Future.value(d);

  @override
  void dispose() {}
}

OcrService createOcrService() => _WebOcrService();
