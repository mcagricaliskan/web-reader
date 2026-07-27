import 'dart:async';

import 'package:uuid/uuid.dart';

import '../browser/browser_controller.dart';
import '../browser/page_data.dart';
import '../core/config.dart';
import '../core/url_utils.dart';
import '../storage/database.dart';
import '../storage/file_store.dart';
import '../storage/manifest.dart';
import 'asset_downloader.dart';
import 'capture_state.dart';
import 'image_candidates.dart';
import 'next_page.dart';
import 'site_rule.dart';
import '../library/series_identity.dart';
import '../library/series_repository.dart';

const _uuid = Uuid();

/// Result of capturing one chapter.
class ChapterCaptureResult {
  const ChapterCaptureResult({
    required this.status,
    required this.chapterId,
    this.manifest,
    this.nextUrl,
    this.nextEvidence,
    this.nextResult,
    this.readerRuleFailed = false,
    this.extractionFailed = false,
    this.pageUrl = '',
    this.error,
    this.detectedImages = 0,
    this.storedImages = 0,
  });

  final CaptureStatus status;
  final String chapterId;
  final ChapterManifest? manifest;
  final String? nextUrl;
  final String? nextEvidence;

  /// The full decision, including whether the user should be asked.
  final NextPageResult? nextResult;

  /// A saved reader-area rule matched nothing on this page.
  final bool readerRuleFailed;

  /// Generic extraction found too little to be a chapter.
  final bool extractionFailed;
  final String pageUrl;
  final String? error;
  final int detectedImages;
  final int storedImages;

  bool get isUsable =>
      status == CaptureStatus.complete || status == CaptureStatus.partial;
}

class CaptureCancelled implements Exception {}

/// Captures the page the WebView is currently showing.
///
/// The load-complete callback is treated as meaningless for content readiness:
/// the engine scrolls, watches document height / image counts / pending
/// decodes, and only extracts once the page has been quiet for a configured
/// period. That is the whole reason this class exists.
class CaptureEngine {
  CaptureEngine({
    required this.browser,
    required this.db,
    required this.fileStore,
    required this.downloader,
    this.config = kDefaultCaptureConfig,
    this.onProgress,
    this.onLog,
  });

  final BrowserController browser;
  final AppDatabase db;
  final FileStore fileStore;
  final AssetDownloader downloader;
  final CaptureConfig config;
  final void Function(CaptureProgress Function(CaptureProgress))? onProgress;
  final void Function(String)? onLog;

  bool _cancelled = false;
  bool _paused = false;

  /// Chapter deadline. A field (not a parameter) because time spent waiting
  /// for the user to bring the Browser back is *their* time, not the page's —
  /// [_waitForRenderedSurface] extends it by exactly the waited duration.
  DateTime _deadline = DateTime.now();

  /// Phase durations for the diagnostic timing line, in milliseconds.
  final Map<String, int> _timings = {};

  /// The best candidate set seen during scrolling. If final extraction
  /// collapses far below this, something broke the page under us (an
  /// unrendered surface, a teardown) — refuse to store the wreckage.
  int _peakAccepted = 0;
  int _peakPanelHeight = 0;

  void cancel() => _cancelled = true;
  void pause() => _paused = true;
  void resume() => _paused = false;
  void reset() {
    _cancelled = false;
    _paused = false;
  }

  void _time(String phase, DateTime since) {
    _timings.update(
      phase,
      (v) => v + DateTime.now().difference(since).inMilliseconds,
      ifAbsent: () => DateTime.now().difference(since).inMilliseconds,
    );
  }

  void _log(String message) => onLog?.call(message);

  void _emit(CaptureProgress Function(CaptureProgress) update) =>
      onProgress?.call(update);

  Future<void> _checkpoint() async {
    if (_cancelled) throw CaptureCancelled();
    while (_paused) {
      _emit((p) => p.copyWith(state: CaptureState.paused));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (_cancelled) throw CaptureCancelled();
    }
  }

