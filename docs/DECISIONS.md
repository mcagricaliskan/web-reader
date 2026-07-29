# Web Reader — Decisions

> The architectural decisions, why they were made, and what would reverse them.
> Status: all decisions are **initial** — taken before any code exists. None have survived contact
> with an implementation yet. Each carries an explicit reversal trigger; that is the honest form of a
> pre-code decision.
> Revised 2026-07-25: D21–D24 added (dependency-version policy, working identity, vertical-slice-first
> ordering, authentication deferred); D03 de-versioned per D21.

Format: **Decision** · *Why* · *Consequence* · *Reverse if*.

---

## Platform and stack

### D01 — Flutter for the client

**Decision.** Flutter, single codebase, iOS and Android.

*Why.* The app is one embedded WebView plus a lot of local UI and local data — Flutter's strongest
shape. It matches the house stack (`astrolith-mobile`), so tooling, lints, and habits transfer. A
native-per-platform build would double the capture engine, which is the hard part and is
platform-agnostic Dart.

*Consequence.* The WebView is a plugin surface, not a first-class API; anything the plugin does not
expose needs platform-channel work (§15 of the technical spec lists the known cases).

*Reverse if.* WebView control turns out to be insufficient through any Flutter plugin — specifically,
if reliable in-page asset acquisition proves impossible on iOS. That would be discovered at M1f.

### D02 — iOS Simulator is the first development target

**Decision.** Develop and validate on the iOS Simulator (Xcode 26.6, iOS 26.5 runtime available
locally). Android stays architecturally supported but unbuilt.

*Why.* Fastest iteration loop, Safari Web Inspector attaches to the WebView (with
`isInspectable: true`, required since iOS 16.4), and it is the environment already set up here.

*Consequence.* Timing constants tuned on the Simulator are optimistic — its network and disk are the
Mac's. Thermal limits, memory pressure, and real backgrounding cannot be validated there. Every
timing number in the spec is provisional until measured on a device.

*Reverse if.* Nothing; this is a starting point, not a commitment. A device pass is required before
anyone claims the reliability numbers.

### D03 — `flutter_inappwebview` for the WebView

**Decision.** `flutter_inappwebview`, behind our own `BrowserController` interface. Version resolved
at implementation time per D21 — this decision is about the *package*, not a version.

*Why.* Two capabilities that capture depends on and the official `webview_flutter` does not expose
*[both verified 2026-07-25 against `webview_flutter` 4.14.1 / `flutter_inappwebview` 6.1.5 sources —
re-verify at implementation, per D21]*:

1. **Document-start user scripts.** The bridge must be installed before page scripts run and must
   survive every navigation. `flutter_inappwebview` registers a `UserScript` at `atDocumentStart`;
   `webview_flutter` uses `WKUserScript` internally for its own channel plumbing but offers no public
   API, leaving manual re-injection from `onPageStarted` — which races the page.
2. **`callAsyncJavaScript`** — passes a JSON argument map and awaits a returned promise.
   `runJavaScriptReturningResult` returns only an immediate value and requires interpolating
   arguments into JS source. Every call our bridge makes is async and parameterised.

*Correction to an earlier draft of this entry:* cookie enumeration (`getCookies`) and `setInspectable`
are **not** differentiators — `webview_flutter` has both. The two points above are the real basis.

*Consequence.* A large, effectively single-maintainer dependency sits on the critical path. The
`BrowserController` interface and the injected JS are the insulation: a swap is one implementation
file, not a rewrite.

*Reverse if.* The plugin stops tracking iOS/Android WebView changes, or a specific capability breaks
and stays broken. The interface makes this a bounded, planned move.

### D04 — Drift (SQLite) for the local database

**Decision.** `drift` + `drift_flutter`. Not Isar, ObjectBox, Realm, or raw `sqflite`.

*Why.* The requirement list — migrations, typed queries, transactions, indexes, reactive queries,
reliable persistence, a future sync path — describes SQLite with a typed layer. Drift is the only
option that has all of them, and it keeps plain SQL available for the multi-table ordering queries
(Continue Reading, New Chapters) that a NoSQL store would force into application code. Realm's device
sync has been sunset `[Unverified — confirm]`; ObjectBox's sync is commercial; Isar's maintenance
trajectory is uncertain `[Unverified]`.

*Consequence.* Codegen in the build loop (`build_runner`). Also: **do not add
`sqlite3_flutter_libs`** — it is `0.6.0+eol` and empty; `package:sqlite3` 3.x now ships SQLite through
Dart build hooks *[Verified 2026-07-25 from the local pub cache]*.

*Reverse if.* Build-hook-based native bundling causes iOS build problems that cannot be resolved. The
data model is plain relational, so a port to another SQLite wrapper stays mechanical.

### D05 — Riverpod and go_router

**Decision.** `flutter_riverpod` + `go_router`, matching `astrolith-mobile`.

*Why.* House stack, so no new vocabulary. Riverpod's `StreamProvider` maps 1:1 onto drift `.watch()`,
which is the whole reactive-library requirement with no glue. `go_router` gives deep links to a
chapter, which the reader wants anyway.

*Consequence.* None significant. State management is a small part of this app; the hard state lives in
SQLite and in the capture state machine.

*Reverse if.* Not worth reversing.

---

## Capture architecture

### D06 — Foreground autonomous crawling only

**Decision.** Capture runs only while the app is in the foreground. No background crawling, no
background update checks.

*Why.* **This is a platform fact, not a preference.** iOS suspends the app shortly after
backgrounding, and WKWebView JavaScript timers stop with it. There is no supported way to keep an
autonomous WebView crawl running in the background.

*Consequence.* The session UI must make a long foreground run tolerable: screen kept awake, status
always visible, accidental-touch protection. A backgrounded session pauses and resumes.

*Reverse if.* Never on iOS with an in-app WebView. The real escape hatch is remote capture workers —
explicitly a future possibility, not a design input now.

### D07 — Explicit state machine, not a procedural loop

**Decision.** Capture is a sealed-class state machine with persisted state, driven by an orchestrator.
No state-machine package.

*Why.* Every hard requirement — pause, resume, skip, retry with bounded attempts, recovery after a
restart, honest UI status — is a question about *which state we are in*. A procedural loop makes each
one a flag, and flags are how "captured but empty" bugs happen. Dart 3 sealed classes give exhaustive
`switch` at compile time in ~150 lines we own; a library would add vocabulary without removing work.

*Consequence.* One small SQLite write per transition. Irrelevant next to a page load, and it is what
makes recovery truthful.

*Reverse if.* The state count grows past comprehension (say beyond ~25). Then extract a
table-driven transition map — still not a package.

### D08 — Real content extraction, not screenshots

**Decision.** Store the original image files for webtoons; cleaned HTML plus plain text for articles.
A raw page snapshot is a debugging fallback only.

*Why.* Screenshots cannot be re-flowed, re-read at a different size, searched, or exported, and they
capture ads and chrome along with the content. The offline reader's quality is the product; a
screenshot library is a worse product wearing the same shape.

*Consequence.* Extraction must be good enough per site, which is why the extractor chain and (later)
recipes exist. Extraction failure is a real, visible state rather than a silently degraded capture.

*Reverse if.* Never as the primary format. A snapshot may be added as an explicit fallback the user
opts into for an unsupported site.

### D09 — Page stability is measured, never assumed from load events

**Decision.** A dedicated stability detector (MutationObserver + height sampling + image completion +
a quiet window + a second scroll pass) gates extraction. `onLoadStop` is treated as meaningless for
content readiness.

*Why.* `onLoadStop` fires before lazy images, before hydration, before infinite-scroll injection.
Trusting it produces chapters that are missing their last third — the single most likely way this app
silently fails.

*Consequence.* Capture is slower than a naive implementation, and there are constants to tune per
site class. Both are acceptable; wrong content is not.

*Reverse if.* Nothing. This is the core of the product.

### D10 — Assets are downloaded Dart-side, with an in-page fallback

**Decision.** Primary: `dio` with the WebView's cookies, UA, and a Referer, streamed to disk.
Fallback: in-page `fetch` + base64 over the bridge. Resource interception is not used.

*Why.* `shouldInterceptRequest` — the "reuse the bytes the WebView already fetched" approach — is
**Android and Windows only** in `flutter_inappwebview 6.1.5` *[Verified 2026-07-25]*. iOS offers only
`WKURLSchemeHandler`, which does not apply to `https:`. On an iOS-first build, interception cannot be
the primary path. The in-page fallback covers hotlink protection, because it inherits the page's exact
credential and Referer context.

*Consequence.* Assets are fetched twice in the worst case (once by the page, once by us), mitigated by
the WebView's HTTP cache. The fallback is memory-hungry and must be chunked.

*Reverse if.* Android becomes a primary target — interception is then a legitimate optimisation
*there*, never the only path.

### D11 — Site adapters are a seam now, recipes are data later

**Decision.** Define `ContentExtractor` and `NextPageStrategy` as priority-ordered chains from day
one, and reserve the `site_recipe` table. Do not build recipes or a recipe editor in the MVP.

*Why.* Site-specific behaviour is inevitable; a marketplace or an editor is not. Defining the
interfaces costs nothing and means "support this site" later is a data change plus one class, not a
refactor of the orchestrator. Building the editor now would be designing for a user who does not exist.

*Consequence.* One unused table and two interfaces with a single implementation each. Cheap.

