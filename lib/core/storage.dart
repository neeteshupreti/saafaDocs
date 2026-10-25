import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Conditional import: so [createStorage] is visible within this file.
// Conditional export: so other files that import this library also get the
// concrete implementation.
import 'storage_mobile.dart' if (dart.library.html) 'storage_web.dart';
export 'storage_mobile.dart' if (dart.library.html) 'storage_web.dart';

/// Unified storage service that works on both mobile and web.
///
/// On mobile: reads/writes files on the native file system via [dart:io].
/// On web: stores data in browser local-storage (shared_preferences) as
/// base64 strings and triggers native download dialogs when needed.
abstract class StorageService {
  /// Read raw bytes from [path], or null if the file does not exist.
  Future<Uint8List?> readFile(String path);

  /// Synchronously read raw bytes from [path] (mobile only; returns null on web).
  Uint8List? readFileSync(String path);

  /// Write [bytes] to [path], creating parent directories as needed.
  Future<void> writeFile(String path, Uint8List bytes);

  /// Whether a file exists at [path].
  Future<bool> exists(String path);

  /// Delete the file at [path] (no-op if it does not exist).
  Future<void> deleteFile(String path);

  /// The root documents directory for scanned content.
  Future<String> documentsDir();

  /// Directory used for exported files.
  Future<String> exportsDir();

  /// Trigger a browser download / save-as dialog for [bytes].
  /// On mobile this is a no-op (use share_plus instead).
  Future<void> download(String name, Uint8List bytes, String mimeType);
}

// Each platform file defines:
//   StorageService createStorage();

/// Provider for the platform-appropriate [StorageService] instance.
final storageProvider = Provider<StorageService>((ref) => createStorage());
