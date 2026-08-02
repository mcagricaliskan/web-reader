# Architecture

> The as-built product and data model. Terminology is defined in
> [TERMINOLOGY.md](./TERMINOLOGY.md); store positioning in
> [STORE_PACKAGE.md](./STORE_PACKAGE.md); policy reasoning in
> [STORE_POLICY_MAP.md](./STORE_POLICY_MAP.md); data flows in
> [PRIVACY.md](./PRIVACY.md).

## 1. What the app is

A general-purpose personal reading tool: an embedded browser, a native library,
and an offline reader. It lets a user save web pages they are legally permitted
to keep, organise them, and read them offline.

It is **not** a bulk fetcher, an automated harvester, a site archiver, a client
for particular websites, or a tool for getting past any access control. It ships no
site list and no site-specific behaviour.

## 2. The model

Library → Collection → Entry → Page/Section. See TERMINOLOGY.md §1.

A **standalone entry** is a first-class library item: `entries.collection_id` is
nullable, no collection row is created for a single saved page, and the library
shelf is a union of collections and standalone entries
(`LibraryCollection` in `lib/features/library_screen.dart`).

The three ways content leaves again — archived, its offline files removed, or
deleted permanently — are three different operations with three different blast
radii. §8.2 is the authoritative account of which is which.

## 3. Content shape — three independent dimensions

`lib/library/content_shape.dart`. Kept independent because a page can be
image-dominant *and* part of a dated feed *and* ordered by publication date.

- **ContentKind**: standalonePage · article · datedPost · sequentialText ·
  imageDominant · **videoDominant** · paginatedDocument · longFormDocument ·
  unknownWebContent
- **SequenceKind**: none · explicitNextPrev · numberedPagination · openEndedNext ·
  chronologicalFeed · reverseChronologicalFeed · continuousPage · manualSelection
- **OrderingBasis**: explicitNumericIndex · publicationDate · detectedNextLink ·
  discoveryOrder · userDefinedManualOrder

Each carries a **ShapeConfidence**, and `low` is a real answer. Nothing assumes
numbering starts at 1, that a total is known, that a sequence increases, that
"next" means newer, that every entry belongs to a collection, or that a
collection has a final entry. `collections.known_entry_total` is nullable and
usually null.

### 3.1 Three separate questions

`ContentKind` is only one of three, and conflating any two of them is what
produced a library where every entry was an image list:

| Concept | Question | Where | Who decides |
|---|---|---|---|
| **ContentKind** | What is this *page*? | `library/content_shape.dart`, `entries.content_kind` | Detection; the user can correct the label |
| **CaptureMode** | What should the *save* produce? | `save/capture_mode.dart`, `save_runs.capture_mode`, `queue_tasks.capture_mode`, `entries.capture_mode` | The user, from what detection says is possible |
| **ArtifactFormat** | What does the stored *package* hold? | `storage/manifest.dart`, `entries.artifact_format`, `manifest.json` | The save that wrote it — a fact, not a claim |

**Only `ArtifactFormat` decides how an entry is read.** Correcting a label to
"article" changes what the library calls an image package and nothing else;
the reader still opens it as the image sequence it physically is. Reader mode
is *derived* from the artifact rather than stored, so the two cannot disagree.

`CaptureCapabilities` (`save/capture_mode.dart`) turns a probe into the set of
modes the engine can genuinely carry out on that page, the reason each
unavailable one is unavailable, and which to preselect. The save sheet is built
from it, so it can never offer a mode the engine would then refuse — and the
engine resolves against the *same* function on the settled page, so the two
cannot disagree.

Two fallbacks live in that one function rather than being duplicated:

- **Unclassifiable and not video** → the image attempt is offered. It is the
  only path with user assistance behind it, and a page nothing could classify
  used to be saved that way.
- **Video-dominant with nothing readable** → nothing is offered, the sheet's
  launch buttons are disabled, and the run refuses.

The engine resolves on the **settled** probe, after scrolling, not on the one
taken at page load: on the second entry of a multi-entry run a lazy image page
has barely loaded at that point, and deciding from it is how entry 2 would end
up stored in a different format from entry 1.

## 4. Detection — generic and domain-independent

`lib/save/content_detection.dart`. Signals used: `rel=next`/`rel=prev`,
`<article>`, `<main>`, `<time datetime>`, article metadata and JSON-LD dates,
pagination controls with a numeric range, measured prose length, measured image
area, document height, and elements the user pointed at. No hostname appears
anywhere in the file, and `test/repository_cleanliness_test.dart` fails the build
if one does.