*Reverse if.* If, after several sites, generic heuristics turn out to be sufficient, drop the recipe
table at a migration. More likely the reverse.

### D12 — URL-number incrementing is not a trusted next-page strategy

**Decision.** Next-page detection is a confidence-ordered chain (recipe → `rel=next` → labelled
control → chapter-list ordering → generic link heuristic). Fabricating a URL by incrementing a number,
with no matching link on the page, is **off by default** and opt-in per recipe.

*Why.* Incrementing invents URLs that may 404, may point at a different series, or may skip
back-catalogue gaps — and it produces *phantom chapters*, which corrupt the library rather than merely
failing. Every other strategy reads something the page actually asserts.

*Consequence.* Some sites will end a session early with `completed(endOfChain)`. That is the correct
failure: honest, visible, and fixable by the user.

*Reverse if.* Never as a default. Per-recipe opt-in only, always labelled low confidence.

### D13 — One shared, visible WebView

**Decision.** Manual browsing and capture use the same non-incognito `InAppWebView`. It stays visible
and attached during capture. Headless capture is deferred.

*Why.* A separate or incognito WebView would lose the login the user performed manually — which
defeats the main use case. Offscreen WKWebViews can differ in layout, rendering, and
`IntersectionObserver` behaviour, which is precisely the machinery lazy loading depends on. Visible
also gives the user something to watch and a place to intervene.

*Consequence.* The capture screen owns the WebView; the UI must prevent accidental touches reaching
the page.

*Reverse if.* Measurements show headless behaves identically on both platforms, and a background-ish
capture UX becomes worth it. That is a post-MVP experiment (Q02).

---

## Data and library

### D14 — Local-first, no backend, no account

**Decision.** Everything on the device. No accounts, no sync, no telemetry, no server of any kind.

*Why.* Nothing in the MVP needs a server, and adding one would add auth, privacy obligations, hosting,
and a sync model to a proof of concept whose actual risk is autonomous capture. Local-first also makes
the privacy story trivially honest: the only network traffic is to the sites the user is already
browsing.

*Consequence.* Losing the device loses the library. Acceptable for the MVP; it is what makes cloud
backup the most likely first post-MVP feature.

*Reverse if.* Never fully — local-first stays the base. Cloud becomes an addition (backup first, then
sync), never a dependency.

### D15 — Cloud features are postponed, and not designed now

**Decision.** No cloud storage, sync, remote workers, or desktop reader in the MVP — and no
speculative architecture for them beyond two cheap habits: client-generated UUIDs, and a relational
store that a sync layer could later sit on.

*Why.* Designing sync before the capture engine works optimises the wrong risk. Those two habits cost
nothing today and remove the worst obstacle later (server-assigned IDs).

*Consequence.* Sync design starts from scratch when it starts. That is correct.

*Reverse if.* Reading on a PC becomes the primary use case. Then design it properly, then.

### D16 — Reading and library state are durable and never implicitly discarded

**Decision.** Reading progress, library metadata, archive state, pin state, favorite state, and last
successful source information survive every operation: restart, crash, capture failure, archive,
content deletion, source outage. Only an explicit user action removes data.

*Why.* This is the difference between a downloader and a library. Users forgive a failed capture; they
do not forgive losing where they were in chapter 340.

*Consequence.* Extra care in migrations (every one ships a no-loss test) and in cleanup routines
(never keyed on lifecycle). Progress is written on a throttle, not only on close.

*Reverse if.* Nothing.

### D17 — Archive is not deletion, and deletion has two distinct sizes

**Decision.** Archive is a visibility flag, fully reversible, that writes only lifecycle columns.
Deletion is explicit and comes in two clearly separated forms: *Free up space* (files only, history
kept) and *Delete item* (everything, confirmed, visually separated).

*Why.* Archiving is how users tidy without committing. Conflating it with deletion is the failure mode
that makes a library untrustworthy, and it is unrecoverable when it happens.

*Consequence.* A hard rule with teeth: **no cleanup, sweep, or query may use `lifecycle` as a deletion
predicate.** M9's acceptance criteria test exactly this.

*Reverse if.* Nothing.

### D18 — Lifecycle, pinned, and favorite are independent

**Decision.** `lifecycle` (active/dormant/archived), `pinned` (+ order), and `favorite` are four
orthogonal attributes. Every combination is legal, including an archived favorite.

*Why.* They answer different questions — *is it in my rotation*, *should it be prominent*, *do I like
it*. Collapsing them into one status enum forces users to give up one meaning to express another, and
that is the sort of model error that is expensive to undo once data exists.

*Consequence.* Slightly more UI surface, and views must state which attributes they filter on.

*Reverse if.* Nothing.

### D19 — Chapter identity is the normalised URL; four pointers stay separate

**Decision.** `url_key` (normalised URL, unique per item) is chapter identity, with `canonical_url`
and `content_hash` as secondary signals. *Latest known*, *latest captured*, *last opened*, and *last
completed* are four separate fields.

*Why.* Duplicate chapters and navigation loops are the two most likely capture bugs, and both are
identity problems. Separately: collapsing any two pointers produces a specific known bug —
mark-on-download, opening counting as finishing, or a new-chapter badge that clears when you download
without reading.

*Consequence.* More columns, and pointer maintenance inside the transactions that cause them, plus a
`repairPointers()` routine.

*Reverse if.* Nothing. See [DATA_MODEL.md](./DATA_MODEL.md) §5 for the worked example.

### D20 — Manual, foreground update checking for the MVP

**Decision.** *Check for updates* is user-triggered while the app is open. No scheduling, no
background fetch. Results record a **check quality** (`complete` / `partial`) and never touch read
state.

*Why.* Background scheduling inherits D06's constraint and adds iOS background-task budgeting to a
milestone whose actual risk is capture reliability. Manual checking delivers the whole user value —
"do my series have new chapters" — with none of that. The quality field is there because a bounded
forward walk can only prove "at least N new", and reporting that as a definitive count would be a lie
the UI repeats.

*Consequence.* The user initiates catch-up. Acceptable, and arguably preferable for battery and
politeness.

*Reverse if.* Users check daily and find it tedious. Then evaluate `BGAppRefreshTask` for the *check*
only — never for capture.

---

## Process and sequencing

*(Added 2026-07-25.)*

### D21 — Dependency versions are resolved at implementation time, not pinned in documentation

**Decision.** These docs name *packages*, never version constraints. At M0 — and again whenever a
dependency is added — resolve the latest stable, mutually compatible versions available at that
moment; prefer stable over prerelease; never add deprecated or end-of-life compatibility packages;
commit `pubspec.lock`; and record any version-driven architectural limitation here as a new decision.

*Why.* A version number written into a design document hardens into a false architectural commitment
within weeks, and then gets copied forward by anyone reading the doc later. The *choice* of
`flutter_inappwebview` over `webview_flutter` is a real decision with a rationale that survives
version bumps (D03). "`^6.1.5`" is a fact about one afternoon. Separating the two keeps the durable
part durable and stops the perishable part from masquerading as architecture.

*Consequence.* An implementer must actually resolve versions rather than copy a list — which is the
point. The lockfile, not the doc, is the reproducibility mechanism. Package *observations* in
[TECHNICAL_SPEC.md](./TECHNICAL_SPEC.md) §2 (which APIs exist, which platforms they cover) carry a
verification date and must be re-checked, not assumed.

*Reverse if.* Nothing. If a specific version ever becomes load-bearing — a capability that exists
only there, or a regression to avoid — that gets its own decision entry naming the version *and the
reason*, which is exactly the case this policy is designed to make visible.

### D22 — Working product identity: `Web Reader` / `com.mcagricaliskan.webreader`

**Decision.**

| | |
|---|---|
| Product name | `Web Reader` |
| Working description | `Archive and read web content offline` |
| iOS bundle identifier | `com.mcagricaliskan.webreader` |
| Internal slug | `webread` — storage directory, database filename, JS bridge namespace |

This is a **development identity, not a finalised brand.** The display name and bundle identifier may
be reviewed before distribution. No generic identifier (`com.example.*`) is used at any stage.

*Why.* Naming discussions are unbounded and this is not the moment for one. A concrete identity
unblocks the project scaffold immediately. Choosing a real reverse-DNS identifier now avoids the
specific trap of a placeholder that survives into signing.

*Consequence.* Renaming the **display name** stays cheap indefinitely. Renaming the **bundle
identifier** gets progressively more inconvenient once signing, provisioning profiles, TestFlight, or
any release setup exist — so if it is going to change, change it before any of that. The **internal
slug is deliberately decoupled from the display name**: a rebrand must never require renaming a
directory that holds user data, so `webread/` and `webread.db` stay put regardless of what the app is
called.

*Reverse if.* A real brand is chosen. Do it before signing setup, and change the display name only —
leave the slug alone.

### D23 — Vertical slice first; build order is PoC → MVP → Full product

**Decision.** The first gate is one vertical slice: *open one webtoon chapter, load all relevant
images, save the actual image files locally, restart or go offline, and read the saved chapter without
contacting the source website.* Milestones are staged **Stage 0 (PoC, M0–M3) → Stage 1 (MVP, M4–M11)
→ Stage 2 (Full product)**. The database, JS bridge, scroll driver, stability detector, image
extractor, asset store, and state machine are **sub-steps of one milestone (M1a–M1g)** with a single
vertical acceptance gate, not seven separate milestones.

