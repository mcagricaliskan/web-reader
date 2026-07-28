# Web Reader — project instructions

iOS-first, Android-compatible Flutter app: embedded browser + autonomous
webtoon capture + offline reading library. Plans live in `docs/MVP_PLAN.md`,
as-built truth in `docs/IMPLEMENTATION_STATUS.md`, durable decisions in
`docs/DECISIONS.md`.

## Live-Site Verification Protocol

Real websites are **optional, explicit, bounded smoke tests** — never
dependencies of the normal suite. But when a change touches behavior that
only a real site can prove, the matching live smoke test is part of "done".

1. Run the deterministic fixture tests first (`flutter test`, then the
   fixture integration suites). They gate everything; live tests never
   substitute for them.
2. Decide whether the change affects: capture scrolling · panel extraction ·
   image downloads / MIME handling · next-chapter navigation · multi-chapter
   chaining · update checking · duplicate handling · user-assisted rules ·
   authentication/session behavior.
3. If yes: run the bounded live smoke test(s) whose matrix entry covers that
   area, on a Simulator/device. If the environment has no device or no
   network access, say so — report the limitation honestly instead of
   skipping silently.
4. Never make `flutter test` (or CI) depend on a live site. Structural
   guarantee today: everything under `test/` is network-free, and
   `integration_test/live_*.dart` runs only by explicit file + `-d device`.
5. Never commit downloaded third-party chapter content. Captured bytes stay
   in app containers or scratch directories.
6. Record every live run's outcome as one of: **PASSED · FAILED · BLOCKED ·
   SKIPPED (unreachable)**. The tests print a machine-greppable line:
   `[LIVE][<site>] RESULT: <outcome> url=<url> …`.
7. An unreachable or blocked site is **never** a passing verification. The
   live tests call `markTestSkipped` in that case; report it as such.
8. No site-specific production hacks unless a generic strategy is impossible
   — and then isolated behind its own seam and documented in
   `docs/DECISIONS.md`.
9. Keep each live run to the smallest operation that answers the question:
   one chapter for capture checks, two for chaining, read-only probes for
   detection. Never run "Until the end" against a live site in automation.
10. When the user supplies a new site/series, add a matrix row below with its
    purpose and bounds before relying on it.

### Command reference

```bash
# deterministic (network-free) — the gate:
flutter test
# fixture integration suites (Simulator; in-process fixture server):
flutter test integration_test/capture_flow_test.dart  -d <udid>
flutter test integration_test/offline_read_test.dart  -d <udid>
flutter test integration_test/reading_flow_test.dart  -d <udid>
flutter test integration_test/update_check_test.dart  -d <udid>
flutter test integration_test/user_assist_test.dart   -d <udid>
# live smoke (explicit, bounded, third-party):
flutter test integration_test/live_capture_test.dart     -d <udid>  # uzaymanga, 1 chapter
flutter test integration_test/live_asura_smoke_test.dart -d <udid>  # asura, 2 chapters
flutter test integration_test/live_site_probe_test.dart  -d <udid>  # read-only, both sites
flutter test integration_test/live_queue_start_test.dart -d <udid>  # queue-first flow
#   ^ two groups: one chapter page per site (extraction + next-detection),
#     and one series index page per site (chapter-list ordering, D40).
```

### Live-site matrix