Two rules are load-bearing: a number in a URL is not evidence of a structure, and
arriving from the web is not evidence of a page.

**Video** is classified, never captured. `videoDominant` requires all three of:
a player inside the readable region, occupying at least
`kVideoDominantViewportShare` (20%) of the measured viewport, on a page that is
neither prose nor a run of full-size images. A page that merely embeds a clip
stays what it is. `PageMediaSignals` carries geometry only — a count, an area
and an in-region flag — and deliberately no media URL of any kind.

**Text extraction** is split the same way detection is. `bridge_script.dart`
walks the readable region and reports every candidate block with flags
(`chrome`, `hidden`, tag, size); `save/document_extraction.dart` decides what
survives. The judgement half is pure Dart over literal fixtures, which is what
makes "what ends up in a user's saved copy" testable without a WebView.

Feed **direction** is measured from the dates on the page, never assumed —
getting it backwards saves the wrong end of a blog.

## 5. Save flow

**Built today:**

0. **What to save** and **how much to save** are separate choices, in one sheet.
   The capture modes are *Images only* · *Text only* · *Text and images*;
   unavailable ones stay on screen, disabled, with the reason beside them. The
   default comes from detection and every alternative is one tap away.
1. The default and preselected scope is **Save current page only**.
2. `SaveScope` is `currentPageOnly` | `selectedEntries` | `fixedCount`.
   `SaveLimits.forScope` is the only constructor and **cannot produce an
   unbounded run**: `maxEntries` is always a positive integer, clamped to
   `maxEntriesPerRun`.

   There is deliberately **no open-ended scope**. The app used to offer "until
   there is no next page", bounded by an internal ceiling the user never saw —
   and, because the sheet had no field to type one into, it passed a count of 1
   and saved exactly one entry. A typed number is the same safety guarantee
   stated plainly: the run stops where the person said it would, and every
   ceiling in the app is now one they chose and can see. A row persisted with
   the removed scope reads as `currentPageOnly`, the safest value, rather than
   saving more than was asked for.
3. `SaveRunController.start` takes `range` as a **required** parameter, so no
   caller can inherit a default about how much of someone else's site to touch.
4. Every multi-entry save is user-initiated, bounded, visible in the queue,
   cancellable, retryable, and survives a restart as *queued and unstarted* —
   the start authorisation is never persisted.
5. A collection can **remember** a capture mode (`collections.preferred_capture_mode`).
   It is a proposal, never an instruction: every page is re-measured and the
   preference is run through `CaptureCapabilities.resolve`, so a remembered
   mode that no longer applies falls back and the run says so in its log.
   A multi-entry run re-resolves per entry, because entry 7 may not be shaped
   like entry 1.
6. A text extraction that finds nothing is reported and walked past. It
   deliberately does **not** route into reader-area selection: that assistance
   hands back a container of images and cannot help a page with no prose.

**Deferred — modelled but not on screen.** The domain layer computes everything
the review step needs (`detectSequence` returns the kind, direction, known total
and confidence; `SaveLimits` the ceiling), and `SaveScope.selectedEntries` is
plumbed through the queue and the run — but there is **no review-step UI yet**.
Until there is, a multi-entry save is bounded and cancellable but is not
previewed. Wording for that screen is fixed in `STORE_PACKAGE.md` §6.4.

## 6. Stopping conditions

`lib/save/stop_conditions.dart`, one `StopReason` per outcome, persisted on
`save_runs.stop_reason` and `queue_tasks.stop_reason`. See STORE_POLICY_MAP.md §7
for the full table.

The app detects and stops. There is no retry-with-different-headers, no
alternate-URL attempt, no cookie manipulation, and no rate-limit wait-out
anywhere in the codebase.

## 7. Capture modes and unsupported media

**Built today.** Audio and video are **not saved**: `AssetFetcher` accepts image
bytes only, verified by magic number rather than `Content-Type`. `<video>`,
`<audio>` and media `<iframe>`s are counted by the page probe
(`PageMediaSignals`) and the run logs that they were left alone; no media URL is
read or fetched. Images are stored byte-for-byte in app-private storage — no
re-encoding, and no export to Photos, Gallery or Downloads.

