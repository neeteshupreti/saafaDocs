import 'package:flutter_riverpod/flutter_riverpod.dart';

// Conditional import (for use within this file) + conditional export
// (for other files that import this library).
import 'scanner_service_mobile.dart'
    if (dart.library.html) 'scanner_service_web.dart';
export 'scanner_service_mobile.dart'
    if (dart.library.html) 'scanner_service_web.dart';

/// Platform-agnostic document scanner.
///
/// On mobile: wraps Google ML Kit's [DocumentScanner] (live edge-detection,
/// auto-capture, flash, multi-page, gallery import).
/// On web: uses [image_picker] to select images from the gallery / camera.
abstract class ScannerService {
  Future<List<String>> scan({int pageLimit = 30});

  /// Scan from the camera (requires camera permission).
  Future<List<String>> scanFromCamera();

  /// Pick from the photo / media library (requires photos permission).
  Future<List<String>> scanFromGallery();
}

/// Provider — concrete implementation is selected at compile time.
final scannerProvider =
    Provider<ScannerService>((ref) => createScannerService());

// Each platform file defines:
//   ScannerService createScannerService();
