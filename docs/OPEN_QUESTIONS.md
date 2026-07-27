# Web Reader — Open Questions

> Unresolved product and technical questions. **None of them block the next milestone**: each one
> has a working default in force, so implementation proceeds and the question gets answered by
> evidence rather than by argument.
> Status: revised 2026-07-25 — renumbered to the staged plan; Q17/Q23 resolved into
> [DECISIONS.md](./DECISIONS.md). Revised **2026-07-27** — Q01/Q05/Q07/Q08/Q15 closed by
> implementation evidence; Q09/Q10/Q13/Q14/Q18 updated to the as-built state; Q24–Q26 added for
> the Stage 1b backlog (M12–M17).
> Move an answered question into `DECISIONS.md` and mark it resolved here — do not leave two homes
> for the same answer.

**Reading a block:** *Question* → *Why it matters* → **Default in force** (what we build meanwhile) →
*What would settle it* → *Settle by* (milestone).

Milestones refer to [MVP_PLAN.md](./MVP_PLAN.md): **Stage 0 PoC** = M0–M3 · **Stage 1 MVP** = M4–M11.

---

## Resolved

| # | Question | Resolution |
|---|---|---|
| **Q01** | Which site is the M1 test fixture? | **Resolved by use.** The controlled local fixture (`tool/fixture/`) plus two real public sites: `uzaymanga.com` (Turkish, AVIF, Referer-gated CDN — live-captured) and `asurascans.com` (English, `rel=next` — live-probed). |
| **Q05** | How does a user correct a wrong next link? | **Resolved** — option (b) was built a stage early: low confidence or disagreement → `awaitingSelection`, the user points at the control, the answer is saved as a scoped, reusable rule. The M8 checker reuses the same flow. |
| **Q07** | Does build-hooks `sqlite3` build on iOS? | **Resolved** — yes, Simulator and device builds are clean with no `sqlite3_flutter_libs`. |
| **Q08** | Do the plugin APIs behave on current iOS? | **Resolved** — `callAsyncJavaScript`, user scripts, cookies and selection all verified on iOS 26.5 through M0–M8. One caveat became [DECISIONS.md](./DECISIONS.md) **D25**: SPM must be disabled (device builds fail otherwise). |
| **Q15** | Check the list page, or walk the chain? | **Resolved (M8)** — both, in that order: chapter-list heuristic first (an unrecognisable page falls through, never "up to date"), then the bounded walk (12 pages / 20 chapters / 3 min) over saved rules → generic detection → user assist. Bounds not user-configurable, as leaned. |
| **Q17** | What is the product called? | **Resolved** → [DECISIONS.md](./DECISIONS.md) **D22**. `Web Reader` · `com.mcagricaliskan.webreader` · internal slug `webread`. Development identity; display name and bundle id may be reviewed before distribution, but the bundle id gets inconvenient to change once signing exists. |
| **Q23** | Which package versions? | **Resolved** → [DECISIONS.md](./DECISIONS.md) **D21**. Not a documentation concern: resolve latest stable at implementation time, no EOL packages, commit the lockfile, record version-driven limitations as decisions. |

---

## Product

### Q02 — Should a capture session keep the WebView visible?

**Why it matters.** Visible is safer (attached WKWebViews lay out and fire `IntersectionObserver`
predictably) and gives the user something to watch. Headless would free the screen.

**Default in force.** **Visible and attached** ([DECISIONS.md](./DECISIONS.md) D13). The capture
screen embeds the WebView with a touch-blocking overlay and a status panel above it.

**What would settle it.** A measured A/B on the fixture: capture the same 5 chapters headless and
visible, compare asset counts, failure rates, and wall-clock time. Headless is only worth it if the
results are indistinguishable.

**Settle by.** Stage 2.

---

### Q09 — How is chapter completion detected?

**Why it matters.** Too eager and everything is marked read; too strict and Continue Reading fills up
with chapters the user finished.

**Default in force (as built, M5).** `fraction >= 0.97` held for ≥ 800 ms (the dwell prevents a
fling from counting), or an explicit *Mark as read*. Opening never completes. The
navigate-while-nearly-done rule from the original default was **not** built.

**What would settle it.** Real use. Watch whether chapters get stuck near-complete (last panel
taller than the viewport), and whether the missing navigate-away rule is missed in practice.

**Settle by.** Revisit after a week of real reading — no code work scheduled until evidence.

---

### Q11 — Should pinned items support drag-and-drop ordering in the first UI?

