import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:shared_preferences/shared_preferences.dart';
import 'storage.dart';

/// Browser storage. Keeps files in [SharedPreferences] (local-storage) as
/// base64 strings and uses [dart:html] for download dialogs.
class _WebStorage implements StorageService {
  _WebStorage();

  late Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  String _key(String path) => 'file:$path';

  @override
  Uint8List? readFileSync(String path) =>
      null; // web has no synchronous file I/O

  @override
  Future<Uint8List?> readFile(String path) async {
    final prefs = await _prefs;
    final b64 = prefs.getString(_key(path));
    if (b64 == null) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeFile(String path, Uint8List bytes) async {
    final prefs = await _prefs;
    await prefs.setString(_key(path), base64Encode(bytes));
  }

  @override
  Future<bool> exists(String path) async {
    final prefs = await _prefs;
    return prefs.containsKey(_key(path));
  }

  @override
  Future<void> deleteFile(String path) async {
    final prefs = await _prefs;
    await prefs.remove(_key(path));
  }

  @override
  Future<String> documentsDir() async => '/app/scans';

  @override
  Future<String> exportsDir() async => '/app/exports';

  @override
  Future<void> download(String name, Uint8List bytes, String mimeType) async {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', name)
      ..target = 'blank';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    // Defer revocation so the browser can start the download.
    html.Url.revokeObjectUrl(url);
  }
}

StorageService createStorage() => _WebStorage();
