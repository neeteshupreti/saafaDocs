import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'scanner_service.dart';

/// Web implementation: picks images from the gallery / camera via
/// [image_picker], then stores each image as base64 in shared_preferences
/// using the same key scheme as [WebStorage] so the rest of the app can
/// read them transparently.
class _WebScannerService implements ScannerService {
  static const _uuid = Uuid();
  final _picker = ImagePicker();

  @override
  Future<List<String>> scan({int pageLimit = 30}) async {
    final prefs = await SharedPreferences.getInstance();
    final root = '/app/scans';
    final images = await _picker.pickMultiImage();
    if (images.isEmpty) return [];

    final paths = <String>[];
    for (var i = 0; i < images.length && i < pageLimit; i++) {
      final bytes = await images[i].readAsBytes();
      final id = _uuid.v4();
      final path = '$root/scan_$id.jpg';
      await prefs.setString('file:$path', base64Encode(bytes));
      paths.add(path);
    }
    return paths;
  }

  @override
  Future<List<String>> scanFromCamera() => _pickSingle(ImageSource.camera);

  @override
  Future<List<String>> scanFromGallery() => _pickSingle(ImageSource.gallery);

  Future<List<String>> _pickSingle(ImageSource source) async {
    final prefs = await SharedPreferences.getInstance();
    final root = '/app/scans';
    final xfile = await _picker.pickImage(source: source);
    if (xfile == null) return [];
    final bytes = await xfile.readAsBytes();
    final id = _uuid.v4();
    final path = '$root/scan_$id.jpg';
    await prefs.setString('file:$path', base64Encode(bytes));
    return [path];
  }
}

ScannerService createScannerService() => _WebScannerService();
