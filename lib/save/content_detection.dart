/// Generic, domain-independent detection of what a page *is* and how it
/// continues.
///
/// Pure Dart over a [PageProbe], so every rule below is unit-testable against a
/// literal fixture. Three properties are load-bearing:
///
/// 1. **No hostname ever appears here.** Not in a condition, not in a list, not
///    in a comment as an example. Every signal is a standard HTML semantic
///    (`rel`, `<article>`, `<time datetime>`, pagination `aria-label`) or a
///    measurement any browser can make.
/// 2. **Low confidence is a real answer.** Most of the web is
///    `unknownWebContent` at `low`, and the label system prints "Saved item" for
///    it rather than inventing a structure.
/// 3. **A number is not a structure.** `/section/12` in a URL proves nothing;
///    the page has to *declare* a relationship before a sequence is claimed.
library;

import '../browser/page_data.dart';
import '../library/content_shape.dart';
import 'next_page.dart';

/// What kind of thing this page is.
ContentShape detectContentKind(PageProbe probe) {
  final c = probe.content;

  // Real pagination beats everything: a control that states "page 3 of 12" is
  // the source telling us its own structure.
  if (_hasPagerRange(c)) {
    return const ContentShape(
      kind: ContentKind.paginatedDocument,
      confidence: ShapeConfidence.high,
      basis: 'pagination control with a numeric range',
    );
  }

  // A declared publication date on a page that also reads as prose is a post.
  // The date alone is not enough — footers carry copyright years.
  if (c.publishedAt != null && c.looksProse) {
    return ContentShape(
      kind: ContentKind.datedPost,
      confidence: c.hasArticleElement
          ? ShapeConfidence.high
          : ShapeConfidence.medium,
      basis:
          'declared publication date + prose'
          '${c.hasArticleElement ? ' + <article>' : ''}',
    );
  }

  // Image-dominant: measured area against measured prose. Deliberately says
  // nothing about what the images depict — there is no path from "mostly
  // images" to any genre in this file or anywhere else in the app.
  if (c.looksImageDominant) {
    return ContentShape(
      kind: ContentKind.imageDominant,
      confidence: c.contentImageCount >= 4
          ? ShapeConfidence.high
          : ShapeConfidence.medium,
      basis:
          '${c.contentImageCount} content images, '
          '${c.textLength} chars of prose',
    );
  }

  if (c.looksProse) {
    // A very long single page is a different reading experience from an article,
    // and the reader treats it differently (progress by fraction, no
    // next-page affordance).
    final tall =
        probe.viewportHeight > 0 &&
        probe.documentHeight > probe.viewportHeight * 12;
    if (tall && c.textLength > 20000) {
      return ContentShape(
        kind: ContentKind.longFormDocument,
        confidence: ShapeConfidence.medium,
        basis: '${c.textLength} chars over ${probe.documentHeight}px',
      );
    }
    if (c.hasArticleElement || c.hasMainElement) {
      return ContentShape(
        kind: ContentKind.article,
        confidence: c.hasArticleElement
            ? ShapeConfidence.high
            : ShapeConfidence.medium,
        basis: c.hasArticleElement ? '<article> + prose' : '<main> + prose',
      );
    }
    return const ContentShape(
      kind: ContentKind.article,
      confidence: ShapeConfidence.low,
      basis: 'prose, but no article or main landmark',
    );
  }

  // Saved, readable, and honestly not classified.
  return const ContentShape(
    kind: ContentKind.unknownWebContent,
    confidence: ShapeConfidence.low,
    basis: 'no structural signal strong enough to classify',
  );
}

