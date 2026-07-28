import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'bridge_script.dart';
import 'browser_presentation.dart';
import 'browser_url.dart';
import 'history_repository.dart';
import 'page_data.dart';

/// The single boundary between the app and `flutter_inappwebview`.
///
/// Nothing else in `lib/` imports the plugin. Swapping the WebView means
/// reimplementing this class and the injected JS — not touching capture,
/// storage, or UI.
class BrowserController extends ChangeNotifier {
  InAppWebViewController? _webView;

  String _currentUrl = '';
  String _title = '';
  bool _isLoading = false;
  double _progress = 0;
  String? _lastError;
  bool _canGoBack = false;
  bool _canGoForward = false;

  final _navigationCompleters = <Completer<void>>[];
  final _selectionController = StreamController<SelectedElement>.broadcast();

  /// While a capture job runs, the page may not initiate its own top-level
  /// navigation. A user-selected control is a strong signal about *one* link;
  /// it is not permission to follow whatever the page does next.
  bool navigationLocked = false;
  String? _allowedNavigationUrl;

  /// Who is driving the WebView right now ("a capture job", "an update
  /// check"), or null. There is exactly one WebView; two autonomous processes
  /// navigating it at once would corrupt both, so each refuses to start while
  /// the other holds this.
  String? automationOwner;

  /// What kind of navigation the WebView is doing right now.
  ///
  /// Set beside [automationOwner] by whoever takes the WebView. History
  /// recording reads it, and *also* refuses outright while
  /// [automationOwner] is non-null — two independent guards, because a
  /// capture flooding the user's history is the failure this exists to
  /// prevent (D53).
  NavigationSource navigationSource = NavigationSource.manual;

  /// True when something other than the user is moving the page.
  bool get isAutomating => automationOwner != null;

  /// The source a visit landing now should be attributed to.
  ///
  /// While something holds the WebView, `manual` is not an available answer
  /// even if nobody set [navigationSource] — a forgotten assignment degrades
  /// to `internal`, which is excluded from History, rather than to the one
  /// value that would pollute it.
  NavigationSource get effectiveNavigationSource {
    if (!isAutomating) return navigationSource;
    return navigationSource == NavigationSource.manual
        ? NavigationSource.internal
        : navigationSource;
  }

  /// Called once per completed main-frame load. The history repository is
  /// wired to this at bootstrap; the controller itself knows nothing about
  /// storage.
  void Function(BrowserVisit visit)? onVisitCompleted;

  /// Hosts the user has explicitly allowed this session to leave for.
  final Set<String> _allowedHostChanges = {};

  /// A cross-host navigation waiting on the user. Null when nothing is pending.
  HostChangeRequest? _pendingHostChange;
  HostChangeRequest? get pendingHostChange => _pendingHostChange;

  /// How long the prompt waits before denying. Silence means "stay here" —
  /// a redirect the user did not ask for should not win by default.
  static const Duration hostChangeTimeout = Duration(seconds: 5);

  /// Elements the user taps while in selection mode.
  Stream<SelectedElement> get selections => _selectionController.stream;

  bool _selectionActive = false;
  bool get isSelecting => _selectionActive;

  String get currentUrl => _currentUrl;
  String get title => _title;
  bool get isLoading => _isLoading;
  double get progress => _progress;
  String? get lastError => _lastError;
  bool get canGoBack => _canGoBack;
  bool get canGoForward => _canGoForward;
  bool get isAttached => _webView != null;

  /// Registered at document start so `__wr` exists for Web Inspector poking.
  /// Bridge calls do not depend on it — they carry their own preamble.
  static final UserScript bridgeUserScript = UserScript(
    source: kBridgePreamble,
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    forMainFrameOnly: true,
  );