  Future<ChapterCaptureResult> captureCurrentPage({
    required String libraryItemId,
    required int sequence,
    required Set<String> visitedNormalized,
    SiteRule? readerRule,
    SiteRule? nextRule,
    bool replaceExisting = false,
  }) async {
    var chapterId = _uuid.v4();
    _deadline = DateTime.now().add(config.maxCaptureDuration);
    _timings.clear();
    _peakAccepted = 0;
    _peakPanelHeight = 0;
    StagingHandle? staging;

    try {
      // 1. Inspect ------------------------------------------------------
      _emit(
        (p) => p.copyWith(
          state: CaptureState.inspecting,
          message: 'Reading the page',
          clearError: true,
        ),
      );
      var tPhase = DateTime.now();
      final initial = await _awaitDomReady(_deadline);
      _time('domReady', tPhase);
      await _checkpoint();

      // An unrendered WebView (hidden tab) answers probes but measures
      // nothing real. Hold here — before any scrolling or judgement — until
      // the surface is back.
      await _waitForRenderedSurface('inspect');

      final pageTitle = initial.title.trim().isEmpty
          ? 'Untitled chapter'
          : initial.title;
      final pageUrl = initial.url.isEmpty ? browser.currentUrl : initial.url;

      // Re-capturing a chapter (a retry after a partial, say) must replace the
      // existing row, not insert a second one: `url_key` is unique per item, so
      // a fresh id would collide and the retry could never succeed.
      final existing = await db.findChapterByUrlKey(
        libraryItemId,
        normalizeUrl(pageUrl),
      );
      if (existing != null) {
        chapterId = existing.id;
        _log(
          're-capturing existing chapter '
          '${existing.id.length > 8 ? existing.id.substring(0, 8) : existing.id} '
          '(was ${existing.captureStatus})',
        );
      }
      _emit((p) => p.copyWith(chapterTitle: pageTitle, currentUrl: pageUrl));
      _log('capture start: "$pageTitle" <$pageUrl>');

      // 2-4. Scroll until the page stops changing ------------------------
      tPhase = DateTime.now();
      await _scrollUntilStable(initial);
      _time('scroll', tPhase);
      await _checkpoint();

      // 5. Verify --------------------------------------------------------
      _emit(
        (p) => p.copyWith(
          state: CaptureState.verifying,
          message: 'Checking what loaded',
        ),
      );
      // Never measure the final candidate set on an unrendered surface.
      await _waitForRenderedSurface('verify');
      tPhase = DateTime.now();
      var probeWithLinks = await browser.probe(withLinks: true);
      if (probeWithLinks.viewportHeight <= 0) {
        // Went hidden between the guard and the probe: wait and re-measure.
        await _waitForRenderedSurface('verify');
        probeWithLinks = await browser.probe(withLinks: true);
      }

      // A user-taught reader area wins over the generic heuristic — the user
      // pointed at the container, so there is nothing to infer.
      CandidateSelection? selection;
      if (readerRule != null) {
        final images = await browser.applyReaderRule(
          readerRule.locator.toJson(),
        );
        if (images != null && images.isNotEmpty) {
          selection = selectImageCandidates(images, config: config);
          _log(
            'reader-area rule matched ${images.length} image(s) -> '
            '${selection.acceptedCount} candidate(s)',
          );
        } else {
          _log('reader-area rule matched nothing on this page');
          return ChapterCaptureResult(
            status: CaptureStatus.failed,
            chapterId: chapterId,
            error: 'saved reader-area rule no longer matches',
            readerRuleFailed: true,
            pageUrl: pageUrl,
          );
        }
      }

      final chosen =
          selection ??
          selectImageCandidates(probeWithLinks.images, config: config);
      final rejectionCounts = <RejectReason, int>{};
      for (final r in chosen.rejected) {
        rejectionCounts.update(r.reason, (v) => v + 1, ifAbsent: () => 1);
      }
      _log(
        'candidates: ${chosen.acceptedCount} accepted, '
        '${chosen.rejected.length} rejected '
        '(of ${probeWithLinks.images.length} images) '
        '${rejectionCounts.entries.map((e) => '${e.key.name}=${e.value}').join(' ')}',
      );

      if (chosen.acceptedCount < config.minCandidates) {
        // Not a hard failure: the job can ask the user to point at the reader.
        return ChapterCaptureResult(
          status: CaptureStatus.failed,
          chapterId: chapterId,
          error:
              'Only ${chosen.acceptedCount} content images found '
              '(need ${config.minCandidates})',
          extractionFailed: true,
          pageUrl: pageUrl,
        );
      }

      // Defensive extraction: if scrolling saw a healthy panel set and the
      // final selection collapsed to a fraction of it — or to short
      // avatar-sized images where tall panels were seen — the page is not
      // what it was (unrendered surface, teardown, layout loss). Storing
      // that would be a confident lie; fail towards user assistance instead.
      final chosenMaxHeight = chosen.accepted.fold<int>(
        0,
        (m, c) => c.height > m ? c.height : m,
      );
      final collapsedCount =
          _peakAccepted >= config.minCandidates &&
          chosen.acceptedCount * 2 < _peakAccepted;
      final collapsedHeight =
          _peakPanelHeight > 0 && chosenMaxHeight * 10 < _peakPanelHeight;
      if (readerRule == null && (collapsedCount || collapsedHeight)) {
        _log(
          'extraction collapsed: saw $_peakAccepted candidates '
          '(tallest $_peakPanelHeight px) while scrolling, now '
          '${chosen.acceptedCount} (tallest $chosenMaxHeight px) — refusing '
          'to store',
        );
        return ChapterCaptureResult(
          status: CaptureStatus.failed,
          chapterId: chapterId,
          error:
              'The page changed under the capture — found '
              '${chosen.acceptedCount} images where $_peakAccepted were seen',
          extractionFailed: true,
          pageUrl: pageUrl,
        );
      }
      _time('extract', tPhase);

      // 6. Extract -------------------------------------------------------
      _emit(
        (p) => p.copyWith(
          state: CaptureState.extracting,
          detectedImages: chosen.acceptedCount,
          message: '${chosen.acceptedCount} images to fetch',
        ),
      );
      await _checkpoint();

      // 7. Download into staging ----------------------------------------
      staging = await fileStore.beginChapter(
        libraryItemId: libraryItemId,
        chapterId: chapterId,
      );

      final userAgent = await browser.userAgent();
      final cookieHeader = await browser.cookieHeaderFor(pageUrl);

      var entries = <AssetEntry>[
        for (var i = 0; i < chosen.accepted.length; i++)
          AssetEntry(
            index: i + 1,
            sourceUrl: chosen.accepted[i].url,
            status: AssetStatus.pending,
            width: chosen.accepted[i].width,
            height: chosen.accepted[i].height,
          ),
      ];

      _emit(
        (p) => p.copyWith(
          state: CaptureState.downloading,
          storedImages: 0,
          failedImages: 0,
        ),
      );

      tPhase = DateTime.now();
      entries = await _downloadAll(
        entries: entries,
        staging: staging,
        refererUrl: pageUrl,
        userAgent: userAgent,
        cookieHeader: cookieHeader,
      );
      _time('download', tPhase);
      await _checkpoint();

      final stored = entries.where((e) => e.isStored).length;
      final failed = entries.length - stored;

      if (stored == 0) {
        await fileStore.discard(staging);
        return _fail(chapterId, 'No images could be downloaded');
      }

      // 8. Detect the next chapter before we leave the page --------------
      _emit((p) => p.copyWith(state: CaptureState.detectingNext));

      String? ruleHref;
      if (nextRule != null) {
        final match = await browser.applyLocator(nextRule.locator.toJson());
        if (match != null && match.isMatch) {
          ruleHref = match.href;
          _log(
            'saved next-link rule matched (${match.matchedSignals}, '
            'score ${match.score}${match.ambiguous ? ", ambiguous" : ""})',
          );
        } else {
          _log(
            'saved next-link rule did not match: '
            '${match?.failureReason ?? "no result"}',
          );
        }
      }

      final next = resolveNextPage(
        probeWithLinks,
        currentUrl: pageUrl,
        visitedNormalized: visitedNormalized,
        ruleHref: ruleHref,
      );
      if (next.needsUserSelection) {
        _log('next: not confident — ${next.reason}');
      } else if (next.hasNext) {
        _log(
          'next: ${next.chosen!.href} '
          'via ${next.chosen!.strategy.label} (${next.chosen!.evidence})',
        );
      } else {
        _log(
          'next: none (${next.considered.length} candidates considered, '
          '${next.rejection?.name ?? "no candidates"})',
        );
      }

      // 9. Save: manifest -> atomic move -> database --------------------
      _emit((p) => p.copyWith(state: CaptureState.saving, message: 'Saving'));

      final status = failed == 0
          ? CaptureStatus.complete
          : CaptureStatus.partial;
      final manifest = ChapterManifest(
        schemaVersion: ChapterManifest.currentSchemaVersion,
        chapterId: chapterId,
        libraryItemId: libraryItemId,
        sourceUrl: pageUrl,
        canonicalUrl: probeWithLinks.canonicalUrl,
        title: pageTitle,
        capturedAt: DateTime.now(),
        status: status,
        statusReason: failed == 0 ? null : 'assetsFailed:$failed',
        detectedImageCount: entries.length,
        storedImageCount: stored,
        nextUrl: next.chosen?.href,
        sequence: sequence,
        assets: entries,
      );

      // Replacing keeps the old copy until the new one is safely in place, so
      // a failed re-download leaves the readable chapter untouched.
      tPhase = DateTime.now();
      final relativePath = replaceExisting || existing?.contentPath != null
          ? await fileStore.commitReplacing(staging, manifest)
          : await fileStore.commit(staging, manifest);
      staging = null;

      final byteSize = await fileStore.chapterByteSize(relativePath);
      final chapterNumber = parseChapterNumber(title: pageTitle, url: pageUrl);
      await db.upsertChapter(
        Chapter(
          id: chapterId,
          libraryItemId: libraryItemId,
          title: pageTitle,
          sourceUrl: pageUrl,
          urlKey: normalizeUrl(pageUrl),
          captureStatus: status.name,
          contentPath: relativePath,
          capturedAt: manifest.capturedAt,
          detectedImageCount: entries.length,
          storedImageCount: stored,
          nextSourceUrl: next.chosen?.href,
          // A row that already had a place in the series (a discovered
          // chapter, a retried partial) keeps it; this job's traversal
          // ordinal is only for chapters it introduces.
          sequence: existing != null && existing.sequence > 0
              ? existing.sequence
              : sequence,
          captureError: failed == 0 ? null : '$failed image(s) failed',
          byteSize: byteSize,
          chapterNumber: chapterNumber,
          chapterLabel: chapterLabelFrom(
            title: pageTitle,
            url: pageUrl,
            number: chapterNumber,
          ),
          // Reading state is carried over verbatim, never rebuilt. Capturing a
          // chapter — including re-downloading one — must not move the user's
          // place or un-finish something they had read.
          readStatus: existing?.readStatus ?? 'unread',
          progressFraction: existing?.progressFraction ?? 0,
          progressImageIndex: existing?.progressImageIndex ?? 0,
          progressOffsetInImage: existing?.progressOffsetInImage ?? 0,
          firstOpenedAt: existing?.firstOpenedAt,
          lastReadAt: existing?.lastReadAt,
          completedAt: existing?.completedAt,
          progressUpdatedAt: existing?.progressUpdatedAt,
          // Capturing a chapter an update check discovered fills in the same
          // row; keep the discovery record as history.
          discoveredAt: existing?.discoveredAt,
          discoveryBasis: existing?.discoveryBasis,
          discoveryConfidence: existing?.discoveryConfidence,
        ),
      );
      // Files are back, so the user-removed marker must go (a null on the
      // data class would be treated as "leave it alone").
      await db.clearOfflineRemovedMark(chapterId);
      await db.markSeriesCaptured(libraryItemId, manifest.capturedAt);

      _time('commit', tPhase);
      _log(
        'saved $stored/${entries.length} images -> $relativePath '
        '(${status.name})',
      );
      _log(
        '[timing] ${_timings.entries.map((e) => '${e.key}=${e.value}ms').join(' · ')}',
      );

      _emit(
        (p) => p.copyWith(
          state: status == CaptureStatus.complete
              ? CaptureState.complete
              : CaptureState.partial,
          storedImages: stored,
          failedImages: failed,
          message: 'Saved $stored of ${entries.length} images',
        ),
      );

      return ChapterCaptureResult(
        status: status,
        chapterId: chapterId,
        manifest: manifest,
        nextUrl: next.hasNext ? next.chosen?.href : null,
        nextEvidence: next.chosen?.evidence,
        nextResult: next,
        pageUrl: pageUrl,
        detectedImages: entries.length,
        storedImages: stored,
      );
    } on CaptureCancelled {
      if (staging != null) await fileStore.discard(staging);
      _emit(
        (p) => p.copyWith(state: CaptureState.cancelled, message: 'Cancelled'),
      );
      return ChapterCaptureResult(
        status: CaptureStatus.failed,
        chapterId: chapterId,
        error: 'cancelled',
      );
    } catch (e, stack) {
      if (staging != null) await fileStore.discard(staging);
      _log('capture error: $e\n$stack');
      return _fail(chapterId, e.toString());
    }
  }

