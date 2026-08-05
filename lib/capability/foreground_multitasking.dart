import 'package:flutter/foundation.dart';

/// Whether one user-started operation may keep running while the user is
/// somewhere else in the app.
///
/// **One boolean, one owner.** Everything that changes behaviour reads
/// [enabled] and nothing asks *why* it is what it is. Today the only thing
/// that writes it is a setting the user can see and change. That single
/// indirection is the whole seam — see docs/FOREGROUND_MULTITASKING.md §10.
/// Nothing here counts anything, remembers a purchase, or holds a state
/// waiting to be switched on; `library_check_test.dart` fails the build if it
/// ever does.
///
/// The capability may only ever remove a *convenience*. With it off, every
/// operation still runs, still completes, still reports and still recovers —
/// the user simply has to be looking at the Browser, which is the behaviour
/// that shipped before this existed. Nothing here may gate safety, status,
/// cancellation, recovery or access to saved content.
///
/// Deliberately in its own directory with no imports beyond `foundation`: it
/// must stay unreachable from reading state, cleanup and collection deletion.
class ForegroundMultitasking extends ChangeNotifier {
  ForegroundMultitasking([this._enabled = defaultEnabled]);

  /// The persisted settings key. The value is `'true'` or `'false'`; anything
  /// else — including a missing row — reads as [defaultEnabled].
  static const String settingKey = 'capability.foregroundMultitasking';

  /// **Off, deliberately.**
  ///
  /// The architecture gate passed on the iOS Simulator and the Android
  /// emulator, but not yet on physical hardware (docs/FOREGROUND_MULTITASKING.md
  /// §3.1, and test D-1 in the plan). Until it does, keeping a WebView painted
  /// under another screen is an opt-in, so an unverified compositing assumption
  /// cannot become the default path a save takes.
  ///
  /// Flip this to `true` when D-1 and D-2 pass, and say so in the plan's
  /// validation record.
  static const bool defaultEnabled = false;

  static bool parse(String? raw) => switch (raw) {
    'true' => true,
    'false' => false,
    _ => defaultEnabled,
  };

  bool _enabled;
  bool get enabled => _enabled;

  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
  }

  /// What the persisted row should say.
  String get storedValue => _enabled ? 'true' : 'false';
}