  static InAppWebViewSettings get settings => InAppWebViewSettings(
    javaScriptEnabled: true,
    // Needed so navigation can be vetoed while a job is running.
    useShouldOverrideUrlLoading: true,
    javaScriptCanOpenWindowsAutomatically: false,
    supportMultipleWindows: false,
    // Non-incognito and never cleared: the session the user browsed with
    // is the session capture runs in.
    incognito: false,
    cacheEnabled: true,
    mediaPlaybackRequiresUserGesture: true,
    transparentBackground: false,
    // iOS 16.4+ requires this opt-in for Safari Web Inspector.
    isInspectable: kDebugMode,
    allowsInlineMediaPlayback: true,
  );

  /// Allow exactly one upcoming navigation (the chapter the job chose).
  void allowNextNavigation(String url) => _allowedNavigationUrl = url;

  /// Veto policy for `shouldOverrideUrlLoading`. Returns true to block.
  bool shouldBlockNavigation(String? url, {required bool isMainFrame}) {
    if (!navigationLocked || !isMainFrame || url == null) return false;
    final allowed = _allowedNavigationUrl;
    if (allowed == null) return true;
    if (url == allowed) return false;
    // Redirects within the allowed target's origin+path prefix are fine; a
    // jump elsewhere is not.
    final a = Uri.tryParse(allowed);
    final b = Uri.tryParse(url);
    if (a == null || b == null) return true;
    return a.host.toLowerCase() != b.host.toLowerCase();
  }

  /// Does leaving [fromUrl] for [toUrl] need the user's say-so?
  ///
  /// Only for navigation the *page* started — a tap the user made is already
  /// their decision. A redirect that hops to another host is the case worth
  /// interrupting for.
  bool needsHostChangeConsent({
    required String? fromUrl,
    required String? toUrl,
    required bool isMainFrame,
    required bool userInitiated,
  }) {
    if (!isMainFrame || toUrl == null) return false;
    final to = Uri.tryParse(toUrl);
    if (to == null || to.host.isEmpty) return false;
    if (to.scheme != 'http' && to.scheme != 'https') return false;

    final from = Uri.tryParse(fromUrl ?? _currentUrl);
    final fromHost = from?.host.toLowerCase() ?? '';
    final toHost = to.host.toLowerCase();
    if (fromHost.isEmpty || fromHost == toHost) return false;
    if (_allowedHostChanges.contains(toHost)) return false;
    // A deliberate tap during ordinary browsing is not something to nag about.
    if (userInitiated && !navigationLocked) return false;
    return true;
  }

  /// Ask, and wait. Times out into a refusal.
  Future<bool> requestHostChange({
    required String fromUrl,
    required String toUrl,
  }) async {
    final toHost = Uri.tryParse(toUrl)?.host.toLowerCase() ?? toUrl;
    final request = HostChangeRequest(
      fromHost: Uri.tryParse(fromUrl)?.host ?? fromUrl,
      toHost: toHost,
      targetUrl: toUrl,
      deadline: DateTime.now().add(hostChangeTimeout),
    );
    _pendingHostChange = request;
    notifyListeners();

    bool decided;
    try {
      decided = await request.completer.future.timeout(
        hostChangeTimeout,
        onTimeout: () => false,
      );
    } catch (_) {
      decided = false;
    }

    if (decided) _allowedHostChanges.add(toHost);
    _pendingHostChange = null;
    notifyListeners();
    return decided;
  }

  void resolveHostChange(bool allow) {
    final request = _pendingHostChange;
    if (request == null) return;
    if (!request.completer.isCompleted) request.completer.complete(allow);
  }

  /// Forget the session's allow-list (used when a capture job starts, so a
  /// decision made while browsing does not silently widen an autonomous run).
  void clearAllowedHostChanges() => _allowedHostChanges.clear();

  // --- wiring from the widget -------------------------------------------

  void attach(InAppWebViewController controller) {
    _webView = controller;
    final pending = _pendingUrl;
    _pendingUrl = null;
    if (pending != null) unawaited(load(pending));
    notifyListeners();
  }

