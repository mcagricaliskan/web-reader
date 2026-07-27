import 'package:collection/collection.dart';

import '../features/library_screen.dart' show SeriesGroup;
import '../storage/database.dart';

/// How the All Series list is ordered. Persisted in the settings store so the
/// choice survives restarts (Q26).
enum LibrarySort {
  /// Default: what the user last touched leads; never-read series follow,
  /// then everything ties break by name. The library leads with what the
  /// user cares about, not with what the app last did.
  lastRead,

  /// Deliberate lookup order.
  name,
}

const String kLibrarySortSettingKey = 'library.sort';

LibrarySort librarySortFromName(String? name) => LibrarySort.values.firstWhere(
  (s) => s.name == name,
  orElse: () => LibrarySort.lastRead,
);

/// Pure ordering over series groups — unit-tested directly; the provider just
/// applies it.
List<SeriesGroup> sortSeriesGroups(List<SeriesGroup> groups, LibrarySort sort) {
  final sorted = [...groups];
  switch (sort) {
    case LibrarySort.name:
      sorted.sort(
        (a, b) => compareAsciiLowerCaseNatural(a.displayName, b.displayName),
      );
    case LibrarySort.lastRead:
      sorted.sort((a, b) {
        final at = _lastReadOf(a.item);
        final bt = _lastReadOf(b.item);
        if (at != null && bt != null) {
          final byTime = bt.compareTo(at);
          if (byTime != 0) return byTime;
        } else if (at != null) {
          return -1; // read series before never-read ones
        } else if (bt != null) {
          return 1;
        }
        return compareAsciiLowerCaseNatural(a.displayName, b.displayName);
      });
  }
  return sorted;
}

DateTime? _lastReadOf(LibraryItem item) => item.lastReadAt;
