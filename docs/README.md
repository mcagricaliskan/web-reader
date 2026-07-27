# Web Reader — docs

**Web Reader** — *archive and read web content offline.*

A reader-focused autonomous web browser and a persistent local reading library. The user browses to a
chapter in an embedded WebView, starts a capture session, and the app scrolls, waits, saves, finds the
next chapter, and repeats — then keeps the reading state forever.

> `Web Reader` / `com.mcagricaliskan.webreader` is a **development identity, not a finalised brand**
> ([DECISIONS.md](./DECISIONS.md) D22). The internal slug `webread` (storage directory, database
> filename, JS bridge namespace) is deliberately decoupled from the display name and does not change
> if the product is renamed.

**Status: pre-implementation.** No Flutter project exists yet. These documents define what we build
and in what order.

## The first product checkpoint

> **The first successful vertical slice is: open one webtoon chapter, load all relevant images, save
> the actual image files locally, restart or go offline, and read the saved chapter without
> contacting the source website.**

Everything in the architecture is judged by whether it enables that flow. It is
[MVP_PLAN.md](./MVP_PLAN.md) **M2**.

## Index

| Doc | Owns |
|---|---|
| **[PRODUCT.md](./PRODUCT.md)** | **Start here.** Working identity, vision, core concepts + glossary, user journeys, the two product checkpoints, library lifecycle, reading state, non-goals, success criteria. |
| **[TECHNICAL_SPEC.md](./TECHNICAL_SPEC.md)** | Architecture, package choices + version policy, capture state machine, page-stability algorithm, extraction / next-page / update-check pipelines, error model, platform notes, security. |
| **[DATA_MODEL.md](./DATA_MODEL.md)** | Entities, relationships, statuses, SQLite tables, indexes, chapter manifest, the four chapter pointers. |
| **[MVP_PLAN.md](./MVP_PLAN.md)** | Staged **PoC (M0–M3) → MVP (M4–M11) → Full product**: goal, deliverable, acceptance criteria, risks. |
| **[DECISIONS.md](./DECISIONS.md)** | D01–D24 — what was decided, why, and what would reverse it. |
| **[OPEN_QUESTIONS.md](./OPEN_QUESTIONS.md)** | Q01–Q22 — unresolved, each with a default in force so nothing blocks. |

## Read order

1. **PRODUCT.md** — what we're building and the vocabulary everything else uses.
2. **DECISIONS.md** — the constraints the design works inside.
3. **TECHNICAL_SPEC.md** — how it works.
4. **DATA_MODEL.md** — what gets stored.
5. **MVP_PLAN.md** — what to build next.
6. **OPEN_QUESTIONS.md** — what we deliberately left open, and the default in force meanwhile.

## Precedence on conflict

`PRODUCT.md` > `DECISIONS.md` > `TECHNICAL_SPEC.md` / `DATA_MODEL.md` > `MVP_PLAN.md` > code.

Once code exists, code wins over `TECHNICAL_SPEC.md` on *as-built* details — but a divergence is a
bug in one of the two, so record which in `DECISIONS.md`.

## Conventions used in these docs

- `[Assumption]` — a stated guess we are building on. If wrong, something changes; the line says what.
- `[Unverified]` — believed true, not checked. Verify before relying on it.
- `[Verified <date>]` — checked against the local toolchain or package source on that date.
  Verification dates are re-checkable claims, not guarantees.
- **No package version constraints appear in these docs**, deliberately — see
  [DECISIONS.md](./DECISIONS.md) D21. Versions are resolved at implementation time and pinned by
  `pubspec.lock`.
- MVP vs. Future are separated in every section. Future items exist to keep seams honest, not to be
  built.