  /// A page the app asked for before the WebView existed.
  ///
  /// The Browser tab builds its WebView lazily, so "open this chapter's page"
  /// from the Library arrives with nothing to load into. Held here rather
  /// than making every caller wait for an attach it cannot observe.
  String? _pendingUrl;

  /// Show [url] in the Browser, whether or not the tab has been opened yet.
  ///
  /// The caller is still responsible for switching to the Browser tab; this
  /// only guarantees the URL is not dropped when it gets there.
  /// The queued page, for tests that assert *where* the app tried to go
  /// without standing up a WebView.
  @visibleForTesting
  String? get debugPendingUrl => _pendingUrl;

  Future<void> requestOpen(String url) async {
    if (_webView == null) {
      _pendingUrl = url;
      return;
    }
    await load(url);
  }

  void detach() {
    _webView = null;
  }

  void onLoadStart(String? url) {
    _isLoading = true;
    _lastError = null;
    _fault = null;
    // A load that starts is the previous load's error going away, and the
    // start of the URL this navigation was *asked* for — kept so a redirect
    // to a different address is visible as one.
    _requestedUrl = url ?? _requestedUrl;
    if (url != null) _currentUrl = url;
    notifyListeners();
  }

  Future<void> onLoadStop(String? url) async {
    final hadError = _fault != null;
    _isLoading = false;
    _progress = 1;
    if (url != null) _currentUrl = url;
    String? iconUrl;
    try {
      _title = await _webView?.getTitle() ?? _title;
      await _refreshHistory();
      iconUrl = await _readPageIcon();
    } catch (_) {
      // The platform view can be mid-teardown (tab disposed, app shutting
      // down); a closed channel here must not surface as an error.
    }
    _pageIconUrl = iconUrl;

    // Only a load that finished without a fault is a destination. An error
    // page the user never wanted is not somewhere they went (§7).
    if (!hadError && _currentUrl.isNotEmpty) {
      onVisitCompleted?.call(
        BrowserVisit(
          url: _currentUrl,
          title: _title,
          source: effectiveNavigationSource,
          requestedUrl: _requestedUrl,
          iconUrl: iconUrl,
        ),
      );
    }

    notifyListeners();
    for (final c in _navigationCompleters) {
      if (!c.isCompleted) c.complete();
    }
    _navigationCompleters.clear();
  }

  void onProgress(int p) {
    _progress = p / 100;
    notifyListeners();
  }

  void onError(String message) {
    _isLoading = false;
    _lastError = message;
    notifyListeners();
    for (final c in _navigationCompleters) {
      if (!c.isCompleted) c.complete();
    }
    _navigationCompleters.clear();
  }

  /// A classified main-frame failure, ready for the design's error copy.
  ///
  /// Kept separate from [lastError], which stays the raw platform string —
  /// the user gets the classification, diagnostics keep the original (§14).
  BrowserPageFault? _fault;
  BrowserPageFault? get fault => _fault;

  /// The address this navigation was asked for, before any redirect.
  String _requestedUrl = '';
  String get requestedUrl => _requestedUrl;

  /// The icon the current page declared, if any.
  String? _pageIconUrl;
  String? get pageIconUrl => _pageIconUrl;

  /// True while the connection is one we would let a capture run on.
  bool get isSecure =>
      _currentUrl.startsWith('https://') &&
      _fault?.state != BrowserPageState.certificate;

  /// Record a classified failure for the current page.
  void onPageFault({
    String description = '',
    String type = '',
    int? statusCode,
    bool online = true,
  }) {
    final state = classifyPageError(
      description: description,
      type: type,
      statusCode: statusCode,
      online: online,
    );
    _isLoading = false;
    final detail = statusCode != null
        ? 'HTTP $statusCode'
        : [type, description].where((s) => s.isNotEmpty).join(' · ');
    _lastError = detail;
    _fault = BrowserPageFault(
      state: state,
      detail: detail,
      url: _currentUrl.isEmpty ? _requestedUrl : _currentUrl,
    );
    notifyListeners();
    for (final c in _navigationCompleters) {
      if (!c.isCompleted) c.complete();
    }
    _navigationCompleters.clear();
  }

