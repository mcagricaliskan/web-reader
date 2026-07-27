import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../storage/database.dart';
import 'series_identity.dart';

const _uuid = Uuid();

/// The display name for a group, in the order the brief specifies:
/// user-edited → detected series title → page/site title → host.
String displayNameFor(LibraryItem item) {
  final user = item.userTitle?.trim();
  if (user != null && user.isNotEmpty) return user;
  final detected = item.title.trim();
  if (detected.isNotEmpty) return detected;
  return item.host.isEmpty ? 'Unknown source' : item.host;
}

/// Owns series grouping: which group a chapter belongs to, and regrouping
/// captures that predate this model.
class SeriesRepository {
  SeriesRepository(this.db);

  final AppDatabase db;

  /// Find or create the group a chapter belongs to.
  ///
  /// Matching is on `(host, seriesKey)` only. A user-renamed group keeps its
  /// name: renaming is presentation, so it must not cause a new group or a
  /// missed match.
  Future<LibraryItem> resolveGroup({
    required String chapterUrl,
    String? pageTitle,
    SeriesHints hints = const SeriesHints(),
    void Function(String)? log,
  }) async {
    final identity = resolveSeriesIdentity(
      chapterUrl: chapterUrl,
      pageTitle: pageTitle,
      hints: hints,
    );

    // Low confidence means we could not tell one series from another on this
    // host. Joining an existing group would risk mixing two series together,
    // which is far worse than an extra group, so keep it separate.
    if (identity.canMerge) {
      final existing = await db.findSeriesGroup(
        identity.host,
        identity.seriesKey,
      );
      if (existing != null) {
        log?.call(
          'series: joined "${displayNameFor(existing)}" '
          '(${identity.host}${identity.seriesKey}, ${identity.basis})',
        );
        // Refresh the detected title if we had nothing before; never touch a
        // name the user chose.
        if (existing.title.trim().isEmpty &&
            (identity.detectedTitle ?? '').isNotEmpty) {
          await db.upsertLibraryItem(
            existing.copyWith(title: identity.detectedTitle!),
          );
          return (await db.libraryItemById(existing.id))!;
        }
        return existing;
      }
    }

    final now = DateTime.now();
    final item = LibraryItem(
      lifecycle: 'active',
      id: _uuid.v4(),
      title: identity.detectedTitle ?? identity.host,
      sourceUrl: identity.seriesUrl ?? chapterUrl,
      host: identity.host,
      seriesKey: identity.canMerge
          ? identity.seriesKey
          // A low-confidence group gets a key nothing else can match, so it
          // can never silently absorb a later capture.
          : '${identity.seriesKey}#${_uuid.v4()}',
      seriesUrl: identity.seriesUrl,
      identityBasis: identity.basis,
      identityConfidence: identity.confidence.name,
      createdAt: now,
    );
    await db.upsertLibraryItem(item);
    log?.call(
      'series: created "${item.title}" '
      '(${identity.basis}, ${identity.confidence.name} confidence)',
    );
    return item;
  }

  Future<void> rename(String itemId, String? newName) =>
      db.renameLibraryItem(itemId, newName);

  /// M16: archiving hides the series and stops its checks. Chapters, files
  /// and reading state are untouched — restore puts it back exactly as-is.
  Future<void> archive(String itemId) =>
      db.setSeriesLifecycle(itemId, 'archived');

  Future<void> restore(String itemId) =>
      db.setSeriesLifecycle(itemId, 'active');