*Why.* The previous plan built those seven layers in sequence before anything was readable, which
deferred the only question that actually determines whether this product is possible — *can we capture
a chapter and read it offline?* — until seven milestones in. A layer-first order also lets each layer
be "done" against its own local criteria while the composition is untested, which is where integration
surprises live. The slice is small enough to reach quickly and complete enough to prove the claim.

*Consequence.* M1 is a large milestone by line count. That is mitigated by explicit sub-steps with
their own checks, not by splitting the gate. Anything not needed for the slice — library organisation,
reading progress, text extraction, update checks, login — is M4+ and stays there.

*Reverse if.* Nothing. If M1 proves too large to hold in one head, split the *gate* only if the slice
itself is still reachable within a milestone.

### D24 — Authentication is deferred to M10

**Decision.** Login, cookie persistence, and authenticated-site capture move to M10, after public-page
capture works end to end. Cookie persistence is explicitly **not** an acceptance criterion for M0 or
M1.

*Why.* Login is not the first product risk. Most initial target sites are public, so authentication
gates nothing early — while the genuinely unproven parts (lazy-image stability detection, asset
acquisition, offline readback) gate everything. Making cookie persistence the first acceptance test
would have spent the first milestone validating a plugin behaviour instead of the product's central
claim.

*Consequence.* The architecture still accommodates it from day one at zero cost: one shared,
non-incognito WebView with the persistent data store (D13). M10 is largely a verification milestone
plus the `awaitingUser` path for expired sessions. Its acceptance criteria include two hard
constraints that hold from day one: **no automatic credential collection** and **no cloud transfer of
cookies** ([TECHNICAL_SPEC.md](./TECHNICAL_SPEC.md) §16).

*Reverse if.* The chosen test fixture site turns out to require a login to reach any chapter. Then
pull the *manual login* part of M10 forward into M1 — but not the expired-session handling, which
still belongs with M3's session states.

---

### D25 — Swift Package Manager is disabled for this project

**Decision.** `pubspec.yaml` sets `flutter: config: enable-swift-package-manager: false`, pinning the
iOS build to CocoaPods.

*Why.* `flutter_inappwebview_ios` does not ship a Swift package. With SPM on, `flutter run` against a
physical device fails outright at *"Xcode failed to resolve Swift Package Manager dependencies"* — it
is a build-blocker on device, not the cosmetic warning it appears to be in Simulator builds. The
alternative was to drop the plugin, and its capabilities (D14) are the reason it was chosen.

*Consequence.* CocoaPods stays a required toolchain dependency, and `pod install` must run after
dependency changes. Flutter has stated SPM will eventually become mandatory, so this is a dated
decision, not a permanent one.

*Reverse if.* `flutter_inappwebview` adds a Swift package, or Flutter removes the opt-out. Either
forces a move to SPM — and if the plugin has not adopted it by then, that is the trigger to
re-evaluate the WebView plugin choice entirely.

---

### D26 — A stored asset's dimensions come from its own bytes

**Decision.** After a successful download, the asset's pixel dimensions are decoded from the file
header (`core/image_dimensions.dart`) and recorded in the manifest as the truth the reader lays out
with. DOM-reported values are kept only as `domWidth`/`domHeight` diagnostics. Manifests written
before this are repaired from the files when the reader opens them.

*Why.* The reader showed a real captured chapter (uzaymanga 885) with wrong panel proportions. The
investigation showed why the DOM can never be the durable source: those panels are 800×13850 to
800×16000 strips carrying **no** width/height attributes, styled `w-full h-auto` — so the probe's
report is whatever the WebView happened to have resolved at that instant (a lazy placeholder, a
partially decoded strip), while the file on disk is unambiguous. A wrong height in a fixed-height
list box shows a cropped slice of the panel, which reads as "compressed".

*Consequence.* A pure-Dart header parser (PNG, JPEG + EXIF orientation, GIF, BMP, WebP, AVIF/HEIC
`ispe`) becomes part of the capture path — covering exactly the formats `detectImageMime` accepts,
verified against the real AVIF strips. Repair-on-open adds one cheap header read per panel, once
ever per file.

*Reverse if.* Never for stored assets. If a format appears that the parser cannot read, the entry
stays unverified and the reader falls back to a crop-not-stretch box — extend the parser then.

---

### D27 — Duplicate decisions during a run are session-scoped, never global

**Decision.** When a running capture walks onto an already-captured chapter it pauses and asks
(Skip / Re-download / Stop), with "use this choice for all already captured chapters in this
capture session". The answer is persisted on the job row — surviving an interrupted-session resume —
and dies with the job. The requested chapter count means **new capture attempts**; skips do not
consume it, and a skip bound (`maxSkippedPerJob`) keeps a fully-captured stretch from becoming a
crawl.

*Why.* Silently skipping hides data the user asked for; silently re-downloading wastes their
bandwidth on the source's dime. Both are decisions, so the user makes them — once per session, not
per chapter, and not forever: the right answer for repairing a broken chapter today is the wrong
default for a routine range capture next week.

*Reverse if.* Users demonstrably answer the same way every session. Then add a settings-level
default — as a *default answer*, still shown in the prompt, never as silent behaviour.

---

### D28 — Design system: flat theme, no token layer

**Decision.** The Claude Design UI is implemented as one flat `appTheme()`
(`lib/ui/theme.dart`) plus shared status-vocabulary widgets
(`lib/ui/status_style.dart`). Colours, radii and type are written as the
design's literal values at the point of use. A `ThemeExtension`-based token
layer (`WrColors`/`WrSpace`/`WrType`, `context.wr.*`) was built first and
then removed at the user's direction ("tokens must be removed for now").

*Why.* The prototype is light-only and expresses itself in literals; a token
indirection had no second consumer (no dark theme yet, no theming setting)
and every widget would have paid the abstraction without a demonstrated use
case. The Material `ColorScheme` inside `appTheme()` already centralises the
palette for the framework's own widgets.

*Consequence.* Dark mode later means either reintroducing an extension or a
second `ColorScheme` — an additive change. Until then the design's dark
surfaces exist only where the design itself has them (the pure-black reader).

*Reverse if.* A real second theme or per-user appearance setting lands
(M17). Reintroduce tokens then, driven by that concrete need.

---

### D29 — flutter_inappwebview pinned to 6.2.0-beta.3

**Decision.** The WebView plugin is pinned to the exact prerelease
`6.2.0-beta.3` (no caret). Chosen over (a) staying on stable 6.1.5 and
downgrading AGP 9→8.x, and (b) deferring Android entirely.

*Why.* Stable 6.1.5's Android package cannot build under AGP 9 (hard error on
its legacy proguard reference); only the 6.2 betas fix it. The two unknowns
that made a beta scary were both measured: `apk --debug` builds under AGP 9,
and the complete iOS battery (334 unit/widget + all 5 Simulator integration
suites) passed on the pin. The beta also ships SPM support — the SPM-off
workaround (D25) stays until a physical-device pass verifies it.

