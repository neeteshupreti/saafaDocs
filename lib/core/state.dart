import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../features/scanner/image_engine.dart';
import 'models.dart';
import 'storage.dart';

final prefsProvider = Provider<SharedPreferences>(
    (_) => throw UnimplementedError('override in main'));

enum SortMode { newest, oldest, name }

final queryProvider = StateProvider<String>((_) => '');
final gridProvider = StateProvider<bool>((_) => false);
final sortProvider = StateProvider<SortMode>((_) => SortMode.newest);
final folderProvider = StateProvider<String?>((_) => null);
final themeModeProvider = StateProvider<ThemeMode>(
    (ref) => ThemeMode.values[ref.read(prefsProvider).getInt('theme') ?? 0]);

class FoldersNotifier extends Notifier<List<String>> {
  @override
  List<String> build() =>
      ref.read(prefsProvider).getStringList('folders') ?? [];
  void add(String name) {
    final n = name.trim();
    if (n.isEmpty || state.contains(n)) return;
    state = [...state, n];
    ref.read(prefsProvider).setStringList('folders', state);
  }
}

final foldersProvider =
    NotifierProvider<FoldersNotifier, List<String>>(FoldersNotifier.new);

/// Pro flag. `purchase()` is the single place to hook Play Billing (in_app_purchase).
class ProNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(prefsProvider).getBool('pro') ?? false;
  Future<void> purchase() async {
    await ref.read(prefsProvider).setBool('pro', true);
    state = true;
  }
}

final proProvider = NotifierProvider<ProNotifier, bool>(ProNotifier.new);

/// File-system layout: <docs>/scans/index.json, <docs>/scans/<docId>/*.jpg, <docs>/exports
class DocRepository {
  final StorageService storage;
  String? _root;

  DocRepository(this.storage);

  Future<String> root() async {
    if (_root != null) return _root!;
    final docs = await storage.documentsDir();
    return _root = p.join(docs, 'scans');
  }

  Future<String> _indexKey() async => p.join(await root(), 'index.json');

  Future<List<ScanDoc>> load() async {
    final key = await _indexKey();
    final data = await storage.readFile(key);
    if (data == null) return [];
    try {
      final list = jsonDecode(utf8.decode(data)) as List;
      return list
          .map((e) => ScanDoc.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<ScanDoc> docs) async {
    final key = await _indexKey();
    final json = jsonEncode(docs.map((d) => d.toJson()).toList());
    await storage.writeFile(key, Uint8List.fromList(utf8.encode(json)));
  }

  Future<String> docDir(String id) async => p.join(await root(), id);

  Future<void> purge(ScanDoc d) async {
    for (final page in d.pages) {
      await storage.deleteFile(page.path);
      await storage.deleteFile(page.originalPath);
    }
  }

  Future<String> exports() => storage.exportsDir();
}

final repoProvider =
    Provider<DocRepository>((ref) => DocRepository(ref.read(storageProvider)));

const _uuid = Uuid();

class DocsNotifier extends AsyncNotifier<List<ScanDoc>> {
  DocRepository get _repo => ref.read(repoProvider);
  StorageService get _storage => ref.read(storageProvider);
  List<ScanDoc> get _cur => state.value ?? [];

  @override
  Future<List<ScanDoc>> build() => _repo.load();

  Future<void> _commit(List<ScanDoc> l) async {
    state = AsyncData(l);
    await _repo.save(l);
  }

  Future<List<ScanPage>> _import(List<String> paths, String docId,
      void Function(double)? onProgress) async {
    final dir = await _repo.docDir(docId);
    final out = <ScanPage>[];
    for (var i = 0; i < paths.length; i++) {
      final id = _uuid.v4();
      final origPath = p.join(dir, 'orig_$id.jpg');
      final bytes = await _storage.readFile(paths[i]);
      if (bytes == null) continue;
      await _storage.writeFile(origPath, bytes);
      final r = await ImageEngine.render(
          RenderParams(srcBytes: bytes, maxSide: 2600, quality: 90));
      final processedPath = p.join(dir, 'page_$id.jpg');
      await _storage.writeFile(processedPath, r.bytes);
      out.add(ScanPage(
          id: id,
          originalPath: origPath,
          path: processedPath,
          width: r.width,
          height: r.height));
      onProgress?.call((i + 1) / paths.length);
    }
    return out;
  }

  Future<ScanDoc> createFromScan(List<String> paths,
      {String? folder, void Function(double)? onProgress}) async {
    final id = _uuid.v4();
    final pages = await _import(paths, id, onProgress);
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final doc = ScanDoc(
      id: id,
      folder: folder,
      created: now,
      pages: pages,
      name:
          'Scan ${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}',
    );
    await _commit([doc, ..._cur]);
    return doc;
  }

  Future<void> addPages(String docId, List<String> paths,
      {void Function(double)? onProgress}) async {
    final pages = await _import(paths, docId, onProgress);
    await _commit([
      for (final d in _cur)
        d.id == docId ? d.copyWith(pages: [...d.pages, ...pages]) : d
    ]);
  }

  Future<void> upsert(ScanDoc doc) async {
    final l = _cur;
    final i = l.indexWhere((d) => d.id == doc.id);
    await _commit(i < 0 ? [doc, ...l] : ([...l]..[i] = doc));
  }

  Future<void> remove(Iterable<String> ids) async =>
      _commit(_cur.where((d) => !ids.contains(d.id)).toList());

  Future<void> purge(ScanDoc d) => _repo.purge(d);
}

final docsProvider =
    AsyncNotifierProvider<DocsNotifier, List<ScanDoc>>(DocsNotifier.new);
