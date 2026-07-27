import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../capture/capture_preflight.dart';
import '../core/config.dart';
import '../providers.dart';
import '../reading/reading_position.dart';
import '../reading/reading_repository.dart';
import '../storage/cleanup.dart';
import '../storage/database.dart';
import '../storage/file_store.dart';
import '../storage/manifest.dart';
import '../storage/manifest_repair.dart';
import 'cleanup_dialogs.dart';
import 'library_screen.dart' show formatBytes, formatRelative;
import 'series_detail_screen.dart' show sortChaptersForReading;

/// How long the reader waits before writing a scroll position.
///
/// Writing every frame would hammer SQLite for nothing; writing only on close
/// loses a whole session to a crash. A short debounce plus an unconditional
/// flush on close and on lifecycle change bounds the loss to this window.
const Duration kProgressSaveInterval = Duration(seconds: 2);

/// Blank space above the first panel, so content starts below the top chrome
/// instead of under it (design: a 104px lead-in).
const double kReaderTopSpacer = 104;

/// The partial-capture banner scrolls with the content, so its height is part
/// of the leading extent. Fixed rather than measured: the copy is short and
/// known, and a variable leading extent would make the restore offset
/// unknowable before layout — which is exactly what lets the reader open AT
/// the saved position instead of jumping there afterwards.
const double kPartialBannerExtent = 88;