*Consequence.* Prerelease code sits under every capture until 6.2 stables.
Version switches leave stale Xcode module state ("different definitions in
different modules") — fix is `flutter clean` + removing `ios/Pods`.

*Reverse if.* Any WebView regression appears on iOS: fall back to stable
6.1.5 + AGP 8.13 (tested path). Retire the pin for `^6.2.0` on stable
release.

---

### D30 — Original image bytes are stored; no conversion, ever (for stored assets)

**Decision.** Captured images stay byte-for-byte in their source format. No
WebP/AVIF/JPEG/PNG conversion, no quality profiles, no post-capture
optimizer.

*Why (measured, 2026-07-27 audit).* Real sources already use the strongest
codecs: uzaymanga ships AVIF (800×16000 strip = 344 KB); re-encoding that
strip measured 4.4× larger as JPEG-q80 and 16× as PNG. WebP has a hard
16383-px dimension limit that real strips brush against. On-device encoding
would cost seconds-to-minutes of CPU and a ~49 MB decoded bitmap per tall
panel, to make files bigger.

*Reverse if.* A source class emerges whose assets are oversized legacy JPEGs
(Asura serves some 2.6 MB JPEG panels) AND storage pressure is a real user
complaint — then an opt-in, post-capture, JPEG-only recompression is the
only variant worth building.

---

### D31 — Stored file extensions come from sniffed MIME, not the URL

**Decision.** `AssetDownloader` names files from the verified magic bytes
(`001.jpg` for JPEG bytes) and falls back to the URL extension only for
unrecognised types. Existing mismatched files are not renamed — the manifest
is the source of truth and the reader decodes by content; re-capture
normalises names naturally.

*Why.* Live-verified: Asura's CDN serves `image/jpeg` (2.6 MB) under `.webp`
URLs. The stored extension is what any future export/share touches.

---

### D32 — WebView automation pauses on an unrendered surface

**Decision.** Capture and update checks never scroll, measure, or extract
when the WebView reports a zero viewport. The engine holds in a distinct
`waitingForBrowser` state ("Open the Browser to continue capture."), the
Library strip shows the banner with an Open Browser action, wait time does
not consume the chapter deadline, and a defensive extraction guard refuses
to store when the final candidate set collapses far below what scrolling saw.

*Why (live-verified).* A **never-rendered** WKWebView answers probes with
real DOM data but zero viewport and a frozen scroll position — reproduced on
Asura ch137, where it produced an extraction of 8 comment avatars that would
have been stored as a *complete* chapter. Pausing beats failing: the page
and the partial run are both still valid.

*Scope (also live-verified).* A once-painted WebView that is merely hidden
mid-run keeps live metrics on the Simulator and the capture correctly
continues — the guard is evidence-based (it fires on broken measurements,
not on tab state), so hiding the browser does not needlessly pause a healthy
run. Whether a physical device throttles a hidden-but-painted WKWebView is a
device-checklist item; if it does, the same signals catch it.

---

### D33 — Capture scrolling is adaptive (fast over resolved, careful near lazy)

**Decision.** Two paces: careful (0.8 vp / 300 ms — the old behavior) near
pending images, height changes, or the bottom; fast (3.5 vp / 70 ms) after
two consecutive fully-resolved lookaheads. The eligibility lookahead covers
the whole jump plus a margin, so a leap can never clear unloaded ground.
Stopping conditions, second pass, and bounds are unchanged. Irrelevant
pending images (avatar-sized, outside content) no longer hold the asset wait.

*Why (measured).* Scrolling was 90–98 % of real capture time — 47 s of a 48 s
uzaymanga capture; ~88 s on Asura whose panels were fully loaded before the
first step.

*Reverse if.* A site's lazy loader defeats the resolved-lookahead signal
(images report complete before bytes exist). The second pass plus the
partial-status pipeline bound the damage; drop `fastScrollStepViewports` to
re-tune, not the mechanism.

---

### D34 — Disk policy via a hand-rolled two-method platform channel

**Decision.** `webread/device_storage` (iOS Swift / Android Kotlin) exposes
`freeBytes` and `excludeFromBackup`. No plugin dependency for two calls.
Policy (centralised in `CaptureConfig`): 500 MB floor to start · 200 MB
emergency reserve · 50 MB unknown-chapter estimate (median of the series'
own chapters when known) · rolling check before each chapter · both-copies
check before atomic replacement · distinct `insufficientStorage` error class.
`webread/` (assets) is excluded from iCloud backup at startup; the database,
settings and rules stay backed up. Android backup exclusion is a documented
no-op (auto-backup's 25 MB cap makes it moot; revisit at release).

*Why.* The audit found no safeguard at any layer, and the maintained-plugin
options for "one statfs call" are heavier than the channel itself.

---

### D35 — Removing offline files is not deleting a chapter

**Decision.** "Remove offline files" deletes bytes under `library/…` and
nothing else. The chapter row keeps its series, source URL, ordering,
reading progress, read/completed marks, timestamps, discovery metadata and
any user-edited series title; a new `chapters.offlineRemovedAt` records that
the *user* chose this. The chapter then reads as **"Not available offline —
capture again"**, never as an error. Permanent metadata deletion is a
separate concept and is not part of this feature.

*Why.* Space pressure and losing your library are different problems. A
reader who frees 8 GB should keep every read mark and every place they were.

*Implementation guard.* `CleanupService._writeRemoved` names only the three
columns that change, so no future edit can widen it by accident.

*Trap found while building.* drift's `insertOnConflictUpdate` treats a null
field on a data class as *absent*, so nullable columns survive an upsert.
Both `offlineRemovedAt` and `captureJobs.pauseReason` therefore need explicit
clearing writers (`clearOfflineRemovedMark`, `clearJobPauseReason`) —
otherwise a re-captured chapter would still look user-removed, and a resumed
job would look forever "paused — Browser required".

---

### D36 — Leaving the Browser mid-capture pauses; it never cancels

**Decision.** When a capture is in a phase that genuinely needs a rendered
WebView (inspecting · scrolling · waiting for page assets · verifying ·
extracting · detecting next · navigating), leaving the Browser — bottom nav,
system back, or any route push — asks first: **Stay in Browser** /
**Leave and pause**. Pausing holds the phase, persists
`pauseReason = browserHidden` on the job row, and leaves the queue task
active. Returning resumes automatically once the engine's existing render
guard (D32) confirms the surface and the page.

**No modal** when: nothing WebView-dependent is running · only downloading or
committing remains (bytes over HTTP touch no layout) · the run is already
paused · the capture engine is navigating on its own.

*Why.* The audit proved an unrendered WebView produces garbage measurements
(avatars stored as chapter panels). Blocking the user from their own library
is the wrong fix; pausing costs nothing and loses nothing.

---

### D37 — The finished-chapter cleanup decision belongs to the series

**Decision.** Cleanup is configured **per series and nowhere else**. Each
library item carries `finished_cleanup` (schema v12): `remove` · `keep`, or
**null** meaning the series has not been asked. There is no app-wide default,
no per-chapter memory and no settings key — the series row is the single
source of truth, and null is a question rather than a value.

**Asked once, per series.** On a series' first *eligible* forward transition,
the reader shows the decision dialog: **Downloaded chapters in this series**,
two radio options — *Remove after continuing* / *Keep downloaded files* — and
an explicit **Save choice**. **Remove after continuing is preselected,
always**: it is a constant of the widget, reachable from no setting, no other
series and no previous answer. Saving stores the choice on that series and
applies it to the transition in hand; the series is never asked again unless
the decision is reset. Dismissing without saving stores nothing, removes
nothing, and leaves the question for next time.

Eligibility is unchanged: only a *completed* chapter, only *forward* movement
to a different, openable chapter whose files exist and are not in use. Closing
the reader, moving backward, re-opening, partial reads and file-less chapters
never trigger it.

**Changed and reset from the series.** Series detail › *Series actions* ›
**Downloaded chapters** offers the two outcomes plus **Ask again next time**,
which writes null and brings the question back on the next eligible
transition — where *Remove after continuing* is preselected again. It is
deliberately not called "use the global setting": there is no global setting.

*The decision follows the chapter being left.* The series id is read from that
chapter and captured before any await, so a dialog that resolves after the
reader has moved on — even to another series — still writes to the series it
asked about. One question is open at a time (`_cleanupAskSeriesId`), so a burst
of forward taps cannot stack dialogs or race two writes.

*Safeguards on removal are unchanged.* Cleanup runs only after the next
chapter is loading and the reader's lock has moved, so the chapter now on
screen can never be the one removed; the open chapter and anything mid-capture
are locked; a failure is logged and never blocks reading; a soft delete
(rename into `tmp/undo-*`) backs the Undo in the reader notice (D61), and the
startup staging sweep collects anything a crash leaves behind. Only downloaded
files go — the chapter row, its source URL, read marks, progress and the
library item all survive (D35).

*Changing a decision never removes anything retroactively*, and it reaches no
other series. Bulk removal of already-downloaded chapters is a separate,
explicit action in Storage.

*Supersedes the previous global model.* Until v12 this was one app-wide
setting (`storage.afterFinished`: *Ask each time* · *Keep offline* · *Remove
automatically*) with a "Don't ask again" checkbox that turned a single answer
into the default for every series. It was wrong in the way that matters: the
checkbox copy described a *chapter* while writing a *global*, and one tap
while reading one series enabled silent deletion across the whole library. The
migration adds the column, leaves every existing series **null** — no
backfill, because the old answer was never given per series — and deletes the
obsolete row. Existing installs are simply asked once per series, on their
next eligible transition.

---

### D38 — The library stream watches every table it reads

**Decision.** `allSeriesGroupsProvider` merges the `library_items` **and**
`chapters` change streams, rather than watching one and reading the other.

*Why (found by a test, 2026-07-27).* Drift invalidates query streams per
table. The provider read both tables but subscribed only to `library_items`,
so a chapters-only write produced no emission — the shelf counts and the
Storage screen stayed stale until something unrelated happened to touch a
series row. It went unnoticed because the operations exercised until now
(capture, mark-read) happen to write a series row as a side effect;
offline-file removal does not.

*Rule this generalises to.* If a derived stream reads from table A and table
B, it must subscribe to A and B. A comment claiming "recomputed whenever
either changes" is not a subscription — this provider had exactly that
comment while watching one table.

### D39 — A completed chapter is 100% read

**Decision.** `progress_fraction` is pinned to 1 whenever `read_status` is
`completed`. The rule is applied on write (dwell completion, *Mark as read*,
and every subsequent progress save), and again on display via
`readProgressFor()`. The *anchor* (`progress_image_index` +
`progress_offset_in_image`) keeps following the scroll, so resuming a
finished chapter still lands where the reader actually is.

*Why.* Progress and completion were two independent facts written by the same
call. Re-opening a finished chapter and scrolling back — which is what
re-reading looks like — wrote a lower fraction while leaving the status
`completed`. The chapter then reported itself 40% read on the Continue card
and in the series list, which is the sort of number a user cannot argue with
and cannot fix.

*Corollaries.*

- *Mark as unread* resets the fraction to 0 (and only then), because
  completion had forced it to 1 and an unread chapter must not show a full
  bar. The anchor is kept — "unfinished", not "never visited".
- An explicit mark cancels the reader's pending throttled write first, so a
  save queued a moment earlier cannot land afterwards and undo the choice.
- `ReadingRepository.repairCompletedProgress()` runs at boot and brings rows
  written before this rule into line. Idempotent.

*Rule this generalises to.* When two stored fields encode one user-visible
fact, one of them is the truth and the other must be derived from it at every
write *and* every read. Storing both independently means eventually
displaying the disagreement.

### D40 — Chapter-list ordering is measured, never assumed

**Decision.** Every chapter link on a series page gets a **position** on the
number line: its own parsed number, or — for an unnumbered one — a value
interpolated from its numbered neighbours in list order. One comparison then
decides both novelty (`position > checkpoint`) and emission order (**oldest
first**), whichever way the page runs. Direction is measured separately from
DOM order and used only to gate early stopping: an empty result ends the check
only when the ordering was unambiguous, otherwise the chain walk still gets
its turn.

*Why.* Most sites list newest first. The previous implementation sorted by
parsed number and filtered on "above the highest number held", which happened
to work for plain numbered lists and quietly failed everywhere else: a chapter
whose label carries no number was discarded outright, and a list we could not
order still produced a confident "up to date".

*Corollaries.*

- Comparison is on parsed numbers, never text: `385 < 385.5 < 386`.
- Unnumbered chapters (`Extra`, `Side Story`) are interpolated between their
  numbered neighbours, so a side story between 386 and 385 lands at 385.5.
  A link with no numbered neighbour has no position and is never claimed as
  new. Two guards keep page furniture out: the link must sit inside the
  numbered run and at the same URL depth as the numbered chapters.
- **Direction detection is tolerant, and the live probe is why.** The first
  version required strict monotonicity. Both sites this project verifies
  against put *First Chapter* / *Latest Chapter* jump links above their list,
  so every real page came back `unknown` — correct results, but a chain walk
  on every up-to-date check. It now takes a majority of ≥ 80 % of ordered
  pairs over ≥ 3 numbered links. Interpolating positions rather than sorting
  by list index is what makes those same jump links harmless to ordering.
- `seriesFingerprint` cannot recognise a chapter whose slug is just a word
  (`/manga/foo/extra` fingerprints as its own series), so discovery also
  admits a link sitting exactly one path segment below the series. That
  relaxation is local to discovery; the shared fingerprint is unchanged.
- The checkpoint is the highest number held **plus** the set of known URL
  keys, which is what makes "my library starts at chapter 100 of 400" an
  ordinary check rather than a special case.
- Chapters cut by `maxNewChapters` are logged, never silently dropped.

### D41 — The Library shows device fullness, from one throttled call

**Decision.** The Library header carries a disk glyph and one number: the
percentage of **device** storage in use, `(total - free) / total`, read from a
single `capacity` platform call behind `deviceCapacityProvider`. When the
platform cannot report both halves, the glyph stands alone — no percentage is
invented. Detailed figures stay on Settings → Storage.

*Why (the slow indicator).* The previous pill watched `storageDeviceProvider`,
which bundled the free-space channel call with `stagingByteSize()` — a
**recursive walk of the staging tree**. Drawing the Library header therefore
waited on a directory listing that only the Storage screen needs, and the pill
stayed blank until it finished. Two providers now: `deviceCapacityProvider`
(one channel call, throttled) for the header, `stagingBytesProvider` (the walk)
for the Storage screen alone.

*Why a percentage rather than free bytes.* `formatBytes` produces
variable-width text — "1.2 GB free" then "834 MB free" — so the pill changed
width whenever it refreshed and nudged the Archive and Settings buttons. The
percentage is at most four characters, and the box is a fixed 52 pt with the
number scaled down rather than clipped, so nothing beside it can move.

*Corollaries.*

- The **library's** share of the disk is a different fact and is never shown
  as though it were device usage.
- The low-space warning still keys off *free bytes*, not the percentage: 8%
  left of a small disk is urgent in a way "92% used" is not on a large one. It
  is a colour change only — no text is added to the header.
- Refreshes are throttled to `kCapacityRefreshInterval` (2 min) so a
  twenty-chapter capture does not fire twenty channel calls, and forced at the
  two moments the disk actually changed: automation falling idle, and a
  cleanup removing files (`CleanupService.removals`).

### D42 — A chapter keeps its source URL, and a chapter without files offers it

**Decision.** `chapters.source_url` is the durable record of where a chapter
came from. No second URL field was added: the column already exists, is
`NOT NULL`, and is written by both capture and remote discovery.

*Why it already survives.* Every writer that touches a chapter names its
columns explicitly — `CleanupService._writeRemoved` sets `content_path`,
`byte_size` and `offline_removed_at` and nothing else, and the reading writers
are equally narrow. Removal, archive, restore, re-download and reading updates
therefore preserve the URL, the label and number, the series relationship, the
reading progress and read state, and the discovery and update-check metadata
**by construction** rather than by remembering to.

*What was missing.* Rows written blank by an older build (or reconciled from a
manifest without one). `SeriesRepository.repairChapterSourceUrls()` restores
those from `url_key` — the normalised form of the same address, stored beside
it — at boot, idempotently. A row with neither is left blank: the UI disables
"Open on website" and says the original page is unknown rather than guessing.

*Behaviour.* Tapping a chapter with no offline files no longer does nothing
and does not open the reader onto an unavailable screen; it offers **Open on
website · Capture again · Cancel**. Opening the website uses the stored URL and
only that — never the series page, never a sibling chapter — checks the network
first so the WebView's own error page is not how the user learns they are
offline, and refuses while a capture owns the browser. Tapping a chapter that
*is* offline still opens the reader; the source page moves to a long-press
sheet so it never competes with reading.

### D43 — The episode list shows a painted progress value, newest first

**Decision.** Three changes to the episode list, all in service of the same
thing — the list should answer "where am I in this series?" at a glance.

1. **The progress pie is painted from the real fraction.** `ChapterProgressRing`
   is a `CustomPainter`: a track circle plus one wedge from twelve o'clock, and
   a solid disc at 100%. Not a set of range icons — the design's pie is a
   continuous quantity, and bucketing it would draw 51% and 74% identically.
   It is the *only* read-state indicator now, so an unread chapter cannot
   render as finished by picking the wrong icon. `shouldRepaint` compares the
   value, so an unchanged row costs nothing on a list rebuild, and the
   semantics label spells the percentage out.
2. **Newest first by default**, with a two-state toggle beside the section
   label and the choice persisted in `settings` (`series.chapterSort`). A
   reader who is up to date cares about the end of the list; a 400-chapter
   series should not open at chapter 1. Descending is the *same* ordering
   reversed, never a second comparison, so a non-numeric `Extra` keeps the same
   neighbours either way.
3. **Chapter numbers are the display label.** `chapterDisplayLabel` prints
   `Chapter 487` / `Chapter 487.5`; the raw source marker (`487. Bölüm`) stays
   on the row and is shown in the details sheet. The product noun is
   `kChapterNoun` — one word, one place.

*Why the raw label survives.* It is what the site called the chapter, it is the
only material a future chapter-*name* field can be built from, and it is the
honest fallback when no number can be parsed. `Prologue`, `Extra` and
`Side Story` print as themselves; a number is never invented for them, because
an invented number would corrupt the ordering and the update check together.

### D44 — Long press explains, tap reads

**Decision.** A tap on an offline chapter opens the reader, unchanged. A long
press opens a details bottom sheet: number, raw source label, progress, read
state, offline availability, capture status and image count, stored size,
capture and last-read dates, source host and URL — plus the actions that make
sense for *that* chapter's state.

*Why a sheet.* It is the phone-native surface for "tell me about this and let
me act on it", it is dismissible by drag, and it does not fight the list
underneath. Long press also gets a `selectionClick` haptic, matching how
selection mode is entered elsewhere.

*What it costs to open.* Nothing measured. Every fact comes from the chapter
row the list already holds — including `byteSize`, which capture records at
commit time. A details sheet must not stat a directory tree to show a size.

*Actions, and their words.* **Remove offline files** when the metadata stays;
**Delete episode** would mean the record goes, so it is *not offered* —
permanent metadata deletion does not exist in this product (D35) and adding it
from a details sheet would be the worst possible place to introduce it.
**Re-fetch** is the ordinary queued capture with `DuplicatePolicy.replaceAll`,
which is the flow that already guarantees the same row, an atomic file swap and
reading state carried over verbatim; a bespoke re-fetch path would be a second
set of bugs.

### D45 — No "First chapter" action on Series Detail

**Decision.** Removed. The list is right there and now opens newest-first with
a sort toggle, so a dedicated jump-to-the-start button is a second way to do
something the list already does — and it sat next to Continue Reading, where it
competed with the one action that actually knows where the user is.

Continue Reading is unaffected: it already falls back from "the unfinished
chapter" to "the earliest unfinished one" to "nothing to read yet", and a
series with one chapter, no history, or nothing offline is unchanged.

### D46 — Queueing a capture does not start it

**Decision.** Adding a capture request creates a `queued` row and stops there.
Nothing navigates, nothing scrolls, no WebView is touched. The work waits
until the user presses **Start Capture**, which is the only place Browser
automation is authorised from.

*Why.* Every capture entry point — the Browser button, Series Detail, the
episode details sheet, re-fetch, New Chapters, a multi-select batch — used to
be a trapdoor into a minutes-long Browser takeover. Preparing a list of things
to fetch and then fetching them is the actual shape of the task; the old flow
made every single addition an irreversible commitment to stop what you were
doing.

*Scope.* Capture only. Update checks and cleanup still drain on their own:
they are bounded, cheap, and already one-action-one-intent, so a second
confirmation would be ceremony. `taskWaitsForExplicitStart` is the single
predicate that decides, and the pump consults it rather than special-casing
task types.

*Corollaries.*

- **The authorisation is not persisted.** Queued rows survive a relaunch; the
  permission to drive the Browser does not. A restart that resumed scrolling
  because a row existed yesterday is exactly what Q24 forbids.
- A queued capture is **skipped, not a roadblock** — a check queued behind one
  still runs.
- A drained capture queue revokes its own authorisation. Adding more later is
  a new decision and needs a new Start.
- **Stop ≠ cancel.** Stopping a batch returns the remainder to `queued`; the
  user stopped the run, not the plan.

### D47 — The Browser comes forward before automation, never as a side effect

**Decision.** Before the queue runs any Browser-dependent task it calls
`ensureBrowserVisible`, injected by the shell, which switches to the Browser
tab and waits for the WebView to attach. If it cannot, the task **stays
queued** — that is not a failure and not a cancellation.

*Why.* "Navigate, then automate" is the only ordering in which the user can
see what the app is doing to their session. The reverse — automation starting
and the UI catching up — is how a capture ends up scrolling a page while the
user is reading something else in the Library.

*What this does not replace.* The capture engine's own zero-viewport guard
(D32) is still the safety net that refuses to measure an unrendered surface.
This is the *navigation*; that is the *proof*.

*The leave-Browser distinction is unchanged and now load-bearing.*
`needsRenderedBrowser` is true only for inspecting/scrolling/waiting/
verifying/extracting/detecting/navigating. Once a chapter's panel URLs and
next-page metadata are extracted, the task is downloading over HTTP: the user
may leave, downloads continue, and the leave-Browser confirmation must not
appear.

### D48 — Removed episodes are batch-queued for re-download, oldest first

**Decision.** Selection mode in Series Detail selects **any unlocked chapter**,
not only offline ones, and the selection bar offers whichever action the
selection supports: *Remove offline files* for chapters that have files,
*Add to capture queue* for chapters that do not. Quick-selects cover
`All offline`, `Finished`, `Not downloaded` and `Finished · files removed`.

*Ordering.* `enqueueChapters` re-sorts into reading order regardless of the
display sort. The list usually shows 490, 489, 488; the queue gets 488, 489,
490. Capture walks *forward* through a series, so queueing it backwards fights
the engine's own chain-following. Decimal-safe, because the comparison is the
same one the reader uses.

*Partial success is a real outcome.* A chapter with no usable `source_url`
cannot be captured automatically. It is **reported, not dropped and not fatal**
— "8 selected · 6 can be queued · 2 have no source page" — because failing the
whole selection over two orphan rows helps nobody.

*Identity.* Each chapter becomes its own single-chapter task against its own
stored URL with `replaceAll`. The queue carries a URL, never a copy of the
chapter, so there is nothing for it to duplicate: the existing row is reused,
reading progress and read state survive, and the atomic replacement keeps the
old copy until the new one lands.

*Duplicates.* `pendingCaptureFor` matches on normalised start URL across
queued and running capture rows only. History is deliberately excluded — a
chapter captured last week must never veto an intentional re-fetch today.

### D49 — The development reset empties the database rather than deleting it

**Decision.** `LocalResetService` stops active work, empties every table
(foreign keys suspended, discovered from `db.allTables` so a new table cannot
be missed), deletes the whole asset tree, and clears cookies. It does **not**
delete the database file.

*Why.* Deleting the file means disposing the live `AppDatabase` — which every
provider, stream and service in the running app holds. Tearing that graph down
mid-session and rebuilding it is precisely the kind of half-initialised state
that produces bugs indistinguishable from product bugs. Emptying the tables
gives the same observable result — empty library, empty queue, default
settings, reclaimed disk after `VACUUM` — with live streams that simply emit
empty, so the UI walks itself back to the first-launch screen with no restart.

*Order.* Machines, then rows, then bytes. Files last on purpose: a crash
between rows and files leaves orphaned files that startup recovery already
sweeps, whereas orphaned rows pointing at deleted files would surface as
broken chapters.

*Honesty.* The result is a per-area `ResetReport`, not a bool. A wipe where
the cookie store threw reports `INCOMPLETE`, names the area, and offers a
retry — a "start clean" button that claims success while leaving state behind
is worse than one that fails loudly.

### D50 — Destructive development tools are `kDebugMode` only

**Decision.** `developerToolsAvailable` is `kDebugMode` and nothing else. Not
a setting, not a hidden gesture, not a build-flavour string that could be
typo'd into production — the constant the compiler strips in release.

*Enforced in three places, deliberately redundant:* the Settings entry is
inside an `if`, the `/developer` route is not registered at all in release, and
the screen itself refuses to render. A hand-typed deep link in a release build
finds no route.

*The action itself is two-step:* a plain-language warning, then a dialog whose
destructive button stays disabled until the word `RESET` has been typed. A
hold-to-confirm button was the alternative; typing leaves a record of intent
that a stray long-press cannot produce.

### D51 — Storage warnings are driven by the percentage, from one palette

**Decision.** How full the device is decides the colour, everywhere storage
appears:

| Used | Level | Colour | Word |
|---|---|---|---|
| < 75% | normal | quiet ink (`#7A756C`) | Healthy |
| 75–89% | warning | amber (`#8A5A1F`) | Filling up |
| ≥ 90% | critical | red (`#8E3B31`) | Almost full |
| unknown | unknown | quiet, **no number, no bar** | Unavailable |

`DeviceCapacity.level` computes it; `storageLook()` maps it to the palette.
The Library pill and the Storage screen read the same two functions, so they
cannot disagree about how worried to look.

*Why the percentage and not free bytes.* Free space alone is unreadable —
"12 GB free" means nothing without the size of the disk it is free on, and the
previous thresholds (1 GB amber, 500 MB red) fired far too late on a large
device and never at all on a small one that was merely 85% full.

*Why an absolute floor survives anyway.* Under 1 GB free nothing large will
finish, whatever share of the disk that is. It escalates straight to critical.
In practice it only matters on very large disks, where a high percentage would
still leave what looks like comfortable headroom.

*Corollary — one warning surface per screen.* The Storage screen's metric
tiles are now never coloured. The device meter carries the state; a second
tile shading itself amber on a differently-derived threshold is how two
numbers on the same screen end up contradicting each other. `_Metric` lost its
`warn` parameter entirely so it cannot come back.

*Chosen thresholds, and why these.* 75% is early enough that a user who wants
a long series still has room to act, and late enough not to shout at a
normally-loaded phone. 90% is where a single large chapter becomes a realistic
risk of failing part-way — which is the specific outcome the colour warns
about.

### D52 — Browser Home is a layer over the WebView, never a replacement

**Decision.** The Browser has exactly one `InAppWebView`, constructed in one
place, and it stays mounted for the life of the session. Browser Home and the
expanded URL editor are drawn **over** it in the same `Stack`; opening either
changes which surface is on top and nothing else.

The consequence is the whole point: closing Home reveals the same document —
same scroll position, same back/forward list, same cookies, same in-page
state, same paused capture — because nothing was ever torn down. There is no
save/restore path to get wrong, because there is nothing to restore.

*Why not a route.* A pushed route would keep the WebView alive underneath too,
but it would also give Home its own entry in the app's navigation stack, and
system back would then have three plausible meanings. Presentation state is
explicit instead ([`BrowserSurface`](../lib/browser/browser_presentation.dart)):
`website`, `home`, `editingAddress`, with one rule for Back — close the local
surface, else go back in the page, else leave the Browser.

*Corollary — a local surface is still "leaving the Browser".* Covering the
rendered page hides it, and a WebView-dependent capture phase cannot run
against a hidden surface (D32). So opening Home goes through exactly the same
`LeaveBrowserGuard` as a tab switch or a route push, and pauses the same way
(D36). Downloading and saving phases are excluded, as always — the
confirmation must not cry wolf.

*Corollary — nothing creates a second WebView.* Saved sites, history rows and
the URL editor's Go all call `load` on the existing controller. A second
WebView would mean a second cookie jar and a capture running in a session the
user never browsed with.

### D53 — Only manual navigation enters browsing history

**Decision.** `browsing_history` records pages **the user visited**. Capture
automation, update checks, rule validation, internal navigation and live tests
all move the same WebView, and none of them are ever written.

The user can watch the address bar change during a capture, which is exactly
why "it appeared in the address bar" cannot be the rule. A twelve-chapter run
would otherwise bury a day of real browsing.

*How it is enforced — twice.* The controller carries a `navigationSource`, set
beside `automationOwner` by whoever takes the WebView. `HistoryRepository`
records only `manual`. Independently, `effectiveNavigationSource` refuses to
answer `manual` while `automationOwner` is non-null: a forgotten assignment
degrades to `internal`, which is excluded, rather than to the one value that
would pollute the log.

*What else never enters.* Non-`http(s)` URLs (`about:blank`, app schemes,
`data:`, `file:`), loads that did not complete, and loads that ended on a
classified fault. Only a completed, user-visible destination is a place the
user went.

*Repeated visits.* Individual rows, not a collapsed counter — that is what
keeps "clear the last hour" accurate. A repeat of the same normalised URL
within 30 minutes refreshes the existing row's timestamp instead of stacking,
so a reload loop is one entry without losing time-range precision.

*Retention.* 90 days **or** 5,000 rows, whichever bites first. Both bounds,
because either alone leaves a way to grow without limit — a quiet year, or a
very busy afternoon. Internal for now; no user-facing setting was designed,
and clearing history remains the user-controlled cleanup action.

### D54 — Google is the initial saved site, and removing it is permanent

**Decision.** A clean install seeds one saved site, Google, so Browser Home is
not an empty grid on first run. It is an ordinary row with an `isDefault`
flag: it can be opened, renamed, re-pointed, reordered and removed exactly
like any other.

Once removed it stays removed. The seed is gated on a settings flag rather
than on the table being empty — inferring "clean install" from an empty table
would make the row impossible to delete, because the state after removing it
is indistinguishable from the state before seeding it.

*Existing development databases* get the row only when no equivalent entry
already exists, so a database that saved Google by hand does not end up with
two.

*The one exception* is the full development reset (D50), which is the app
becoming a clean install again — and a clean install has it.

*Saved sites are not history rows.* Separate table, separate lifecycle:
history is a log the user clears by time range, saved sites are a curated list
they order by hand. Storing one as a flavour of the other would let "clear the
last hour" delete a bookmark. Identity is the normalised URL, so two pages on
one host are two saved sites, and the same page saved twice is one.

### D55 — Favicons are decoration, with a fixed-size fallback

**Decision.** No list, row, save or history write ever waits on an icon.
Every icon sits in a box of a fixed size, so one arriving late repaints a
square rather than reflowing a list.

A miss is not a failure state: the hostname initial on a tinted tile is the
designed fallback, and the tile colour is a stable hash of the host, so a site
looks the same wherever it appears.

*Sources, in confidence order:* the page's declared `<link rel="icon">`, read
once per completed load; then `/favicon.ico`, which is a guess and treated as
one. Bytes are sniffed (D31's principle again — trust the bytes, not the
Content-Type), capped at 24 KB, and cached per host in SQLite.

*Failures are cached too.* A site with no icon would otherwise be re-requested
on every rebuild of every list. A negative entry stands for seven days.

*Tests are network-free.* `allowNetwork: false` makes a miss render the
fallback immediately — which is a state the UI must handle correctly anyway —
and keeps an in-flight request from outliving the widget tree.

### D56 — A derived dark appearance, and the one token layer

**Decision.** The app ships light and dark, selected by a persisted
System / Light / Dark preference. The reader stays pure black in every
appearance: it is built for night reading, and a "light reader" nobody asked
for would be a regression.

This is a deliberate, narrow amendment to D28 ("flat theme, no token layer").
That decision was right while there was one appearance — a literal
`Color(0xFFF5F3EF)` said exactly what the design said. A second appearance
makes a literal a lie, because the same value cannot be "the quiet surface" in
both. `AppPalette` names the *roles* the design already uses and nothing more:
no scale, no elevation system, no component tokens. `ColorScheme` is built
from it rather than written out twice, so the two cannot drift.

*The dark values are derived, not designed.* The Claude Design artifact ships
light only (it labels itself "375pt · light theme"). The dark palette keeps
the warm neutral — brown-greys, not blue-greys — and lifts the accents to
clear 4.5:1 on the dark surfaces. It is marked as derived wherever it appears
so a future design pass knows it is replacing an inference, not a decision.

### D57 — A cold start opens Browser Home, and never re-visits the last page

**Decision.** With no page loaded the Browser's WebView holds `about:blank`
and Browser Home is the visible surface.

The alternatives are both worse. A search engine makes the app's first act a
network request to a third party. Silently re-loading the last page would look
like a fresh manual visit — a history row nobody created — and re-loading it
*without* recording would mean a load whose source has to be un-set again
afterwards, which is exactly the kind of state that leaks.

The last page is one tap away under Recently visited, where tapping it is a
real visit because the user really did visit it.

### D58 — Browser Capture offers Add to Queue **and** Start Capture, in one sheet

**Decision.** The capture range sheet ends in two actions, side by side:
**Add to Queue** (secondary) and **Start Capture** (primary). There is no
second drawer asking which one — the range and what to do with it are one
decision, and splitting them across two modals is how a two-tap action became
a four-tap one.

*What each does.*

| | Add to Queue | Start Capture |
|---|---|---|
| Creates | a `queued` `queue_tasks` row | a `capture_jobs` row, and **no** pending queue row |
| Browser | untouched; the user stays on the page | used immediately, after the same `ensureBrowserVisible` check queued work gets (D47) |
| Starts | nothing (D46) | this request, now |
| Ends in Activity | as a queued task released by Start | as a **terminal** `direct`-origin row: history, never a plan |

*Why a direct start does not become a queue row.* D46 is about **batching**:
preparing a list and then running it. A capture the user is watching happen on
the page in front of them is not a batch — putting it in the queue and
immediately releasing it would mean the queue's authorisation flag
(`_captureStartAuthorised`) is set, which releases *every other pending
capture behind it*. That is the isolation this decision exists to protect:

> Chapters 200–202 are queued. The user is reading chapter 350 and presses
> Start Capture. Chapter 350 runs. 200–202 are still waiting when it finishes,
> in the same order, and they start when — and only when — the user presses
> **Start queued captures**.

*Corollaries.*

- **The direct claim is its own flag.** `_directCaptureClaimed` is taken before
  the first await, so two taps cannot both start, and the pump cannot slip a
  queued check into the gap before `automationOwner` is set. It is cleared when
  the run ends, and the pump is then invited to drain the work that drains on
  its own — checks and cleanup, never pending captures.
- **Ownership is asked before the sheet offers.** `browserOwner` names whatever
  holds the WebView; when it is non-null the sheet replaces Start Capture with
  **View active task** and keeps Add to Queue, because queueing starts nothing
  and so cannot conflict with anything. One capture controller means one run:
  a genuinely parallel second capture is not something the current
  architecture can do safely, and pretending otherwise would race two jobs over
  the same files.
- **The launch survives the duplicate preflight.** The intent is carried into
  `_launch`, so "Start Capture" → "this chapter is already saved" →
  "Re-download" still starts here and now, and the same path chosen from Add to
  Queue still waits. The question is never asked twice.
- **Recovery keeps its launch.** `capture_jobs.origin` persists `direct` /
  `queue`, so an interrupted direct capture is offered as Resume/Discard and
  resumes *directly* — it is never silently converted into a pending queue
  task. A row from before v11 has no origin and reads as `queue`, which is what
  it was.
- **Retrying a direct history row queues it.** A record of something that ran
  must not become a plan that runs itself; the retry copy carries
  `origin = queue` and waits like everything else.

### D59 — The Browser's capture state is page state

**Decision.** Everything the Browser shows about capturing is scoped to the
page on screen: its **page session** (a counter on `BrowserController`, bumped
on a main-frame page change) and its canonical identity (`pageIdentityKey` —
the normalised URL without the fragment). A finished run is a **result**
belonging to the page it finished on, not a state.

*The bug this replaces.* `CaptureJobController.progress` is an app-lifetime
snapshot that is never reset, and the Browser rendered it directly. So a
capture that completed left `COMPLETE` on screen — on that page, on the next
page, on every page for the rest of the session — and the capture control
looked stuck. Hiding the widget would have left the same wrong model
underneath: *job state was being read as page state*.

*What is derived, and from what.* `resolveBrowserCaptureState` takes the page
key and session, the genuinely active run (and **which page** it is on), what
this page already holds locally, and whether a *waiting* queue row covers it.
Its output is one of: `capture` · `availableOffline` · `queued` · `capturing` ·
`downloading` · `waitingForBrowser` · `needsInput` · `busyElsewhere`.

*Rules that fall out of it.*

- A completed, failed or cancelled run **never** carries to another page: the
  result matches only while its own page session is on screen.
- A historical job never disables Capture. "Already available offline" is page
  metadata — it changes the label to *Capture again*, and offers both launches.
- `queued` shows only on a page an actually-waiting task points at. Running and
  terminal rows are not "queued"; history must not make a page look busy.
- An active run **elsewhere** presents as `busyElsewhere` — Add to Queue stays,
  Start Capture does not — rather than as this page capturing.
- **Manual and automation navigation take the same presentation path and
  different job paths.** A chapter hop re-scopes what the Browser *shows* (the
  page really did change) and does nothing to the run, which is not the
  screen's to reset. Redirects resolve to the landing page; hash-only jumps,
  sub-frames and asset loads never reach the session at all; `about:blank` and
  app schemes start no session.
- On completion the durable outcome goes to Activity, the Browser shows a
  dismissible result banner for that page, and the control returns to idle.

### D60 — "Open in Browser" is one coordinator, and it pops before it switches

**Decision.** Every source-page action — the episode row, the long-press
details sheet, the unavailable-episode sheet, a History row — calls one
function, [`openInBrowser`](../lib/features/open_in_browser.dart). No call
site does part of it.

*The bug this replaces.* The old action did two of the six necessary things:
it handed the URL to `BrowserController` and set the shell's tab index to the
Browser. Both worked. Neither was visible — because every call site is
reached from a route **pushed above the shell** (`/series/:id`, and the sheets
shown from it). Changing the index of an `IndexedStack` underneath a
full-screen pushed route changes nothing the user can see. The page loaded
into a Browser nobody was looking at.

*The six steps, in order:*

1. validate the URL — no usable `source_url` means no navigation at all
   (D42), and the message says so: *This episode does not have a source page.*
2. confirm with a running capture, if one owns the rendered Browser;
3. store the request on `BrowserNavigator`;
4. **pop back to the shell** — the step that was missing;
5. select the Browser tab;
6. let the Browser drain the request when it is mounted and attached.

*Why pop rather than `go('/')`.* Popping leaves the shell route untouched, and
with it the WebView, its cookies, its back/forward list and any running
capture. `go` would rebuild the shell — a new WebView and a lost session,
which is the opposite of what this action is for. Nothing is pushed, so there
is no duplicate Browser, Library or Series Detail route.

*Why a stored request rather than a load.* Between the ask and the load there
is a route pop, a tab switch and possibly a WebView attach. A load issued into
an unattached controller is silently dropped. The request waits on
`BrowserNavigator` and is consumed **exactly once** by `PendingOpenDrainer` —
so a provider rebuild after the drain finds nothing and cannot fetch the page
twice. The wait is on the attach, never on a duration.

*Local surfaces yield.* A request arriving while Browser Home or the URL
editor is up calls `showWebsite()` first. A page the user explicitly asked for
must not load behind an overlay — and on a cold start Browser Home is the
default surface (D57), so this is the normal case, not the edge case.

*Taking the page from a capture.* A WebView-dependent phase is asked about
with its own dialog — *Stay with capture* / *Pause and open episode* — worded
as taking the page rather than leaving the Browser, because the user is not
walking away. Choosing to proceed pauses with `browserHidden` (D36: a hold,
never a stop) and the engine's own page-validation handles the rest. Download
and save phases are **not** asked about: they read bytes over HTTP and touch
no layout, so moving the page costs them nothing.

*Corollary.* `_onTabRequested` in the shell must not lift a leave-pause. It is
the path this action uses, and auto-resuming there would restart the run one
frame before the page is navigated out from under it. Only a user tapping the
Browser tab (`_select`) resumes.

### D61 — A reader notice is screen state, and it says one thing

**Decision.** The notice the reader shows after the finished-chapter cleanup
(D37) is a widget inside the reader, not a `SnackBar`. It reads *Previous
chapter removed offline*, carries a trash glyph, offers **Undo** while the undo
window is genuinely open, shows its own timeout as a hairline that empties, and
is gone five seconds later.

*Why not a SnackBar.* `ScaffoldMessenger` lives above the router. Its queue
outlives the reader route, its animations are ticker-driven — so a snack bar
that was mid-entrance when the app was suspended finishes entering on resume
and starts its dwell *then* — and `SnackBar.persist` defaults to
`action != null`, which makes any snack bar carrying an Undo ignore its own
`duration` and stay until something dismisses it. Together those are what made
one deletion notice read as a permanent one that came back after every
switch away. A notice owned by the screen has nowhere to come back from.
`showCleanupToast` keeps the snack bar for the list screens, with `persist`
reduced to the one case that earns it (a screen reader).

*One at a time, replaced never queued.* One nullable field holds it, keyed by a
sequence number so a second removal restarts the countdown instead of
inheriting a half-spent one. It is dropped when the chapter changes, on **every**
app lifecycle transition (including the resume, so returning has nothing left
to replay), when the user closes it, and with the screen. Nothing about it is
persisted — there is no state for a later page or a later launch to restore.

*No byte count.* How much space came back is not a decision anyone makes
mid-read; it belongs on Settings › Storage. What matters for five seconds is
that something was removed and that it can be put back. The wording stays
"removed offline" rather than "deleted" because nothing was deleted (D35).

*It never covers a control.* The notice floats above the bottom chrome, offset
from the safe-area inset rather than a fixed distance — Android's three-button
navigation bar reports ~48px there, which a fixed offset would let it eat.
Reading, scrolling and chapter movement are untouched while it is up.

---

### D62 — Both appearances are measured, and the palette is the only source

**Decision.** `AppPalette` is the *only* place a colour value exists outside
`ReaderColors`. No widget file may name a `Color(0x…)` or a Material swatch
other than `Colors.transparent` / `Colors.black`, and both ramps are tuned
against measured contrast rather than chosen by eye. Two tests in
[`test/theme_palette_test.dart`](../test/theme_palette_test.dart) enforce both
halves.

*What was actually wrong.* Nothing in `AppPalette` was mis-valued. D56 added
the token layer for the browser work, but the screens written before it —
Library, Series detail, Reader, Capture panel, Activity, Storage, the selection
overlay, the duplicate panel, the cleanup dialogs — plus the shared component
file `status_style.dart` still carried the prototype's **light-only literals**
from D28. Around four hundred of them, `Color(0xFF5F5B54)` alone appearing
sixty-three times. In the dark appearance every one of those painted the light
design on a near-black page: `serifStyle()` defaulted to `#1B1A18`, so the
Library title was near-black on near-black; `kHeaderIconColor` was a constant,
so header glyphs were too; `monogramPairs` had no dark variant at all, so cover
stand-ins stayed pastel; `SeriesGroup.warningLine` baked `0xFF8E3B31` into a
*model getter*. A dark theme cannot be fixed screen by screen when the thing
that is broken is that the screens were never asking.

*Measured, not eyeballed.* WCAG 2.x is the compliance floor; APCA Lc is the
judgement, because WCAG 2 overstates contrast near black badly enough that it
cannot be used to design a dark theme at all. The app is for hour-long reading,
so the target is the comfort band and both of its edges matter. The old dark
body ink (`#F2EFE9` on `#161513`) measured 15.9:1 / Lc −97 — past APCA's Lc 90
"preferred for fluent body text", which is what "glowing" was. The old light
body ink measured 16.7:1 / Lc +101 on a page at L\* 98, which is glare. Both
ends moved inwards: 13.4:1 dark, 14.0:1 light, on a page that is a warm
near-black at one end and an off-white at the other.

*Four accessible text levels, then decoration.* `ink`, `inkStrong`, `inkMuted`
and `inkFaint` clear 4.5:1 on **every** surface they are drawn on, not just on
the page — the check that caught `inkFaint` failing at 4.24:1 on a card while
passing at 4.55:1 on the page. `inkGhost` sits below 4.5:1 deliberately and is
documented as decoration only; `inkDisabled` is the disabled tone. Hierarchy is
carried by weight and size as well as tone, because five near-identical greys on
one row is what brightness-only hierarchy produces.

*Borders exist.* The old dark border measured 1.37:1 — Lc 0, literally
imperceptible. Cards now separate twice, by a surface step *and* an edge, and
the card step is bounded above (< 1.9:1) so a card is not a lit rectangle.

*Accents survive a warm filter.* A device night-light filter crushes the blue
channel, which collapses a teal accent toward the neutral inks — a link becomes
grey text. The old light `primary` and `inkMuted` sat at L\* 38.2 and 37.6:
under the filter, indistinguishable. Both appearances' accents were re-levelled
so they differ in lightness as well as hue, and the test asserts that in L\*
*after* simulating the filter. Every accent surface also carries a border, so
tinting is never the only signal.

*The reader is outside the preference, but not pure black.* `ReaderColors` is a
fixed set for one screen that is dark in every appearance. Its canvas moved from
`#000000` to `#0C0B0A`: on OLED a pure-black background smears visibly under the
continuous vertical scrolling this screen exists for, and it maximises halation
around the overlaid chrome. It is still dark enough that a panel's own black
borders read as artwork.

*The rule is enforced by a test, not by discipline.* A source scan over `lib/`
fails on any colour literal outside `ui/palette.dart` and on any Material swatch
beyond the two that mean the same thing in both appearances. That check is the
one that would have caught the original bug, and it is cheaper than noticing it
again in a screenshot.

---

### D63 — The app has one generated mark, and startup is a screen

**Decision.** The identity is a single piece of artwork produced by
[`tool/brand/generate_brand_assets.swift`](../tool/brand/generate_brand_assets.swift),
and the work between launch and a usable library is presented as a named,
observable sequence rather than hidden behind a blank window.

*One generator, every raster.* The mark — an open book with a download arrow
descending into the centrefold, cream and `toastAccent` on a teal ground
derived from `AppPalette.primary` — is defined once, in CoreGraphics, and
emitted at every size the platforms ask for: the 15 iOS `AppIcon` slots, the
Android legacy mipmaps *and* the adaptive foreground, both launch images, and
`assets/brand/app_mark.png` for the splash. Hand-editing a PNG is therefore
always wrong; edit the generator and re-run it. No package was added to draw
two shapes, and no icon-generator dependency sits in `pubspec.yaml`.

*The launch window is the same picture as the first frame.* iOS draws the
tile on a `LaunchBackground` colour set (light/dark) and Android on
`@color/launch_background` (`values` / `values-night`) — both the app's own
`surface`. The Flutter splash then draws the same mark at the same 96pt on the
same colour, so the hand-off from the OS window to the app is not a visible
cut. The splash follows the *system* appearance, like the launch window it
continues; the persisted preference (D56) applies once the app is up.

*Startup moved into the tree.* `main()` used to run recovery, backfills,
repairs, the saved-site seed, history pruning and the queue restore **before**
`runApp` — correct, but invisible: a library with thousands of chapters spent
that time on a blank window that is indistinguishable from a hang. The same
work now runs as five [`StartupStep`](../lib/core/startup.dart)s under the
splash, which reports the step being worked on and its position in the
sequence. Ordering and semantics are unchanged; the app still mounts only
after the sequence ends, so nothing observes a half-repaired database.

*Only the first step is fatal.* Storage and the controllers built on it are
`critical: true` — without them there is no app, and the splash says which
step failed, shows the error and offers **Try again** (which reuses the
already-open database rather than opening a second connection). Every later
step is maintenance: it logs, records a warning and lets the user into their
library, exactly as the old `try`/`catch` blocks did. A backfill that throws
must never be the reason someone cannot read.

*The report is paced, the work is not.* `minStepDuration` (130 ms) and an
850 ms floor on the splash exist because five steps that each take four
milliseconds are one unreadable flicker. Neither delays any step: the pause
happens after the work has already returned.