| | Uzay Manga | Asura Scans |
|---|---|---|
| Series | Efsanevi Büyü İmparatoru | The Nebula's Civilization |
| Example URL | `https://uzaymanga.com/manga/efsanevi-buyu-imparatoru/885-bolum-oku` | `https://asurascans.com/comics/the-nebulas-civilization-059befe1/chapter/137` |
| Purpose | Real single-chapter capture · Referer-gated AVIF CDN · very tall panels (800×16000) · MIME/extension verification · next-chapter detection · aspect-ratio/manifest repair · adaptive scroll on a long lazy chapter · chapter-list ordering on the series index page | Very long eager-rendered chapter (~146k px, ~31 panels) · fast traversal over loaded content · hidden-WebView pause protection · comment-avatar false-positive rejection · JPEG bytes under `.webp` URLs · next-chapter detection · bounded multi-chapter chain · large-chapter downloads (15–40 MB) · chapter-list ordering on the series index page · queue-first start flow (D46/D47) |
| Download allowed | Yes — 1 chapter (~1.4 MB) | Yes — max 2 chapters (~30–80 MB) |
| Max chapters | 1 | 2 |
| Content type | Webtoon, AVIF strips, no HTML size attrs | Webtoon, WebP/JPEG strips via Astro/React island (panels absent from static HTML; hydrate eagerly) |
| Test file | `integration_test/live_capture_test.dart` (+ probe) | `integration_test/live_asura_smoke_test.dart` (+ probe) |
| Last verified | 2026-07-27 (capture+dims+extensions; series-page list read-only: 500 links, 483 chapters, `newestFirst`, confident) | 2026-07-27 (2-chapter smoke incl. pause/resume; series-page list read-only: 141 links, 103 chapters, `newestFirst`, confident) |
| Caveats | Series page carries *İlk Bölüm* / *En Son Bölüm* jump links above the list (D40); Turkish titles; site occasionally slow; CDN 503s single assets (partial-capture path) | Cloudflare-fronted; comment avatars sit pending forever; URL slugs contain content hashes and may rot; a hidden-but-once-painted WebView keeps live metrics on the Simulator (run continues — correct); the pause fires only on broken metrics |

> **Coding-agent rule:** when a change affects an area covered by a matrix
> entry, run the relevant bounded live smoke test after deterministic tests —
> unless the environment cannot access a device or the site, in which case
> report that limitation honestly. Do not run every live site after every
> unrelated change.

## Standing engineering rules (project-specific)

- Original image bytes are stored byte-for-byte; no format conversion, no
  quality profiles (D31). Stored file extensions come from sniffed MIME.
- WebView-dependent automation must never scroll, measure, or extract on an
  unrendered surface (zero viewport) — pause and ask for the Browser (D32).
- Disk-space checks run before and during captures; low-disk is its own
  error class (`insufficientStorage`), never a generic I/O failure.
- `webread/` (chapter assets) is excluded from device backup; the database
  and settings are not.
- Capture range UX is exactly three choices: current chapter · number of
  chapters · until the end (safety-limited, distinct result at the limit).
- `flutter_inappwebview` is pinned to an exact version (see pubspec comment,
  D29). Do not let a caret drift it.
- SPM stays disabled for iOS builds (D25) until verified on a physical
  device.
- **A completed chapter is 100% read** (D39). `progress_fraction` is pinned
  at 1 whenever `read_status` is `completed`, enforced on write and again on
  display (`readProgressFor`). Re-reading a finished chapter moves the anchor,
  never the fraction.
- Update-check chapter-list ordering is **measured from the page**, never
  assumed. Emission is oldest-first; "nothing new" ends a check only when the
  ordering was unambiguous, otherwise the chain walk still runs.
- **Queueing a capture does not start it** (D46). Adding a capture request
  creates a `queued` row and nothing else — no navigation, no WebView. It
  waits for **Start Capture**. Update checks and cleanup still drain on their
  own (`taskWaitsForExplicitStart` is the predicate). The start authorisation
  is **never persisted**: queued rows survive a restart, permission does not.
- **The Browser comes forward before automation** (D47), via the queue's
  `ensureBrowserVisible` hook, which the shell provides. If it cannot, the
  task stays queued — not failed, not cancelled. Downloading and saving do
  **not** need the Browser: `needsRenderedBrowser` is the line, and leaving
  during a download must not warn or pause.
- **Removed episodes can be batch-queued for re-download** (D48), oldest
  first regardless of the display sort, reusing the existing chapter row.
  Chapters with no usable `source_url` are reported separately, never
  silently dropped and never fatal to the rest of the selection.
- **Destructive developer tools are `kDebugMode` only** (D50) — Settings
  entry, route registration and the screen itself all check it. The reset is
  two-step and requires typing `RESET`.
- **Anything in a screen header uses the shared action geometry**:
  `HeaderIconButton`, `kHeaderActionSize` (40), `kHeaderIconSize` (22),
  `kHeaderIconColor`. A widget with its own size or glyph size in that row is
  how the header ended up with two centre lines and three glyph sizes.
- **The episode list's progress pie is painted from the real fraction** (D43)
  and is the only read-state indicator. Newest-first by default, with the sort
  persisted in `settings['series.chapterSort']`. Descending is the same
  ordering reversed, never a second comparison.