**Built today.** The capture modes are on screen in the save sheet, and the
old `save_runs.include_images` boolean is gone: it could not express the
difference between an ordered sequence of full-size images and an article with
pictures in it, and nothing ever read it. `save_runs.capture_mode` and
`queue_tasks.capture_mode` carry a real `CaptureMode` end to end.

A page that is primarily a video is classified `videoDominant`, the sheet says
plainly that video is not saved, and — when the page carries no readable text —
the save is refused rather than falling back to sweeping up its thumbnails.
A document's inline image that was not stored renders as an honest "this image
was not saved" placeholder in its right position.

**Not built, and out of scope:** any video capture or playback. See §11.

## 8. Database — version 1, created whole

`lib/storage/database.dart`. `schemaVersion` is **1**, the strategy has an
`onCreate` and **no `onUpgrade`**, and there is no schema dump, step verifier or
data-copying routine anywhere in the project.

Tables: `collections` · `entries` · `save_runs` · `user_page_hints` · `settings` ·
`queue_tasks` · `browsing_history` · `saved_sites` · `favicon_cache`.

Columns carrying the three separated concepts:
`entries.content_kind` / `content_kind_confidence` / `content_kind_is_user_set`
(what the page was) · `entries.artifact_format` / `capture_mode` (what the
package holds and how it was produced) · `collections.preferred_capture_mode`
(what to propose next time) · `save_runs.capture_mode` /
`capture_mode_is_user_set` and the same pair on `queue_tasks`.

Relationships: `entries.collection_id → collections.id`, nullable, with
`PRAGMA foreign_keys = ON` set in `beforeOpen`. There is **no `ON DELETE
CASCADE`**: a collection row cannot go while an entry still points at it, which
is what forces permanent deletion to remove dependents first and in a
transaction (§8.2). The four browsing tables reference nothing in the library
and nothing references them, so clearing history can never cascade into saved
content.

Indexes created with the schema: a **partial unique index** on
`entries(url_key) WHERE collection_id IS NULL` (a composite UNIQUE cannot enforce
standalone identity — SQLite treats NULLs as distinct), plus
`entries(collection_id, entry_order | save_status | read_status)`,
`entries(url_key)`, `entries(canonical_url)`, `entries(last_read_at)`,
`collections(lifecycle, last_read_at)`, `collections(created_at)`,
`queue_tasks(state, order_index)`, `browsing_history(source, visited_at)`, and a
unique index on `saved_sites(url_key)`.

Pages live in each entry's `manifest.json`, next to the bytes they describe,
rather than in a table that could disagree with the files.

### 8.1 Entry packages and manifest versioning

    library/<collection-id>/entries/<entry-id>/
      manifest.json        always
      document.json        structured-document entries only
      assets/001.png …     image pages, or a document's inline images
    library/standalone/<entry-id>/    entries belonging to no collection

**`manifest.json` is version 2.** It gained `artifact`, `captureMode` and a
`document` reference. Version 1 packages are read exactly as written and are
never rewritten in place: a manifest with no `artifact` field is an image
sequence, because that is the only thing this app could produce when it wrote
one. That rule is asserted against literal version-1 JSON in
`test/document_persistence_test.dart`, not against something this build wrote.

An `artifact` value this build does not recognise resolves to
`ArtifactFormat.unknown` and the reader says the entry was saved in a format it
cannot open. It is deliberately *not* read as an image sequence — misreading a
newer package would be worse than refusing it.

`document.json` is a list of typed blocks with plain text and offset-based
emphasis marks. It is **not** HTML: a saved page cannot carry a script, a
stylesheet, an iframe, an event handler or a remote reference, and the offline
reader has no HTML engine in it at all.

The database is still **version 1 with no migration system**, per the rule at
the top of this section: nothing has shipped, so the new columns were added to
`onCreate` rather than to a migration branch. The durable user data is the
packages on disk, and `storage/recovery.dart` rebuilds library rows from them —
for both manifest versions, and for standalone entries as well as collected
ones.

That last property is a **capability, not a guarantee that a row always comes
back**, and the difference matters: recovery reconciles the packages it finds,
so anything that intends a row to stay gone has to remove the package too. That
is exactly why permanent deletion takes the files out of `library/` before it
touches a row — see §8.2.

### 8.2 Three ways content leaves: archive · remove files · delete

Three operations, three blast radii, and none of them is a substitute for
another. The confirmation copy for each is built on this table.

