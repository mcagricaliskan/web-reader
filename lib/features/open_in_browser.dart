import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/url_utils.dart';
import '../providers.dart';
import '../storage/database.dart';
import '../ui/palette.dart';
import '../ui/status_style.dart';
import 'chapter_actions.dart' show connectivityProvider, hasUsableSourceUrl;

/// The copy the product uses when a row has nowhere to go.
const kNoSourcePageMessage = 'This episode does not have a source page.';

/// The one way anything in this app opens a page in the Browser.
///
/// Every "Open on website" / "Open in Browser" action funnels through here,
/// because doing it correctly is six steps and every call site that
/// implemented "some of them" produced the same bug: the Browser was sent the
/// URL and the user never saw it.
///
/// The six steps, and why each one is load-bearing:
///
/// 1. **Validate.** A row with no usable `source_url` must not move the user
///    anywhere — least of all to a blank Browser (D42).
/// 2. **Confirm with a running capture.** A WebView-dependent phase owns the
///    page; taking it silently would break the run.
/// 3. **Store the request**, rather than loading now — see [BrowserNavigator].
/// 4. **Pop back to the shell.** This is the step every call site was
///    missing. Series Detail and the details sheet are routes pushed *above*
///    the shell; flipping the shell's tab index under them changes nothing
///    the user can see.
/// 5. **Select the Browser tab.**
/// 6. **Let the Browser drain the request** once it is mounted with a live
///    WebView, dismissing Browser Home or the URL editor on the way.
///
/// Returns true when the Browser was actually sent somewhere.
Future<bool> openInBrowser(
  BuildContext context,
  WidgetRef ref,
  String rawUrl, {

  /// Shown when [rawUrl] is unusable. The default is the episode wording;
  /// callers with a different noun pass their own.
  String missingUrlMessage = kNoSourcePageMessage,

  /// Skip the reachability probe. Used by callers that already know the page
  /// is local or that want the Browser's own error state instead.
  bool checkConnectivity = true,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final url = rawUrl.trim();

  // 1. A URL we cannot use is not a reason to move the user.
  if (!_isUsableUrl(url)) {
    messenger?.showSnackBar(SnackBar(content: Text(missingUrlMessage)));
    return false;
  }

  // 2. Does anything own the Browser in a way this would break?
  if (!await _confirmTakeOver(context, ref)) return false;
  if (!context.mounted) return false;

  // 3. Offline is worth saying here: the WebView's own error page is a poor
  //    way to learn the device has no connection.
  if (checkConnectivity) {
    final online = await ref.read(connectivityProvider).canReach(hostOf(url));
    if (!online) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'No network connection — the original page needs to be online.',
          ),
        ),
      );
      return false;
    }
    if (!context.mounted) return false;
  }

  // 4. Store first, so nothing is lost across the pop and the tab switch.
  ref.read(browserNavigatorProvider).request(url);

  // 5. Back to the shell. `popUntil`-style rather than `go('/')`: popping
  //    leaves the shell route — and therefore the WebView, its cookies and
  //    any running capture — exactly as it was, where `go` would rebuild it.
  //    Nothing is pushed, so there is no duplicate Browser, Library or
  //    Series Detail route.
  final router = GoRouter.of(context);
  while (router.canPop()) {
    router.pop();
  }

  // 6. Select the Browser tab. The shell owns the index; the Browser screen
  //    drains the pending request when it is mounted and attached.
  ref.read(shellTabRequestProvider).value = 1;
  return true;
}

/// [openInBrowser] for a chapter row, with the source-URL rule applied.
Future<bool> openChapterInBrowser(
  BuildContext context,
  WidgetRef ref,
  Chapter chapter,
) => openInBrowser(
  context,
  ref,
  hasUsableSourceUrl(chapter) ? chapter.sourceUrl : '',
);

bool _isUsableUrl(String url) {
  if (url.isEmpty) return false;
  final uri = Uri.tryParse(url);
  return uri != null && uri.hasScheme && uri.host.isNotEmpty;
}

/// Ask before taking the page out from under a running capture.
///
/// Returns true when it is safe to proceed — either nothing needed the
/// Browser, or the user chose to pause. Mirrors D36: a hold, never a stop,
/// and never a silent replacement.
///
/// Download-only phases deliberately do **not** ask. Once panels are
/// extracted the run reads bytes over HTTP and touches no layout, so
/// navigating the page away costs it nothing — and a confirmation there would
/// be the modal crying wolf.
Future<bool> _confirmTakeOver(BuildContext context, WidgetRef ref) async {
  final job = ref.read(captureJobProvider);
  final checker = ref.read(updateCheckerProvider);
  final atRisk = job.needsRenderedBrowser || checker.isRunning;
  if (!atRisk) return true;

  final proceed = await showTakeOverBrowserDialog(
    context: context,
    progressLine: job.isRunning
        ? job.progressSummary
        : 'Checking for new chapters',
  );
  if (!proceed) return false;

  // Hold the run where it is before the page moves. The engine's own
  // page-validation handles the rest: coming back to a different chapter
  // keeps it paused and says so, rather than resuming onto the wrong page.
  if (job.isRunning) job.pauseForBrowserHidden();
  return true;
}

/// "Something is using the Browser — open this page anyway?"
///
/// Deliberately worded as taking the page rather than leaving the Browser:
/// the user is not walking away, they are asking for a different page in the
/// same window, and "Leave the Browser?" would describe the wrong thing.
Future<bool> showTakeOverBrowserDialog({
  required BuildContext context,
  required String progressLine,
}) async {
  final palette = AppPalette.of(context);
  final proceed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(Icons.public, size: 26, color: palette.primary),
      title: const Text('A capture is using the Browser'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Opening this page moves the Browser off the chapter being '
            'captured. The capture pauses — nothing captured so far is lost, '
            'and you can resume it from Activity.',
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: palette.inkMuted,
            ),
          ),
          if (progressLine.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              decoration: BoxDecoration(
                color: palette.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Text(
                progressLine,
                style: monoStyle(size: 11.5, color: palette.inkStrong),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('takeOverBrowserPause'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Pause and open episode'),
        ),
        FilledButton(
          key: const ValueKey('takeOverBrowserStay'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Stay with capture'),
        ),
      ],
    ),
  );
  return proceed ?? false;
}
