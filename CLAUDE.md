# Web Reader — project instructions

A general-purpose personal reading tool, iOS-first and Android-compatible:
embedded browser + explicit page saving + offline reading library.

Read [docs/TERMINOLOGY.md](docs/TERMINOLOGY.md) before writing any code. The
as-built model is [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md); store positioning
is [docs/STORE_PACKAGE.md](docs/STORE_PACKAGE.md); the policy reasoning behind the
safety rules is [docs/STORE_POLICY_MAP.md](docs/STORE_POLICY_MAP.md).

## What this app is, and is not

It lets a user save web pages they are legally permitted to keep, organise them,
and read them offline.

It is **not** a bulk fetcher, an automated harvester, a site archiver, a client
for particular websites, or a tool for getting past any access control. Do not write
code, comments, tests, fixtures, docs or store copy that position it as any of
those. `test/repository_cleanliness_test.dart` enforces this and will fail the
build.

## Standing rules

### Terminology — one model, one label system

- The canonical model is **Library / Collection / Entry / Page or Section**.
  `Collection` and `Entry` are the only nouns in code.
- User-facing nouns come from `lib/library/entry_labels.dart` and **nowhere
  else**. A screen that types its own noun is how one app calls the same thing an
  three different things on three consecutive screens.
- Low or unknown confidence prints **Item** / **Saved item**. Never infer a
  structure from a number in a URL, and never infer a page from the fact that the
  content came from the web.

### Nothing site-specific ships

- No hostname, selector, site list, provider catalogue or "supported sites"
  anywhere in the binary, the tests, the fixtures or the docs. Use the reserved
  example domains.
- `user_page_hints` holds only what a person taught by tapping an element. It is
  empty on a clean install; nothing seeds it, and nothing seeds `saved_sites`
  either.
- Detection uses standard HTML semantics and measurements only —
  `lib/save/content_detection.dart` is the whole surface.

### Saving is explicit and bounded

- **The default is one page.** `SaveScope.currentPageOnly` is preselected, and
  `SaveRunController.start` takes `range` as a **required** parameter so nothing
  inherits a default about how much of someone else's site to touch.
- `SaveLimits.forScope` is the only way to build limits and cannot produce an
  unbounded run. There is **no open-ended scope**: a multi-entry save is a
  number the user typed, so every ceiling is one they chose and can see. Do not
  reintroduce a range whose real bound lives in `SaveConfig`.
- Show the detection result *before* saving more than one page: what was found,
  the domain, the count or that it is unknown, the shape, the direction, the stop
  condition, the estimate, and how to cancel.
- Nothing saves in the background. Queued work waits for an explicit Start, and
  that authorisation is never persisted.

### The app stops; it never works around

- Add stopping conditions to `lib/save/stop_conditions.dart` as a named
  `StopReason`. Never add a retry with different headers, an alternate-URL
  attempt, cookie manipulation, or a rate-limit wait-out.
- Structural signals stand alone; **phrase hints never do**. A footer that says
  "subscribe to continue" is not a paywall.
- "Finished" and "the site stopped us" are different outcomes and live in
  different column values.

### Capture modes

- **Three separate concepts, never merged**: `ContentKind` (what the page is),
  `CaptureMode` (what the save was asked for), `ArtifactFormat` (what the
  package holds). Only `ArtifactFormat` decides how an entry is read, and
  `setEntryContentKind` deliberately cannot reach it.
- Modes are `imageSequence` · `textOnly` · `textAndImages`. **There is no video
  mode** — the save sheet is built from that enum, so an unhonourable value
  would become a button that lies.
- A mode is only ever offered when `CaptureCapabilities` says the engine can
  carry it out. A collection preference proposes; the page disposes.
- Text extraction splits the same way detection does: the bridge measures and
  flags, `save/document_extraction.dart` decides. Keep the judgement in Dart so
  it stays testable against literal fixtures.
- Documents are stored as typed blocks in `document.json`, never as HTML. No
  script, stylesheet, iframe or remote reference may enter a saved package.

### Media

Audio and video are never saved. `AssetFetcher` accepts image bytes only, verified
by magic number rather than `Content-Type`. `PageMediaSignals` carries **geometry
only** — never a media URL — so a video-dominant page can be classified honestly
and refused. Do not add video URL extraction, HLS/DASH, interception or playback.

### Storage and privacy

- Original image bytes are stored byte-for-byte; no format conversion, no quality
  profiles. Stored extensions come from sniffed MIME.
