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
```

### Live-site matrix

| | Uzay Manga | Asura Scans |
|---|---|---|
| Series | Efsanevi Büyü İmparatoru | The Nebula's Civilization |
| Example URL | `https://uzaymanga.com/manga/efsanevi-buyu-imparatoru/885-bolum-oku` | `https://asurascans.com/comics/the-nebulas-civilization-059befe1/chapter/137` |
| Purpose | Real single-chapter capture · Referer-gated AVIF CDN · very tall panels (800×16000) · MIME/extension verification · next-chapter detection · aspect-ratio/manifest repair · adaptive scroll on a long lazy chapter | Very long eager-rendered chapter (~146k px, ~31 panels) · fast traversal over loaded content · hidden-WebView pause protection · comment-avatar false-positive rejection · JPEG bytes under `.webp` URLs · next-chapter detection · bounded multi-chapter chain · large-chapter downloads (15–40 MB) |
| Download allowed | Yes — 1 chapter (~1.4 MB) | Yes — max 2 chapters (~30–80 MB) |
| Max chapters | 1 | 2 |
| Content type | Webtoon, AVIF strips, no HTML size attrs | Webtoon, WebP/JPEG strips via Astro/React island (panels absent from static HTML; hydrate eagerly) |
| Test file | `integration_test/live_capture_test.dart` (+ probe) | `integration_test/live_asura_smoke_test.dart` (+ probe) |
| Last verified | 2026-07-27 (capture+dims+extensions) | 2026-07-27 (2-chapter smoke incl. pause/resume) |
| Caveats | Turkish titles; site occasionally slow; CDN 503s single assets (partial-capture path) | Cloudflare-fronted; comment avatars sit pending forever; URL slugs contain content hashes and may rot |

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
