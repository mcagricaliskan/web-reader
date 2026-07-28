# Web Reader — Implementation Status

> As-built record for milestones M0–M6 and M8. Written 2026-07-25; revised
> 2026-07-26 (user-assisted fallback, live-site results) and 2026-07-27
> (series-grouped library, M3 recovery coverage, reading progress, Continue
> Reading, duplicate and re-capture UX; later the same day: M5 lifecycle
> hardening, M8 update checking, in-session duplicate decisions, the
> image-dimension investigation and fix; and the Stage 1b pre-design batch —
> P0.2, P0.3, M12, and the M13/M14 backends, schema v6; and later still the
> Claude Design UI implementation — new theme, library/series/reader/browser
> redesign, activity + settings screens).
> This document reports what was **run and observed**, not what was intended.
> Design intent lives in [TECHNICAL_SPEC.md](./TECHNICAL_SPEC.md); the plan and
> its acceptance criteria live in [MVP_PLAN.md](./MVP_PLAN.md).

---

## 1. Toolchain

| | |
|---|---|
| Flutter | 3.44.0 stable (Dart 3.12.0) |
| Xcode | 26.6 |
| Simulator | iPhone 17, iOS 26.5 |
| Bundle id | `com.mcagricaliskan.webreader` (iOS and Android aligned) |
| Display name | `Web Reader` |

## 2. Resolved dependency versions

From the committed `pubspec.lock`. Per [DECISIONS.md](./DECISIONS.md) D21 these
were resolved at implementation time, not copied from a doc.

| Package | Locked | Role |
|---|---|---|
| `flutter_inappwebview` | 6.1.5 | WebView + JS bridge |
| `drift` / `drift_flutter` | 2.34.2 / 0.3.1 | Local database |
| `sqlite3` (transitive) | 3.5.0 | SQLite via Dart build hooks |
| `dio` | 5.11.0 | Asset download |
| `flutter_riverpod` | 3.3.2 | State / reactive queries |
| `go_router` | 17.3.0 | Routing |
| `path_provider` / `path` | 2.1.6 / 1.9.1 | App directories |
| `uuid` | 4.6.0 | Client-generated IDs |
| `crypto` | 3.0.7 | (available; not yet used — content hashing is M4+) |
| `collection` | 1.19.1 | Grouping helpers |
| `wakelock_plus` | 1.7.0 | Keep the screen awake during capture |
| `drift_dev` / `build_runner` | 2.34.0 / 2.15.1 | Codegen (dev) |

**`sqlite3_flutter_libs` is deliberately absent** — it is published `0.6.0+eol`
and empty. `sqlite3` 3.x bundles SQLite through Dart build hooks; the iOS
Simulator build works with no extra setup. This was verified, not assumed.

### Dependency-driven limitations

1. **`flutter_inappwebview_ios` does not support Swift Package Manager.** Every
   `flutter` command prints a warning and the build falls back to CocoaPods
   (`pod install` is required). Flutter states this will become an error in a
   future release. Not blocking today; it is the most likely reason we would
   have to move off this plugin.
2. **No resource interception on iOS.** `shouldInterceptRequest` is Android/
   Windows only, so asset bytes are re-fetched by Dio rather than reused from
   the WebView. See §8.
3. **Riverpod 3 renamed `AsyncValue.valueOrNull` to `.value`**, and Flutter 3.44
   deprecated `ListView.cacheExtent` in favour of a `ScrollCacheExtent` type
   that is not exported from `material.dart`. The reader uses the default cache
   extent instead; `ListView.builder` still only builds visible panels.
4. **`flutter_inappwebview` is pinned to `6.2.0-beta.3`** (2026-07-27,
   user-approved). Why: stable 6.1.5's Android package fails to build under
   the app's AGP 9.0.1 (legacy `proguard-android.txt` reference is now a hard
   error); the fix exists only in the 6.2 betas. Evidence for the pin:
   `flutter build apk --debug` succeeds on the beta under AGP 9, and the full
   iOS battery passed on it — 334/334 unit, `offline_read` 3/3,
   `capture_flow` 5/5, `reading_flow` 1/1, `update_check` 1/1,
   `user_assist` 5/5, Simulator build clean. Caveats: (a) switching versions
   leaves stale Xcode module state — a `'InAppWebViewFlutterPlugin' has
   different definitions in different modules` build error means run
   `flutter clean` + delete `ios/Pods`; (b) the beta ships `Package.swift`,
   so the SPM warning is gone — SPM stays **disabled** (D25) until verified
   on a physical device; (c) physical-device build on the beta not yet run —
   rides along with the P0.1 device pass. Move to `^6.2.0` when stable; the
   tested fallback if the beta ever misbehaves is stable 6.1.5 + AGP 8.13.

---

## 2a. Implemented vs. proven (2026-07-27)

Everything below §3 is *implemented with automated evidence*. What that evidence does **not**
cover — the honest gap between "implemented" and "proven in its real environment":

| Claim | Automated evidence | Still unproven |
|---|---|---|
| Reading progress survives iOS lifecycle | Restart, backgrounding flush, kill-mid-fling — Simulator | **Physical-device pass** (app-switcher kill, background-then-kill, immediate force-quit) — checklist §10, not run |
| Multi-chapter capture works on real sites | 5-chapter chains on the fixture; one **single** live chapter captured (uzaymanga 885) | A live **multi-chapter** run |
| Update checking works on real sites | Fixture acceptance end-to-end; discovery reuses the live-verified navigation chain | Any live update check |
| Capture timing constants | Tuned on Simulator (host network/disk) | Re-measurement on a device |
| Read vs. captured are distinct states | **Fixed (P0.2, 2026-07-27):** capture uses the download/offline glyph set, read state has its own indicator (check / % / unread dot), series cards count unread — 5 widget tests incl. a bare-insert default assertion | — |

Everything else in this document is both implemented and exercised by the tests named next to it.

---

## 3. What is implemented

### M0 — Project and browser ✅

- Flutter project created in place; `docs/` preserved.
- Embedded, visible `InAppWebView`: URL entry, Go, Back, Forward, Reload/Stop,
  progress bar, current URL, page title, and a visible error strip for load and
  HTTP errors.
- Non-incognito, persistent data store; one WebView reused for the whole
  session and kept alive across tab switches by an `IndexedStack`.
- `isInspectable` enabled in debug builds → Safari Web Inspector attaches.
- **All plugin use is behind `lib/browser/browser_controller.dart`.** No other
  file imports `flutter_inappwebview` (`storage/` is likewise the only importer
  of `drift`).
- JS bridge reports: `document.title`, URL, canonical URL, `readyState`,
  document height, viewport height, scroll position, `atBottom`, and per-image
  `src` / `currentSrc` / lazy attribute / `complete` / natural size / rendered
  size / declared size / document order / visibility / in-chrome flag; plus
  links with `rel`, text, `aria-label`, `title`, class, id and nav membership.

### M1 — Single-page autonomous capture ✅

- `Capture` action → sheet (current chapter / next 3 / next 5). One job at a
  time.
- 15-state model in `lib/capture/capture_state.dart` with an explicit
  transition table, surfaced live in the capture panel.
- Gradual scrolling with configurable step/delay, re-inspection after each
  step, document-height and image-count change detection, lazy-load triggering,
  bottom detection, a quiet period, and required consecutive stable checks.
  Bounded by iterations, per-capture duration, and per-call timeouts.
- Image candidate heuristic: intrinsic/declared/rendered sizing, size floor,
  banner aspect rejection, hidden and page-chrome exclusion, URL de-duplication,
  and a dominant-width cluster. DOM order preserved. Every rejection is counted
  by reason in the log.
- Download via Dio with Referer, WebView User-Agent and WebView cookies;
  bounded retries; in-page `fetch` → base64 fallback; magic-number verification
  (not Content-Type, which servers lie about).
- Staging → manifest → atomic rename → database transaction. Relative paths
  only.
- Per-asset status (`pending`/`downloading`/`stored`/`failed`) with the error
  retained. A failed asset never claims a local file.

### M2 — Library and offline reader ✅

- Library screen grouped by library item: title, source host, capture time,
  status, stored/detected counts, size.
- Vertical reader over local files only, `ListView.builder`, `cacheWidth` set to
  display width so panels decode small.
- Partial captures show a banner; missing files show "not available offline"
  and the database row survives; no remote-URL fallback exists anywhere in the
  reader.

### M3 — Bounded multi-chapter capture ✅

- Next-page chain, ordered by trust: **saved rule** → `link[rel=next]` →
  `a[rel=next]` → nav container → labelled control → chapter progression.
  Fabricating a URL by incrementing a number is deliberately **not** a
  strategy; chapter progression can only corroborate a link the page actually
  contains.
- Validation: resolve relative, scheme allow-list, reject current, reject
  visited (loop guard), fragment normalisation, same-host preference, auth-path
  deny-list, chapter limit, job duration bound.
- Controls: Pause, Resume, Retry current, Skip current, Stop. Stop is honoured
  between chapters as well as inside one.
- Job state persisted on every transition; a "Resume / Discard" card appears in
  the library after an interrupted run. Resume is never automatic.
- Startup recovery: staging swept, in-flight chapters demoted (never promoted),
  committed-but-unrecorded chapters reconciled from their manifest.

### User-assisted fallback ✅

Automatic detection first; a prompt only when it would otherwise be guessing.

**Confidence model** (`lib/capture/next_page.dart`). Every candidate carries a
base confidence from its strategy. The job proceeds when the best candidate is
high-confidence, or medium-confidence and uncontested. It asks when only a weak
signal exists, or when two candidates of comparable standing point at different
pages. A saved rule is **authoritative** — page heuristics do not re-open a
question the user already answered, or saving a rule would not actually stop the
prompts. Corroboration (two strategies agreeing on one URL) raises confidence but
does **not** silence a rival pointing elsewhere.