- App-private storage only. No export to Photos, Gallery, Downloads or shared
  storage. No new permission without a visible, justified feature.
- No analytics, crash-reporting or advertising SDK. Nothing is sent to the
  developer. Do not add a dependency that changes this.
- Never claim "no tracking", "completely private" or "everything stays on device"
  — the embedded browser contacts the sites the user visits.

### Structural invariants

- **Cancelling preserves the row; dismissing deletes it.** A cancel moves a task
  to the existing `cancelled` state — there is no sixth state — and *Remove from
  Activity* deletes a row that is already terminal, refusing anything live. A
  waiting row is removed on a tap with an **Undo** that restores its
  `orderIndex`; a running one gets a dialog naming what survives, and its
  cancellation is written the moment it is asked for, because `restore()` demotes
  a killed `running` row back to `queued`. Both the pump's claim and every cancel
  go through `updateQueueTaskIfState` — one conditional SQL `UPDATE` — so exactly
  one wins and the loser is told; a pump that loses the claim skips the row and
  carries on. Never offer a stop that does not stop: `removeOfflineNow` takes
  `shouldContinue` and is asked between entries, and stopping is cooperative
  everywhere, so the wording is "at the next safe point".

- Reading state is writable only from `lib/reading/`; `writeEntryReading` is the
  only DAO method that can reach a reading column.
- A completed entry is 100% read, enforced on write and again on display.
- Removing offline files is never deleting an entry: only `content_path`,
  `byte_size` and `offline_removed_at` are written.
- `entries.source_url` is durable metadata — every writer names its columns.
- `entries.collection_id` is nullable. A standalone entry is a first-class
  library item; never wrap one in a collection of one.
- Only manual navigation enters browsing history, enforced twice.
- `AppPalette` is the only source of colour; `test/theme_palette_test.dart` scans
  `lib/` and fails on a literal `Color(0x…)`.
- Header actions use `HeaderIconButton` / `kHeaderActionSize` (40) /
  `kHeaderIconSize` (22) / `kHeaderIconColor`.
- **drift trap:** `insertOnConflictUpdate` treats a null field as *absent*, so
  anything that must be cleared needs its own narrow writer.
- The app mark is generated by `tool/brand/generate_brand_assets.swift`, never
  hand-edited. Its colours are `AppPalette`'s.
- Destructive developer tools are `kDebugMode`-only at the settings entry, the
  route registration and the screen.

### The database has no history; the manifest does

`schemaVersion` is **1**, with an `onCreate` and no `onUpgrade`. Do not add a
migration branch, a schema dump, a step verifier or a data-copying routine. If the
schema needs to change after release, write a migration then.

`manifest.json` is **version 2** and *is* versioned, because those files are
durable user data that exists on devices today. A version-1 manifest has no
`artifact` field and is read as an image sequence — the only thing the app could
produce when it wrote one. Never rewrite a stored manifest in place, and never
read an unrecognised `artifact` as a known one: it resolves to
`ArtifactFormat.unknown` and the reader says so. `lib/storage/recovery.dart`
rebuilds library rows from packages of either version.

## Verification

```bash
dart format lib test integration_test tool
flutter analyze
flutter test
dart run build_runner build          # after touching lib/storage/database.dart
```

Deterministic tests are network-free and gate everything. Fixture integration
suites run against the in-process server in `tool/fixture/`:

```bash
flutter test integration_test/save_flow_test.dart     -d <udid>
flutter test integration_test/offline_read_test.dart  -d <udid>
flutter test integration_test/reading_flow_test.dart  -d <udid>
flutter test integration_test/update_check_test.dart  -d <udid>
flutter test integration_test/user_assist_test.dart   -d <udid>
```

### Live-site verification

Bounded, explicit, and **against the developer-owned demo site only** — see
[docs/DEMO_CONTENT.md](docs/DEMO_CONTENT.md). Pass the origin in; never compile
one in:

```bash
flutter test integration_test/live_demo_test.dart -d <udid> \
  --dart-define=DEMO_BASE_URL=https://demo.example
```

Rules: deterministic tests first, always. Never make `flutter test` or CI depend
on a network. Never commit downloaded third-party content. Report each live run as
**PASSED · FAILED · BLOCKED · SKIPPED (unreachable)** — an unreachable site is
never a passing verification. Keep each run to the smallest operation that answers
the question.

There is deliberately no matrix of third-party sites. If a change needs a real
site to prove it, add the case to the demo site.
