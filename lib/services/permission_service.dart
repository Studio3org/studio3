import 'package:permission_handler/permission_handler.dart';

enum GalleryPermissionOutcome { granted, denied, deniedForever }

/// Centralizes gallery/photo and notification permission requests so
/// call sites (image pickers, login flow) can request lazily at the point
/// of use and handle denial without re-prompting once the OS has recorded
/// a permanent decision.
class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  /// Call immediately before invoking image_picker.
  Future<GalleryPermissionOutcome> requestGalleryAccess({
    required bool forVideo,
  }) async {
    final permission = forVideo ? Permission.videos : Permission.photos;
    var status = await permission.status;
    if (status.isGranted || status.isLimited) {
      return GalleryPermissionOutcome.granted;
    }
    if (status.isPermanentlyDenied) {
      return GalleryPermissionOutcome.deniedForever;
    }

    status = await permission.request();
    if (status.isGranted || status.isLimited) {
      return GalleryPermissionOutcome.granted;
    }
    if (status.isPermanentlyDenied) {
      return GalleryPermissionOutcome.deniedForever;
    }
    return GalleryPermissionOutcome.denied;
  }

  /// Requests both photo and video library access together, for pickers
  /// that show mixed media (e.g. the Scene gallery grid). On Android 13+
  /// these are distinct runtime permissions, so requesting only one leaves
  /// the other media type invisible to the picker.
  Future<GalleryPermissionOutcome> requestMixedGalleryAccess() async {
    final statuses = await [Permission.photos, Permission.videos].request();
    final results = statuses.values;
    if (results.every((s) => s.isGranted || s.isLimited)) {
      return GalleryPermissionOutcome.granted;
    }
    if (results.any((s) => s.isPermanentlyDenied)) {
      return GalleryPermissionOutcome.deniedForever;
    }
    return GalleryPermissionOutcome.denied;
  }

  /// Requested once, right after login, alongside device/push registration.
  Future<bool> requestNotifications() async {
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;
    final result = await Permission.notification.request();
    return result.isGranted;
  }

  /// Whether the phone lets the app show notifications (`NotifSettings` card).
  Future<bool> notificationsAllowed() async =>
      (await Permission.notification.status).isGranted;

  Future<void> openSettings() => openAppSettings();
}