| Operation | Entry point | Rows written | Files | Reversible |
|---|---|---|---|---|
| **Archive a collection** | `CollectionRepository.archive` → `setCollectionLifecycle` | `collections.lifecycle` + `archived_at`, nothing else | untouched | **Yes** — *Restore* puts it back exactly as it was |
| **Remove offline files** | `CleanupService.removeOffline` (soft, with undo) / `removeOfflineNow` (bulk) | `content_path`, `byte_size`, `offline_removed_at` on the entry, nothing else | that entry's bytes | **Yes** in substance — the entry never left the library, so it reads "Not available offline — save again", and the soft path also has a real undo window |
| **Delete a collection permanently** | `CollectionDeletionService.delete` (`lib/library/collection_deletion.dart`) | the collection row, its entry rows, and the local work records that named it | every file the collection owns | **No.** The *source* can be saved again, which produces a new collection with a new id |

Archiving hides, removal frees space, and only deletion removes the record.
Archiving a collection is not a quiet way to delete it, and removing offline
files is not a way to delete an entry — see the two invariants in §9.

The action lives on the collection screen's overflow menu, below a rule and in
the danger colour, and it is offered only for an actual collection: a
standalone entry has no collection to delete. There is one confirmation, not a
type-the-name step — nothing else in this product uses that pattern.

#### What deletion removes

- the `collections` row, and with it the collection-scoped preferences and
  pointers stored on it: `cleanup_preference`, `preferred_capture_mode`,
  `last_opened_entry_id`, `last_completed_entry_id`, `last_read_at`, and the
  update-check columns;
- every `entries` row of that collection, and therefore the reading state
  carried on those rows — `read_status`, `progress_fraction`, the anchor,
  `first_opened_at`, `completed_at` — so Continue Reading stops offering it
  because the rows it derives from are gone;
- `queue_tasks` rows naming the collection, **in any state**, waiting or
  historical;
- `save_runs` rows for an interrupted run that was walking it, so the library's
  Resume card cannot re-walk a collection that no longer exists;
- `library/<collection-id>/` entire, including the `.previous` backups an
  interrupted replacement leaves inside it;
- any entry file outside that tree — an entry saved standalone and later moved
  into the collection keeps its `library/standalone/<entry-id>` path, because
  reassignment moves the row and not the bytes;
- `tmp/undo-<entry-id>` and `tmp/<entry-id>`: a removal still inside its undo
  window would otherwise restore a package under `library/`, and startup
  recovery would reconcile it back into existence.

#### What deletion keeps

Other collections and their files · standalone entries that were never part of
it · `user_page_hints` · `saved_sites` · `browsing_history` · `favicon_cache` ·
`settings` · queue history belonging to anything else.

The hints are the deliberate one. They are keyed to a *host and page shape*,
not to a collection, they are shared with every other collection on that host,
and they are what makes saving the same source again work as well as it did the
first time. Deleting a collection is not a statement about the site it came
from.

#### The order, and why it is that order

1. **Stop the work.** The collection's queue rows are cancelled through the
   existing conditional-`UPDATE` path (§9): waiting rows are cancelled outright,
   a running one is asked to stop at its next safe point. Save tasks carry a
   collection id only when the caller knew one, so a save started from the
   Browser is matched by **address** instead — the entries' URLs, plus same host
   and same `collectionFingerprint` as the stored `collection_key` for a page
   that has never been saved. That second test is skipped for a key that is not
   a path (`manual:…`, `title:…`, `host:…`, and the `…#…` form a low-confidence
   grouping gets), because those keys are built so that nothing matches them.
   A row matched only by address is **cancelled, not deleted**: it names no
   collection, so it survives step 4 as ordinary cancelled history rather than
   disappearing from Activity without explanation.
2. **Refuse if anything still holds it.** A cooperative stop lands between
   entries, not instantly. If an entry is open in the reader or mid-save
   (`CleanupService.lockReasonFor`), if the live run is on one of the
   collection's addresses, or if a task naming it is still pending, the delete
   **refuses and nothing is touched**. `DeleteRefusal` names which
   — `gone` · `inUse` · `filesKept` — and the UI shows the reason. Deleting
   under an in-flight save would either resurrect the collection or fail the
   save on a foreign-key error.
3. **Move the files out of the library.** Every owned directory is *renamed*
   into `tmp/deleting-<collection-id>` — one atomic rename each, no partial
   trees. A failure here restores what was already moved and returns
   `DeleteRefusal.filesKept`; **nothing has been deleted** and the collection
   still works.