**Selection mode** (`bridge_script.dart` → `startSelection`). Taps are swallowed
in capture phase so the page cannot navigate while the user is choosing; the
element under the pointer is outlined; the tapped element's tag, text, URL,
`rel`, classes, generated selector, container and nearby DOM are reported to
Dart and shown in the overlay before anything is saved.

**Rules** (`site_rule.dart`, `rule_repository.dart`, table `site_rule_rows`).
A rule stores a *bag of independent signals* — `rel`, a conservative selector,
the nav container, link text, `aria-label`, `title`, image `alt`, and the
destination's path pattern — not one fragile selector. Long `nth-child` chains
and generated-looking ids and classes (hashed, `css-`, tailwind-arbitrary) are
excluded on purpose. At apply time each signal is scored and the best-scoring
link wins, needing a minimum score. `signalCount` is surfaced, and a
single-signal rule is labelled **weak** in the UI and the log rather than
presented as stable.

**Scope** — narrowest first: `series` (host + series fingerprint, the default),
`pathPattern` (same URL shape on the host), `host`. `bestMatchingRule` prefers
the narrowest. A rule learned on one series is never applied to another unless
the user explicitly widened the scope. Creating a rule for a scope that already
has one *replaces* it.

**Failure** — when a saved rule stops matching, the job pauses, says so, lets
the user re-select, deletes the stale rule and resumes from the incomplete
chapter. It never silently falls back to guessing another link.

**Safe navigation, even with a user-selected rule.** During a job the WebView is
navigation-locked: `shouldOverrideUrlLoading` vetoes any top-level navigation
the job did not announce, `onCreateWindow` returns false (no popups), and
`javaScriptCanOpenWindowsAutomatically` is off. Each chapter is announced with
`allowNextNavigation`; where the browser actually **landed** is re-validated
after redirects, and a redirect that leaves the *series fingerprint* stops the
job rather than capturing something else.

**UI** — `Select next chapter button`, `Select reader area`, `Retry automatic
detection`, `Cancel job`, scope picker, plus a saved-rules screen
(Library → ☰) with `Forget this rule`. Functional, not polished.

**Reader-area fallback** — the same mechanism when image extraction finds too
little: the user points at the container, and the rule stores container
selector, image selector, exclusions and a size floor derived from what is
actually inside.

### M4 — Series-grouped library ✅ *(2026-07-27)*

The problem this fixed: captured chapters appeared as flat entries, and the old
grouping rule (host + first path segment) would have collapsed *every* series on
a site onto one shelf.

**Series identity** (`lib/library/series_identity.dart`, pure Dart) resolves in
order of strength:

1. a same-host link back to the series index — gives the key *and* the series
   name as the site writes it;
2. the series-path fingerprint of the chapter URL
   (`/manga/efsanevi-buyu-imparatoru`, `/comics/genius-archers-streaming-f886a8af`);
3. `og:title` / `h1` / page title, when the URL carries no usable path;
4. host — **low confidence, which never merges**. An extra group is
   recoverable; a wrong merge mixes two series on one shelf and is not.

