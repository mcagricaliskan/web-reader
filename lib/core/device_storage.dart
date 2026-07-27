import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Free-space queries and backup exclusion, via one small platform channel.
///
/// A hand-rolled channel instead of a plugin (D30): the whole need is two
/// calls, the unmaintained "disk space" plugins are exactly the kind of
/// dependency that rots, and backup exclusion is iOS-API-specific anyway.
///
/// Everything here fails SOFT and says so: a channel error returns null /
/// false rather than throwing, because storage policy must degrade to
/// "could not check" — it must never be the thing that crashes a capture.
class DeviceStorage {
  DeviceStorage({@visibleForTesting MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('webread/device_storage');

  final MethodChannel _channel;

  /// Free bytes on the volume holding the app container, or null when the
  /// platform could not say (which callers must treat as "unknown", never as
  /// zero and never as infinite).
  Future<int?> freeBytes() async {
    try {
      final v = await _channel.invokeMethod<num>('freeBytes');
      return v?.toInt();
    } catch (_) {
      return null;
    }
  }

  /// Exclude [absolutePath] from device backup (iOS:
  /// NSURLIsExcludedFromBackupKey). Returns true when the attribute was set.
  /// On Android this is a no-op returning false — chapter assets there are
  /// already outside the (25 MB-capped) auto-backup in practice, and a
  /// backup-rules entry is release work, not capture work.
  Future<bool> excludeFromBackup(String absolutePath) async {
    try {
      final v = await _channel.invokeMethod<bool>('excludeFromBackup', {
        'path': absolutePath,
      });
      return v ?? false;
    } catch (_) {
      return false;
    }
  }
}
