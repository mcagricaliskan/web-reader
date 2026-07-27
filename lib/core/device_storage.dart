import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// How full the device is, as one reading.
///
/// Both halves come from a single platform call so they describe the same
/// moment: a percentage assembled from two round-trips can straddle a write
/// and land outside 0..1. Either half may be null — the platform is allowed
/// to not know, and "unknown" must stay distinguishable from "zero".
class DeviceCapacity {
  const DeviceCapacity({this.freeBytes, this.totalBytes});

  static const DeviceCapacity unknown = DeviceCapacity();

  final int? freeBytes;
  final int? totalBytes;

  /// 0..1 of the device in use, or null when it cannot be established
  /// honestly. Never guessed, and never the app's own share of the disk.
  double? get usedFraction {
    final total = totalBytes;
    final free = freeBytes;
    if (total == null || free == null || total <= 0) return null;
    final used = total - free;
    if (used < 0) return null;
    return (used / total).clamp(0.0, 1.0);
  }

  /// The rounded percentage shown in the Library, or null when unknown.
  int? get usedPercent {
    final fraction = usedFraction;
    return fraction == null ? null : (fraction * 100).round();
  }

  bool get isKnown => usedFraction != null;
}

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

  /// Total and available bytes for the volume holding the app container.
  ///
  /// Fails soft to [DeviceCapacity.unknown]: a device that will not report
  /// its size makes the indicator go quiet, never wrong.
  Future<DeviceCapacity> capacity() async {
    try {
      final v = await _channel.invokeMapMethod<String, dynamic>('capacity');
      if (v == null) return DeviceCapacity.unknown;
      final free = v['free'];
      final total = v['total'];
      return DeviceCapacity(
        freeBytes: free is num ? free.toInt() : null,
        totalBytes: total is num ? total.toInt() : null,
      );
    } catch (_) {
      return DeviceCapacity.unknown;
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
