import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Platform-agnostic permission service.
///
/// On mobile: uses [permission_handler] to request CAMERA and
/// Photos/Media permissions.
/// On web: no-op — browser file-picker handles permissions via user gesture.
import 'permission_service_mobile.dart'
    if (dart.library.html) 'permission_service_web.dart';

// Conditional export so other files can use the concrete impl if needed.
export 'permission_service_mobile.dart'
    if (dart.library.html) 'permission_service_web.dart';

abstract class PermissionService {
  /// Request camera permission. Returns `true` if granted.
  Future<bool> requestCamera();

  /// Request photo/media library permission. Returns `true` if granted.
  Future<bool> requestPhotos();

  /// Open the app's settings screen so the user can manually grant permissions.
  void openAppSettings();
}

final permissionProvider =
    Provider<PermissionService>((ref) => createPermissionService());

/// Convenience wrapper used by UI code to request a permission and, if denied,
/// show an explanatory dialog and send the user to settings.
Future<bool> ensurePermission(
  BuildContext context,
  PermissionService service,
  Future<bool> Function() request,
  String title,
  String message,
) async {
  var granted = await request();
  if (!granted && !context.mounted) return false;
  if (!granted && context.mounted) {
    final open = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Open Settings')),
            ],
          ),
        ) ??
        false;
    if (open) service.openAppSettings();
    granted = await request();
  }
  return granted;
}