  ChapterCaptureResult _fail(String chapterId, String reason) {
    _log('capture failed: $reason');
    _emit(
      (p) => p.copyWith(
        state: CaptureState.failed,
        lastError: reason,
        message: reason,
      ),
    );
    return ChapterCaptureResult(
      status: CaptureStatus.failed,
      chapterId: chapterId,
      error: reason,
    );
  }

  // --- page readiness -----------------------------------------------------

  Future<PageProbe> _awaitDomReady(DateTime deadline) async {
    final domDeadline = DateTime.now().add(config.domReadyTimeout);
    PageProbe? last;
    while (DateTime.now().isBefore(domDeadline) &&
        DateTime.now().isBefore(deadline)) {
      await _checkpoint();
      try {
        final probe = await browser.probe();
        last = probe;
        if (probe.domReady) return probe;
      } catch (_) {
        // The page may be mid-navigation; retry until the deadline.
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (last != null) return last;
    throw StateError('Page never became inspectable');
  }

  /// Hold while the WebView surface is unrendered (hidden tab).
  ///
  /// An offstage WKWebView answers probes with real DOM data but zero
  /// viewport and a scroll position that never moves — measurements taken in
  /// that state are garbage. The engine waits (checkpointing for cancel), and
  /// the waited time is *added back* to the chapter deadline: the page did
  /// not get slower, the user just looked away.
  Future<void> _waitForRenderedSurface(String phase) async {
    var warned = false;
    final waitStart = DateTime.now();
    while (true) {
      await _checkpoint();
      PageProbe probe;
      try {
        probe = await browser.probe();
      } catch (_) {
        // Mid-navigation; the caller's own probe loop handles that case.
        return;
      }
      if (probe.viewportHeight > 0) {
        if (warned) {
          final waited = DateTime.now().difference(waitStart);
          _deadline = _deadline.add(waited);
          _time('browserWait', waitStart);
          _log(
            'browser surface is back after ${waited.inSeconds}s — resuming '
            '($phase)',
          );
        }
        return;
      }
      if (!warned) {
        warned = true;
        _log(
          'browser surface is not rendered (zero viewport) — holding the '
          '$phase phase until the Browser tab is visible',
        );
        _emit(
          (p) => p.copyWith(
            state: CaptureState.waitingForBrowser,
            message: 'Open the Browser to continue capture.',
          ),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  /// Pending images that could plausibly be chapter content. A comment-box
  /// avatar that never loads must not hold the capture for the full asset
  /// wait — but a pending image with a content-sized box (or no measurable
  /// size at all, which is unknowable and therefore treated as relevant)
  /// still does.
  int _relevantPendingCount(PageProbe probe) {
    final threshold = (config.minImageEdge * 0.7).round();
    return probe.images.where((i) {
      if (i.effectiveUrl == null || i.hidden || i.inPageChrome) return false;
      if (i.complete || i.isResolved) return false;
      final w = i.effectiveWidth > 0 ? i.effectiveWidth : i.renderedWidth;
      final h = i.effectiveHeight > 0 ? i.effectiveHeight : i.renderedHeight;
      if (w == 0 && h == 0) return true; // unknown: assume it matters
      return w >= threshold || h >= threshold;
    }).length;
  }

  /// Track the best candidate set seen while traversing, for the collapse
  /// guard at extraction time.
  void _trackPeak(PageProbe probe) {
    final selection = selectImageCandidates(probe.images, config: config);
    if (selection.acceptedCount > _peakAccepted) {
      _peakAccepted = selection.acceptedCount;
    }
    for (final c in selection.accepted) {
      if (c.height > _peakPanelHeight) _peakPanelHeight = c.height;
    }
  }

  /// Scroll, watching for growth and lazy loads, and stop only when the page
  /// has been quiet for [CaptureConfig.quietPeriod] at the bottom.
  ///
  /// A second downward pass runs when the first one revealed new images: many
  /// lazy loaders only fire when an element is scrolled *into* view from
  /// above, so a first pass that outran the loader leaves holes.
  Future<PageProbe> _scrollUntilStable(PageProbe initial) async {
    var probe = initial;
    var pass = 0;
    var previousImageCount = probe.images.length;

    while (pass < config.maxScrollPasses) {
      pass++;
      _log('scroll pass $pass');
      probe = await _scrollPass(probe, pass);
      await _checkpoint();

      probe = await _waitForPendingAssets();
      await _checkpoint();

      final grew = probe.images.length > previousImageCount;
      previousImageCount = probe.images.length;
      if (!grew) break;

      if (pass < config.maxScrollPasses) {
        await browser.scrollTo(0);
        await Future<void>.delayed(config.scrollDelay);
      }
    }
    return probe;
  }

  /// One downward pass, paced by evidence.
  ///
  /// **Careful** (the original 0.8-viewport / 300 ms pace) whenever anything
  /// within [CaptureConfig.lookaheadViewports] below the position is still
  /// loading, the document height moved, or the bottom is near. **Fast**
  /// ([CaptureConfig.fastScrollStepViewports] per step,
  /// [CaptureConfig.fastScrollDelay]) after
  /// [CaptureConfig.fastModeAfterStableProbes] consecutive probes with a
  /// fully-resolved lookahead — the audit measured scrolling at 90–98% of
  /// capture time on pages whose content was already loaded.
  ///
  /// The stopping condition is untouched: at bottom, quiet for
  /// [CaptureConfig.quietPeriod], [CaptureConfig.requiredStableChecks] times.
  Future<PageProbe> _scrollPass(PageProbe start, int pass) async {
    _emit(
      (p) => p.copyWith(
        state: CaptureState.scrolling,
        message: 'Scrolling (pass $pass)',
      ),
    );

    var probe = start;
    var stableChecks = 0;
    var iterations = 0;
    var lastSignature = probe.stabilitySignature;
    var lastChangeAt = DateTime.now();
    var lastDocHeight = probe.documentHeight;
    var resolvedStreak = 0;
    var frozenSteps = 0;
    var fastSteps = 0;

    while (iterations < config.maxScrollIterations) {
      await _checkpoint();
      if (DateTime.now().isAfter(_deadline)) {
        _log('scroll pass $pass hit the capture deadline');
        break;
      }
      iterations++;

      // Unrendered surface: hold instead of issuing scrolls into the void.
      if (probe.viewportHeight <= 0) {
        await _waitForRenderedSurface('scroll');
        _emit(
          (p) => p.copyWith(
            state: CaptureState.scrolling,
            message: 'Scrolling (pass $pass)',
          ),
        );
        probe = await browser.probe();
        lastChangeAt = DateTime.now();
        continue;
      }

      // Fast when everything within the lookahead is resolved and the layout
      // is standing still; careful otherwise, and always near the bottom.
      // The lookahead must cover the whole prospective jump PLUS a margin —
      // a 3.5-viewport leap cleared by a 2-viewport check would sail past a
      // lazy trigger sitting between the two.
      final viewport = probe.viewportHeight;
      final lookahead =
          probe.scrollY +
          viewport *
              (1 + config.fastScrollStepViewports + config.lookaheadViewports);
      final unresolvedNear = probe.images.any(
        (i) =>
            i.effectiveUrl != null &&
            !i.hidden &&
            !i.isResolved &&
            !i.isBroken &&
            i.documentTop < lookahead,
      );
      final heightMoved = probe.documentHeight != lastDocHeight;
      lastDocHeight = probe.documentHeight;
      final distanceToBottom =
          probe.documentHeight - (probe.scrollY + viewport);
      final nearBottom =
          distanceToBottom < viewport * config.lookaheadViewports;

      if (!unresolvedNear && !heightMoved && !nearBottom) {
        resolvedStreak++;
      } else {
        resolvedStreak = 0;
      }
      final fast = resolvedStreak >= config.fastModeAfterStableProbes;
      if (fast) fastSteps++;

      final step = fast
          ? (viewport * config.fastScrollStepViewports).round()
          : (viewport * config.scrollStepFraction).round();
      final yBefore = probe.scrollY;
      await browser.scrollStep(step < 100 ? 400 : step);
      await Future<void>.delayed(
        fast ? config.fastScrollDelay : config.scrollDelay,
      );

      probe = await browser.probe();
      _trackPeak(probe);

      // Scroll commands that move nothing: with a rendered viewport this is
      // a page quirk — stop the pass and let extraction (and its collapse
      // guard) judge what actually loaded, instead of spinning the bound.
      if (probe.scrollY == yBefore && !probe.atBottom) {
        frozenSteps++;
        if (probe.viewportHeight <= 0) continue; // handled at loop top
        if (frozenSteps >= 6) {
          _log(
            'scroll pass $pass: position frozen at ${probe.scrollY} for '
            '$frozenSteps steps — stopping the pass',
          );
          break;
        }
      } else {
        frozenSteps = 0;
      }

      final signature = probe.stabilitySignature;
      if (signature != lastSignature) {
        lastSignature = signature;
        lastChangeAt = DateTime.now();
        stableChecks = 0;
      }

      final percent = probe.documentHeight == 0
          ? 0.0
          : ((probe.scrollY + probe.viewportHeight) / probe.documentHeight)
                .clamp(0.0, 1.0);
      _emit(
        (p) => p.copyWith(
          scrollPercent: percent,
          detectedImages: probe.images.length,
          message:
              'Scrolling (pass $pass) · '
              '${probe.resolvedImageCount}/${probe.images.length} images',
        ),
      );

      // Quiescence is judged on *change*, not on everything having succeeded.
      // A broken image never resolves, so requiring zero pending images here
      // would spin until the iteration bound.
      final quietFor = DateTime.now().difference(lastChangeAt);
      if (probe.atBottom && quietFor >= config.quietPeriod) {
        stableChecks++;
        if (stableChecks >= config.requiredStableChecks) {
          _log(
            'stable after $iterations steps '
            '($fastSteps fast, ${probe.images.length} images, '
            'height ${probe.documentHeight}, '
            '${probe.pendingImageCount} pending, '
            '${probe.brokenImageCount} broken)',
          );
          break;
        }
      } else if (probe.atBottom) {
        // At the bottom but not yet quiet — hold position and keep watching.
        await Future<void>.delayed(config.scrollDelay);
      }
    }

    if (iterations >= config.maxScrollIterations) {
      _log(
        'scroll pass $pass stopped at the iteration bound '
        '(possible infinite scroll)',
      );
    }
    return probe;
  }

  Future<PageProbe> _waitForPendingAssets() async {
    _emit((p) => p.copyWith(state: CaptureState.waitingForAssets));
    final assetDeadline = DateTime.now().add(config.maxAssetWait);
    var probe = await browser.probe();

    // Wait only for images that could be content. A comments-section avatar
    // stuck in "loading" forever is not a reason to hold the chapter for
    // [CaptureConfig.maxAssetWait].
    var relevant = _relevantPendingCount(probe);
    while (relevant > 0 &&
        DateTime.now().isBefore(assetDeadline) &&
        DateTime.now().isBefore(_deadline)) {
      await _checkpoint();
      _emit((p) => p.copyWith(message: '$relevant image(s) still loading'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      probe = await browser.probe();
      relevant = _relevantPendingCount(probe);
    }

    final irrelevant = probe.pendingImageCount - relevant;
    if (relevant > 0) {
      _log('$relevant content image(s) never finished loading');
    }
    if (irrelevant > 0) {
      _log('$irrelevant unrelated image(s) still pending — not waiting');
    }
    if (probe.brokenImageCount > 0) {
      // Not fatal here: a broken image stays a candidate so its download fails
      // explicitly and the chapter is marked partial, rather than the page
      // quietly shrinking by one.
      _log('${probe.brokenImageCount} image(s) failed to load in the page');
    }
    return probe;
  }

  // --- downloads ----------------------------------------------------------

  Future<List<AssetEntry>> _downloadAll({
    required List<AssetEntry> entries,
    required StagingHandle staging,
    required String refererUrl,
    String? userAgent,
    String? cookieHeader,
  }) async {
    final results = List<AssetEntry>.from(entries);
    var completed = 0;
    var failed = 0;
    var cursor = 0;

    Future<void> worker() async {
      while (true) {
        await _checkpoint();
        final index = cursor;
        if (index >= results.length) return;
        cursor++;

        final result = await downloader.download(
          entry: results[index],
          staging: staging,
          refererUrl: refererUrl,
          userAgent: userAgent,
          cookieHeader: cookieHeader,
        );
        results[index] = result;

        if (result.isStored) {
          completed++;
        } else {
          failed++;
          _log('asset ${result.index} failed: ${result.error}');
        }
        _emit(
          (p) => p.copyWith(
            storedImages: completed,
            failedImages: failed,
            message: 'Downloaded $completed/${results.length}',
          ),
        );
      }
    }

    await Future.wait([
      for (var i = 0; i < config.downloadConcurrency; i++) worker(),
    ]);
    return results;
  }
}

/// Find or create the series group that owns chapters captured from [url].
///
/// Superseded the old "host + first path segment" rule, which collapsed every
/// series on a site into one shelf. Identity now comes from
/// [resolveSeriesIdentity]; see `lib/library/series_identity.dart`.
Future<LibraryItem> ensureLibraryItem({
  required AppDatabase db,
  required String url,
  required String title,
  SeriesHints hints = const SeriesHints(),
  void Function(String)? log,
}) => SeriesRepository(
  db,
).resolveGroup(chapterUrl: url, pageTitle: title, hints: hints, log: log);