  /// The user dismissed an error banner, or is retrying.
  void clearFault() {
    if (_fault == null && _lastError == null) return;
    _fault = null;
    _lastError = null;
    notifyListeners();
  }

  /// A link the Browser will not follow itself (`mailto:`, `reader://`).
  /// Recorded so the page-state banner can offer the handoff explicitly
  /// rather than the tap doing nothing.
  void onExternalAppLink(String url) {
    _fault = BrowserPageFault(
      state: BrowserPageState.externalApp,
      detail: url,
      url: url,
    );
    notifyListeners();
  }

  /// Read the page's declared icon. Best effort and never awaited by
  /// anything that matters — a page with no `<link rel="icon">` is normal.
  Future<String?> _readPageIcon() async {
    try {
      final raw = await _call(kCallPageIcon, timeout: const Duration(seconds: 5));
      final href = raw?.toString().trim();
      return href == null || href.isEmpty ? null : href;
    } catch (_) {
      return null;
    }
  }

  void onUrlChanged(String? url) {
    if (url != null) _currentUrl = url;
    notifyListeners();
  }

  void onSelection(Map<String, dynamic> payload) {
    _selectionController.add(SelectedElement.fromJson(payload));
  }

  Future<void> _refreshHistory() async {
    _canGoBack = await _webView?.canGoBack() ?? false;
    _canGoForward = await _webView?.canGoForward() ?? false;
  }

  // --- navigation --------------------------------------------------------

  /// Load [url].
  ///
  /// Callers that already hold an absolute address (capture, checks, a saved
  /// site, a history row) pass it straight through. Free text typed by the
  /// user goes through [interpretUrlInput] first — see [open].
  Future<void> load(String url) async {
    final target = url.trim();
    if (target.isEmpty) return;
    _lastError = null;
    _fault = null;
    _requestedUrl = target;
    await _webView?.loadUrl(urlRequest: URLRequest(url: WebUri(target)));
  }

  /// Open whatever the user typed: an address, or a search for it.
  ///
  /// Returns the intent so the caller can say what it did ("Search Google
  /// for…") without re-deriving it. An external-app scheme is classified and
  /// **not** loaded — handing a `reader://` link to the WebView produces an
  /// unhelpful platform error, so the banner offers the handoff instead.
  Future<UrlIntent> open(String text) async {
    final intent = interpretUrlInput(text);
    if (intent.isEmpty) return intent;
    if (isExternalAppScheme(intent.url)) {
      onExternalAppLink(intent.url);
      return intent;
    }
    await load(intent.url);
    return intent;
  }

  /// Navigate and wait for the load to settle (or time out). The capture
  /// engine does its own readiness checks afterwards — `onLoadStop` is only a
  /// hint, never proof that content has arrived.
  Future<void> loadAndWait(String url, {Duration? timeout}) async {
    final completer = Completer<void>();
    _navigationCompleters.add(completer);
    await load(url);
    await completer.future.timeout(
      timeout ?? const Duration(seconds: 30),
      onTimeout: () {},
    );
  }

  Future<void> goBack() async => _webView?.goBack();
  Future<void> goForward() async => _webView?.goForward();
  Future<void> reload() async {
    _fault = null;
    _lastError = null;
    await _webView?.reload();
  }

  Future<void> stopLoading() async {
    await _webView?.stopLoading();
    _isLoading = false;
    notifyListeners();
  }

  // --- find in page --------------------------------------------------------