/// Vertical image reader over **local files only**.
///
/// No remote-URL fallback exists anywhere in this screen: if a file is missing
/// the reader says so. Falling back to the source would make "offline" a lie
/// that only surfaces once the network is gone.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.chapterId});

  final String chapterId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  ScrollController? _scrollController;
  Future<_ReaderData>? _future;

  ChapterLayout? _layout;

  /// The live position, updated on every scroll event. The footer listens to
  /// this directly (M12) so the visible percentage moves *while* scrolling;
  /// persistence stays debounced and reads the same value at flush time.
  /// Nothing else listens — the panel list must not rebuild per scroll tick.
  final ValueNotifier<ReadingPosition> _livePosition = ValueNotifier(
    ReadingPosition.start,
  );
  ReadingPosition get _position => _livePosition.value;
  set _position(ReadingPosition value) => _livePosition.value = value;

  /// Height of everything above panel 1 inside the scroll view. Every
  /// offset conversion goes through this, in both directions.
  double _leadingExtent = kReaderTopSpacer;

  /// Where the chapter was restored to, so the jump chip can offer a way
  /// back once the reader has wandered off. The position is what the chip
  /// scrolls to (the anchor is what restore actually used); the fraction is
  /// what it shows.
  ReadingPosition _restoredPosition = ReadingPosition.start;
  double get _restoredFraction => _restoredPosition.fraction;

  Timer? _saveTimer;
  DateTime? _pastThresholdSince;
  bool _completed = false;
  bool _restored = false;
  String? _chapterId;

  /// The series this chapter belongs to — the destination of the swipe-back.
  String? _seriesId;

  /// Held in a field, not read through `ref`, because the last flush runs
  /// from [dispose] — where Riverpod forbids `ref`. Reading it there threw,
  /// which silently lost the final position on every ordinary reader close.
  late final ReadingRepository _reading;
  late final CleanupService _cleanup;

  static const _policy = kDefaultCompletionPolicy;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reading = ref.read(readingRepositoryProvider);
    _cleanup = ref.read(cleanupProvider);
    _chapterId = widget.chapterId;
    // The open chapter is locked against offline-file removal for as long
    // as this screen exists.
    _cleanup.openReaderChapterId.value = widget.chapterId;
    _future = _load(widget.chapterId);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    // Fire-and-forget: dispose cannot await, but the write is a single row.
    unawaited(_flush());
    _scrollController?.dispose();
    _livePosition.dispose();
    if (_cleanup.openReaderChapterId.value == _chapterId) {
      _cleanup.openReaderChapterId.value = null;
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounded or about to be killed: write now rather than hoping the
    // debounce fires first.
    if (state != AppLifecycleState.resumed) unawaited(_flush());
  }

  // --- loading -------------------------------------------------------------

  Future<_ReaderData> _load(String chapterId) async {
    final db = ref.read(databaseProvider);
    final store = ref.read(fileStoreProvider);
    final reading = _reading;

    final chapter = await db.chapterById(chapterId);
    if (chapter == null) {
      return const _ReaderData.unavailable('This chapter is no longer listed.');
    }
    final relative = chapter.contentPath;
    if (relative == null && chapter.offlineRemovedAt != null) {
      // The USER removed these files. That is a state, not a failure —
      // nothing gets demoted, and the copy says "capture again", not
      // "something went wrong".
      return _ReaderData.unavailable(
        'You removed this chapter\'s offline files. It\'s still in your '
        'library with your reading history — capture it again to read it '
        'here.',
        filesGone: true,
        removedByUser: true,
        unavailableMeta:
            'removed ${formatRelative(chapter.offlineRemovedAt)}'
            '${chapter.detectedImageCount > 0 ? ' · ${chapter.detectedImageCount} panels' : ''}',
        unavailableChapter: chapter,
      );
    }
    if (relative == null || !store.chapterExists(relative)) {
      await db.markChapterContentMissing(chapter.id);
      return _ReaderData.unavailable(
        'The local files for "${chapter.title}" are gone. The chapter is '
        'still listed, but it is not available offline.',
        filesGone: true,
        unavailableMeta: '0 of ${chapter.detectedImageCount} files present',
        unavailableChapter: chapter,
      );
    }

    var manifest = await store.readManifest(relative);
    if (manifest == null) {
      return const _ReaderData.unavailable(
        'The chapter package is unreadable (missing manifest).',
      );
    }

    // Older manifests carry DOM-reported dimensions, which can disagree with
    // the files (placeholder boxes, probe timing). Verify against the stored
    // bytes before building any geometry from them — each file is read once,
    // ever, and progress anchors survive because panel count is unchanged.
    final repair = await repairManifestDimensions(store, relative, manifest);
    manifest = repair.manifest;
    if (repair.didRepair) {
      debugPrint(
        '[reader] corrected ${repair.correctedCount} panel dimension(s) '
        'from stored files for ${chapter.id}',
      );
    }

    // Manifest order is DOM order, which is reading order.
    final pages = <_ReaderPage>[];
    for (final asset in manifest.storedAssets) {
      final file = store.assetFile(relative, asset.relativePath!);
      pages.add(
        _ReaderPage(
          file: file,
          exists: file.existsSync(),
          width: asset.width,
          height: asset.height,
        ),
      );
    }

    final siblings = sortChaptersForReading(
      (await db.chaptersForItem(chapter.libraryItemId))
          .where(
            (c) =>
                c.contentPath != null &&
                (c.captureStatus == 'complete' || c.captureStatus == 'partial'),
          )
          .toList(),
    );

    await reading.markOpened(chapter.id);
    await db.touchLibraryItem(chapter.libraryItemId);

    _position = reading.positionOf(chapter);
    _completed = chapter.readStatus == ReadStatus.completed.name;
    _seriesId = chapter.libraryItemId;

    return _ReaderData(
      chapter: chapter,
      manifest: manifest,
      pages: pages,
      siblings: siblings,
    );
  }

  // --- finished-chapter cleanup ---------------------------------------------

  /// The chapter being left, when this transition qualifies for the
  /// finished-chapter cleanup flow — otherwise null.
  ///
  /// Every condition here is a guard the spec names: only a *completed*
  /// chapter, only *forward* movement to a different chapter, only when the
  /// files actually exist locally, only when nothing else is using them, and
  /// only when the target is genuinely openable. Closing the reader, moving
  /// backwards, re-opening the same chapter, a partially-read chapter, or one
  /// with no local files all fall through to null.
  Future<Chapter?> _finishedChapterLeavingFor(Chapter target) async {
    final leavingId = _chapterId;
    if (leavingId == null || leavingId == target.id) return null;
    if (!_completed) return null;

    final db = ref.read(databaseProvider);
    final leaving = await db.chapterById(leavingId);
    if (leaving == null) return null;
    if (leaving.readStatus != ReadStatus.completed.name) return null;
    if (!_cleanup.isRemovable(leaving)) return null;

    // Forward only: reading order, not tap order.
    final ordered = sortChaptersForReading(
      await db.chaptersForItem(leaving.libraryItemId),
    );
    final from = ordered.indexWhere((c) => c.id == leaving.id);
    final to = ordered.indexWhere((c) => c.id == target.id);
    if (from < 0 || to < 0 || to <= from) return null;

    // The target must be openable, or removing the old one strands the user.
    if (target.contentPath == null) return null;
    return leaving;
  }

  /// Apply the stored preference to the chapter just left behind.
  Future<void> _afterFinished(Chapter leaving) async {
    final pref = await ref
        .read(databaseProvider)
        .getSetting(kAfterFinishedPrefKey);
    switch (afterFinishedFromName(pref)) {
      case AfterFinishedPref.keep:
        return;
      case AfterFinishedPref.remove:
        await _removeFinished(leaving);
      case AfterFinishedPref.ask:
        if (!mounted) return;
        final choice = await showFinishedChapterDialog(
          context: context,
          chapter: leaving,
        );
        if (choice == null) return; // dismissed: safest is to keep
        if (choice.rememberChoice) {
          await ref
              .read(databaseProvider)
              .setSetting(
                kAfterFinishedPrefKey,
                choice.remove
                    ? AfterFinishedPref.remove.name
                    : AfterFinishedPref.keep.name,
              );
        }
        if (choice.remove) await _removeFinished(leaving);
    }
  }

  /// Remove and offer an undo. A failure here never blocks reading — the new
  /// chapter is already open; the worst case is that files stay.
  Future<void> _removeFinished(Chapter leaving) async {
    try {
      final result = await _cleanup.removeOffline([leaving.id]);
      if (!mounted || result.removed == 0) return;
      showCleanupToast(
        context,
        text:
            '${leaving.chapterLabel ?? leaving.title} removed offline · '
            '${formatBytes(result.freedBytes)} freed',
        undo: result.canUndo ? result.undo.undo : null,
      );
    } catch (e) {
      debugPrint('[cleanup] finished-chapter removal failed: $e');
    }
  }

  // --- position ------------------------------------------------------------

  /// Build the layout and open the list already at the saved offset.
  ///
  /// Panel heights come from the manifest, so the geometry is known before any
  /// image decodes — which is what lets the reader open *at* the position
  /// rather than visibly jumping there afterwards.
  ScrollController _controllerFor(_ReaderData data, double viewportWidth) {
    final layout = ChapterLayout(
      viewportWidth: viewportWidth,
      panels: [for (final p in data.pages) (width: p.width, height: p.height)],
    );
    if (_layout != null &&
        _layout!.viewportWidth == viewportWidth &&
        _scrollController != null) {
      return _scrollController!;
    }
    _layout = layout;

    final initial = _restored
        ? 0.0
        : _leadingExtent + layout.offsetForPosition(_position);
    if (!_restored) _restoredPosition = _position;
    _restored = true;

    _scrollController?.dispose();
    final controller = ScrollController(initialScrollOffset: initial)
      ..addListener(_onScroll);
    _scrollController = controller;
    return controller;
  }

  void _onScroll() {
    final controller = _scrollController;
    final layout = _layout;
    if (controller == null || layout == null || !controller.hasClients) return;

    final viewportHeight = controller.position.viewportDimension;
    // Panel geometry starts after the lead-in; convert before asking the
    // layout where we are.
    final panelOffset = (controller.offset - _leadingExtent).clamp(
      0.0,
      double.infinity,
    );
    _position = layout.positionForOffset(
      panelOffset,
      viewportHeight: viewportHeight,
    );

    // The jump chip earns its place only when the reader is genuinely
    // somewhere else — a chip pointing at where you already are is noise.
    final drifted =
        _restoredFraction > 0.02 &&
        (_position.fraction - _restoredFraction).abs() > 0.12;
    if (drifted != _showJump && mounted) {
      setState(() => _showJump = drifted);
    }

    // Completion needs dwell: a fling to the bottom is not reading.
    if (_policy.reachedEnd(_position.fraction)) {
      _pastThresholdSince ??= DateTime.now();
      if (!_completed &&
          DateTime.now().difference(_pastThresholdSince!) >= _policy.dwell) {
        _completed = true;
        unawaited(_flush());
        if (mounted) setState(() {});
      }
    } else {
      _pastThresholdSince = null;
    }

    _saveTimer ??= Timer(kProgressSaveInterval, () {
      _saveTimer = null;
      unawaited(_flush());
    });
  }

  Future<void> _flush() async {
    final id = _chapterId;
    if (id == null || _layout == null) return;
    _saveTimer?.cancel();
    _saveTimer = null;
    try {
      await _reading.saveProgress(id, _position, completed: _completed);
    } catch (_) {
      // The dispose-time flush is fire-and-forget; if the database is
      // already shutting down there is nowhere left to save to, and an
      // unhandled zone error would be the only result.
    }
  }

  // --- actions -------------------------------------------------------------

  Future<void> _toggleRead() async {
    final id = _chapterId;
    if (id == null) return;
    final reading = _reading;
    // A debounced save queued before the tap would land after it and write
    // the status straight back. The user's explicit choice is the newer
    // fact, so the pending write is dropped rather than allowed to race.
    _saveTimer?.cancel();
    _saveTimer = null;
    if (_completed) {
      await reading.markUnread(id);
      _completed = false;
      _pastThresholdSince = null;
    } else {
      await reading.markRead(id);
      _completed = true;
    }
    if (mounted) setState(() {});
  }

  /// Save first, then move. Losing the position of the chapter you are leaving
  /// is the obvious way to get this wrong.
  Future<void> _goTo(Chapter target) async {
    await _flush();
    final leaving = await _finishedChapterLeavingFor(target);
    _saveTimer?.cancel();
    _scrollController?.removeListener(_onScroll);
    // The lock follows the reader: the chapter being LEFT is no longer open,
    // and the one arriving is. Without this the chapter just finished stays
    // locked against its own cleanup.
    _cleanup.openReaderChapterId.value = target.id;
    setState(() {
      _chapterId = target.id;
      _restored = false;
      _layout = null;
      _completed = false;
      _pastThresholdSince = null;
      _position = ReadingPosition.start;
      _future = _load(target.id);
    });
    // Navigation is secured (the new chapter is already loading and the lock
    // has moved) before anything is removed — the chapter the user is now
    // looking at can never be the one cleaned up.
    if (leaving != null) unawaited(_afterFinished(leaving));
  }

  // --- leaving for the episode list ----------------------------------------

  /// Accumulated travel of the drag currently in flight, used to decide
  /// whether it was meant horizontally.
  Offset _dragTravel = Offset.zero;

  /// A right-swipe must clear this much horizontal distance…
  static const double _kSwipeDistance = 72;

  /// …or be flicked at least this fast (logical px/s)…
  static const double _kSwipeVelocity = 420;

  /// …and in either case be at least this much more horizontal than vertical.
  /// Reading is a vertical gesture; anything ambiguous belongs to the scroll
  /// view, not to navigation.
  static const double _kSwipeRatio = 2;

  void _onDragStart(DragStartDetails _) => _dragTravel = Offset.zero;

  void _onDragUpdate(DragUpdateDetails details) {
    _dragTravel += details.delta;
  }

  void _onDragEnd(DragEndDetails details) {
    final dx = _dragTravel.dx;
    final dy = _dragTravel.dy;
    _dragTravel = Offset.zero;
    // Rightwards only: a left-swipe means nothing here, and treating it as
    // "back" would fire on any sloppy drag.
    if (dx <= 0) return;
    if (dx.abs() <= dy.abs() * _kSwipeRatio) return;
    final velocity = details.velocity.pixelsPerSecond;
    final decisive =
        dx >= _kSwipeDistance ||
        (velocity.dx >= _kSwipeVelocity &&
            velocity.dx.abs() > velocity.dy.abs() * _kSwipeRatio);
    if (!decisive) return;
    unawaited(_leaveToSeries());
  }

  /// Swipe right: back to this series' episode list.
  ///
  /// The position is flushed **before** navigating — this is a way out of the
  /// reader like any other, and losing the last few seconds of scroll because
  /// the user left by gesture rather than by button would be indefensible.
  ///
  /// Where it lands is the same either way. If the episode list is already the
  /// route underneath, pop onto it; otherwise (opened from Continue Reading,
  /// Activity, a deep link) replace the reader with it. Both leave exactly one
  /// episode-list route on the stack, so repeated in-and-out never piles up.
  Future<void> _leaveToSeries() async {
    final seriesId = _seriesId;
    if (seriesId == null) return;
    await _flush();
    if (!mounted) return;

    final target = '/series/$seriesId';
    final matches = GoRouter.of(
      context,
    ).routerDelegate.currentConfiguration.matches;
    final below = matches.length >= 2 ? matches[matches.length - 2] : null;
    if (below != null && below.matchedLocation == target) {
      context.pop();
    } else {
      context.pushReplacement(target);
    }
  }

  /// Chrome starts visible so the way out is never hidden, then gets out of
  /// the way on the first tap. Tapping the page toggles it.
  bool _chromeVisible = true;

  /// True once the reader has scrolled far enough from the restored position
  /// that offering a way back is useful rather than confusing.
  bool _showJump = false;

  /// Bring a chapter back that has no local files — the same queued capture
  /// as anywhere else, so it shows up in Activity like any other run.
  Future<void> _captureAgain(Chapter chapter) async {
    await ref
        .read(taskQueueProvider)
        .enqueueCapture(
          startUrl: chapter.sourceUrl,
          chapterLimit: 1,
          libraryItemId: chapter.libraryItemId,
          policy: DuplicatePolicy.replaceAll,
          range: CaptureRangeMode.currentChapter,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Capturing this chapter — progress in Activity'),
      ),
    );
  }

  /// Re-capture this chapter to fill in the panels a partial capture missed.
  /// The queue owns the work; the Browser is where it becomes visible.
  Future<void> _retryMissing(_ReaderData data) async {
    final chapter = data.chapter;
    if (chapter == null) return;
    await ref
        .read(taskQueueProvider)
        .enqueueCapture(
          startUrl: chapter.sourceUrl,
          chapterLimit: 1,
          libraryItemId: chapter.libraryItemId,
          policy: DuplicatePolicy.retryPartial,
          range: CaptureRangeMode.currentChapter,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Re-capturing the missing panels — progress in Activity'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<_ReaderData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data;
          if (data == null || data.unavailableReason != null) {
            final missing = data?.unavailableChapter;
            return _Unavailable(
              message: data?.unavailableReason ?? 'Could not open the chapter.',
              filesGone: data?.filesGone ?? false,
              removedByUser: data?.removedByUser ?? false,
              meta: data?.unavailableMeta,
              onCaptureAgain: missing == null
                  ? null
                  : () => _captureAgain(missing),
            );
          }
          if (data.pages.isEmpty) {
            return const _Unavailable(
              message: 'This chapter has no stored images.',
            );
          }

          final manifest = data.manifest!;
          final width = MediaQuery.of(context).size.width;
          final controller = _controllerFor(data, width);

          final partial = manifest.status == CaptureStatus.partial;
          _leadingExtent =
              kReaderTopSpacer + (partial ? kPartialBannerExtent : 0);

          return Stack(
            children: [
              // Everything above panel 1 lives INSIDE the scroll view, so the
              // banner scrolls away with the content instead of permanently
              // eating a band of the page. Its extent is a known constant,
              // and every offset conversion goes through [_leadingExtent].
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _chromeVisible = !_chromeVisible),
                // Horizontal-only recogniser: it and the list's vertical drag
                // enter the same arena, so a reading scroll never reaches it
                // and a deliberate sideways drag never scrolls the page.
                onHorizontalDragStart: _onDragStart,
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                child: ListView.builder(
                  controller: controller,
                  // The lead-in is list PADDING, not a child: padding adds its
                  // extent exactly, while a short first child would skew
                  // ListView's running estimate of total extent and leave the
                  // scrollable's own maxScrollExtent short of the real bottom.
                  padding: const EdgeInsets.only(top: kReaderTopSpacer),
                  // One trailing row for the end-of-chapter block, plus the
                  // partial banner when there is one.
                  itemCount: data.pages.length + 1 + (partial ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (partial && index == 0) {
                      return _PartialBanner(
                        stored: manifest.storedImageCount,
                        detected: manifest.detectedImageCount,
                        reason: manifest.statusReason,
                        onRetry: () => _retryMissing(data),
                      );
                    }
                    final panel = index - (partial ? 1 : 0);
                    if (panel == data.pages.length) {
                      return _EndOfChapter(
                        data: data,
                        chapterId: _chapterId!,
                        onGoTo: _goTo,
                      );
                    }
                    return _PanelView(
                      page: data.pages[panel],
                      index: panel + 1,
                      height: _layout?.heightOf(panel),
                    );
                  },
                ),
              ),
              // A jump back to where reading left off, offered only once the
              // reader has actually wandered away from it — the app restores
              // the position on open, so an always-on chip would point at
              // where you already are.
              _JumpToSavedChip(
                visible: _chromeVisible && _showJump,
                fraction: _restoredFraction,
                onTap: () {
                  final layout = _layout;
                  if (layout == null) return;
                  controller.animateTo(
                    _leadingExtent +
                        layout.offsetForPosition(_restoredPosition),
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOut,
                  );
                  setState(() => _showJump = false);
                },
              ),
              _ReaderChrome(
                visible: _chromeVisible,
                data: data,
                chapterId: _chapterId!,
                completed: _completed,
                position: _livePosition,
                panelCount: data.pages.length,
                onGoTo: _goTo,
                onToggleRead: _toggleRead,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The overlaid reader chrome: a top bar that identifies the chapter and owns
/// the read toggle, and a bottom bar with chapter movement and position.
///
/// Both fade rather than reflow, so toggling them never moves a single panel —
/// the reader must not jump under the reader's thumb.
///
/// The progress readout listens to the live position notifier, so it moves
/// while the user scrolls (M12) — only that small column rebuilds per tick,
/// never the panel list.
class _ReaderChrome extends StatelessWidget {
  const _ReaderChrome({
    required this.visible,
    required this.data,
    required this.chapterId,
    required this.completed,
    required this.position,
    required this.panelCount,
    required this.onGoTo,
    required this.onToggleRead,
  });

  final bool visible;
  final _ReaderData data;
  final String chapterId;
  final bool completed;
  final ValueListenable<ReadingPosition> position;
  final int panelCount;
  final Future<void> Function(Chapter) onGoTo;
  final VoidCallback onToggleRead;

  @override
  Widget build(BuildContext context) {
    final siblings = data.siblings;
    final index = siblings.indexWhere((c) => c.id == chapterId);
    final previous = index > 0 ? siblings[index - 1] : null;
    final next = (index >= 0 && index + 1 < siblings.length)
        ? siblings[index + 1]
        : null;
    final insets = MediaQuery.paddingOf(context);
    final chapter = data.chapter;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(6, insets.top + 6, 6, 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xF2000000),
                      Color(0xC0000000),
                      Color(0x00000000),
                    ],
                    stops: [0, 0.7, 1],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back, size: 24),
                      color: const Color(0xFFEDEAE4),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            chapter?.chapterLabel ?? chapter?.title ?? 'Reader',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'IBM Plex Mono',
                              fontSize: 14,
                              color: Color(0xFFF2EFE9),
                            ),
                          ),
                          Text(
                            chapter?.title ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8E8A83),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ReadPill(completed: completed, onPressed: onToggleRead),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(10, 8, 10, insets.bottom + 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0xC0000000),
                      Color(0xF2000000),
                    ],
                    stops: [0, 0.3, 1],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous saved chapter',
                      icon: const Icon(Icons.skip_previous, size: 22),
                      color: const Color(0xFFDCD8D1),
                      disabledColor: const Color(0xFF4A4741),
                      onPressed: previous == null
                          ? null
                          : () => onGoTo(previous),
                    ),
                    Expanded(
                      child: ValueListenableBuilder<ReadingPosition>(
                        valueListenable: position,
                        builder: (context, live, _) {
                          final pct = (live.fraction * 100)
                              .clamp(0, 100)
                              .round();
                          final panel = (live.imageIndex + 1).clamp(
                            1,
                            panelCount,
                          );
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: live.fraction.clamp(0.0, 1.0),
                                  minHeight: 4,
                                  backgroundColor: const Color(0xFF24272A),
                                  color: const Color(0xFF9FC3CE),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    completed ? 'Completed' : '$pct%',
                                    style: _readerMeta,
                                  ),
                                  Text(
                                    'panel $panel / $panelCount',
                                    style: _readerMeta,
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next saved chapter',
                      icon: const Icon(Icons.skip_next, size: 22),
                      color: const Color(0xFFDCD8D1),
                      disabledColor: const Color(0xFF4A4741),
                      onPressed: next == null ? null : () => onGoTo(next),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _readerMeta = TextStyle(
  fontFamily: 'IBM Plex Mono',
  fontSize: 10.5,
  color: Color(0xFF7E7A73),
);

class _ReadPill extends StatelessWidget {
  const _ReadPill({required this.completed, required this.onPressed});

  final bool completed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: completed ? const Color(0xFF1E2426) : const Color(0xFF141416),
    borderRadius: BorderRadius.circular(999),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              completed ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 17,
              color: completed
                  ? const Color(0xFF9FC3CE)
                  : const Color(0xFFB8B4AD),
            ),
            const SizedBox(width: 6),
            Text(
              completed ? 'Read' : 'Mark read',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: completed
                    ? const Color(0xFF9FC3CE)
                    : const Color(0xFFB8B4AD),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// What happens after the last panel: the chapter is over, and the next one is
/// one tap away. "Continue" skips ahead to the next thing actually unread.
class _EndOfChapter extends StatelessWidget {
  const _EndOfChapter({
    required this.data,
    required this.chapterId,
    required this.onGoTo,
  });

  final _ReaderData data;
  final String chapterId;
  final Future<void> Function(Chapter) onGoTo;

  @override
  Widget build(BuildContext context) {
    final siblings = data.siblings;
    final index = siblings.indexWhere((c) => c.id == chapterId);
    final next = (index >= 0 && index + 1 < siblings.length)
        ? siblings[index + 1]
        : null;
    final nextUnread = siblings
        .skip(index < 0 ? 0 : index + 1)
        .where((c) => c.readStatus != ReadStatus.completed.name)
        .firstOrNull;
    final target = nextUnread ?? next;
    final label = data.chapter?.chapterLabel ?? data.chapter?.title ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 110),
      child: Column(
        children: [
          Text(
            'END OF ${label.toUpperCase()}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'IBM Plex Mono',
              fontSize: 11,
              letterSpacing: 0.66,
              color: Color(0xFF5E5A54),
            ),
          ),
          if (target != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () => onGoTo(target),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFF14181A),
                foregroundColor: const Color(0xFFDCE6E9),
                side: const BorderSide(color: Color(0xFF2C3134)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),
              ),
              child: Text(
                'Next chapter · ${target.chapterLabel ?? target.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PanelView extends StatelessWidget {
  const _PanelView({required this.page, required this.index, this.height});

  final _ReaderPage page;
  final int index;
  final double? height;

  @override
  Widget build(BuildContext context) {
    if (!page.exists) {
      return Container(
        height: height ?? 160,
        color: const Color(0xFF201010),
        alignment: Alignment.center,
        child: Text(
          'Image $index is missing from local storage',
          style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
        ),
      );
    }

    // Decode at display width, not full resolution: a 60-panel chapter would
    // otherwise be hundreds of MB of bitmaps.
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final decodeWidth = (MediaQuery.of(context).size.width * dpr).round();

    final image = Image.file(
      page.file,
      width: double.infinity,
      height: height,
      // fitWidth + a height derived from the file's own aspect ratio paints
      // the panel exactly, with no stretch in either axis. Never BoxFit.fill:
      // if the recorded ratio is ever wrong, fill distorts, fitWidth merely
      // crops — and topCenter makes that failure show the top of the panel
      // rather than an arbitrary middle slice.
      fit: BoxFit.fitWidth,
      alignment: Alignment.topCenter,
      cacheWidth: decodeWidth,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (context, error, _) => Container(
        height: height ?? 160,
        color: const Color(0xFF201010),
        alignment: Alignment.center,
        child: Text(
          'Image $index could not be decoded',
          style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
        ),
      ),
    );

    // A fixed box keeps the list's geometry identical to the layout the saved
    // offset was computed against, so restoring cannot drift.
    return height == null ? image : SizedBox(height: height, child: image);
  }
}

/// The partial-capture banner. It scrolls away with the content rather than
/// occupying a permanent band, and its height is a fixed constant because the
/// restore offset is computed from it before any layout happens.
class _PartialBanner extends StatelessWidget {
  const _PartialBanner({
    required this.stored,
    required this.detected,
    required this.reason,
    required this.onRetry,
  });

  final int stored;
  final int detected;
  final String? reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final missing = detected - stored;
    return SizedBox(
      height: kPartialBannerExtent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF24190A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF4A3411)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.arrow_circle_down,
              size: 19,
              color: Color(0xFFE0B463),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Partial capture — $stored of $detected images',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF0D9A9),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$missing panel${missing == 1 ? ' is' : 's are'} '
                    'missing${reason == null ? '' : ' ($reason)'}. '
                    'You can read the rest now.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      color: Color(0xFFBFA478),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE0B463),
                foregroundColor: const Color(0xFF2A1D06),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                textStyle: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text('Retry $missing'),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Continue · N%" — the way back to where reading left off.
class _JumpToSavedChip extends StatelessWidget {
  const _JumpToSavedChip({
    required this.visible,
    required this.fraction,
    required this.onTap,
  });

  final bool visible;
  final double fraction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Positioned(
      right: 14,
      bottom: 104,
      child: Material(
        color: const Color(0xFFE8F1F4),
        borderRadius: BorderRadius.circular(999),
        elevation: 6,
        shadowColor: Colors.black,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.south, size: 18, color: Color(0xFF133845)),
                const SizedBox(width: 7),
                Text(
                  'Continue · ${(fraction * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF133845),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The chapter cannot be shown. When its files are gone this is the state the
/// user actually hits — the row is still in the library, the position is still
/// saved, and the only thing missing is the bytes.
class _Unavailable extends StatelessWidget {
  const _Unavailable({
    required this.message,
    this.filesGone = false,
    this.removedByUser = false,
    this.meta,
    this.onCaptureAgain,
  });

  final String message;
  final bool filesGone;

  /// The user removed the files deliberately: cloud glyph and "Not available
  /// offline", never the alarming folder_off/"files are gone" wording.
  final bool removedByUser;

  /// One mono line of fact under the explanation ("removed 3 days ago",
  /// "0 of 41 files present").
  final String? meta;

  /// Offered when the chapter can be brought back.
  final VoidCallback? onCaptureAgain;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            removedByUser
                ? Icons.cloud
                : (filesGone ? Icons.folder_off : Icons.cloud_off),
            size: 34,
            color: const Color(0xFF7E7A73),
          ),
          const SizedBox(height: 10),
          if (filesGone)
            Text(
              removedByUser
                  ? 'Not available offline'
                  : 'The files for this chapter are gone',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              removedByUser
                  ? message
                  : filesGone
                  ? 'The chapter is still listed, but its images are not on '
                        'the device any more. Your reading position is kept — '
                        'capture it again to read it.'
                  : message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.6,
                color: Color(0xFF9C978F),
              ),
            ),
          ),
          if (meta != null) ...[
            const SizedBox(height: 10),
            Text(
              meta!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'IBM Plex Mono',
                fontSize: 11,
                color: Color(0xFF6A665F),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Builder(
            builder: (context) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onCaptureAgain != null) ...[
                  FilledButton(
                    onPressed: onCaptureAgain,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE8F1F4),
                      foregroundColor: const Color(0xFF133845),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Capture again'),
                  ),
                  const SizedBox(width: 9),
                ],
                OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE4E1DA),
                    side: const BorderSide(color: Color(0xFF3A3833)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Back to series'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReaderPage {
  const _ReaderPage({
    required this.file,
    required this.exists,
    this.width,
    this.height,
  });

  final File file;
  final bool exists;
  final int? width;
  final int? height;
}

class _ReaderData {
  const _ReaderData({
    required this.chapter,
    required this.manifest,
    required this.pages,
    this.siblings = const [],
  }) : unavailableReason = null,
       filesGone = false,
       removedByUser = false,
       unavailableMeta = null,
       unavailableChapter = null;

  const _ReaderData.unavailable(
    this.unavailableReason, {
    this.filesGone = false,
    this.removedByUser = false,
    this.unavailableMeta,
    this.unavailableChapter,
  }) : chapter = null,
       manifest = null,
       pages = const [],
       siblings = const [];

  final Chapter? chapter;
  final ChapterManifest? manifest;
  final List<_ReaderPage> pages;

  /// The row is intact but its images are not on the device any more.
  final bool filesGone;

  /// …because the user removed them (not because the system lost them).
  final bool removedByUser;

  /// One line of fact for the unavailable state.
  final String? unavailableMeta;

  /// The row behind an unavailable chapter, so it can be captured again.
  final Chapter? unavailableChapter;

  /// Locally readable chapters of the same series, in reading order.
  final List<Chapter> siblings;
  final String? unavailableReason;
}

/// Re-exported so the reader route can resolve files without importing
/// `file_store.dart` in the router.
typedef ReaderFileStore = FileStore;
