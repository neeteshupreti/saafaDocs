import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'storage.dart';

/// Native file-system storage. Uses [dart:io] + path_provider.
class _MobileStorage implements StorageService {
  @override
  Uint8List? readFileSync(String path) {
    final f = File(path);
    if (!f.existsSync()) return null;
    return f.readAsBytesSync();
  }

  @override
  Future<Uint8List?> readFile(String path) async {
    final f = File(path);
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }

  @override
  Future<void> writeFile(String path, Uint8List bytes) async {
    final f = File(path);
    await f.create(recursive: true);
    await f.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<bool> exists(String path) async => File(path).exists();

  @override
  Future<void> deleteFile(String path) async {
    final f = File(path);
    if (f.existsSync()) await f.delete();
  }

  @override
  Future<String> documentsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/scans');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  @override
  Future<String> exportsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/exports');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  @override
  Future<void> download(String name, Uint8List bytes, String mimeType) async {
    // No-op on mobile: use share_plus for sharing instead.
  }
}

StorageService createStorage() => _MobileStorage();