  /// The plugin's own find controller, handed to the `InAppWebView` widget.
  ///
  /// Created here rather than in the widget so find state survives the
  /// Browser Home overlay going up and coming down.
  late final FindInteractionController findController =
      FindInteractionController(
        onFindResultReceived:
            (_, activeMatchOrdinal, numberOfMatches, isDoneCounting) {
              if (!isDoneCounting && numberOfMatches == 0) return;
              _findMatches = numberOfMatches;
              _findActiveMatch = numberOfMatches == 0
                  ? 0
                  : activeMatchOrdinal + 1;
              notifyListeners();
            },
      );

  String _findQuery = '';
  int _findMatches = 0;
  int _findActiveMatch = 0;

  String get findQuery => _findQuery;

  /// How many matches the last search found.
  int get findMatchCount => _findMatches;

  /// 1-based index of the highlighted match, or 0 when there is none.
  int get findActiveMatch => _findActiveMatch;

  Future<void> findAll(String query) async {
    _findQuery = query;
    if (query.trim().isEmpty) {
      await clearFind();
      return;
    }
    _findMatches = 0;
    _findActiveMatch = 0;
    notifyListeners();
    await findController.findAll(find: query);
  }

  Future<void> findNext({bool forward = true}) async {
    if (_findQuery.trim().isEmpty || _findMatches == 0) return;
    await findController.findNext(forward: forward);
  }

  Future<void> clearFind() async {
    _findQuery = '';
    _findMatches = 0;
    _findActiveMatch = 0;
    notifyListeners();
    try {
      await findController.clearMatches();
    } catch (_) {
      // Nothing was highlighted; clearing is idempotent by intent.
    }
  }

  // --- website data --------------------------------------------------------

  /// Clear the app-owned WebView website storage: cookies, local and session
  /// storage, and the HTTP cache.
  ///
  /// Deliberately does **not** touch anything the app owns — saved sites,
  /// history, the library, captured files, reading progress and queue rows
  /// all live in SQLite and are not reachable from here.
  ///
  /// Returns what could not be cleared, so the caller can say so honestly
  /// rather than claiming a clean sweep (§11).
  Future<List<String>> clearWebsiteData() async {
    final failures = <String>[];

    try {
      await CookieManager.instance().deleteAllCookies();
    } catch (e) {
      failures.add('cookies ($e)');
    }

    try {
      if (Platform.isIOS || Platform.isMacOS) {
        // WKWebsiteDataStore has no "delete everything" call; deleting
        // everything modified since the epoch is the supported equivalent.
        await WebStorageManager.instance().removeDataModifiedSince(
          dataTypes: WebsiteDataType.ALL,
          date: DateTime.fromMillisecondsSinceEpoch(0),
        );
      } else {
        await WebStorageManager.instance().deleteAllData();
      }
    } catch (e) {
      failures.add('site storage ($e)');
    }

    try {
      await InAppWebViewController.clearAllCache();
    } catch (e) {
      failures.add('cache ($e)');
    }

    // A session that no longer exists must not keep an in-memory allow-list
    // of hosts the user consented to under it.
    clearAllowedHostChanges();
    notifyListeners();
    return failures;
  }

