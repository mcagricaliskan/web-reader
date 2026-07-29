import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../capture/capture_job.dart';
import 'database.dart';
import 'file_store.dart';

/// Removing offline files is NOT deletion. The chapter row survives with its
/// source URL, ordering, reading progress, read marks, timestamps and
/// discovery metadata — only the bytes under `library/…` go, and
/// `offlineRemovedAt` records that the *user* chose this (unlike files the
/// system lost, which stay an error state).
///
/// Two paths:
///  - [removeOffline] — soft: the chapter directory is renamed into
///    `tmp/undo-<id>` and can be restored until [UndoHandle.finalize] runs
///    (a few seconds later, or at next startup via the existing staging
///    sweep). This is what the reader flow and manual selection use, and
///    what makes the toast's Undo honest.
///  - [removeOfflineNow] — hard: for queued bulk work, where an undo window
///    per chapter would be theatre.
class CleanupService {
  CleanupService({
    required this.db,
    required this.fileStore,
    this.captureJob,
    this.undoWindow = const Duration(seconds: 6),
  });

  final AppDatabase db;
  final FileStore fileStore;

  /// Optional: without it, the "in use by the running capture" lock simply
  /// cannot fire. The chapter's own `capturing` status still protects it.
  final CaptureJobController? captureJob;
  final Duration undoWindow;

  /// The chapter currently open in the reader, if any. Set by the reader
  /// screen; cleanup refuses to touch it.
  final ValueNotifier<String?> openReaderChapterId = ValueNotifier(null);

  /// Bumped once per removal batch that actually freed something.
  ///
  /// Removal happens from five places (series selection, whole series, the
  /// Storage screen, the finished-chapter flow, the queue). Anything showing
  /// a storage figure listens here instead of every one of those call sites
  /// remembering to refresh it.
  final ValueNotifier<int> removals = ValueNotifier(0);

  void _noteRemoval(int removed) {
    if (removed > 0) removals.value++;
  }

  /// Why a chapter cannot be removed right now, or null when it can.
  ///
  /// Locked chapters are *kept*, never errors: bulk operations skip them and
  /// say so, selection UI shows them as locked.
  Future<String?> lockReasonFor(Chapter chapter) async {
    if (chapter.id == openReaderChapterId.value) {
      return 'open in the reader';
    }
    if (chapter.captureStatus == 'capturing') {
      return 'being captured';
    }
    final job = captureJob;
    if (job != null &&
        job.isRunning &&
        chapter.sourceUrl.isNotEmpty &&
        Uri.tryParse(job.progress.currentUrl)?.path ==
            Uri.tryParse(chapter.sourceUrl)?.path) {
      return 'in use by the running capture';
    }
    return null;
  }

  bool isRemovable(Chapter c) =>
      c.contentPath != null &&
      (c.captureStatus == 'complete' || c.captureStatus == 'partial');

  /// Soft-remove [chapterIds]; locked/non-offline chapters are skipped and
  /// reported. Returns a handle carrying freed bytes and the undo.
  Future<CleanupResult> removeOffline(List<String> chapterIds) async {
    final undoable = <_UndoEntry>[];
    var freed = 0;
    var removed = 0;
    final kept = <String>[];

    for (final id in chapterIds) {
      final chapter = await db.chapterById(id);
      if (chapter == null || !isRemovable(chapter)) continue;
      final lock = await lockReasonFor(chapter);
      if (lock != null) {
        kept.add('${chapter.chapterLabel ?? chapter.title} ($lock)');
        continue;
      }

      final srcDir = Directory(fileStore.resolve(chapter.contentPath!));
      if (!srcDir.existsSync()) {
        // Files already gone: just record the state honestly.
        await _writeRemoved(chapter);
        removed++;
        continue;
      }
      final undoDir = Directory(
        p.join(fileStore.rootDir.path, FileStore.tmpFolderName, 'undo-$id'),
      );
      if (undoDir.existsSync()) undoDir.deleteSync(recursive: true);
      undoDir.parent.createSync(recursive: true);
      final bytes = chapter.byteSize;
      srcDir.renameSync(undoDir.path);
      await _writeRemoved(chapter);
      undoable.add(
        _UndoEntry(chapter: chapter, undoDir: undoDir, bytes: bytes),
      );
      freed += bytes;
      removed++;
    }

    final handle = UndoHandle._(this, undoable);
    if (undoable.isNotEmpty) {
      handle._timer = Timer(undoWindow, handle.finalize);
    }
    _noteRemoval(removed);
    return CleanupResult(
      removed: removed,
      freedBytes: freed,
      keptLocked: kept,
      undo: handle,
    );
  }

