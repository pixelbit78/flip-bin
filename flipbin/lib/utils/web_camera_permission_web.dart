import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Queries `navigator.permissions` for camera.
///
/// Returns `granted`, `denied`, `prompt`, or `null` if the API is missing /
/// rejects (some browsers do not expose `camera` to Permissions.query).
Future<String?> queryCameraPermissionState() async {
  try {
    final permissions = web.window.navigator.permissions;
    final descriptor = <String, String>{'name': 'camera'}.jsify() as JSObject;
    final status = await permissions.query(descriptor).toDart;
    return status.state;
  } catch (_) {
    return null;
  }
}