No domain or slug is hardcoded. Chapter markers are stripped so a group is named
after the series, not one of its chapters ("Efsanevi Büyü İmparatoru 883. Bölüm
- Türkçe Manga Oku |" → "Efsanevi Büyü İmparatoru").

**Editable name.** `library_items.user_title` holds it; `title` keeps the
detected one underneath. Display order: user → detected → host. Renaming touches
nothing else — identity, source URLs, storage paths and future matching all key
off `(host, series_key)`, so a later capture rejoins the renamed group.

**Storage paths are unaffected by names.** Chapters are addressed by
`content_path`, keyed on stable ids, so grouping and renaming never move a file.

**Chapter ordering**: parsed number → capture sequence → capture time.
Non-integer identifiers ("Extra", "Prologue") sort after numbered ones instead of
being coerced to 0.

**UI**: grouped library list (name, host, chapter count, latest chapter, last
capture time, partial/failed flag) → series detail (chapters in reading order,
status, stored counts, capture time, offline availability, rename) → the
existing offline reader, unchanged.

### M5 — Persistent reading progress ✅ *(2026-07-27)*

**Position model** (`lib/reading/reading_position.dart`, pure Dart, no Flutter
import). A `ReadingPosition` carries both a **hybrid anchor** (`imageIndex` +
`offsetInImage` within that panel) and a normalised `fraction`. The anchor is
what survives a re-download or a re-render at a different width; the fraction is
the fallback when the panel count changes and the display value shown to the
user.

`ChapterLayout` computes panel offsets from the **stored manifest dimensions**,
so the reader can be constructed with
`ScrollController(initialScrollOffset: layout.offsetForPosition(saved))`. The
chapter therefore **opens at** the saved position — there is no visible jump from
the top, which a post-layout `jumpTo` would produce.

`CompletionPolicy`: 0.97 of the chapter, **held for 800 ms**. The dwell is what
separates finishing a chapter from flinging past the end.

**Write path.** `lib/reading/reading_repository.dart` is the only writer of
reading state: `markOpened`, `saveProgress`, `markRead`, `markUnread`, and the
series-pointer refresh that follows each of them. Scroll writes are debounced
2 s; `didChangeAppLifecycleState`, chapter change, the right-swipe out, and
`dispose` flush immediately.

**Completed means 100%, revised 2026-07-27 (D39).** `progress_fraction` is
pinned to 1 whenever `read_status` is `completed` — on write and again on
display through `readProgressFor()`, so rows written before the rule read
correctly too. The anchor keeps following the scroll, so re-reading a finished
chapter still resumes where the reader is; only the *fraction* is fixed.
*Mark as unread* resets the fraction to 0 (it had been forced to 1) while
keeping the anchor, and cancels any pending throttled write so a save queued a
moment earlier cannot undo the choice. `repairCompletedProgress()` runs at boot
and is idempotent.

**Leaving by gesture.** A right-swipe in the reader flushes the position and
goes to the series' episode list. The recogniser is horizontal-only and
competes with the list's vertical drag in the same arena, plus a distance /
velocity / 2:1-ratio gate, so ordinary reading never triggers it. If the
episode list is the route underneath, it pops; otherwise it replaces the
reader — either way exactly one episode-list route is left on the stack, so
in-and-out never piles up.

**Schema v4** (additive; no column is dropped or retyped, so an existing
database migrates in place):

| Table | Added |
|---|---|
| `chapters` | `read_status`, `progress_fraction`, `progress_image_index`, `progress_offset_in_image`, `first_opened_at`, `last_read_at`, `completed_at`, `progress_updated_at` |
| `library_items` | `last_opened_chapter_id`, `last_completed_chapter_id`, `last_read_at` |

**Capture and reading cannot corrupt each other, structurally.**
`writeChapterReading` is the *only* DAO method that writes a reading column, and
it writes nothing else; every capture-side write copies the reading fields
verbatim. A capture running while a chapter is open changes no read state, and
reading changes no capture state. Asserted in `reading_repository_test.dart` and
again in the integration test.

### M5a — Duplicate and re-capture UX ✅ *(2026-07-27)*

`lib/capture/capture_preflight.dart` classifies the target **before any network
use**:

| State | Meaning |
|---|---|
| `none` | not held |
| `complete` | held, all assets present |
| `partial` | held, some assets failed |
| `failed` | a capture attempt exists but stored nothing |
| `filesMissing` | the row says complete, the files are gone |
| `inActiveJob` | another capture job owns it right now |

`DuplicatePolicy { skipComplete, retryPartial, replaceAll, ask }` drives it.
A range run consults preflight per chapter, so it skips what it already holds
and says so in the log rather than silently re-downloading.

The sheet (`lib/features/capture_preflight_sheet.dart`) offers only the actions
the state allows: *Open saved chapter*, *Capture following chapters*,
*Re-download this chapter*, *Retry missing files*, *Restart chapter capture*,
*Repair capture*, *Remove broken local record*, *Resume existing capture*,
*Discard it and start over*.

**Replacement is atomic.** `FileStore.commitReplacing()` steps the existing
directory aside to `.previous`, moves staging in, then deletes the backup; any
failure restores it, and `restoreInterruptedReplacements()` finishes the job on
next launch after a crash. A re-download cannot leave a chapter unreadable, and
it does not touch the reading columns — verified in criterion 10 below.

### M6 — Continue Reading and Recently Read ✅ *(2026-07-27)*

The library screen now leads with two sections above **All Series**:

- **Continue Reading** — series with an unfinished or never-opened chapter,
  most recently read first. The card names the exact chapter and its progress;
  one tap opens the reader at the saved position.
- **Recently Read** — series read recently, *including* fully finished ones, so
  a completed series does not vanish from the home screen.

Both derive from the same `computeSeriesReadingState` the reader writes through,
over the existing drift `.watch()` stream. There is no second source of truth
and no manual refresh.

**Not built: New Chapters.** It has nothing to report until a source is
re-polled, which is M8. Building the section now would mean building a section
that is always empty. *(Superseded the same day — M8 below built both.)*

### M5 hardening — lifecycle write-path ✅ *(2026-07-27, second pass)*

The design does **not** rely on a final callback (iOS provides none on a hard
force-quit): scroll writes are debounced at 2 s, which bounds the loss window;
lifecycle callbacks (`inactive`/`paused`/`hidden`/`detached`), chapter change
and dispose flush immediately when they do arrive; completion is dwell-gated
in the scroll handler, so no termination-time write can invent it.

Two real defects were found and fixed by the new tests:

1. **The dispose-time flush had never worked.** Riverpod 3 forbids `ref` in
   `dispose()`; the reader's last flush read the repository through `ref`
   there and threw — every ordinary reader close (back navigation) silently
   lost the final position and depended on the debounce having fired. The
   repository is now cached in a field at `initState`.
2. **Progress writes were unserialized read-modify-writes** fired from four
   places. A stale in-flight save could read "not completed", lose the race,
   and overwrite a completion that had already landed. All reading writes now
   run through one queue in `ReadingRepository`: outcome = call order, and a
   pending write can never clobber a newer one. (The queue starts idle writes
   synchronously — an unconditional `.then` hop deadlocks widget tests'
   fake-async zone, which is itself now covered by tests.)

Automated coverage: `reader_lifecycle_test.dart` (restore-at-open, flush on
backgrounding inside the debounce window, no false completion when killed
mid-fling, dwell completion, repair-on-open) and the serialization group in
`reading_repository_test.dart`.

**Physical-device pass: PENDING.** App-switcher kills and backgrounding need
hands on the device; see §10 for the exact checklist. Uninstalling the app
removes all local data by design — that is iOS container semantics, not a
persistence failure.

### Queue-first capture · batch re-download · dev reset ✅ *(2026-07-28)*

**Queue-first (D46).** `_enqueue` no longer pumps capture work.
`taskWaitsForExplicitStart` decides who waits: captures do, update checks and
cleanup do not. `startQueuedCaptures()` sets an **in-memory** authorisation
and pumps; a drained queue revokes it. Restart leaves rows `queued` and
unauthorised, which is Q24 stated as a product rule instead of an accident.

**Browser routing (D47).** `TaskQueueController.ensureBrowserVisible` is
injected by `_ShellState`: switch to the Browser tab, wait for attach, return
whether it worked. A false return leaves the task queued. The existing
`needsRenderedBrowser` split (extraction vs downloading) is unchanged and now
drives both the leave-Browser modal and the Activity row.

**Entry points.** Browser capture, Series Detail, New Chapters, the episode
details sheet, re-fetch, capture-again and the reader's retry all go through
`showQueuedConfirmation` — a snackbar with **View Activity**, no redirect.

**Batch re-download (D48).** Selection mode selects any unlocked chapter;
quick-selects gained `Not downloaded` and `Finished · files removed`. The
selection bar offers *Remove files* or *Add to queue* depending on what is
selected, and a confirmation sheet shows series, count, range, estimate and
the chapters that have no source page. `enqueueChapters` orders ascending.

**Entry-point audit.** Every `enqueueCapture` call site now pairs with a
`showQueuedConfirmation` — including the three inside the Browser's preflight
sheet, which previously opened the capture panel as if a run had begun.

**Development reset (D49, D50).** `lib/core/local_reset.dart` +
`/developer`, both `kDebugMode`-gated. Stops work, empties every table with
foreign keys suspended, deletes the asset tree, clears cookies, and returns a
per-area `ResetReport`.

### Episode list: real progress, ordering, details, labels ✅ *(2026-07-27)*

**Progress (D43).** `ChapterProgressRing` in `lib/ui/status_style.dart` — a
`CustomPainter` drawing a track circle plus a wedge from twelve o'clock, a
solid disc at 100%. It replaces the three-icon `ReadGlyph` switch entirely, so
there is one indicator and one source of truth (`readProgressFor`, D39).
`shouldRepaint` compares the value; semantics announce the percentage.

**Ordering (D43).** `ChapterSort` + `sortChapters()`; default `newestFirst`,
persisted at `settings['series.chapterSort']` and exposed as a two-state pill
beside the SAVED CHAPTERS label. Descending is `sortChaptersForReading()`
reversed, so the decimal-safe comparison and the non-numeric fallback are
shared by both directions. Selection helpers still work in reading order.

**Labels (D43).** `chapterDisplayLabel()` prints `Chapter 487` / `Chapter 487.5`
from the parsed number; `chapterLabelFrom()` still records the raw source
marker on the row. `parseChapterNumber` now takes an `extra` list — the capture
engine feeds it the page `<h1>`, `og:title` and the last breadcrumb — and its
URL rules are separate from its prose rules, so `/chapter-385-5` reads as
385.5 and `/chapter/137` as 137 while "Chapter 487 - 5 pages" does not become
487.5.

**Details (D44).** `lib/features/chapter_details_sheet.dart`, on long press.
Reads only from the chapter row; re-fetch delegates to the queued
`DuplicatePolicy.replaceAll` capture. No permanent-delete action.

**First chapter (D45).** Removed from Series Detail.

### Chapter source URL + Library storage indicator ✅ *(2026-07-27)*

**Source URL (D42).** No schema change: `chapters.source_url` already existed,
is `NOT NULL`, and is written by both the capture engine and remote discovery.
It already survived removal, archive, restore, re-download and reading updates
because every writer names its columns — `CleanupService._writeRemoved` touches
`content_path`, `byte_size` and `offline_removed_at` only. The gap was rows
written blank by an older build, closed by
`SeriesRepository.repairChapterSourceUrls()` at boot (restores from `url_key`,
idempotent, never invents one) plus the narrow writer `writeChapterSource`.

`lib/features/chapter_actions.dart` owns the behaviour: tapping a chapter with
no offline files opens a sheet (**Open on website · Capture again · Cancel**)
instead of the reader; opening uses the stored URL and only that, checks the
network through an injectable `Connectivity` seam (a `dart:io` DNS probe, no
new dependency), and refuses while automation owns the browser.
`BrowserController.requestOpen` holds the URL until the WebView attaches, since
the Browser tab builds lazily. Offline chapters still open the reader on tap;
their source page is on the long-press sheet.

**Header alignment, corrected 2026-07-27.** The row had three different
geometries in it: 48pt `IconButton`s with 22pt glyphs, a 40pt pill with a 15pt
glyph, and a bottom-aligned 28pt serif title. Measured, that put the pill's
centre 4pt below every icon's, and at 320pt "Library" wrapped to **three
lines** (title box 96×99) and dragged the header down with it. Now one shared
definition — `HeaderIconButton` / `kHeaderActionSize` (40) / `kHeaderIconSize`
(22) / `kHeaderIconColor` — with `CrossAxisAlignment.center` and a
single-line title. All four actions share centre y at both 320 and 430pt;
locked by `library_ui_test.dart`'s header-alignment group.

**Storage levels, revised 2026-07-28 (D51).** Warning colour is now derived
from the **percentage of the device used** (75% amber, 90% red, plus a
sub-1 GB escalation) rather than from free bytes, via `DeviceCapacity.level` +
`storageLook()` — one rule and one palette shared by the pill and the Storage
screen. The Storage screen leads with a `_DeviceMeter` card: percentage, bar,
and a line that says what the colour means and what to do about it. Its metric
tiles are no longer coloured (`_Metric.warn` removed), so only one element per
screen carries the state.

**Storage indicator (D41).** The header now shows a disk glyph and the device
usage percentage, from a new `capacity` platform call (iOS
`volumeTotalCapacity` + `volumeAvailableCapacityForImportantUsage`, Android
`StatFs`) behind `deviceCapacityProvider`. Fixed 52 pt box, number scaled down
rather than clipped, one merged semantics node (`Device storage 72% used`),
tap → Settings → Storage.

*Root cause of the slow indicator:* the old pill watched a provider that
bundled the free-space call with `stagingByteSize()`, a recursive walk of the
staging tree — so drawing the Library header waited on a directory listing only
the Storage screen needs. Split into `deviceCapacityProvider` (one throttled
call) and `stagingBytesProvider` (the walk, Storage screen only). Refreshes are
throttled to 2 minutes and forced at the two moments the disk changes:
automation falling idle, and `CleanupService.removals` firing.

### M8 — Update checking and New Chapters ✅ *(2026-07-27)*

`lib/library/update_checker.dart`: foreground, user-triggered, metadata only.
A discovered chapter is a `chapters` row with `captureStatus = 'knownRemote'`,
no `contentPath`, plus `discoveredAt` / `discoveryBasis` /
`discoveryConfidence` (schema v5). Capturing it later fills the **same row** —
discovered → captured → read are three independent facts about one chapter.

**Discovery order.** The series page's chapter list first
(`discoverFromChapterList`, pure: same-host + same-series + links beyond the
checkpoint; a page that shows neither known chapters nor several numbered
links is *unrecognised* and falls through — a 404 must never produce "up to
date"). Then a bounded next-chain walk from the
latest known chapter, through the exact trust chain captures use: saved rule →
`resolveNextPage` → **ask the user** via the same selection overlay, saving
the same reusable rule at the same scopes.

**Ordering, revised 2026-07-27 (D40).** Every chapter link gets a *position*
on the number line — its own parsed number, or one interpolated from its
numbered neighbours in list order — and one comparison then decides both
novelty and emission order. New chapters come out oldest-first whichever way
the page runs, so a run cut by `maxNewChapters` leaves a contiguous block;
comparison is on parsed numbers, so `385 < 385.5 < 386`; unnumbered chapters
are interpolated rather than discarded; and an empty result ends the check only
when the ordering was unambiguous — otherwise the chain walk still runs. The
checkpoint is the highest number held plus the known URL keys, which makes "my
library starts at chapter 100 of 400" an ordinary check.

Direction detection is tolerant (≥ 80 % of ordered pairs, ≥ 3 numbered links)
because the live probe showed both verified sites put *First Chapter* /
*Latest Chapter* jump links above their list; a strict rule made every real
page `unknown` and every up-to-date check pay for a chain walk.

Live-verified read-only on 2026-07-27 (`live_site_probe_test.dart`, new
chapter-list group — no downloads, no rows written): uzaymanga 500 links →
483 chapters, `newestFirst`, confident; asurascans 141 links → 103 chapters,
`newestFirst`, confident. Both emitted oldest-first, and resuming from a
mid-list checkpoint re-reported nothing at or below it.

**Bounds.** 12 pages, 20 new chapters, 3 minutes, per-page navigation timeout,
cooldown between pages. Stops at end-of-chain, when the next link leaves the
series or host, on deny-listed paths (login/signup/account), on cancel, and at
every bound — with the bound named in the log.

**State.** `library_items.last_check_at / last_check_success_at /
last_check_error / last_check_result` — failures persisted so the UI can say
"last check failed: …" after a restart. Counts derive from the chapters table.

**UI.** Series detail: *Check for new chapters* / *Check again* / *Cancel
check*; a "New on source — not downloaded" list separate from saved chapters;
*Capture N new chapters* starting an ordinary bounded job over the discovered
URLs. Library home: **New Chapters** section between Continue Reading and
Recently Read (name, count, latest-known vs latest-captured, last successful
check, last failure).

**Mutual exclusion.** One WebView, one driver: `browser.automationOwner` makes
the checker and the capture job refuse to start while the other runs.

**Deferred.** *Check all active series* (per-series is the requirement; a
sweep is UI plumbing on top). A distinct `authRequired` state (M10 owns
session detection; today a login redirect is stopped by the deny-list/series
checks and reported as a failed check).

### In-session duplicate decisions ✅ *(2026-07-27)*

The preflight sheet already covered duplicates known *before* a run; this
covers the ones a running job walks onto:

- The loop preflights each chapter **before navigating** (a skip with a
  stored next-URL costs no page load) and re-checks after any redirect.
- Under `DuplicatePolicy.ask` (now the default for captures started from the
  browser), an already-complete chapter pauses the job and asks:
  *Skip* / *Re-download* / *Stop capture*, plus **"Use this choice for all
  already captured chapters in this capture session."** Partial / failed /
  files-missing chapters get state-appropriate actions (*Retry missing
  files*, *Restart chapter capture*, *Skip*, *Stop*).
- Session answers live on the job row (`session_duplicate_decision`,
  `session_partial_decision`): they survive an interrupted-session resume and
  reset when a new job starts. *Stop* is never recordable.
- **The requested count now means new capture attempts.** Skips do not
  consume it; `maxSkippedPerJob` (50) bounds the walk instead. The report
  says all four numbers: `Requested 2 new · captured 2 · skipped 2 existing ·
  traversed 4`.
- Re-downloads use the existing atomic replacement and carry reading state
  verbatim; `restoreInterruptedReplacements()` now actually runs at startup
  (it existed but was never called — found and fixed in this pass).

### Image dimensions — investigation and fix ✅ *(2026-07-27)*

**Reported:** a captured uzaymanga chapter (885) rendered with vertically
wrong panel proportions offline while the site looked normal.

**Evidence.** The live page's panel `<img>` tags carry **no width/height
attributes** and are CSS-sized (`w-full h-auto`); the actual files measure
`718×513`, `800×13850`, `800×13700`, `800×16000`, `800×14990`, `800×2660` —
aspect ratios from 0.7 to 20× tall in one chapter. So the only dimension the
old pipeline could record was the WebView probe's snapshot
(`naturalWidth`/rendered box at whatever instant the probe ran), and the
reader then laid out a fixed-height box from it with `BoxFit.fitWidth`: a
too-short recorded height shows a cropped slice of a 16 000-px strip — which
is exactly "compressed". The failing layer is **(2)/(3)/(4) of the candidate
list: DOM-reported dimensions treated as intrinsic file dimensions**; the
files themselves are well-formed (their headers parse and match `sips`), the
manifest serialisation is faithful to what it was given, and the reader's
layout maths is correct when fed true ratios.

**Fix.** `core/image_dimensions.dart` — pure-Dart header parser (PNG, JPEG
incl. EXIF orientation swap, GIF, BMP, WebP VP8/VP8L/VP8X, AVIF/HEIC `ispe`,
largest-wins for multi-property files) covering exactly the formats the
downloader accepts, validated byte-for-byte against the six real AVIF strips.
The downloader records decoded dimensions as truth
(`dimensionsVerified: true`), demoting the DOM's claim to
`domWidth`/`domHeight` diagnostics. The reader repairs pre-existing manifests
from the stored files on open — once per file, no re-download, progress
anchors intact (panel count unchanged) — and `live_capture_test.dart` now
prints the DOM/manifest/file truth table per panel and asserts
manifest == file for every stored asset of the real chapter 885.

**Reader layout.** Width-constrained, height from the verified ratio,
`BoxFit.fitWidth` with `Alignment.topCenter` — never `BoxFit.fill`, so even a
wrong ratio can crop but not stretch. `cacheWidth` never upscales (Flutter's
`ResizeImage` clamps to intrinsic width).

**Live acceptance (chapter 885, 2026-07-27, Simulator).** Captured `complete`,
6/6 panels, all AVIF, 1.47 MB; the run also logged *"12 image(s) failed to
load in the page"* — the WebView intermittently failing on the giant strips is
precisely the unreliability the byte-decode removes. Per-panel truth table:

```
[dims] panel 1: dom=718x513    manifest=718x513    file=718x513
[dims] panel 2: dom=800x13850  manifest=800x13850  file=800x13850
[dims] panel 3: dom=800x13700  manifest=800x13700  file=800x13700
[dims] panel 4: dom=800x16000  manifest=800x16000  file=800x16000
[dims] panel 5: dom=800x14990  manifest=800x14990  file=800x14990
[dims] panel 6: dom=800x2660   manifest=800x2660   file=800x2660
[dims] 6 panels checked · 0 DOM report(s) disagreed with the stored file
```

Manifest = file on every panel is asserted, not just printed — the reader lays
out from the manifest, so this is the distortion pipeline closed end to end.

### Claude Design UI implementation *(2026-07-27)*

The UI was rebuilt from the Claude Design prototype ("Web Reader.dc.html").
Platform-neutral by construction: plain Material widgets only, no Cupertino
or iOS-only chrome, insets from `MediaQuery` — the same screens run on iOS
and Android. `ios-frame.jsx` (the prototype's device bezel) was deliberately
not ported.

- **Theme** — `lib/ui/theme.dart`: one flat `appTheme()` (light) built from
  the design's literal values (primary `#35606F`, bg `#FBFAF8`; Newsreader /
  IBM Plex Sans / IBM Plex Mono, bundled OFL variable fonts with
  `FontVariation` weights). **No token layer** — a `ThemeExtension` token set
  was written first and removed on request (D28); widgets style from
  `Theme.of(context)` plus literal values, the way the prototype does.
- **Status vocabulary** — `lib/ui/status_style.dart`: capture state
  (download/offline glyphs, never a checkmark), read state (dot / partial
  ring + % / hollow check), update-check chips where **never-checked is its
  own state**, monogram tiles, section labels.
- **Screens** — app shell with the design's two-tab bar (Library first);
  library (activity strip → Activity, continue cards, series rows with check
  chip + one worst-first warning line, persisted sort control, overflow
  sheet); series detail (monogram header, meta chips, warning card, 5-state
  update-check card, dashed remote list, chapter rows); reader (pure-black,
  tap-to-toggle gradient chrome, read pill, live %/panel bar, end-of-chapter
  block, amber partial banner, files-gone state); browser (address pill,
  extended Capture FAB); capture panel (phase chip, progress, dark log
  drawer, pill controls); element-picker and duplicate sheets; **new**
  Activity and Settings screens (+ `/activity`, `/settings` routes).
- **Deliberate deviations** — no jump-to-position chip (the reader restores
  the saved offset directly, which the M5 tests assert); no spacer above
  panel 1 (leading padding would shift every restored offset); no theme
  picker (the design is light-only). New Chapters / Recently Read library
  sections were replaced by the design's row chips and the series-detail
  remote list.
- **Load-bearing find** — with Library as the boot tab, the WebView lives in
  the IndexedStack's hidden slot; an unrendered WKWebView loads pages but
  throttles rAF/lazy-load and reports zero layout metrics, so captures
  driven from outside the Browser tab stalled mid-scroll. Fix: the shell
  brings the Browser tab forward on the idle→running edge of the capture job
  or update checker (what the design's prototype does on `startRun`), and
  the M0 probe test looks at the tab before reading layout metrics.
- **Evidence** — `flutter analyze` clean; full suite 334/334 after updating
  `library_ui_test` (keyed row finders, phone-sized surface) and the M12
  reader assertion; Simulator integration re-runs under the new UI:
  `offline_read` 3/3 · `reading_flow` 1/1 · `update_check` 1/1 ·
  `capture_flow` 5/5 · `user_assist` 5/5 (each run also rebuilds the iOS
  app), and re-run in full on the `6.2.0-beta.3` plugin pin (limitation 4).
  Android now builds (`apk --debug` OK on the pin). Not yet: physical
  device.
- **Out of scope, needs approval** — archive/restore + Archived screen
  require schema v7 (`library_items.lifecycle`), a persisted-schema change.
- **Release-prep note** — the OFL license texts live next to the fonts in
  `assets/fonts/`; registering them in Flutter's `LicenseRegistry` (so they
  appear in the app's licenses page) should land with release hardening.

### M14 routing · M15 check-all · M16 archive *(2026-07-27)*

- **M14 (routing)** — every UI start now goes through the queue: browser
  post-preflight starts, series-detail "capture N new", both check actions.
  Decisions still happen *before* enqueue (the preflight sheet is unchanged);
  resume/discard of an interrupted `capture_jobs` row stays direct by design.
  Queue gained two behaviours: it re-pumps when a direct owner releases the
  browser (listening to both controllers' end-of-run notifications), and
  `enqueueSeriesCheck` is idempotent per series while pending.
- **M15** — `enqueueCheckAll()` expands into per-series `seriesCheck` rows
  (the spec-sanctioned choice): kill mid-run leaves the remainder as the
  restart offer, one failure is one history row with its reason, counts are
  the queue's own. `cancelQueuedChecks()` = drop the waiting rows, let the
  in-flight one finish. Entry: the library header's sync action; bulk cancel
  in Activity's app bar. Archived series are skipped.
- **M16 (schema v7)** — `library_items.lifecycle` (`active`|`archived`,
  default active) + `archivedAt`; additive migration `from < 7`. Archive:
  overflow sheets → confirm dialog quoting the exact pending-task count
  (Q25 settled as confirm-and-cancel), cancels that series' tasks, flips
  lifecycle; nothing under `library/` is touched. Restore from the Archived
  screen or the detail banner (which replaces the check card while
  archived). Providers split: `allSeriesGroupsProvider` → active
  (`seriesGroupsProvider`) / `archivedGroupsProvider`; detail looks across
  both so a just-archived series keeps working.
- **Evidence** — 347/347 unit/widget (7 new archive tests, 6 new scheduler
  tests); the full 5-suite Simulator chain re-run green on the finished
  batch (`offline_read` · `capture_flow` · `reading_flow` · `update_check` ·
  `user_assist`). Note: the v7 *migration body* itself has no automated test — the
  project has no drift schema-verifier infrastructure (true of v2–v6 as
  well); adding `drift_dev`'s schema-dump/step-verifier workflow is a
  worthwhile standalone task.

### Capture hardening batch *(2026-07-27, post-audit)*

Implements the verified audit recommendations (see D30–D34):

- **Capture range UX** — exactly three choices (Current chapter · Number of
  chapters · Until the end) in `capture_range_sheet.dart`; typed count with
  validation (positive integers, max `maxChaptersPerJob`=100); until-end
  bounded by `untilEndSafetyLimit`=150 and a 45-min duration bound, with the
  distinct result *"Stopped at the safety limit before a confirmed end of
  series."* Range mode persists (schema **v8**: `capture_jobs.rangeMode`,
  `queue_tasks.rangeMode`) and survives resume. The 1/3/5 presets are gone.
- **Hidden-WebView protection** — `waitingForBrowser` state; the engine holds
  before scroll/verify/extract whenever the viewport is zero, wait time is
  credited back to the chapter deadline, the Library strip becomes an amber
  banner with an Open Browser action (shell tab-request notifier), the
  update checker holds in its probe helper, and a collapse guard refuses
  extraction when the final candidate set falls far below what scrolling saw
  (the Asura avatar case). Frozen-scroll watchdog stops a pass after 6
  no-movement steps on a rendered surface. Live nuance (verified on Asura):
  the guard is evidence-based — a once-painted WebView hidden mid-run keeps
  live metrics on the Simulator and the capture correctly continues; the
  pause fires only when measurements actually break (never-painted surface,
  and potentially device-side throttling — a physical-device checklist item).
- **Adaptive scrolling** — fast lane 3.5 vp / 70 ms after 2 fully-resolved
  probes with the lookahead covering jump+margin; careful lane unchanged;
  stopping contract unchanged; irrelevant pending images (avatars) excluded
  from the asset wait; per-phase `[timing]` log line.
- **Disk safety** — `webread/device_storage` channel (Swift/Kotlin);
  500 MB start floor, 200 MB reserve, per-chapter rolling check with
  median-of-series estimate, both-copies replacement check,
  `insufficientStorage` error class end to end, range-sheet preflight with
  free/estimated space and a refusal dialog. Backup exclusion set on
  `webread/` at startup (DB and settings stay backed up).
- **MIME-named extensions** — files named from sniffed bytes; legacy
  mismatched files remain readable (manifest is the reference); re-capture
  normalises.
- **Storage visibility** — Settings shows offline chapter count + total
  bytes + the backup-exclusion note; per-series/per-chapter sizes were
  already on their screens.
- **Live protocol** — repo-root `CLAUDE.md` with the Live-Site Verification
  Protocol, the two-site matrix, and `[LIVE][site] RESULT:` reporting;
  live tests now mark SKIPPED (never pass) when unreachable; new bounded
  `live_asura_smoke_test.dart` (2 chapters, incl. mid-capture tab-switch
  pause/resume).
- **Evidence** — 381/381 unit/widget (34 new across
  `capture_range_test`, `capture_range_sheet_test`, `hidden_webview_test`,
  `adaptive_scroll_test`, `disk_safety_test`, `mime_extension_test`); the
  adaptive-scroll test caught and fixed a real flaw (jump could outrun the
  lookahead) before it shipped. Simulator + live results recorded below and
  in the CLAUDE.md matrix.

### Storage cleanup + Browser-leave flows *(2026-07-27, design v2)*

- **Schema v9** — `chapters.offlineRemovedAt` (user removal, distinct from
  files the system lost) and `capture_jobs.pauseReason`. Additive.
- **`lib/storage/cleanup.dart`** — the removal engine. `removeOffline` is a
  *soft* delete: the chapter directory is renamed into `tmp/undo-<id>` so the
  toast's Undo is real, finalised after a short window (or swept at startup
  by the existing staging sweep). `removeOfflineNow` is the hard path for
  queued bulk work. The DB write names only `contentPath`/`byteSize`/
  `offlineRemovedAt`, so all other metadata survives by construction (D35).
  `lockReasonFor` keeps chapters that are open in the reader or mid-capture.
- **Browser-leave** — `needsRenderedBrowser` on the job is true only for
  genuinely WebView-dependent phases; `LeaveBrowserGuard` (an
  InheritedWidget) fronts the bottom nav, system back (`PopScope`) and every
  route push. Choosing *Leave and pause* calls `pauseForBrowserHidden`,
  persists the reason, and leaves the queue task active; returning calls
  `resumeAfterBrowserVisible`, with the engine's existing render guard (D32)
  doing the surface/page validation. Activity shows a dedicated
  "paused — Browser required" row with an *Open Browser to resume* action.
- **Finished-chapter flow** — `_finishedChapterLeavingFor` applies every
  guard (completed · forward · different chapter · files present · target
  openable) *before* navigating; cleanup runs *after* the next chapter is
  loading and the reader lock has moved (D37).
- **Storage screen** — real totals derived from the same library stream the
  shelf uses (chapter `byteSize`, no file-tree walk per rebuild); free space
  and temp-file size as one `FutureProvider` per visit. Per-series rows with
  size bars, temp-file cleaning, and the two cleanup entry points. Minimal
  entry: a quiet `StoragePill` in the Library header that only colours when
  space is low, plus Settings › Storage.
- **Selection mode lives in Series detail only** — Storage's "Choose chapters
  to remove" navigates into a series with `?select=1`; the Storage screen
  never hosts a selection list. Locked chapters render dimmed with a lock and
  cannot be selected.
- **Four bugs found and fixed by the new tests**, three of them pre-existing
  or latent:
  1. drift's `insertOnConflictUpdate` treats a null field on a data class as
     *absent*, so a re-captured chapter kept its `offlineRemovedAt` — a later
     system-side file loss would then have been reported as a deliberate
     removal. Fixed with an explicit `clearOfflineRemovedMark` writer.
  2. The same trap left `captureJobs.pauseReason` set after a resume, so a
     restored job would have looked "paused — Browser required" forever.
     Fixed with `clearJobPauseReason`.
  3. The reader's cleanup lock stayed on the chapter being *left*, so
     automatic removal silently skipped the very chapter it was meant to
     remove. The lock now moves with the reader.
  4. **`allSeriesGroupsProvider` only watched `library_items`** despite its
     own comment claiming both tables. Drift invalidates per table, so any
     chapters-only write (exactly what cleanup does) left the shelf and the
     Storage screen stale until something happened to touch a series row.
     Now merges both table streams. This one predates this batch and
     affected the whole library, not just cleanup.
- **Evidence** — 419/419 unit/widget (38 new across `cleanup_test`,
  `finished_transition_test`, `leave_browser_test`); `flutter analyze` clean.

---

## 4. Build and run

```bash
# once
flutter pub get
dart run build_runner build          # drift codegen
(cd ios && pod install)

# checks
dart format --set-exit-if-changed lib test integration_test tool
flutter analyze
flutter test                         # 134 unit tests

# run the app
flutter run -d <simulator-id>        # e.g. iPhone 17
xcrun simctl list devices | grep Booted
```

### Fixture server (manual browsing)

```bash
dart tool/fixture/serve.dart 8099
# then browse to http://localhost:8099/chapter/1 inside Web Reader and tap Capture
```

3 chapters × 6 panels, lazy-loaded, with a slow panel, a 503 panel in chapter 2,
a duplicate URL, a hidden image, and decoy chrome (logo/icon/avatar/banner/
tracking pixel). `rel="next"` chains 1 → 2 → 3; chapter 3 has no next link.

The automated tests do **not** need this server — they serve the same fixture
in-process (see §5).

### Integration tests

```bash
# core capture + multi-chapter chain (in-process fixture)
flutter test integration_test/capture_flow_test.dart  -d <simulator-id>

# online -> offline: captures, kills the source, reads from disk
flutter test integration_test/offline_read_test.dart  -d <simulator-id>

# user-assisted fallback: ambiguity -> prompt -> saved rule -> reuse
# run ONE scenario at a time; see the harness caveat in §8
flutter test integration_test/user_assist_test.dart -d <simulator-id> \
  --plain-name "ambiguous page"

# optional, read-only live probe of the two real sites
flutter test integration_test/live_site_probe_test.dart -d <simulator-id>
```

Fixture paths for manual driving: `/chapter/N` (rel=next), `/tr/N`, `/de/N`,
`/amb/N` (ambiguous, prompts), `/nolabel/N` (icon-only, prompts).

---

## 5. Tests

### Unit and widget — 314 tests, all passing

`flutter test` → `00:16 +561: All tests passed!`

| File | Tests | Covers |
|---|---|---|
| `image_candidates_test.dart` | 11 | Size floor, aspect, hidden/chrome, de-duplication, URL preference, width clustering, **broken-image retention** |
| `url_utils_test.dart` | 12 | Normalisation, relative resolution, loop/scope/scheme/deny-list validation |
| `next_page_test.dart` | 11 | Strategy ordering, multilingual text matching, deny-listed near-misses, validation inside the chain |
| `manifest_test.dart` | 6 | JSON round-trip, asset order, failure detail, relative-path invariant |
| `capture_state_test.dart` | 12 | Legal/illegal transitions, terminal states, progress `copyWith` |
| `database_test.dart` | 10 | Insert/query, chapter ordering, `url_key` uniqueness, in-flight reset, missing-content demotion, reactive stream, job resumability |
| `file_store_test.dart` | 11 | Relative paths, staging invisibility, atomic commit, discard, sweep, reconciliation listing, byte size |
| `site_rule_test.dart` | 16 | Series fingerprinting (EN/TR/DE slugs), href-pattern generalisation, locator JSON, signal counting, scope matching + narrowest-wins, **rules not leaking between series or hosts** |
| `next_page_confidence_test.dart` | 21 | Automatic-proceed cases (EN/TR/DE + an unlisted language via `rel`), corroboration, **ambiguity → askUser**, saved-rule authority, mid-series start, deny hints, **short-hint word boundaries** |
| `rule_persistence_test.dart` | 12 | Creating a rule from a tapped element, DB round-trip, reuse on the next chapter, scope isolation, reader-area derivation, failure counting, replacement |
| `safe_navigation_test.dart` | 21 | Navigation lock, allowed-target pass-through, cross-host veto, sub-frame pass-through, post-redirect validation, series-change detection, bounded chapter count |
| `image_format_test.dart` | 5 | Magic-byte sniffing incl. ISO-BMFF/AVIF brands, rejection of HTML error bodies |
| `recovery_test.dart` | 7 | Interrupted job reset, orphaned staging sweep, missing-content demotion, interrupted replacement restore |
| `series_identity_test.dart` | 22 | Signal ordering, fingerprints, title cleaning, **low confidence never merges** |
| `series_grouping_test.dart` | 15 | Group resolution, rename semantics, backfill without data loss, chapter ordering |
| `library_ui_test.dart` | 19 | Grouped list, series detail, rename, **Continue Reading / Recently Read sections and their edge cases** |
| `reading_position_test.dart` | 15 | Anchor↔fraction, `ChapterLayout` geometry, restore offset, completion threshold + dwell, changed panel count |
| `reading_repository_test.dart` | 21 | `markOpened` never completes, throttled/flushed writes, mark read/unread, series pointers, **capture ↔ reading isolation**, **write serialization: a stale in-flight save cannot undo a completion**, **completed stays at 100% while the anchor keeps tracking (D39)** |
| `duplicate_capture_test.dart` | 20 | All six local states, each policy, range skipping, atomic replace + restore, **a job must not collide with itself** |
| `library_ui_test.dart` (M8 group) | +4 | New Chapters section (count, latest-known vs captured, failed-check surfacing), series detail known-remote separation |
| `reader_lifecycle_test.dart` | 6 | Restore-at-open offset, lifecycle flush inside the debounce window, **no false completion on kill mid-fling**, dwell completion, manifest repair on open, **a finished chapter re-read from the top stays at 100%** |
| `reader_navigation_test.dart` | 4 | Right-swipe to the episode list, **position flushed before the route changes**, **a reading scroll (or a left-swipe) never triggers it**, pop-not-stack when the episode list is already underneath |
| `image_dimensions_test.dart` | 12 | PNG/JPEG(+EXIF orientation)/GIF/BMP/WebP(3 variants)/AVIF(`ispe`, largest-wins) headers; truncation and garbage → null |
| `manifest_repair_test.dart` | 5 | DOM-claim correction from stored files, verify-once, unparseable/missing files left alone, **progress approximately valid across repair** |
| `session_duplicate_test.dart` | 10 | Mid-run prompt (real loop + real downloads over local HTTP), skip/re-download once vs for-session, stop-not-a-policy, partial actions, **resume keeps session decisions, new job resets**, requested-count semantics, skip bound |
| `capture_queue_test.dart` | 26 | Queueing starts nothing and touches no browser · queued rows survive a restart unstarted · a queued capture does not block a check · start asks for the Browser first and refuses when it is unavailable · sequential processing · one failure does not discard the batch · stop keeps the remainder queued · duplicate prevention (history excluded) · batch ordering incl. decimals · missing source URLs reported · row reuse · reorder/clear/start-one |
| `capture_queue_ui_test.dart` | 14 | Library strip appears only when captures wait · "Not now" keeps the queue and navigates nowhere · confirming runs it · Activity's WAITING TO START section, per-row position/mode/host, remove, reorder, clear-with-confirm · counts summary with no invented percentage · Settings shows Developer in debug · two-step reset, wrong word leaves the button dead |
| `local_reset_test.dart` | 10 | A used app comes back empty · every table emptied (discovered from the schema) · files, staging and `.previous` backups gone · cookies cleared · active work stopped first · per-area report · a failing area reports INCOMPLETE and does not claim success · idempotent |
| `chapter_progress_ring_test.dart` | 8 | 0% / partial / 100% rendering and semantics, completed always reads 100%, `shouldRepaint` only on a real change, compact 14pt row size |
| `chapter_sort_test.dart` | 10 | Default newest-first, ascending, decimal ordering (`385 < 385.5 < 386`), non-numeric stable fallback and exact mirroring, preference persistence incl. an unrecognised stored value, display-label rules |
| `chapter_details_sheet_test.dart` | 11 | Tap opens the reader with no sheet; long press opens the sheet and does **not** fire the tap; facts shown; mark-read from inside the sheet; state-appropriate actions; no re-fetch without a URL; unnumbered chapters keep their name; sort toggle flips and persists; the First-chapter action is gone. All at 320 pt |
| `chapter_source_url_test.dart` | 9 | Capture and discovery both record `source_url`; removal preserves URL, label, number, series, progress, read state and discovery metadata; re-download keeps the same identity; blank/scheme-less URLs are unusable; the boot repair restores from `url_key` and invents nothing |
| `chapter_actions_test.dart` | 6 | Offline tap → reader; non-offline tap → website/capture/cancel sheet; Open on website sends the Browser to the stored URL; offline device says so and does not navigate; unknown URL disables the action; an available chapter still reaches its source on long-press |
| `storage_indicator_test.dart` | 12 | Percentage maths incl. unknown/nonsense readings; compact layout at 320 pt with no neighbour shift and no overflow; no free-MB text; semantics label; tap → Settings → Storage; unavailable fallback; low-storage colour; **no re-read across 20 unrelated rebuilds**; throttled vs forced refresh |
| `update_checker_test.dart` | 21 | Chain discovery without downloads, no duplicate rows on re-check, persisted failure state, bounds, cancel keeps findings, series-exit stop, mutual exclusion, pure chapter-list discovery; **newest-first lists recorded oldest-first, decimals (`385 < 385.5 < 386`), unnumbered chapters interpolated between their neighbours, jump links above the list not defeating the ordering, dedup, starting-from-the-middle, and an unorderable list falling through to the chain walk instead of claiming "up to date"** |

### Integration — real WebView on the iOS Simulator

`capture_flow_test.dart` (5 tests), `offline_read_test.dart` (3),
`user_assist_test.dart`, `live_site_probe_test.dart`, `live_capture_test.dart`
(now chapter 885, with a per-panel DOM/manifest/file dimension truth table),
`reading_flow_test.dart` (the M5+M6 acceptance run) and
`update_check_test.dart` (the M8 acceptance run). Nothing is mocked: a live
WebView loads the fixture, the engine scrolls it, real bytes land in the app
container.

**Isolation:** every integration test file opens its own database
(`AppDatabase(name: 'it_…_<runStamp>')`) and its own storage root — the run
stamp matters because a run killed mid-way never uninstalls the app, so a
fixed name would leak rows into the next invocation. `user_assist_test` goes
one further (one database per boot): its tests are each self-contained and
several assert that no rules exist. No execution-order dependence, no state
leaks between files or runs.

Suite status on the Simulator (2026-07-27, final pass): `capture_flow` 5/5 ·
`offline_read` 3/3 · `user_assist` 5/5 · `reading_flow` 1/1 ·
`update_check` 1/1 · `live_capture` 1/1 (live, chapter 885). Re-running the
older suites against the current loop surfaced and fixed two real defects
beyond the stale test flows themselves: cancelling a next-link selection now
ends the job as `cancelled` (it fell through to a false `complete`), and a
capture started away from the page on screen (library's *Capture new
chapters*) now navigates to its start URL first (it used to capture whatever
page the WebView happened to be showing).

The offline test serves the fixture **in-process on the simulator** so it can
`close(force: true)` the server mid-test. That matters: `flutter test
integration_test/...` uninstalls the app afterwards and wipes the container, so
a two-invocation "capture then read offline" sequence cannot work — the capture
and the offline read must happen in one run.

---

## 6. Observed results

### Multi-chapter capture (`capture_flow_test.dart`)

```
job start · limit 3 · http://localhost:8099/chapter/1
capture start: "Fixture Webtoon — Chapter 1"
stable after 18 steps (13 images, height 4540, 0 pending, 0 broken)
candidates: 6 accepted, 7 rejected (of 13 images)
            pageChrome=3 tooSmall=2 duplicateUrl=1 hidden=1
next: http://localhost:8099/chapter/2 via a[rel=next]
saved 6/6 images -> library/<item>/chapters/<chapter> (complete)

capture start: "Fixture Webtoon — Chapter 2"
stable after 20 steps (13 images, height 4339, 0 pending, 1 broken)
1 image(s) failed to load in the page
candidates: 6 accepted, 7 rejected (of 13 images)
asset 5 failed: HTTP 503
saved 5/6 images -> ... (partial)

capture start: "Fixture Webtoon — Chapter 3"
stable after 21 steps
next: none (0 candidates considered, no candidates)
saved 6/6 images -> ... (complete)
requested chapter limit reached
job finished: 3 chapter(s) stored
```

**~28 seconds for 3 chapters, 17 panels, unattended.** Chapter 2 is `partial`
with the 503 recorded per-asset — not a false `complete`.

Decoys behave: the logo/icon/avatar are rejected as `pageChrome`, the tracking
pixel and small chrome as `tooSmall`, the repeated panel as `duplicateUrl`, the
`display:none` image as `hidden`. The 970×90 banner is inside `<header>`, so it
is rejected as chrome before the aspect test.

### Online → offline (`offline_read_test.dart`)

```
[fixture] serving on http://127.0.0.1:54286
[M2] Fixture Webtoon — Chapter 1: 6 panels · complete
[M2] Fixture Webtoon — Chapter 2: 5 panels · partial
[M2] Fixture Webtoon — Chapter 3: 6 panels · complete
[fixture] STOPPED — the source no longer exists
   → source unreachable confirmed
   → app restarted against the same container
   → library still lists 3 chapters
   → reader rendered local panels, every provider a FileImage under ResizeImage
```

### Bugs found and fixed during the pass

Real defects, all surfaced only by running the thing rather than by reading it.

**From the fixture runs (first pass):**

1. **False `complete` on a broken panel.** A 503 image has no intrinsic size and
   a collapsed box, so the size floor filtered it out — the chapter saved 5 of 6
   panels and reported success. Fixed by reporting the declared `width`/`height`
   attributes and preferring them over the rendered box (the rendered box is
   post-CSS layout, ~390px, while loaded panels measure intrinsic 800px; mixing
   the two bases made the broken panel look like it belonged to a different
   column and it was discarded as `outsideContentColumn`). Regression test
   added.
2. **93-second stall on a broken image.** `pendingImageCount` counted broken
   images as still loading, so the scroll loop never saw a quiet page and ran to
   its iteration bound. Broken (`complete && naturalWidth == 0`) is now distinct
   from pending; quiescence is judged on *change*, not on success. 93s → 6s.
3. **Retrying a partial chapter could never succeed** — a retry minted a new
   chapter id against the same `url_key` and hit the UNIQUE constraint. The
   engine now reuses the existing row's id when re-capturing a known URL.
4. **Stop was ignored between chapters.** `stop()` only cancelled the engine,
   and between chapters there is no engine. A controller-level flag is now
   checked at the top of the loop.

**From the live-site probe (second pass):**

5. **A short hint matched inside a longer word.** `ileri` matched inside
   "anime öner**ileri**", offering three unrelated sites as next-chapter
   candidates. Only same-host validation stopped them from being followed.
   Hints under 6 characters now require a word boundary.
6. **Unbounded probe payload** on heavy reader pages — now capped, with
   `imagesTruncated` reported so a truncated read cannot pass as complete.

**From capturing a real chapter (reported by the user):**

10. **AVIF panels were rejected as "not a usable image".** `uzaymanga.com`
    serves `.avif`, and the magic-number verifier only knew PNG/JPEG/GIF/WebP.
    All 15 detected images downloaded successfully and were then thrown away,
    surfacing as *"No images could be downloaded"* — the single most misleading
    failure message the app has produced. The verifier now understands ISO-BMFF
    (`ftyp` + brand: `avif`/`avis`/`heic`/`mif1`/`msf1`) and BMP, and an
    unrecognised payload now logs its leading bytes as hex + ASCII instead of a
    bare "not usable". Verified separately that Flutter *does* decode AVIF
    (700x3630 from the real file), so the reader needs no change.

    Two things this also confirmed about that CDN, neither of which needed a
    fix: it is **Referer-gated** (403 without, 200 with — the downloader already
    sends one) and it sends **no `Access-Control-Allow-Origin`**, so the in-page
    `fetch` fallback cannot read it. The primary Dio path is what works there.

**From the user-assist runs:**

7. **Corroboration silenced genuine disagreement.** Lifting the winner to high
   confidence excluded a medium-confidence rival from the competing set, so a
   page with two plausible controls proceeded confidently into the wrong one.
   Competition is now judged against the winner's *base* confidence.
8. **A saved rule was being re-litigated** by page heuristics, so teaching a
   rule did not actually stop the prompts. A saved rule is now authoritative.
9. **Duplicate rules for one scope** left the winner decided by a
   same-millisecond timestamp tie-break. Creating a rule for a scope that
   already has one now replaces it.

Also corrected: the transition table disallowed `downloading → detectingNext`
(the real and correct order — the next link is read while still on the page,
before committing) and later `complete → awaitingSelection` (the chapter is
saved; it is the *next* link that is ambiguous).

**From the M5/M6 run:**

10. **The capture job collided with itself.** Once preflight was added,
    `findResumableJob()` returned the job *currently executing* (state
    `inspecting`), so every chapter was classified `inActiveJob` and logged
    `skipped (owned by another job)`. Capture stored **zero** chapters. This
    is a real product bug, not a test artefact — it would have broken every
    capture in the shipped app, and it was found only because the acceptance
    test captures before it reads. Fixed by passing the running job's own id as
    `ignoreJobId`, plus allowing `inspecting → complete/partial/navigating`.
    Three regression tests were added.
11. **A same-millisecond pointer tie** picked the earlier chapter as "most
    recent". Comparison is now `!at.isBefore(newest)`, so the later chapter wins.
12. **`repairSeriesReadingState` awaited a stream's first emission**, which
    deadlocked under the widget-test binding. It now uses the one-shot
    `db.allLibraryItems()`.

### Observed — M5 + M6 acceptance (`reading_flow_test.dart`)

Run on the iPhone 17 Simulator against the in-process fixture, one invocation:

```
[job] job b9e80862 start · limit 2 · http://127.0.0.1:65506/chapter/1
[job] saved 6/6 images -> library/.../chapters/... (complete)
[job] asset 5 failed: HTTP 503
[job] saved 5/6 images -> ... (partial)
[job] job finished: 2 chapter(s) stored
[M5] captured 2: [Chapter 1, Chapter 2]
[M5] saved position: panel 2 +40% (50% of chapter)
[M5] restored after restart: panel 2 +40% (50% of chapter)
[M6] continue -> Chapter 1
[M6] after completing 1, continue -> Chapter 2
[M6] all read: continue=null, lastReadAt kept
[M6] after mark-unread, continue -> Chapter 1
[M5] after re-download: status=completed anchor=2 images=6
01:13 +1: All tests passed!
```

The last line is the one that matters most: after a full `replaceAll`
re-download, the row is still the same row, `read_status` is still `completed`,
the anchor is still panel 2 and `completed_at` is unchanged — while the files
underneath were genuinely re-fetched.

---

## 7. Not implemented (deliberately deferred)

Everything the brief listed as postponed: login UX and auth persistence tests,
novel/article extraction and the HTML reader, pin/favorite/dormant/archive,
search, sync, export. Also deferred from the spec: `crypto` content hashing,
`site_recipe` rows, the low-disk guard, and `NSURLIsExcludedFromBackupKey`.
From the M8 pass: *Check all active series* (per-series checks are the
requirement; the sweep is UI plumbing on top) and a distinct `authRequired`
check state (owned by M10's session detection).

---

## 8. Known limitations

**Test harness (not the product)**

- `integration_test/user_assist_test.dart` is reliable **one scenario per
  invocation** (`--plain-name`), not as a suite. All tests in a run share the
  one app-container database, and a job started with `unawaited` in one test can
  still be running when the next test's `tearDown` closes that database. Teardown
  now stops the job and waits, which helps, but the shared database remains the
  root cause. Fixing it properly means letting `AppDatabase` take a filename so
  each test gets its own — worth doing, not done.
- `flutter test integration_test/...` uninstalls the app afterwards and wipes
  the container, which is why the capture and the offline read must happen in a
  single run.
- The live probe (`live_site_probe_test.dart`) must also be run one site at a
  time: a test that times out leaves async work running, and its output then
  appears under the *next* test's label. The first version of this document's
  live results were nearly mis-attributed for exactly that reason.

**iOS**

- Capture is foreground-only; iOS suspends WKWebView JavaScript shortly after
  backgrounding. `wakelock_plus` keeps the screen on during a job.
- No resource interception (`shouldInterceptRequest` is Android/Windows only),
  so asset bytes are re-fetched by Dio rather than reused from the WebView.
- The in-page `fetch` fallback is subject to CORS. A site that is
  cross-origin **and** Referer-gated **and** CORS-closed has no working path on
  iOS; such a site would be recorded as unsupported rather than worked around.
- `flutter test integration_test/...` uninstalls the app and wipes the
  container. Manual persistence testing must use `flutter run` and relaunch
  without deleting the app. **Deleting the app wipes the container by design and
  is not part of the persistence test.**

**Capture**

- Timings were tuned on the Simulator, whose network and disk are the host
  Mac's. They are optimistic and must be re-measured on a device.
- The heuristic is validated against the controlled fixture and **two live
  sites**, both of which happened to work automatically (§9). Automatic
  extraction and next-page detection are therefore proven on two real layouts;
  the *user-assisted* path is proven only on the `/amb/` and `/nolabel/`
  fixtures.
- Rule locators are scored, not exact-matched, and a rule with a single signal
  is flagged weak — but nothing yet *prevents* saving a weak rule, and there is
  no "edit rule" UI beyond forget-and-re-teach.
- Reader-area rules support exclusion selectors in the data model, but the
  picker does not yet let the user tap elements to exclude; the list is always
  empty in practice.
- The `pathPattern` scope is implemented and tested, but its shape heuristic
  (`pathShape`) is coarse and has not met a real site that needs it.
- Infinite scroll is bounded by `maxScrollIterations` but not yet reported as a
  distinct `partial` reason.
- Only `complete` chapters are skipped on a re-run; a `partial` one is
  re-captured in place (intended, but it means a re-run costs bandwidth).

**Product**

- One library item per host + first path segment. No real series detection.
- Page title is the chapter title.
- Chapter limit is capped at 5 per job.

---

## 9. Sites tested

### Controlled fixture — passing

`tool/fixture/` serves 3 chapters x 6 panels with lazy loading, a slow panel, a
503 panel in chapter 2, a duplicate URL, a hidden image and decoy chrome, plus
these variants for the fallback model:

| Path | Purpose | Result |
|---|---|---|
| `/chapter/N` | `rel="next"` chain | **Automatic** |
| `/tr/N` | Turkish label, no `rel` | **Automatic** |
| `/de/N` | German label, no `rel` | **Automatic** |
| `/amb/N` | Two plausible controls disagreeing | **Asks the user** (as designed) |
| `/nolabel/N` | Icon-only control: no `rel`, text or `aria-label` | **Asks the user** (as designed) |

### Live sites — both probed read-only on 2026-07-26

Probed with `integration_test/live_site_probe_test.dart`, which loads **one**
chapter per site, scrolls a little, inspects the DOM and reports what detection
*would* do. It downloads no images and walks no chains — there is no reason to
pull large portions of anyone's series to learn whether a heuristic fires.

**`asurascans.com` — fully automatic, no rule needed.**

```
title="Genius Archer's Streaming Chapter 101 …"  height=113146
images=75 links=92 resolved=68 broken=0
EXTRACTION: 27 accepted, 48 rejected
            tooSmall=23 outsideContentColumn=21 duplicateUrl=3 hidden=1
first panel 900x15632  …/genius-archers-streaming/101/….webp
EXTRACTION VERDICT: AUTOMATIC
NEXT VERDICT: proceed -> …/chapter/102 (link[rel=next], high)
```

**`uzaymanga.com` — fully automatic, no rule needed.**

```
title="Efsanevi Büyü İmparatoru 883. Bölüm …"  height=38144
images=42 links=140 resolved=31 broken=11
series=/manga/efsanevi-buyu-imparatoru  chapterNumber=883
EXTRACTION: 15 accepted, 27 rejected  pageChrome=2 tooSmall=25
first panel 700x3630  …/_manga/7/883/1__….avif
EXTRACTION VERDICT: AUTOMATIC
NEXT VERDICT: proceed -> …/884-bolum-oku (labelled control, high)
             via text="Sonraki"; corroborated by chapter progression 884
```

**Neither live site required a user-assisted rule.** The user-assisted path is
therefore proven against the controlled `/amb/` and `/nolabel/` fixtures, not
against these two sites. That is the honest statement of coverage.

### Rules created during testing

| Rule | Host | Scope | Signals | Created by |
|---|---|---|---|---|
| next-link | `127.0.0.1` (fixture) | `series` `/amb` | 2 — link text + href pattern `^/amb/(\d+)$` | The `/amb/` ambiguity prompt |
| next-link | `127.0.0.1` (fixture) | `series` `/amb` | 2 | Pre-taught, to prove reuse without prompting |

No rules were created for either live site, because none were needed.

### What the live probe changed in the code

Running against real pages surfaced two defects that the fixture could not:

1. **Short hints matched inside longer words.** The Turkish hint `ileri` matched
   inside "anime öner**ileri**" (recommendations), offering three unrelated
   sites as next-chapter candidates. Only same-host validation stopped them.
   Hints shorter than 6 characters now require a word boundary. Regression
   tested.
2. **Unbounded probe payload.** A heavy reader page can carry many hundreds of
   images; the probe now caps what it serialises and reports `imagesTruncated`
   so a truncated read is never mistaken for a complete one.

## 10. Manual test scripts

### M5 physical-device lifecycle pass — **PENDING, needs hands on the phone**

The restart path is proven automatically; force-quit, app-switcher kill and
background-then-kill are different iOS callback paths and can only be
exercised by touching the device. Status: **not run** — do not treat M5's
lifecycle claims as device-verified until this has been.

Setup once: `flutter run -d <device-id> --release` (or install a debug build),
with at least one chapter captured. **Do not uninstall between scenarios** —
uninstalling removes the app container by design and would test nothing.

1. **Baseline restore.** Open a chapter, scroll to a clearly recognisable
   middle panel, wait 3 s (past the debounce). Swipe home. Relaunch.
   → reopens at that panel.
2. **Background and return.** Open the same chapter, scroll further, swipe
   home, wait ~10 s, tap the app icon. → same position, no reload jump.
3. **App-switcher kill, reader foregrounded.** Open a chapter, scroll to a
   new spot, wait 3 s, swipe up into the app switcher directly and kill the
   app. Relaunch. → position within one debounce window (≤ 2 s of scrolling)
   of where you were.
4. **Immediate force-quit while reading.** Scroll to a new spot and kill from
   the switcher *within a second or two*. Relaunch. → bounded loss: the
   position is at most the last 2 s of scrolling behind; the chapter is NOT
   marked read.
5. **Background, then kill.** Scroll, swipe home, wait ~10 s, then kill from
   the switcher. Relaunch. → exact position (the backgrounding flush fired).
6. **Fling-to-end, then kill.** Fling to the very bottom and kill immediately.
   Relaunch. → the chapter is **not** completed (dwell rule), position near
   the end.
7. After each scenario: the Library's Continue Reading card shows the same
   chapter and a consistent percentage; read/completed states unchanged
   except where you finished deliberately.
8. **Uninstall/reinstall (expected data loss).** Delete the app, reinstall,
   launch. → empty library. This is correct behaviour, not a failure.

### Online → offline (the M2 checkpoint, by hand)

1. `dart tool/fixture/serve.dart 8099`
2. `flutter run -d <simulator-id>`
3. Browse to `http://localhost:8099/chapter/1`.
4. Tap **Capture** → *Next 3 chapters*. Watch the panel: state, chapter N of 3,
   images, scroll %, log.
5. Library tab → 3 chapters, one marked partial (5/6).
6. Stop the fixture server (`Ctrl-C`).
7. Turn off Wi-Fi on the **host Mac** (the Simulator has no airplane mode).
8. Force-quit the app in the Simulator (do **not** delete it), then relaunch.
9. Library still lists 3 chapters. Open one — it reads end to end. The partial
   one shows an "Incomplete capture" banner.

### Recovery

1. Start a 5-chapter capture.
2. Force-quit mid-download.
3. Relaunch → the library shows a **Resume / Discard** card.
4. Resume continues from the recorded URL without re-capturing completed
   chapters; Discard drops the job and leaves the captured chapters.

Startup also sweeps staging directories, demotes any chapter left `capturing`
to failed (never to complete), and reconciles a committed directory whose
database row is missing by reading its manifest.

---

## 11. Next priorities

The full backlog with acceptance criteria lives in [MVP_PLAN.md](./MVP_PLAN.md) (Stage 1b). In
order:

1. **P0.1** — the physical-device lifecycle checklist (§10) — still the only item needing
   hands on a phone. *(P0.2 read-vs-captured: done. P0.3 self-contained capture_flow: done.
   P0.4 isolation: done.)*
2. **M12** — ✅ done (2026-07-27): the footer % and panel anchor update live while scrolling
   via a ValueNotifier scoped to the footer; DB writes stay debounced (test proves the visible
   state changes before the debounce and the row after it).
3. **M13** — ✅ done (backend 2026-07-27, UI with the design implementation: sort control,
   redesigned rows with check chips and a check action in the overflow sheet, Recently Read
   removed).
4. **M14** — ✅ done (backend + strip + Activity screen with the design; entry-point routing
   through `enqueue*` later the same day — everything autonomous now lands in Activity).
5. **M15** — ✅ done (check-all expands to per-series queue rows; bulk cancel; archived
   skipped).
6. **M16** — ✅ done (schema v7 `lifecycle`+`archivedAt`, archive/restore, Archived screen,
   Q25 confirm-and-cancel).
7. **M17** — remaining: appearance setting + dark theme (waiting on a dark design by the
   user's choice), rebuild-scope/performance acceptance, remaining polish (the design-system
   bullet shipped, D28). Also standalone: drift schema-verifier infrastructure for migration
   tests.
8. Then Stage 1c: M9 pin/favorite/dormant · M7 text extraction · M10 auth · M11 recovery
   hardening. Also carried: exclusion picking for reader-area rules and a weak-rule confirmation
   step (fits naturally alongside M13/M17 UI work or M9).

Before any device-facing claim: re-measure the stability constants on real hardware and set
`NSURLIsExcludedFromBackupKey` on the assets tree (M11).