  /// Hard-remove, for bulk queue work. [onProgress] fires per chapter with
  /// (processed, freedBytes so far).
  Future<CleanupResult> removeOfflineNow(
    List<String> chapterIds, {
    void Function(int processed, int freedBytes)? onProgress,
  }) async {
    var freed = 0;
    var removed = 0;
    var processed = 0;
    final kept = <String>[];
    for (final id in chapterIds) {
      processed++;
      final chapter = await db.chapterById(id);
      if (chapter == null || !isRemovable(chapter)) continue;
      final lock = await lockReasonFor(chapter);
      if (lock != null) {
        kept.add('${chapter.chapterLabel ?? chapter.title} ($lock)');
        continue;
      }
      try {
        await fileStore.deleteChapterContent(chapter.contentPath!);
        await _writeRemoved(chapter);
        freed += chapter.byteSize;
        removed++;
      } catch (e) {
        kept.add('${chapter.chapterLabel ?? chapter.title} ($e)');
      }
      onProgress?.call(processed, freed);
    }
    _noteRemoval(removed);
    return CleanupResult(
      removed: removed,
      freedBytes: freed,
      keptLocked: kept,
      undo: UndoHandle._(this, const []),
    );
  }

  /// Everything the row must keep is untouched by construction: the write
  /// names ONLY the fields that change.
  Future<void> _writeRemoved(Chapter chapter) => db.writeChapterReading(
    chapter.id,
    ChaptersCompanion(
      contentPath: const Value(null),
      byteSize: const Value(0),
      offlineRemovedAt: Value(DateTime.now()),
    ),
  );

  Future<void> _restore(_UndoEntry entry) async {
    final target = Directory(fileStore.resolve(entry.chapter.contentPath!));
    if (entry.undoDir.existsSync() && !target.existsSync()) {
      target.parent.createSync(recursive: true);
      entry.undoDir.renameSync(target.path);
    }
    await db.writeChapterReading(
      entry.chapter.id,
      ChaptersCompanion(
        contentPath: Value(entry.chapter.contentPath),
        byteSize: Value(entry.bytes),
        offlineRemovedAt: const Value(null),
      ),
    );
  }
}

class CleanupResult {
  const CleanupResult({
    required this.removed,
    required this.freedBytes,
    required this.keptLocked,
    required this.undo,
  });

  final int removed;
  final int freedBytes;

  /// Human lines for chapters skipped because they were in use.
  final List<String> keptLocked;
  final UndoHandle undo;

  bool get canUndo => undo._entries.isNotEmpty && !undo._finalized;
}

/// Restores the renamed-away directories, or lets them die. Idempotent both
/// ways; a crash inside the window leaves `tmp/undo-*`, which the existing
/// startup staging sweep removes.
class UndoHandle {
  UndoHandle._(this._service, this._entries);

  final CleanupService _service;
  final List<_UndoEntry> _entries;
  Timer? _timer;
  bool _finalized = false;
  bool _undone = false;

  Future<void> undo() async {
    if (_finalized || _undone) return;
    _undone = true;
    _timer?.cancel();
    for (final entry in _entries) {
      await _service._restore(entry);
    }
  }

  Future<void> finalize() async {
    if (_finalized || _undone) return;
    _finalized = true;
    _timer?.cancel();
    for (final entry in _entries) {
      try {
        if (entry.undoDir.existsSync()) {
          entry.undoDir.deleteSync(recursive: true);
        }
      } catch (_) {
        // The startup sweep owns anything a crash leaves behind.
      }
    }
  }
}

class _UndoEntry {
  const _UndoEntry({
    required this.chapter,
    required this.undoDir,
    required this.bytes,
  });

  final Chapter chapter;
  final Directory undoDir;
  final int bytes;
}

/// What a series does with a finished chapter's downloaded files when the
/// reader moves forward (D37).
///
/// Persisted on the library item itself — `library_items.finished_cleanup` —
/// because the decision belongs to the series being read. There is no global
/// default: a series that has not been asked stores null, and null is a
/// question, not a value.
enum SeriesCleanupPref { remove, keep }

/// Parses a stored value. Null, empty and anything unrecognised all read as
/// "not decided yet", so the user is asked instead of a wrong guess being
/// applied to their files.
SeriesCleanupPref? seriesCleanupFromName(String? name) {
  for (final value in SeriesCleanupPref.values) {
    if (value.name == name) return value;
  }
  return null;
}