- **Chapter numbers are the display label** (D43): `chapterDisplayLabel` prints
  `Chapter 487`; the raw source marker is kept on the row for the details
  sheet. Never invent a number — `Prologue` prints as itself.
- **Tap reads, long press explains** (D44). The details sheet reads only from
  the chapter row (including `byteSize`); it never measures the disk.
  "Remove offline files" keeps metadata; "Delete episode" is not offered
  because permanent metadata deletion does not exist (D35).
- **A chapter's `source_url` is durable metadata** (D42). It survives removal,
  archive, restore, re-download and reading updates because every writer names
  its columns; it is what "Open on website" and "Capture again" stand on. A
  chapter with no usable URL disables those actions rather than guessing one.
- **Storage colour comes from the percentage used** (D51): < 75% quiet,
  75–89% amber, ≥ 90% red, plus a hard escalation under 1 GB free. One rule
  (`DeviceCapacity.level`) and one palette (`storageLook`) shared by the
  Library pill and the Storage screen. Exactly one element per screen carries
  the warning state — the metric tiles never colour themselves.
- **The Library's storage indicator is a glyph and a percentage** (D41):
  device usage from one throttled `capacity` call, fixed width, no filesystem
  walk. Detailed figures live on Settings → Storage. Never show the library's
  own share as though it were device usage, and never invent a percentage when
  the platform will not report capacity.
- **Removing offline files is never deleting a chapter** (D35): bytes go,
  every piece of metadata and reading history stays, and the chapter reads
  as "Not available offline — capture again". Permanent metadata deletion is
  a separate concept and is not implemented.
- **Leaving the Browser during a WebView-dependent capture phase pauses it**
  (D36) — never cancels, never continues blind. Downloading/saving phases do
  not trigger the confirmation.
- **The after-finished cleanup preference defaults to Ask** (D37);
  "Don't ask again" is the only thing that changes the persistent setting.
  Changing the setting never removes anything retroactively.
- **Browser Home is a layer, not a route** (D52). One `InAppWebView`, built in
  one place, mounted for the whole session; Home and the URL editor are drawn
  over it. Closing them reveals the same page — scroll, cookies, in-page state
  and any paused capture intact — because nothing was torn down. Covering the
  page is still *hiding* it, so opening Home goes through the same
  `LeaveBrowserGuard` as a tab switch (D36); download/save phases still do not
  warn.
- **Go is not permanent toolbar chrome** (D52). The toolbar is Back · Forward ·
  Address · Refresh/Stop · Home. Go lives in the expanded URL editor and on the
  keyboard, where entering an address actually happens. The compact address
  field shows host + shortened path and opens the editor; it is never an
  inline editor.
- **Only manual navigation enters browsing history** (D53). Capture, update
  checks, rule validation, internal navigation and live tests all drive the
  same WebView and are never recorded — enforced twice: the source the
  automation sets, and `effectiveNavigationSource`, which cannot answer
  `manual` while `automationOwner` is held. `about:blank`, app schemes,
  incomplete loads and faulted loads never enter either. Retention is 90 days
  or 5,000 rows.
- **Clearing history clears history** (D53). One table. Saved sites, library,
  captured files, reading progress, cookies, rules and queue rows are not
  reachable from it. **Clearing website data** is the separate,
  stronger-confirmation action (cookies, site storage, cache) and never
  touches app data.
- **Google is the removable initial saved site** (D54). Seeded once per
  install behind a settings flag — not inferred from an empty table, or it
  could never be deleted. Removed stays removed; only a full reset (D50)
  brings it back. Saved sites are their own table, keyed by normalised URL,
  hand-ordered.
- **Favicons are optional decoration** (D55). Nothing waits on one; the box is
  a fixed size so a late icon never reflows a list; misses are cached too.
  Tests run with `allowNetwork: false`.
- **`AppPalette` is the one token layer** (D56) — a narrow amendment to D28,
  because a literal colour cannot be "the quiet surface" in both appearances.
  Dark values are *derived*, not designed: the design artifact is light-only.
- **drift trap:** `insertOnConflictUpdate` treats a null field on a data
  class as *absent*, so nullable columns survive an upsert. Anything that
  must be cleared needs its own narrow writer (`clearOfflineRemovedMark`,
  `clearJobPauseReason`).