**Why it matters.** Cheap in the data model, surprisingly fiddly in the UI.

**Default in force.** The data model supports it now (`pinned_order REAL`, fractional indexing —
[DATA_MODEL.md](./DATA_MODEL.md) §7). The first UI pins to the top automatically and orders by pin
time. Nothing is blocked by adding drag-and-drop later.

**Recommendation.** Ship automatic ordering in M9; add drag-and-drop only if you find yourself
wanting it. Below ~8 pins, pin-time order is usually right.

**Settle by.** M9.

---

### Q12 — Should dormant items appear in search by default?

**Why it matters.** Dormant means "not in my current rotation", not "hidden". Excluding them from
search makes the library feel lossy.

**Default in force.** **Yes** — dormant items appear, visually marked. Only `archived` is excluded by
default, with an "include archived" toggle.

**What would settle it.** Whether dormant results feel like noise once there are enough items.

**Settle by.** Whenever search is built — Stage 2; search is not in the MVP.

---

### Q13 — Should archived items participate in update checks?

**Why it matters.** Checking archived items wastes time and can badge something deliberately put
away. Not checking them means an archived series silently goes stale.

**Default in force.** **No** for both `archived` and `dormant` in bulk operations. Both remain
individually checkable from their series detail screen, and a check on an archived item works
normally.

**Recommendation.** Keep it. "Check all" meaning "check what I am actively following" is the
intuitive reading of active/dormant/archived.

**Settle by.** **M15/M16** — M15 builds *Check all* (over the M14 queue) and M16 introduces
`archived`; the default (bulk excludes archived, per-series check still works from detail) is
already written into both milestones' acceptance criteria.

---

### Q14 — What happens when a chapter is detected but cannot be captured?

**Why it matters.** This is the intersection of the four chapter states, and getting it wrong
produces either a permanent false badge or a chapter that silently disappears.

**Default in force (as built, M8/M5a).** A discovered chapter is a `knownRemote` row; a failed
capture attempt keeps its row as `failed` with `capture_error` set, is flagged on the series
detail, is retryable through the duplicate-preflight actions, and never becomes captured or read.

**Open sub-question.** After N failed attempts, should it be auto-suppressed from the New Chapters
badge so a permanently broken chapter does not nag forever? *Leaning:* yes, after 3 attempts,
replaced by a "N chapters could not be captured" line. Stage 2.

**Settle by.** Base behaviour done; the suppression sub-question at Stage 2.

---

### Q21 — Should there be a batch "capture all new chapters" across items?

**Why it matters.** After a catch-up round the natural next action is "get all of it". Item by item
is tedious; in bulk it is a long unattended run that magnifies every reliability bug.

**Default in force.** Per-item only. *Capture more* on the series detail screen, one session at a
time.

**Recommendation.** Wait until M11 is done and the failure modes are known. A batch run over five
sites is the worst possible place to discover a session-recovery bug. Note: M15 builds bulk
*checking* (metadata only) — that is not this question; this one is bulk *downloading*.

**Settle by.** Stage 2.

---

### Q24 — Does queued work resume automatically after a restart?

**Why it matters.** The M14 queue persists across restarts. Auto-resuming means the app navigates a
WebView and hits remote sites the moment it launches, with nobody watching; never resuming makes
the queue feel unreliable.

**Default in force.** **Offer, never auto-resume** — consistent with the existing interrupted-job
resume card and the "resume is always offered, never automatic" rule the capture job already
follows. On launch, pending queue entries show in the activity strip with a single *Resume queue*
action.

**What would settle it.** Whether the extra tap becomes an irritation in daily use. If it does, a
setting (default off) is the ceiling — silent network activity at launch stays out.

**Settle by.** M14.

---

### Q25 — What happens when a series with queued work is archived?

**Why it matters.** Archiving while a capture or check for that series is queued or running is
either a silent contradiction (work continues on an "archived" series) or a destructive surprise
(work vanishes).

**Options.** (a) Block: refuse to archive until its work finishes or is cancelled, with a message.
(b) Confirm-and-cancel: one dialog — "this cancels 2 queued tasks" — then archive.

