import '../browser/page_data.dart';
import '../core/config.dart';

/// Why an image was not treated as chapter content. Kept per-image so the
/// debug view can explain every rejection instead of showing a silent gap.
enum RejectReason {
  noUrl,
  hidden,
  pageChrome,
  tooSmall,
  bannerAspect,
  duplicateUrl,
  outsideContentColumn,
}

class ImageCandidate {
  const ImageCandidate({
    required this.url,
    required this.domIndex,
    required this.width,
    required this.height,
    required this.documentTop,
  });

  final String url;
  final int domIndex;
  final int width;
  final int height;
  final int documentTop;
}

class RejectedImage {
  const RejectedImage(this.url, this.domIndex, this.reason);
  final String? url;
  final int domIndex;
  final RejectReason reason;
}

class CandidateSelection {
  const CandidateSelection({required this.accepted, required this.rejected});
  final List<ImageCandidate> accepted;
  final List<RejectedImage> rejected;

  int get acceptedCount => accepted.length;
}

/// Pick the chapter's content images out of everything the page contains.
///
/// Deliberately a heuristic, not a site rule: size floor, chrome/hidden
/// exclusion, banner-aspect rejection, URL de-duplication, then a width
/// cluster to keep only the dominant content column. Preserves DOM order,
/// which is reading order — filenames are not trusted.
CandidateSelection selectImageCandidates(
  List<PageImage> images, {
  CaptureConfig config = kDefaultCaptureConfig,
}) {
  final rejected = <RejectedImage>[];
  final survivors = <_Scored>[];
  final seenUrls = <String>{};

  for (final img in images) {
    final url = img.effectiveUrl;
    if (url == null) {
      rejected.add(RejectedImage(null, img.domIndex, RejectReason.noUrl));
      continue;
    }
    if (img.hidden) {
      rejected.add(RejectedImage(url, img.domIndex, RejectReason.hidden));
      continue;
    }
    if (img.inPageChrome) {
      rejected.add(RejectedImage(url, img.domIndex, RejectReason.pageChrome));
      continue;
    }

    final w = img.effectiveWidth;
    final h = img.effectiveHeight;
    if (w < config.minImageEdge || h < config.minImageEdge) {
      rejected.add(RejectedImage(url, img.domIndex, RejectReason.tooSmall));
      continue;
    }
    if (h > 0 && w / h > config.maxAspectRatio) {
      rejected.add(RejectedImage(url, img.domIndex, RejectReason.bannerAspect));
      continue;
    }
    if (!seenUrls.add(url)) {
      rejected.add(RejectedImage(url, img.domIndex, RejectReason.duplicateUrl));
      continue;
    }

    survivors.add(_Scored(img, url, w, h));
  }

  final kept = _dominantWidthCluster(survivors, config, rejected);
  kept.sort((a, b) => a.image.domIndex.compareTo(b.image.domIndex));

  return CandidateSelection(
    accepted: [
      for (final s in kept)
        ImageCandidate(
          url: s.url,
          domIndex: s.image.domIndex,
          width: s.width,
          height: s.height,
          documentTop: s.image.documentTop,
        ),
    ],
    rejected: rejected,
  );
}

/// Webtoon panels share a column width. Group survivors by similar width and
/// keep the dominant group — this removes a stray large image (a promo, a
/// related-series thumbnail) that passed every other filter.
///
/// If no group is convincing enough, keep everything: better a slightly noisy
/// chapter than a silently truncated one.
List<_Scored> _dominantWidthCluster(
  List<_Scored> survivors,
  CaptureConfig config,
  List<RejectedImage> rejected,
) {
  if (survivors.length < config.minClusterSize) return survivors;

  final clusters = <List<_Scored>>[];
  for (final s in survivors) {
    var placed = false;
    for (final cluster in clusters) {
      final ref = cluster.first.width;
      final delta = (s.width - ref).abs() / ref;
      if (delta <= config.widthClusterTolerance) {
        cluster.add(s);
        placed = true;
        break;
      }
    }
    if (!placed) clusters.add([s]);
  }

  clusters.sort((a, b) {
    final byCount = b.length.compareTo(a.length);
    if (byCount != 0) return byCount;
    return _area(b).compareTo(_area(a));
  });

  final best = clusters.first;
  if (best.length < config.minClusterSize) return survivors;

  final keptIds = best.map((s) => s.image.domIndex).toSet();
  for (final s in survivors) {
    if (!keptIds.contains(s.image.domIndex)) {
      rejected.add(
        RejectedImage(
          s.url,
          s.image.domIndex,
          RejectReason.outsideContentColumn,
        ),
      );
    }
  }
  return best;
}

int _area(List<_Scored> cluster) =>
    cluster.fold(0, (sum, s) => sum + s.width * s.height);

class _Scored {
  const _Scored(this.image, this.url, this.width, this.height);
  final PageImage image;
  final String url;
  final int width;
  final int height;
}