  /// Regroup captures made before series grouping existed.
  ///
  /// Non-destructive by construction: it only reassigns `chapter.library_item_id`
  /// and fills in chapter ordering. No file is moved and no capture state is
  /// touched — `content_path` is stored per chapter and keyed by stable ids, so
  /// regrouping cannot break a stored chapter.
  Future<BackfillReport> backfillExistingCaptures({
    void Function(String)? log,
  }) async {
    final chapters = await db.allChapters();
    if (chapters.isEmpty) return const BackfillReport();

    final items = {for (final i in await db.watchLibraryItems().first) i.id: i};

    // Anything already keyed has been through this; only touch the rest.
    final needsGrouping = chapters
        .where((c) => (items[c.libraryItemId]?.seriesKey ?? '').isEmpty)
        .toList();
    if (needsGrouping.isEmpty) return const BackfillReport();

    // 1. Work out each chapter's series from its own URL. Old captures have no
    //    page metadata to consult, so the URL fingerprint and the chapter title
    //    are all we have — which is exactly what they were captured with.
    final byKey = <String, List<Chapter>>{};
    final identities = <String, SeriesIdentity>{};
    var lowConfidence = 0;

    for (final chapter in needsGrouping) {
      final identity = resolveSeriesIdentity(
        chapterUrl: chapter.sourceUrl,
        pageTitle: chapter.title,
      );
      if (!identity.canMerge) lowConfidence++;
      final key = identity.canMerge
          ? '${identity.host}|${identity.seriesKey}'
          // Ungroupable rows stay one-per-chapter rather than being piled
          // together on host alone.
          : '${identity.host}|${identity.seriesKey}|${chapter.id}';
      byKey.putIfAbsent(key, () => []).add(chapter);
      identities[key] = identity;
    }

    // A name the user set on an old row must not evaporate when that row
    // splits. Carry it to whichever new group inherits most of its chapters —
    // an imperfect guess, but far better than dropping it silently.
    final inheritedUserTitle = <String, String>{};
    for (final item in items.values) {
      final userTitle = item.userTitle?.trim();
      if (userTitle == null || userTitle.isEmpty) continue;

      String? bestKey;
      var bestCount = 0;
      for (final entry in byKey.entries) {
        final count = entry.value
            .where((c) => c.libraryItemId == item.id)
            .length;
        if (count > bestCount) {
          bestCount = count;
          bestKey = entry.key;
        }
      }
      if (bestKey != null) {
        inheritedUserTitle.putIfAbsent(bestKey, () => userTitle);
      }
    }

    // 2. One group per key, reusing an existing row where possible so ids and
    //    any name already shown stay put.
    var created = 0;
    var reused = 0;
    final touchedOldItems = <String>{};

    for (final entry in byKey.entries) {
      final identity = identities[entry.key]!;
      final groupChapters = entry.value;
      for (final c in groupChapters) {
        touchedOldItems.add(c.libraryItemId);
      }

      final title =
          _sharedSeriesTitle(groupChapters.map((c) => c.title).toList()) ??
          identity.detectedTitle ??
          identity.host;

      var group = await db.findSeriesGroup(identity.host, identity.seriesKey);
      if (group == null) {
        // Reuse the old row when it maps to exactly one group — keeps ids
        // stable for anything already referencing it.
        final oldIds = groupChapters.map((c) => c.libraryItemId).toSet();
        final candidate = oldIds.length == 1 ? items[oldIds.first] : null;
        final soleOwner =
            candidate != null &&
            chapters.where((c) => c.libraryItemId == candidate.id).length ==
                groupChapters.length;

        final now = DateTime.now();
        group =
            (soleOwner ? candidate : null)?.copyWith(
              title: title,
              seriesKey: Value(identity.seriesKey),
              seriesUrl: Value(identity.seriesUrl),
              identityBasis: const Value('backfill'),
              identityConfidence: Value(identity.confidence.name),
              host: identity.host,
            ) ??
            LibraryItem(
              lifecycle: 'active',
              id: _uuid.v4(),
              title: title,
              userTitle: inheritedUserTitle[entry.key],
              sourceUrl: identity.seriesUrl ?? groupChapters.first.sourceUrl,
              host: identity.host,
              seriesKey: identity.seriesKey,
              seriesUrl: identity.seriesUrl,
              identityBasis: 'backfill',
              identityConfidence: identity.confidence.name,
              createdAt: now,
            );
        await db.upsertLibraryItem(group);
        if (soleOwner) {
          reused++;
        } else {
          created++;
        }
      }

      // 3. Point the chapters at it, and fill in ordering while we are here.
      for (final chapter in groupChapters) {
        if (chapter.libraryItemId != group.id) {
          await db.reassignChapter(chapter.id, group.id);
        }
        if (chapter.chapterNumber == null && chapter.chapterLabel == null) {
          final number = parseChapterNumber(
            title: chapter.title,
            url: chapter.sourceUrl,
          );
          await db.setChapterOrdering(
            chapter.id,
            number: number,
            label: chapterLabelFrom(
              title: chapter.title,
              url: chapter.sourceUrl,
              number: number,
            ),
          );
        }
      }

      final latest = groupChapters
          .map((c) => c.capturedAt)
          .whereType<DateTime>()
          .fold<DateTime?>(
            null,
            (acc, d) => acc == null || d.isAfter(acc) ? d : acc,
          );
      if (latest != null) await db.markSeriesCaptured(group.id, latest);
    }

    // 4. Drop rows nothing points at any more. Only ever empty ones.
    final removed = await db.deleteEmptyLibraryItems();

    final report = BackfillReport(
      chaptersRegrouped: needsGrouping.length,
      groupsCreated: created,
      groupsReused: reused,
      emptyGroupsRemoved: removed,
      lowConfidenceChapters: lowConfidence,
    );
    log?.call('backfill: $report');
    return report;
  }

  /// The series name shared by a set of chapter titles.
  ///
  /// Chapter titles from one series differ only in their chapter marker, so
  /// stripping the marker and taking the common prefix recovers the series
  /// name without any page metadata — which old captures do not have.
  static String? _sharedSeriesTitle(List<String> chapterTitles) {
    final cleaned = chapterTitles
        .map(seriesTitleFromPageTitle)
        .whereType<String>()
        .where((t) => t.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) return null;
    if (cleaned.length == 1) return cleaned.first;

    var prefix = cleaned.first;
    for (final title in cleaned.skip(1)) {
      var i = 0;
      while (i < prefix.length && i < title.length && prefix[i] == title[i]) {
        i++;
      }
      prefix = prefix.substring(0, i);
      if (prefix.trim().length < 3) return cleaned.first;
    }
    final trimmed = prefix.replaceAll(RegExp(r'[\s\-–—:|,\.]+$'), '').trim();
    return trimmed.length < 3 ? cleaned.first : trimmed;
  }
}

class BackfillReport {
  const BackfillReport({
    this.chaptersRegrouped = 0,
    this.groupsCreated = 0,
    this.groupsReused = 0,
    this.emptyGroupsRemoved = 0,
    this.lowConfidenceChapters = 0,
  });

  final int chaptersRegrouped;
  final int groupsCreated;
  final int groupsReused;
  final int emptyGroupsRemoved;

  /// Chapters whose series could not be identified confidently; each was left
  /// in its own group rather than merged into a guess.
  final int lowConfidenceChapters;

  bool get didAnything => chaptersRegrouped > 0;

  @override
  String toString() =>
      '$chaptersRegrouped chapter(s) regrouped · $groupsCreated created · '
      '$groupsReused reused · $emptyGroupsRemoved empty removed · '
      '$lowConfidenceChapters low-confidence';
}