**Default in force.** **(b) confirm-and-cancel** — it keeps archive a single decisive action and
nothing is lost that cannot be re-enqueued later. A *running* task still completes its current
chapter safely before cancelling (the job's existing stop semantics).

**What would settle it.** Nothing external — this is a taste decision; flagging it so the M16
implementation does not decide it silently.

**Settle by.** M16.

**Settled (2026-07-27, M16):** (b) as defaulted. The archive dialog quotes the exact pending
count ("This cancels N pending tasks"), `cancelTasksForSeries` cancels queued rows outright and
asks a running one to stop, and only then does the lifecycle flip. Covered by
`test/archive_test.dart` ("archiving cancels the series' pending tasks").

---

### Q26 — What is the default All Series sort?

**Why it matters.** M13 adds by-name and by-last-read sorting with persistence; the default is what
most users will never change. Today's implicit order is by last capture, which surfaces "what the
app did" rather than "what I care about".

**Default in force.** **Last read (descending), never-read series after, then by name** — the
library leads with what the user actually touches. *By name* is the toggle for deliberate lookup.

**What would settle it.** Daily use after M13.

**Settle by.** M13 (cheap to change; the persistence mechanism is the real deliverable).

---

## Technical

### Q03 — What is the minimum page-stability quiet window?

**Why it matters.** The most impactful constant in the app. Too short and chapters save incomplete;
too long and every capture crawls.

**Default in force.** `quietWindow = 1200 ms`, `scrollStep = 0.8 × viewport`, `scrollInterval =
250 ms`, two scroll passes, `hardTimeout = 120 s`.

**What would settle it.** Instrumented runs on the Q01 fixture and target site: record time-to-stable
and whether the extracted asset count matches a manual count, across ~20 chapters. Then set the
default to roughly the 95th percentile plus margin.

**Caution.** Numbers measured on the Simulator will be optimistic — network and disk are the Mac's.
Re-measure on a device before treating any value as final.

**Settle by.** Constants work on the fixture and the live single-chapter capture (Simulator).
Final answer needs re-measurement on a physical device — alongside P0.1 or at latest M11.

---

### Q04 — How should failed images be handled?

**Why it matters.** It decides whether a chapter with one broken image out of forty is usable or
worthless — and M1's acceptance explicitly requires that failed downloads be visible and never
produce a false success.

**Default in force (as built).** Per-asset: 2 retries with backoff, then the in-page fetch
fallback; bytes verified by magic number, dimensions decoded from the file. Per chapter: any
stored assets → **`partial`** with `statusReason: "assetsFailed:N"` and a reader banner; zero
stored → `failed`. The planned 10 % ceiling (above which nothing commits) was **not** built — a
mostly-broken chapter currently commits as a heavily partial one.

**Open sub-question.** Should the reader offer "retry missing images" on an already-committed
`partial` chapter? *Leaning:* yes — a small addition to `AssetFetcher` and exactly what the user will
want. Stage 1 or 2.

**Settle by.** Base behaviour done. The missing failure ceiling and the "retry missing images on
a committed partial" sub-question: revisit on evidence from real use (the preflight's *Retry
missing files* already covers the manual path).

---

### Q06 — Should raw HTML be retained alongside cleaned content?

**Why it matters.** Raw HTML would let a future, better extractor re-process a chapter without
re-downloading — valuable, because extraction quality will improve and sites go offline. It also
roughly doubles text-chapter storage and stores untrusted markup.

**Default in force.** **No.** Store `content.html` (sanitised) + `content.txt` + assets only.

**Options.** (a) Never. (b) Always, gzipped. (c) A per-item or global "keep source" setting, default
off. (d) Retain raw only when extraction confidence is low — the case where re-processing is actually
likely.

**Recommendation.** (d) costs little and targets storage at exactly the chapters a future extractor
would want to revisit.

**Settle by.** M7.

---

### Q10 — How often should reading progress be persisted?

**Why it matters.** Too often is pointless churn; too rarely loses the user's place on a crash.

**Default in force (as built, M5 + hardening).** Throttled to one write per 2 s while scrolling,
immediate flush on close / chapter change / lifecycle change, all writes serialized so a stale
in-flight save can never clobber a newer one. Worst-case loss: ≤ 2 s of scrolling.

**What would settle it.** The physical-device lifecycle pass (backlog **P0.1**) — the Simulator
evidence is in; whether the lifecycle flush lands before iOS kills the process is the only open
part. If it does not, the throttle must shorten.

**Settle by.** **P0.1** (the device checklist in IMPLEMENTATION_STATUS §10).

---

### Q16 — How should chapter identity be normalised across URL changes?

**Why it matters.** A site adding a query parameter, switching to `https`, or moving domains would
otherwise duplicate an entire series and orphan all reading history.

**Default in force.** `url_key` normalisation ([DATA_MODEL.md](./DATA_MODEL.md) §6), with
`canonical_url` and `content_hash` as secondary identity signals, and a manual `source_url` edit for a
domain move.

