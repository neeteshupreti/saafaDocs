import 'permission_service.dart';

/// Web permission service — always grants (browser file-picker handles
/// permissions via user gesture).
class _WebPermissionService implements PermissionService {
  @override
  Future<bool> requestCamera() => Future.value(true);

  @override
  Future<bool> requestPhotos() => Future.value(true);

  @override
  void openAppSettings() {
    // no-op on web
  }
}

PermissionService createPermissionService() => _WebPermissionService();