4. **Delete the rows in one transaction**, dependents first: queue rows, then
   the matching runs, then the entries, then the collection. The foreign key
   makes that order mandatory rather than stylistic (§8).
5. **Discard the staged tree.** A failure at this last step leaks into `tmp/`,
   which the startup sweep already owns. It is not a failed delete.

The filesystem cannot join the SQL transaction, so the ordering is chosen to
make the **reachable** intermediate state the harmless one:

- a crash between 3 and 4 leaves rows whose files are gone. That is a state the
  app already handles: opening such an entry finds no package, calls
  `markEntryContentMissing` — dropping `content_path` and recording *local files
  missing* — and says so instead of failing. The collection is still listed and
  a second delete finishes the job. Nothing comes back to life.
- the reverse order — rows first, bytes second — would leave committed packages
  under `library/` with no rows, and the next launch would reconcile them into
  a collection the user deleted. That failure is silent and looks like a bug in
  the app rather than an interrupted delete, which is why the ordering is not a
  preference.

Afterwards the same source can be saved again: identity is matched on
`(host, collection_key)`, the deleted row is gone, so a save creates a new
collection rather than joining a ghost.

## 9. Invariants worth keeping

- **Reading state is writable only from `lib/reading/`.** `writeEntryReading` is
  the only DAO method that can reach a reading column.
- **A completed entry is 100% read.** `progress_fraction` is pinned at 1 whenever
  `read_status` is `completed`, on write and again on display.
- **Removing offline files is not deleting an entry.** Only `content_path`,
  `byte_size` and `offline_removed_at` are written; everything else survives, and
  the entry reads as "Not available offline — save again". Deleting is a
  different operation with a different entry point (§8.2), and neither this nor
  archiving may be offered as a way to do it.
- **Collection-owned state is deleted through `CollectionDeletionService`, or
  it is not deleted.** Permanent deletion is one flow — cancel the collection's
  queue work, refuse while an entry is locked or a save is still on it, move
  every owned directory out of `library/` *before* any row goes, then remove the
  queue rows, the interrupted runs, the entries and the collection in one
  transaction. Each part is load-bearing: skipping the file move lets startup
  recovery rebuild the entries from the manifests still on disk; skipping the
  cancellation lets delayed work write into a collection that is being deleted.
  `deleteCollection`, `deleteEntriesForCollection`,
  `deleteQueueTasksForCollection` and `allRuns` are that service's vocabulary
  and have no other caller — deleting the collection row on its own leaves
  orphaned files, live queue rows and a foreign-key error. See §8.2.
- **Semantic label and stored format are separate, and only one is editable.**
  `setEntryContentKind` writes `content_kind` and cannot reach
  `artifact_format`. Relabelling an image package as an article changes what it
  is called; it never causes the reader to parse it as a document.
- **A reading anchor belongs to an artifact.** `ReadingPosition.anchorIndex` is
  a panel index for an image sequence and a *block* index for a document. When
  a re-save changes an entry's stored format, `carryReading` keeps everything
  that is a fact about the content (finished, first opened, the
  content-independent fraction) and resets only the anchor, which would
  otherwise drop the reader somewhere arbitrary and call it "where you were".
- **An entry's `source_url` is durable.** Every writer names its columns, so it
  survives removal, archive, restore, re-save and reading updates. It is what
  "Open original page" stands on.
- **Cancelling preserves the row; dismissing deletes it.** A cancel moves a task
  to the existing `cancelled` state — no sixth state — and *Remove from Activity*
  deletes a row that is already terminal, refusing anything live. Both the pump's
  claim and every cancel go through one conditional SQL `UPDATE`
  (`updateQueueTaskIfState`), so exactly one wins and the loser is told.
  `cancelTask` reports which happened (`CancelResult`). Stopping is cooperative
  everywhere — `removeOfflineNow` takes `shouldContinue` and is asked between
  entries — so the wording is "at the next safe point", never an instant stop the
  app cannot deliver.
- **Only manual navigation enters browsing history.** Enforced twice: the source
  the automation sets, and `effectiveNavigationSource`, which cannot answer
  `manual` while `automationOwner` is held.
- **The app ships no page hints.** `user_page_hints` is empty on a clean install
  and nothing seeds it.
- **`AppPalette` is the only source of colour.** `test/theme_palette_test.dart`
  scans `lib/` and fails on a literal `Color(0x…)`.