**Open sub-questions.** Should `www.` be stripped? Should `http`/`https` be unified? Both are usually
safe and occasionally wrong. Current answer: neither, with a per-recipe override later.

**What would settle it.** Encountering a real URL change on a target site. Until then, the manual fix
is proportionate.

**Settle by.** Deferred. Revisit when it happens.

---

### Q18 — Where does the cover image come from?

**Why it matters.** Continue Reading cards look broken without one, and it is the first thing the user
sees.

**Default in force.** In priority order: the series page's `og:image` → the first asset of the first
captured chapter → a generated placeholder from the title. Stored as `cover_path`, relative.

**Open sub-question.** Should the user be able to set a cover from any captured image? Cheap and
pleasant. Stage 2.

**Settle by.** Deferred past the Stage 1b backlog (covers were explicitly out of M4's scope and
are not in M12–M17). Revisit alongside M17's visual work or Stage 2 metadata.

---

### Q19 — What are the politeness and concurrency defaults?

**Why it matters.** Too aggressive risks rate limiting or a block — which looks like a capture bug and
is not. Too conservative makes a 20-chapter run tedious.

**Default in force.** One page at a time (never parallel chapters), 3 concurrent asset downloads
within a chapter, `cooldownBetweenChapters = 1500 ms`.

**What would settle it.** Observing 429s or degraded responses during a long M3 run. If they appear,
raise the cooldown and add jitter before touching anything else.

**Settle by.** Unchallenged on fixture runs and the single live capture. The real test is the
first live **multi-chapter** run (see IMPLEMENTATION_STATUS §2a) — revisit then.

---

### Q20 — What is the low-disk threshold, and what happens at it?

**Why it matters.** Running out of space mid-chapter is the classic way to produce a half-written
library.

**Default in force.** Before each chapter, require free space ≥ `max(200 MB, 3 × last chapter size)`.
Below that: stop the session with `failed(storage)` and a clear message. Never commit a partial
chapter.

**Blocked on.** Reading free disk space needs a platform channel or a small package
([TECHNICAL_SPEC.md](./TECHNICAL_SPEC.md) §1). Until then the guard is reactive: a write failure ends
the session the same way, just later.

**Settle by.** M11.

**Settled (2026-07-27, capture-hardening batch):** a hand-rolled
`webread/device_storage` channel (D34) provides free bytes on both platforms.
Policy in `CaptureConfig`: refuse to start under 500 MB free; before each
chapter require `emergencyReserve (200 MB) + estimate` where the estimate is
the series' median stored chapter size (50 MB default); before an atomic
replacement additionally require room for both copies. Violations stop with
the distinct `insufficientStorage` error, never a generic I/O failure, and
never touch the previous complete copy. Covered by `test/disk_safety_test.dart`.

---

### Q22 — Can Mozilla Readability be vendored?

**Why it matters.** It is the reference implementation of readable-text extraction and would save
considerable effort and quality.

**Default in force.** Plan to vendor `readability.js` as a bundled asset. `[Unverified]` licence
believed Apache-2.0.

**What would settle it.** Reading the licence file at vendoring time and confirming attribution
requirements. If unusable, the fallback is the density heuristic in
[TECHNICAL_SPEC.md](./TECHNICAL_SPEC.md) §7.3 — lower quality, no blocker.

**Settle by.** M7. Trivial to check; do not let it become a surprise.

---

## Summary — when each question needs an answer

| Settle by | Questions |
|---|---|
| **P0.1 (device pass)** | Q10 (does the lifecycle flush land before iOS kills the process) |
| **M13** | Q26 (default All Series sort) |
| **M14** | Q24 (queue resume: offer, never auto) |
| **M15 / M16** | Q13 (archived excluded from bulk checks) · Q25 (archive vs. queued work) |
| **M7** | Q06 (raw HTML) · Q22 (Readability licence) |
| **M9** | Q11 (drag-and-drop pins) |
| **M11 / device** | Q20 (low disk) · Q03 (stability constants re-measured on hardware) |
| **Evidence from real use** | Q09 (completion thresholds) · Q04 sub-question (retry missing images on a committed partial) |
| **Stage 2 / deferred** | Q02 (headless) · Q12 (dormant in search) · Q14 sub-question (badge suppression) · Q16 (URL changes) · Q18 (covers) · Q21 (batch capture) |

Resolved and closed: Q01, Q05, Q07, Q08, Q15, Q17, Q23 (table at the top).
