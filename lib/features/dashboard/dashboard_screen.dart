import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/feedback.dart';
import '../../core/models.dart';
import '../../core/palette.dart';
import '../../core/permission_service.dart';
import '../../core/state.dart';
import '../../core/storage_image.dart';
import '../document_viewer/document_screen.dart';
import '../document_viewer/export_sheet.dart';
import '../monetization/settings_screen.dart';
import '../scanner/scanner_service.dart';

enum ScanMode { camera, library }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<DashboardScreen> {
  final Set<String> _sel = {};
  bool get _selecting => _sel.isNotEmpty;

  Future<void> _showScanMode() async {
    HapticFeedback.mediumImpact();
    final result = await showModalBottomSheet<ScanMode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Scan from', style: Theme.of(ctx).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Open Camera'),
            onTap: () => Navigator.pop(ctx, ScanMode.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Open Library'),
            onTap: () => Navigator.pop(ctx, ScanMode.library),
          ),
        ]),
      ),
    );
    if (result != null && mounted) _scan(result);
  }

  Future<void> _scan(ScanMode mode) async {
    final scanner = ref.read(scannerProvider);
    final perms = ref.read(permissionProvider);
    List<String> paths;
    switch (mode) {
      case ScanMode.camera:
        final ok = await ensurePermission(
            context,
            perms,
            () => perms.requestCamera(),
            'Camera permission',
            'SafaaDocs needs camera permission to take photos of documents.');
        if (!ok || !mounted) return;
        paths = await scanner.scanFromCamera();
        break;
      case ScanMode.library:
        // The system photo picker grants access to the selected image, so a
        // broad photos permission request is unnecessary here.
        paths = await scanner.scanFromGallery();
        break;
    }
    if (paths.isEmpty || !mounted) return;
    final prog = ValueNotifier<double>(0);
    showProgress(context, prog, 'Processing pages');
    final doc = await ref.read(docsProvider.notifier).createFromScan(paths,
        folder: ref.read(folderProvider), onProgress: (v) => prog.value = v);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    notify(context, 'Scan saved', success: true);
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => DocumentScreen(docId: doc.id)));
  }

  void _open(ScanDoc d) {
    if (_selecting) {
      setState(() => _sel.contains(d.id) ? _sel.remove(d.id) : _sel.add(d.id));
    } else {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => DocumentScreen(docId: d.id)));
    }
  }

  void _toggle(ScanDoc d) {
    HapticFeedback.selectionClick();
    setState(() => _sel.contains(d.id) ? _sel.remove(d.id) : _sel.add(d.id));
  }

  Future<void> _delete(List<ScanDoc> docs) async {
    final n = ref.read(docsProvider.notifier);
    await n.remove(docs.map((d) => d.id));
    if (!mounted) return;
    notify(
        context,
        docs.length == 1
            ? 'Document deleted'
            : '${docs.length} documents deleted',
        action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              for (final d in docs) {
                await n.upsert(d);
              }
            })).closed.then((reason) {
      if (reason != SnackBarClosedReason.action) {
        for (final d in docs) {
          n.purge(d);
        }
      }
    });
  }

  Future<void> _newFolder() async {
    final ctl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(
            controller: ctl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Folder name')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctl.text),
              child: const Text('Create')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      ref.read(foldersProvider.notifier).add(name);
      ref.read(folderProvider.notifier).state = name.trim();
      if (mounted) notify(context, 'Folder created', success: true);
    }
  }

  Future<void> _move(List<ScanDoc> docs) async {
    final folders = ref.read(foldersProvider);
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('No folder'),
              onTap: () => Navigator.pop(ctx, '')),
          for (final f in folders)
            ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(f),
                onTap: () => Navigator.pop(ctx, f)),
        ]),
      ),
    );
    if (picked == null) return;
    final n = ref.read(docsProvider.notifier);
    for (final d in docs) {
      await n.upsert(picked.isEmpty
          ? d.copyWith(clearFolder: true)
          : d.copyWith(folder: picked));
    }
    setState(_sel.clear);
    if (mounted) notify(context, 'Moved', success: true);
  }

  List<ScanDoc> _visible(List<ScanDoc> all) {
    final q = ref.watch(queryProvider).trim().toLowerCase();
    final folder = ref.watch(folderProvider);
    final sort = ref.watch(sortProvider);
    final l = all.where((d) {
      if (folder != null && d.folder != folder) return false;
      if (q.isEmpty) return true;
      return d.name.toLowerCase().contains(q) ||
          d.allText.toLowerCase().contains(q);
    }).toList();
    switch (sort) {
      case SortMode.newest:
        l.sort((a, b) => b.created.compareTo(a.created));
      case SortMode.oldest:
        l.sort((a, b) => a.created.compareTo(b.created));
      case SortMode.name:
        l.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return l;
  }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(docsProvider);
    final grid = ref.watch(gridProvider);
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_sel.clear);
      },
      child: Scaffold(
        appBar: _selecting
            ? _selectionBar(docs.value ?? [])
            : AppBar(
                title: Image.asset('assets/safaaDocs.jpg',
                    height: 44, width: 116, fit: BoxFit.contain),
                actions: [
                  IconButton(
                    tooltip: grid ? 'Show list' : 'Show grid',
                    icon: Icon(grid
                        ? Icons.view_list_rounded
                        : Icons.grid_view_rounded),
                    onPressed: () =>
                        ref.read(gridProvider.notifier).state = !grid,
                  ),
                  PopupMenuButton<SortMode>(
                    tooltip: 'Sort',
                    icon: const Icon(Icons.sort_rounded),
                    onSelected: (s) =>
                        ref.read(sortProvider.notifier).state = s,
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: SortMode.newest, child: Text('Newest first')),
                      PopupMenuItem(
                          value: SortMode.oldest, child: Text('Oldest first')),
                      PopupMenuItem(
                          value: SortMode.name, child: Text('Name A–Z')),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen())),
                  ),
                ],
              ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => ref.read(queryProvider.notifier).state = v,
              decoration: const InputDecoration(
                  hintText: 'Search names and text',
                  prefixIcon: Icon(Icons.search_rounded)),
            ),
          ),
          _folderBar(),
          Expanded(
            child: docs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  const Center(child: Text('Could not load documents')),
              data: (all) {
                final l = _visible(all);
                if (l.isEmpty) return _empty(all.isEmpty);
                return grid ? _grid(l) : _list(l);
              },
            ),
          ),
        ]),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _selecting
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _showScanMode(),
                icon: const Icon(Icons.document_scanner_rounded),
                label: const Text('Scan'),
                tooltip: 'Scan a document',
              ),
      ),
    );
  }

  PreferredSizeWidget _selectionBar(List<ScanDoc> all) {
    final chosen = all.where((d) => _sel.contains(d.id)).toList();
    return AppBar(
      leading: IconButton(
          tooltip: 'Cancel selection',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => setState(_sel.clear)),
      title: Text('${_sel.length} selected'),
      actions: [
        IconButton(
            tooltip: 'Move to folder',
            icon: const Icon(Icons.drive_file_move_outline),
            onPressed: () => _move(chosen)),
        IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () {
              setState(_sel.clear);
              _delete(chosen);
            }),
      ],
    );
  }

  Widget _folderBar() {
    final folders = ref.watch(foldersProvider);
    final cur = ref.watch(folderProvider);
    return SizedBox(
      height: 56,
      child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _chip('All', cur == null,
                () => ref.read(folderProvider.notifier).state = null),
            for (final f in folders)
              _chip(f, cur == f,
                  () => ref.read(folderProvider.notifier).state = f),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New folder'),
                  onPressed: _newFolder),
            ),
          ]),
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: sel,
          onSelected: (_) => onTap(),
          labelStyle: TextStyle(color: sel ? Colors.white : null),
        ),
      );

  Widget _empty(bool none) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(
                none
                    ? Icons.document_scanner_outlined
                    : Icons.search_off_rounded,
                size: 56,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(none ? 'No documents yet' : 'No matches',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
                none
                    ? 'Tap Scan to capture your first document.'
                    : 'Try a different search or folder.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
          ]),
        ),
      );

  Widget _thumb(ScanDoc d, {double? w, double? h}) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: StorageImage(
          path: d.pages.first.path,
          width: w,
          height: h,
          fit: BoxFit.cover,
          cacheWidth: 300,
          errorWidget: Container(
              width: w,
              height: h,
              color: Theme.of(context).dividerColor,
              child: const Icon(Icons.description_outlined)),
        ),
      );

  String _sub(ScanDoc d) =>
      '${DateFormat('d MMM yyyy').format(d.created)} · ${d.pages.length} ${d.pages.length == 1 ? 'page' : 'pages'}'
      '${d.folder != null ? ' · ${d.folder}' : ''}';

  Widget _list(List<ScanDoc> l) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: l.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          final d = l[i];
          final sel = _sel.contains(d.id);
          final cs = Theme.of(ctx).colorScheme;
          return Dismissible(
            key: ValueKey(d.id),
            direction: _selecting
                ? DismissDirection.none
                : DismissDirection.horizontal,
            background: _swipeBg(Palette.primary, Icons.ios_share_rounded,
                Alignment.centerLeft, Colors.white),
            secondaryBackground: _swipeBg(
                cs.error,
                Icons.delete_outline_rounded,
                Alignment.centerRight,
                cs.onError),
            confirmDismiss: (dir) async {
              if (dir == DismissDirection.startToEnd) {
                showExportSheet(ctx, d);
                return false;
              }
              return true;
            },
            onDismissed: (_) => _delete([d]),
            child: Card(
              color: sel ? Palette.primary.withValues(alpha: 0.12) : null,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _open(d),
                onLongPress: () => _toggle(d),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(children: [
                    _thumb(d, w: 56, h: 72),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(ctx).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(_sub(d),
                                style: Theme.of(ctx).textTheme.bodySmall),
                          ]),
                    ),
                    if (sel)
                      const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.check_circle_rounded,
                              color: Palette.primary)),
                  ]),
                ),
              ),
            ),
          );
        },
      );

  Widget _swipeBg(Color bg, IconData icon, Alignment a, Color fg) => Container(
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        alignment: a,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Icon(icon, color: fg),
      );

  Widget _grid(List<ScanDoc> l) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.78),
        itemCount: l.length,
        itemBuilder: (ctx, i) {
          final d = l[i];
          final sel = _sel.contains(d.id);
          return Card(
            color: sel ? Palette.primary.withValues(alpha: 0.12) : null,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _open(d),
              onLongPress: () => _toggle(d),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(fit: StackFit.expand, children: [
                          _thumb(d),
                          if (sel)
                            const Positioned(
                                top: 8,
                                right: 8,
                                child: Icon(Icons.check_circle_rounded,
                                    color: Palette.primary)),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      Text(d.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(ctx).textTheme.titleMedium),
                      Text(
                          '${d.pages.length} ${d.pages.length == 1 ? 'page' : 'pages'}',
                          style: Theme.of(ctx).textTheme.bodySmall),
                    ]),
              ),
            ),
          );
        },
      );
}