- **drift trap:** `insertOnConflictUpdate` treats a null field as *absent*, so
  anything that must be cleared needs its own narrow writer
  (`clearOfflineRemovedMark`, `clearRunPauseReason`).

## 10. Status — what is built, and what is not

This document describes a **foundation**, not a finished product. The split
matters because several safety properties are real in the domain layer and not
yet reachable from a screen.

| Area | State |
|---|---|
| Library / Collection / Entry model, standalone entries | **Built**, tested |
| Version-1 schema, no migration system | **Built**, tested (`schema_v1_test.dart`) |
| Content-shape model and detection | **Built**; `detectContentKind` / `detectSequence` / `detectCaptureCapabilities` unit-tested directly (`content_detection_test.dart`) |
| Capture modes (images · text · text+images) | **Built**, tested (`document_save_test.dart`, `document_extraction_test.dart`) |
| Structured-document extraction and storage | **Built**, tested |
| Structured-document reader | **Built**, tested (`document_reader_test.dart`) |
| Manifest v1 → v2 compatibility | **Built**, tested against literal v1 JSON |
| Collection capture-mode preference, with validated fallback | **Built**, tested |
| Entry content-type correction (UI) | **Built** — label only; cannot change the stored artifact |
| Semantic labels, one producer | **Built**, tested |
| Stopping conditions and `StopReason` | **Built** in `stop_conditions.dart` and wired into the run; **no dedicated tests yet** |
| Bounded scopes, required `range`, no unbounded run | **Built**, tested |
| Audio/video never fetched | **Built** (image-only MIME allow-list) |
| Video-dominant pages classified and refused | **Built**, tested; **no video capture or playback exists** |
| Offline reader, reading position, queue, cleanup, archive, storage | **Built**, tested |
| Permanent collection deletion (§8.2) | **Built**, tested (`collection_delete_test.dart`) |
| Repository-cleanliness guard | **Built**, tested |
| Save-scope review step (UI) | **Deferred** |
| First-use and contextual content-rights disclosures (UI) | **Deferred** |
| Video capture or playback | **Not built, and out of scope** — see §11 |
| Privacy / Terms / Content-rights settings pages | **Deferred** |
| Hosted demo site, store assets | **Deferred**, external |
| Device runtime verification | **Not run** — simulator launch only |

## 11. The video boundary

Video is **detected and refused**, never captured. What exists:

- `ContentKind.videoDominant`, with the three guards in §4.
- `PageMediaSignals` — a count, the largest player's laid-out area, and whether
  it sits in the readable region. **Geometry only.** There is no field here that
  holds a media URL, and adding one would turn a classification signal into the
  first half of a downloader.
- Save-sheet copy saying video is not saved, and what will happen instead.
- A refusal when a video page carries nothing readable, rather than a fallback
  that sweeps up its thumbnails.
- `ArtifactFormat`, which a future video artifact could join as another value
  without disturbing the image or document formats.

What does **not** exist, and is out of scope: video URL extraction, network
interception, iframe inspection for media addresses, HLS, DASH, DRM, video file
storage, background video downloading, playback, picture-in-picture, subtitles,
seasons, and any genre-specific logic. `CaptureMode` has no video value on
purpose — the save sheet is built from that enum, so a mode the engine cannot
honour would become a button that lies.

Nothing in this repository, its store copy or its documentation describes video
saving as supported.

## 12. Known limitations

- **Text extraction is heuristic and says so.** The readable region is chosen
  from standard landmarks, then from paragraph density. A page that structures
  itself unusually may lose blocks or keep furniture; the failure mode is a
  named, explained refusal or a visibly incomplete document, never a silent
  half-save.
- **Furniture exclusion uses generic class/id words** (`comment`, `advert`,
  `sidebar`, `related`, `share`, …) alongside HTML landmarks. These are
  structural conventions, not a site list — but a page that names its main
  column with one of them will lose blocks.
- **A document restores *to* its position, not *at* it.** A paragraph has no
  offset until it has been laid out, so the document reader scrolls to the
  saved block on the first frame after measurement. The image reader still
  opens at its position, because panel heights are known from the manifest.
- **A document is built in full rather than lazily**, so every block offset is
  exact and restore is precise. Extraction caps the block count; a pathological
  page is bounded rather than unbounded.
- **The database has no migration system.** A developer with a library created
  before these columns existed must reset it; the packages on disk are
  unaffected and `storage/recovery.dart` rebuilds the rows from them.
