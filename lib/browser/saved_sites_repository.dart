import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../core/url_utils.dart';
import '../storage/database.dart';
import 'browser_url.dart';

const _uuid = Uuid();

/// The address seeded on a clean install, so Browser Home is never an empty
/// grid on first run.
const kDefaultSavedSiteUrl = 'https://www.google.com/';
const kDefaultSavedSiteTitle = 'Google';

/// Marks the settings row that records "the default was seeded once".
///
/// Kept as a setting rather than inferred from the table: once the user
/// removes Google, the table looks exactly like a fresh install, and
/// re-seeding it there would make the row impossible to delete (D54).
const kSavedSiteSeedKey = 'browser.savedSites.seeded';

/// What a save attempt did.
enum SaveSiteOutcome { created, updated, duplicate }

class SaveSiteResult {
  const SaveSiteResult(this.outcome, this.site);

  final SaveSiteOutcome outcome;
  final SavedSite site;

  bool get isDuplicate => outcome == SaveSiteOutcome.duplicate;
}

/// Reading and writing the user's saved sites.
///
/// Everything the user can do to a saved site is a method here, including to
/// the seeded Google row: it is an ordinary row with a flag, not a protected
/// one.
class SavedSitesRepository {
  SavedSitesRepository(this.db);

  final AppDatabase db;

  Stream<List<SavedSite>> watchAll() => db.watchSavedSites();

  Future<List<SavedSite>> all() => db.allSavedSites();

  /// Seed the default entry, exactly once per installation.
  ///
  /// Skipped when the seed already ran, and also when an equivalent entry
  /// exists already — a development database that was saving Google by hand
  /// must not end up with two.
  Future<void> seedDefaultIfNeeded() async {
    if (await db.setting(kSavedSiteSeedKey) == 'true') return;
    final existing = await db.savedSiteByUrlKey(
      normalizeUrl(kDefaultSavedSiteUrl),
    );
    if (existing == null) {
      final now = DateTime.now();
      await db.upsertSavedSite(
        SavedSite(
          id: _uuid.v4(),
          url: kDefaultSavedSiteUrl,
          urlKey: normalizeUrl(kDefaultSavedSiteUrl),
          host: Uri.parse(kDefaultSavedSiteUrl).host,
          title: kDefaultSavedSiteTitle,
          createdAt: now,
          updatedAt: now,
          orderIndex: 0,
          isDefault: true,
        ),
      );
    }
    await db.setSetting(kSavedSiteSeedKey, 'true');
  }

  Future<SavedSite?> findByUrl(String url) =>
      db.savedSiteByUrlKey(normalizeUrl(url));

  Future<bool> isSaved(String url) async => await findByUrl(url) != null;

  /// Save [url] under [title].
  ///
  /// A URL that normalises to one already saved is never inserted twice.
  /// With [updateExisting] the caller has told the user it is a duplicate and
  /// they chose to edit it; without, the existing row comes back untouched so
  /// the caller can offer exactly that.
  ///
  /// Two pages on one host are two saved sites when their normalised URLs
  /// differ — that is the point of keying on the URL rather than the host.
  Future<SaveSiteResult> save({
    required String url,
    required String title,
    bool updateExisting = false,
    String? editingId,
  }) async {
    final cleanUrl = url.trim();
    final key = normalizeUrl(cleanUrl);
    final now = DateTime.now();
    final existing = await db.savedSiteByUrlKey(key);

    // Editing a row into its own URL is not a duplicate of itself.
    if (existing != null && existing.id != editingId) {
      if (!updateExisting) {
        return SaveSiteResult(SaveSiteOutcome.duplicate, existing);
      }
      final merged = existing.copyWith(
        url: cleanUrl,
        host: Uri.tryParse(cleanUrl)?.host ?? existing.host,
        title: title.trim().isEmpty ? existing.title : title.trim(),
        userTitle: Value(title.trim().isEmpty ? null : title.trim()),
        updatedAt: now,
      );
      await db.upsertSavedSite(merged);
      return SaveSiteResult(SaveSiteOutcome.updated, merged);
    }

    if (editingId != null) {
      final row = await db.savedSiteById(editingId);
      if (row != null) {
        final merged = row.copyWith(
          url: cleanUrl,
          urlKey: key,
          host: Uri.tryParse(cleanUrl)?.host ?? row.host,
          title: title.trim().isEmpty ? row.title : title.trim(),
          userTitle: Value(title.trim().isEmpty ? null : title.trim()),
          updatedAt: now,
        );
        await db.upsertSavedSite(merged);
        return SaveSiteResult(SaveSiteOutcome.updated, merged);
      }
    }

    final site = SavedSite(
      id: _uuid.v4(),
      url: cleanUrl,
      urlKey: key,
      host: Uri.tryParse(cleanUrl)?.host ?? displayHost(cleanUrl),
      title: title.trim().isEmpty ? displayHost(cleanUrl) : title.trim(),
      createdAt: now,
      updatedAt: now,
      orderIndex: await db.nextSavedSiteOrderIndex(),
      isDefault: false,
    );
    await db.upsertSavedSite(site);
    return SaveSiteResult(SaveSiteOutcome.created, site);
  }

  /// Rename. An empty name clears the override and the page title shows
  /// again — which is why [SavedSites.title] is kept alongside it.
  Future<void> rename(String id, String? userTitle) =>
      db.writeSavedSite(id, savedSiteRenameCompanion(userTitle));

  Future<void> markOpened(String id) => db.writeSavedSite(
    id,
    SavedSitesCompanion(lastOpenedAt: Value(DateTime.now())),
  );

  Future<void> remove(String id) => db.deleteSavedSite(id);

  /// Move [id] one place towards the front (or back).
  ///
  /// Rewrites the whole list's indices rather than swapping two: rows seeded
  /// or imported with equal indices would otherwise swap into a no-op.
  Future<void> move(String id, {required bool up}) async {
    final sites = await db.allSavedSites();
    final index = sites.indexWhere((s) => s.id == id);
    if (index < 0) return;
    final target = up ? index - 1 : index + 1;
    if (target < 0 || target >= sites.length) return;
    final reordered = [...sites];
    final moved = reordered.removeAt(index);
    reordered.insert(target, moved);
    await reindex(reordered);
  }

  /// Persist an explicit order.
  Future<void> reindex(List<SavedSite> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      if (ordered[i].orderIndex == i) continue;
      await db.writeSavedSite(
        ordered[i].id,
        SavedSitesCompanion(orderIndex: Value(i)),
      );
    }
  }
}

SavedSitesCompanion savedSiteRenameCompanion(String? userTitle) =>
    SavedSitesCompanion(
      userTitle: Value(
        userTitle == null || userTitle.trim().isEmpty ? null : userTitle.trim(),
      ),
      updatedAt: Value(DateTime.now()),
    );

/// What the tile shows: the user's name when they set one, else the page's.
String savedSiteDisplayTitle(SavedSite site) {
  final override = site.userTitle?.trim();
  if (override != null && override.isNotEmpty) return override;
  return site.title.trim().isEmpty ? displayHost(site.url) : site.title.trim();
}