  /// Cookies for one host, for the site-information sheet.
  Future<int> cookieCountFor(String url) async {
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri(url),
      );
      return cookies.length;
    } catch (_) {
      return 0;
    }
  }

  /// Clear cookies for a single site. Best effort: the platform only exposes
  /// per-cookie deletion, so this is "every cookie we can see for this URL".
  Future<void> clearDataForUrl(String url) async {
    try {
      await CookieManager.instance().deleteCookies(url: WebUri(url));
    } catch (_) {
      // Nothing stored for this host, or the platform refused; the sheet
      // reports what it could do rather than pretending.
    }
  }

  // --- JavaScript bridge --------------------------------------------------

  /// Every bridge call is bounded. `callAsyncJavaScript` awaits a promise, and
  /// a promise that never settles — a `fetch` against a dead socket, a page
  /// navigating out from under us — would otherwise hang the capture job with
  /// no way back.
  static const Duration defaultCallTimeout = Duration(seconds: 20);

  Future<Object?> _call(
    String body, {
    Map<String, dynamic> args = const {},
    Duration? timeout,
  }) async {
    final controller = _webView;
    if (controller == null) {
      throw StateError('WebView is not attached');
    }
    final result = await controller
        .callAsyncJavaScript(
          functionBody: '$kBridgePreamble\n$body',
          arguments: args,
        )
        .timeout(
          timeout ?? defaultCallTimeout,
          onTimeout: () => throw BridgeException(
            'JavaScript call timed out after '
            '${(timeout ?? defaultCallTimeout).inSeconds}s',
          ),
        );
    if (result == null) return null;
    if (result.error != null) {
      throw BridgeException(result.error!);
    }
    return result.value;
  }

  Future<PageProbe> probe({bool withLinks = false}) async {
    final raw = await _call(withLinks ? kCallProbeWithLinks : kCallProbe);
    if (raw is! Map) {
      throw BridgeException('probe returned ${raw.runtimeType}');
    }
    return PageProbe.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<Map<String, dynamic>> scrollStep(int dy) async {
    final raw = await _call(kCallScrollStep, args: {'dy': dy});
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<void> scrollTo(int y) async {
    await _call(kCallScrollTo, args: {'y': y});
  }

  /// Fallback asset read: pull the bytes through the page itself.
  /// Returns null when blocked (CORS on a cross-origin CDN is the common case).
  Future<InPageBytes?> fetchAsBase64(String url) async {
    try {
      final raw = await _call(
        kCallFetchBase64,
        args: {'url': url},
        timeout: const Duration(seconds: 45),
      );
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      if (map['ok'] != true) return null;
      return InPageBytes(
        base64Data: map['data']?.toString() ?? '',
        mimeType: map['mime']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// Enter element-picking mode. Taps are swallowed so the page cannot
  /// navigate while the user is choosing.
  Future<void> startSelection({String mode = 'link'}) async {
    await _call(kCallStartSelection, args: {'mode': mode});
    _selectionActive = true;
    notifyListeners();
  }

  Future<void> stopSelection() async {
    try {
      await _call(kCallStopSelection);
    } catch (_) {
      // The page may have navigated; the overlay is gone either way.
    }
    _selectionActive = false;
    notifyListeners();
  }

  /// Resolve a saved next-link rule against the current page.
  Future<LocatorMatch?> applyLocator(Map<String, dynamic> locator) async {
    try {
      final raw = await _call(kCallApplyLocator, args: {'locator': locator});
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      if (map['ok'] != true) {
        return LocatorMatch.failed(map['reason']?.toString() ?? 'no match');
      }
      return LocatorMatch(
        href: map['href']?.toString() ?? '',
        score: (map['score'] as num?)?.toInt() ?? 0,
        ambiguous: map['ambiguous'] == true,
        matchedSignals: map['matched']?.toString() ?? '',
      );
    } catch (e) {
      return LocatorMatch.failed(e.toString());
    }
  }

  /// Resolve a saved reader-area rule into an ordered image list.
  Future<List<PageImage>?> applyReaderRule(Map<String, dynamic> rule) async {
    try {
      final raw = await _call(kCallApplyReaderRule, args: {'rule': rule});
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      if (map['ok'] != true) return null;
      return (map['images'] as List<dynamic>? ?? const [])
          .map((e) => PageImage.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Cookie header for [url], read from the WebView's own store. Never
  /// persisted by us and never logged.
  Future<String?> cookieHeaderFor(String url) async {
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri(url),
      );
      if (cookies.isEmpty) return null;
      return cookies.map((c) => '${c.name}=${c.value}').join('; ');
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _selectionController.close();
    super.dispose();
  }

  Future<String?> userAgent() async {
    try {
      final raw = await _call('return navigator.userAgent;');
      return raw?.toString();
    } catch (_) {
      return null;
    }
  }
}

/// One completed main-frame load, as the controller saw it.
///
/// Emitted for *every* completed load, automation included — the recording
/// rule is the repository's job, and handing it the source rather than
/// pre-filtering keeps that rule in one readable place.
class BrowserVisit {
  const BrowserVisit({
    required this.url,
    required this.title,
    required this.source,
    this.requestedUrl = '',
    this.iconUrl,
  });

  final String url;
  final String title;
  final NavigationSource source;

  /// What was asked for before redirects. Differs from [url] exactly when
  /// something moved the navigation.
  final String requestedUrl;

  /// The page's declared icon, when it had one.
  final String? iconUrl;

  bool get wasRedirected =>
      requestedUrl.isNotEmpty && requestedUrl != url;
}

/// What the user tapped in selection mode.
class SelectedElement {
  const SelectedElement({
    required this.mode,
    required this.tag,
    this.text = '',
    this.href = '',
    this.rel = '',
    this.ariaLabel = '',
    this.title = '',
    this.id = '',
    this.classes = '',
    this.rawClasses = '',
    this.imgAlt = '',
    this.selector,
    this.containerSelector,
    this.outerHtml = '',
    this.imageCount = 0,
    this.minImageEdge = 0,
    this.imageSelector,
  });

  factory SelectedElement.fromJson(Map<String, dynamic> json) =>
      SelectedElement(
        mode: json['mode']?.toString() ?? 'link',
        tag: json['tag']?.toString() ?? '',
        text: json['text']?.toString() ?? '',
        href: json['href']?.toString() ?? '',
        rel: json['rel']?.toString() ?? '',
        ariaLabel: json['ariaLabel']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        id: json['id']?.toString() ?? '',
        classes: json['classes']?.toString() ?? '',
        rawClasses: json['rawClasses']?.toString() ?? '',
        imgAlt: json['imgAlt']?.toString() ?? '',
        selector: json['selector']?.toString(),
        containerSelector: json['containerSelector']?.toString(),
        outerHtml: json['outerHtml']?.toString() ?? '',
        imageCount: (json['imageCount'] as num?)?.toInt() ?? 0,
        minImageEdge: (json['minImageEdge'] as num?)?.toInt() ?? 0,
        imageSelector: json['imageSelector']?.toString(),
      );

  final String mode;
  final String tag;
  final String text;
  final String href;
  final String rel;
  final String ariaLabel;
  final String title;
  final String id;
  final String classes;
  final String rawClasses;
  final String imgAlt;
  final String? selector;
  final String? containerSelector;
  final String outerHtml;
  final int imageCount;
  final int minImageEdge;
  final String? imageSelector;
}

class LocatorMatch {
  const LocatorMatch({
    required this.href,
    required this.score,
    this.ambiguous = false,
    this.matchedSignals = '',
  }) : failureReason = null;

  const LocatorMatch.failed(this.failureReason)
    : href = '',
      score = 0,
      ambiguous = false,
      matchedSignals = '';

  final String href;
  final int score;
  final bool ambiguous;
  final String matchedSignals;
  final String? failureReason;

  bool get isMatch => failureReason == null && href.isNotEmpty;
}

/// A cross-host navigation the page started, waiting on the user.
class HostChangeRequest {
  HostChangeRequest({
    required this.fromHost,
    required this.toHost,
    required this.targetUrl,
    required this.deadline,
  });

  final String fromHost;
  final String toHost;
  final String targetUrl;

  /// When silence becomes a refusal.
  final DateTime deadline;
  final Completer<bool> completer = Completer<bool>();

  Duration get remaining {
    final left = deadline.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }
}

class BridgeException implements Exception {
  BridgeException(this.message);
  final String message;
  @override
  String toString() => 'BridgeException: $message';
}

class InPageBytes {
  const InPageBytes({required this.base64Data, required this.mimeType});
  final String base64Data;
  final String mimeType;
}
