import 'package:permission_handler/permission_handler.dart' as ph;
import 'permission_service.dart';

/// Mobile permission service backed by [permission_handler].
class _MobilePermissionService implements PermissionService {
  @override
  Future<bool> requestCamera() =>
      ph.Permission.camera.request().then((s) => s.isGranted || s.isLimited);

  @override
  Future<bool> requestPhotos() =>
      ph.Permission.photos.request().then((s) => s.isGranted || s.isLimited);

  @override
  void openAppSettings() => ph.openAppSettings();
}

PermissionService createPermissionService() => _MobilePermissionService();
