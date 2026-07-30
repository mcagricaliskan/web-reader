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

## 3. Content shape — three independent dimensions

`lib/library/content_shape.dart`. Kept independent because a page can be
image-dominant *and* part of a dated feed *and* ordered by publication date.

- **ContentKind**: standalonePage · article · datedPost · sequentialText ·
  imageDominant · paginatedDocument · longFormDocument · unknownWebContent
- **SequenceKind**: none · explicitNextPrev · numberedPagination · openEndedNext ·
  chronologicalFeed · reverseChronologicalFeed · continuousPage · manualSelection
- **OrderingBasis**: explicitNumericIndex · publicationDate · detectedNextLink ·
  discoveryOrder · userDefinedManualOrder

Each carries a **ShapeConfidence**, and `low` is a real answer. Nothing assumes
numbering starts at 1, that a total is known, that a sequence increases, that
"next" means newer, that every entry belongs to a collection, or that a
collection has a final entry. `collections.known_entry_total` is nullable and
usually null.

## 4. Detection — generic and domain-independent

`lib/save/content_detection.dart`. Signals used: `rel=next`/`rel=prev`,
`<article>`, `<main>`, `<time datetime>`, article metadata and JSON-LD dates,
pagination controls with a numeric range, measured prose length, measured image
area, document height, and elements the user pointed at. No hostname appears
anywhere in the file, and `test/repository_cleanliness_test.dart` fails the build
if one does.

Two rules are load-bearing: a number in a URL is not evidence of a structure, and
arriving from the web is not evidence of a page.

Feed **direction** is measured from the dates on the page, never assumed —
getting it backwards saves the wrong end of a blog.

## 5. Save flow

**Built today:**

1. The default and preselected scope is **Save current page only**.
2. `SaveScope` is `currentPageOnly` | `selectedEntries` | `fixedCount` |
   `untilNoNextPage`. `SaveLimits.forScope` is the only constructor and **cannot
   produce an unbounded run**: `maxEntries` is always a positive integer, clamped
   to the configured safety ceiling. An open-ended scope requires an explicit
   maximum.
3. `SaveRunController.start` takes `range` as a **required** parameter, so no
   caller can inherit a default about how much of someone else's site to touch.
4. Every multi-entry save is user-initiated, bounded, visible in the queue,
   cancellable, retryable, and survives a restart as *queued and unstarted* —
   the start authorisation is never persisted.

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

## 7. Image-heavy and unsupported media

**Built today.** Audio and video are **not saved**: `AssetFetcher` accepts image
bytes only, verified by magic number rather than `Content-Type`. `<video>`,
`<audio>` and media `<iframe>`s are counted by the page probe
(`PageMediaSignals`) and the run logs that they were left alone; no media URL is
read or fetched. Images are stored byte-for-byte in app-private storage — no
re-encoding, and no export to Photos, Gallery or Downloads.

**Deferred — modelled but not on screen.** `save_runs.include_images` carries the
text-only answer end to end and `PageContentSignals.looksImageDominant` detects
the case, but the *Text only / Text and images / Cancel* dialog is not built, so
nothing asks yet and the flag is always true in practice. The unsupported-media
placeholder in the reader is likewise not built. Wording for both is fixed in
`STORE_PACKAGE.md` §6.3 and §6.6.

## 8. Database — version 1, created whole

`lib/storage/database.dart`. `schemaVersion` is **1**, the strategy has an
`onCreate` and **no `onUpgrade`**, and there is no schema dump, step verifier or
data-copying routine anywhere in the project.

Tables: `collections` · `entries` · `save_runs` · `user_page_hints` · `settings` ·
`queue_tasks` · `browsing_history` · `saved_sites` · `favicon_cache`.

Relationships: `entries.collection_id → collections.id`, nullable. The four
browsing tables reference nothing in the library and nothing references them, so
clearing history can never cascade into saved content.

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

## 9. Invariants worth keeping

- **Reading state is writable only from `lib/reading/`.** `writeEntryReading` is
  the only DAO method that can reach a reading column.
- **A completed entry is 100% read.** `progress_fraction` is pinned at 1 whenever
  `read_status` is `completed`, on write and again on display.
- **Removing offline files is not deleting an entry.** Only `content_path`,
  `byte_size` and `offline_removed_at` are written; everything else survives, and
  the entry reads as "Not available offline — save again".
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
| Content-shape model and detection | **Built**, unit-tested at the domain layer |
| Semantic labels, one producer | **Built**, tested |
| Stopping conditions and `StopReason` | **Built** in `stop_conditions.dart` and wired into the run; **no dedicated tests yet** |
| Bounded scopes, required `range`, no unbounded run | **Built**, tested |
| Audio/video never fetched | **Built** (image-only MIME allow-list); no dedicated media test |
| Offline reader, reading position, queue, cleanup, archive, storage | **Built**, tested |
| Repository-cleanliness guard | **Built**, tested |
| Save-scope review step (UI) | **Deferred** |
| First-use and contextual content-rights disclosures (UI) | **Deferred** |
| Image-heavy confirmation (UI) | **Deferred** |
| Unsupported-media placeholder in the reader | **Deferred** |
| Privacy / Terms / Content-rights settings pages | **Deferred** |
| Hosted demo site, store assets | **Deferred**, external |
| Device runtime verification | **Not run** — simulator launch only |
