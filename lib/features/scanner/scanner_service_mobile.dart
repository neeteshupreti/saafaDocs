import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'scanner_service.dart';

/// Mobile implementation: Google ML Kit on-device Document Scanner.
class _MobileScannerService implements ScannerService {
  static final _picker = ImagePicker();

  @override
  Future<List<String>> scan({int pageLimit = 30}) =>
      _scanWithMlKit(ScannerMode.full);

  @override
  Future<List<String>> scanFromCamera() async {
    final xfile = await _picker.pickImage(source: ImageSource.camera);
    return xfile == null ? const <String>[] : [xfile.path];
  }

  @override
  Future<List<String>> scanFromGallery() async {
    // ML Kit's gallery import flag can still start its scanner UI on some
    // devices. Use the platform photo picker so this action always opens the
    // device library directly.
    final xfile = await _picker.pickImage(source: ImageSource.gallery);
    return xfile == null ? const <String>[] : [xfile.path];
  }

  Future<List<String>> _scanWithMlKit(ScannerMode mode) async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormats: {DocumentFormat.jpeg},
        mode: mode,
        pageLimit: 30,
        isGalleryImport: mode == ScannerMode.base || mode == ScannerMode.full,
      ),
    );
    try {
      final result = await scanner.scanDocument();
      return result.images
              ?.whereType<String>()
              .where((p) => p.isNotEmpty)
              .toList() ??
          const <String>[];
    } catch (_) {
      return const <String>[]; // user cancelled or scanner unavailable
    } finally {
      await scanner.close();
    }
  }
}

ScannerService createScannerService() => _MobileScannerService();