/// How this page continues, if it does.
///
/// The distinctions the save flow needs are exactly the ones the user has to be
/// told about before a multi-entry save starts: a finite numbered range, one
/// detected next page, an open-ended chain, a dated flow and its direction, a
/// continuous page, or no reliable continuation at all.
SequenceShape detectSequence(
  PageProbe probe, {
  required String currentUrl,
  Set<String> visitedNormalized = const {},
  String? hintHref,
}) {
  final c = probe.content;

  // 1. A pagination control that states a range. Finite, and the total is
  //    published rather than guessed.
  if (_hasPagerRange(c)) {
    final total = c.pagerNumbers.reduce((a, b) => a > b ? a : b);
    return SequenceShape(
      kind: SequenceKind.numberedPagination,
      ordering: OrderingBasis.explicitNumericIndex,
      confidence: ShapeConfidence.high,
      knownTotal: total,
      basis: 'pagination control up to $total',
    );
  }

  // 2. A dated list of sibling items. The *direction* is measured from the
  //    dates, never assumed: "next" moves to an older post on most blogs and a
  //    newer one on some, and getting it backwards saves the wrong end.
  final dated = _datedFlow(c);
  if (dated != null) return dated;

  // 3. Whatever the next-page chain thinks, validated. Note this runs *after*
  //    the structural checks: a next-link inside a numbered pager is still
  //    numbered pagination.
  final next = resolveNextPage(
    probe,
    currentUrl: currentUrl,
    visitedNormalized: visitedNormalized,
    hintHref: hintHref,
    allowUserAssist: false,
  );

  if (next.hasNext) {
    // Both halves declared makes the sequence explicit; only `next` means we
    // can move forward but cannot see the shape, which is open-ended.
    final explicit =
        next.chosen!.strategy == NextStrategy.headRelNext ||
        next.chosen!.strategy == NextStrategy.anchorRelNext;
    if (explicit && c.hasRelPrev) {
      return const SequenceShape(
        kind: SequenceKind.explicitNextPrev,
        ordering: OrderingBasis.detectedNextLink,
        confidence: ShapeConfidence.high,
        basis: 'rel=next and rel=prev both declared',
      );
    }
    return SequenceShape(
      kind: SequenceKind.openEndedNext,
      ordering: OrderingBasis.detectedNextLink,
      // An explicit rel=next is trustworthy as a *link*; the extent is still
      // unknown, which is what open-ended means.
      confidence: explicit ? ShapeConfidence.high : ShapeConfidence.medium,
      basis: 'next page via ${next.chosen!.strategy.label}',
    );
  }

  // 4. A very tall page with no continuation reads top to bottom and ends.
  if (probe.viewportHeight > 0 &&
      probe.documentHeight > probe.viewportHeight * 8) {
    return const SequenceShape(
      kind: SequenceKind.continuousPage,
      ordering: OrderingBasis.discoveryOrder,
      confidence: ShapeConfidence.medium,
      basis: 'one long page, no next control',
    );
  }

  return SequenceShape(
    kind: SequenceKind.none,
    ordering: OrderingBasis.discoveryOrder,
    confidence: ShapeConfidence.high,
    basis: next.considered.isEmpty
        ? 'no continuation controls on the page'
        : 'every continuation candidate was rejected',
  );
}

/// A pager is only a pager when it states a *range*. Two numbers, at least one
/// above 1 — otherwise a single "1" in a footer becomes a document with pages.
bool _hasPagerRange(PageContentSignals c) =>
    c.pagerNumbers.length >= 2 && c.pagerNumbers.any((n) => n > 1);

/// A dated feed, with its direction measured from the dates on the page.
SequenceShape? _datedFlow(PageContentSignals c) {
  final dates = c.listedDates;
  if (dates.length < 3) return null;

  var forward = 0;
  var backward = 0;
  for (var i = 1; i < dates.length; i++) {
    final delta = dates[i].compareTo(dates[i - 1]);
    if (delta > 0) forward++;
    if (delta < 0) backward++;
  }
  final pairs = forward + backward;
  if (pairs == 0) return null;

  // Tolerant, not strict: a pinned post or a "latest" jump link at the top is
  // normal, and a strict rule makes every real page "unknown".
  const threshold = 0.8;
  if (backward / pairs >= threshold) {
    return SequenceShape(
      kind: SequenceKind.reverseChronologicalFeed,
      ordering: OrderingBasis.publicationDate,
      confidence: ShapeConfidence.high,
      basis: '${dates.length} dated items, newest first',
    );
  }
  if (forward / pairs >= threshold) {
    return SequenceShape(
      kind: SequenceKind.chronologicalFeed,
      ordering: OrderingBasis.publicationDate,
      confidence: ShapeConfidence.high,
      basis: '${dates.length} dated items, oldest first',
    );
  }

  // Dated, but the order is not consistent enough to claim a direction. Said
  // plainly rather than picked at random: the direction decides which end of a
  // feed gets saved.
  return SequenceShape(
    kind: SequenceKind.chronologicalFeed,
    ordering: OrderingBasis.discoveryOrder,
    confidence: ShapeConfidence.low,
    basis: '${dates.length} dated items, order unclear',
  );
}
