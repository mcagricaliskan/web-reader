/// Reconcile a manifest's recorded dimensions with the stored files.
///
/// Manifests written before dimension verification existed carry whatever the
/// page's DOM reported, which can be a placeholder box or a stale snapshot.
/// The stored file's own header is the truth, so this reads it and corrects
/// the manifest — without re-downloading anything, without touching reading
/// state, and without moving a single asset.
///
/// It runs when the reader opens a chapter: that bounds the work to exactly
/// the chapters that are actually looked at, each repaired at most once
/// (verified entries are skipped on every later open).
library;

import 'dart:io';

import '../core/image_dimensions.dart';
import 'file_store.dart';
import 'manifest.dart';

/// How much of a file the header read may take. Every supported format
/// declares its size well inside this (a JPEG EXIF segment is capped at 64 KB
/// by the format itself).
const int kDimensionProbeBytes = 1024 * 1024;

class ManifestRepairResult {
  const ManifestRepairResult({
    required this.manifest,
    required this.correctedCount,
    required this.checkedCount,
  });

  final ChapterManifest manifest;

  /// Entries whose recorded size disagreed with the file and were corrected.
  final int correctedCount;
  final int checkedCount;

  bool get didRepair => correctedCount > 0;
}

/// Verify (and correct) [manifest] against the files under
/// [chapterRelativePath]. Persists the corrected manifest when anything
/// changed; returns the manifest to lay the chapter out with either way.
Future<ManifestRepairResult> repairManifestDimensions(
  FileStore store,
  String chapterRelativePath,
  ChapterManifest manifest,
) async {
  var corrected = 0;
  var checked = 0;
  var dirty = false;
  final entries = <AssetEntry>[];

  for (final entry in manifest.assets) {
    final relative = entry.relativePath;
    if (!entry.isStored || relative == null || entry.dimensionsVerified) {
      entries.add(entry);
      continue;
    }

    final file = store.assetFile(chapterRelativePath, relative);
    final decoded = await _dimensionsFromFile(file);
    checked++;
    if (decoded == null) {
      // Unreadable or unparseable: keep what we have rather than inventing
      // something. The reader's fixed-ratio fallback covers it.
      entries.add(entry);
      continue;
    }

    if (decoded.width == entry.width && decoded.height == entry.height) {
      // The DOM was right — record that it is now verified so this file is
      // never re-read, but it is not a correction.
      entries.add(entry.copyWith(dimensionsVerified: true));
      dirty = true;
      continue;
    }

    entries.add(
      entry.copyWith(
        // Keep the old claim visible as the DOM diagnostic if nothing was
        // recorded there yet — the disagreement is the evidence.
        domWidth: entry.domWidth ?? entry.width,
        domHeight: entry.domHeight ?? entry.height,
        width: decoded.width,
        height: decoded.height,
        dimensionsVerified: true,
      ),
    );
    corrected++;
    dirty = true;
  }

  var repaired = manifest;
  if (dirty) {
    repaired = manifest.copyWith(assets: entries);
    try {
      await store.writeManifest(chapterRelativePath, repaired);
    } catch (_) {
      // Persisting is best-effort: the corrected geometry is still used for
      // this session, and the next open retries the write.
    }
  }

  return ManifestRepairResult(
    manifest: repaired,
    correctedCount: corrected,
    checkedCount: checked,
  );
}

Future<ImageDimensions?> _dimensionsFromFile(File file) async {
  try {
    if (!file.existsSync()) return null;
    final length = await file.length();
    if (length == 0) return null;
    final take = length < kDimensionProbeBytes ? length : kDimensionProbeBytes;
    final raf = await file.open();
    try {
      return readImageDimensions(await raf.read(take));
    } finally {
      await raf.close();
    }
  } catch (_) {
    return null;
  }
}
