import 'dart:convert';

/// Capture outcome for a chapter. `complete` is only ever written after every
/// required asset is on disk and verified.
enum CaptureStatus { capturing, complete, partial, failed }

CaptureStatus captureStatusFromName(String? name) => CaptureStatus.values
    .firstWhere((s) => s.name == name, orElse: () => CaptureStatus.failed);

enum AssetStatus { pending, downloading, stored, failed }

AssetStatus assetStatusFromName(String? name) => AssetStatus.values.firstWhere(
  (s) => s.name == name,
  orElse: () => AssetStatus.failed,
);

class AssetEntry {
  const AssetEntry({
    required this.index,
    required this.sourceUrl,
    required this.status,
    this.relativePath,
    this.mimeType,
    this.byteSize,
    this.width,
    this.height,
    this.domWidth,
    this.domHeight,
    this.dimensionsVerified = false,
    this.error,
  });

  factory AssetEntry.fromJson(Map<String, dynamic> json) => AssetEntry(
    index: (json['index'] as num).toInt(),
    sourceUrl: json['sourceUrl'] as String,
    status: assetStatusFromName(json['status'] as String?),
    relativePath: json['relativePath'] as String?,
    mimeType: json['mimeType'] as String?,
    byteSize: (json['byteSize'] as num?)?.toInt(),
    width: (json['width'] as num?)?.toInt(),
    height: (json['height'] as num?)?.toInt(),
    domWidth: (json['domWidth'] as num?)?.toInt(),
    domHeight: (json['domHeight'] as num?)?.toInt(),
    dimensionsVerified: json['dimensionsVerified'] == true,
    error: json['error'] as String?,
  );

  /// 1-based position in reading order (DOM order, not filename order).
  final int index;
  final String sourceUrl;
  final AssetStatus status;

  /// Relative to the chapter directory, e.g. `assets/001.png`. Never absolute:
  /// the iOS app-container path changes between installs.
  final String? relativePath;
  final String? mimeType;
  final int? byteSize;

  /// Intrinsic pixel size. Once [dimensionsVerified] is true these were read
  /// from the stored file's own header — the source of truth for layout. Until
  /// then they are whatever the page reported, kept only as a best guess.
  final int? width;
  final int? height;

  /// What the page's DOM reported at probe time. Diagnostics only: attributes
  /// and rendered boxes routinely disagree with the actual file, which is
  /// exactly the disagreement this field makes visible.
  final int? domWidth;
  final int? domHeight;

  /// True once width/height were decoded from the downloaded bytes rather
  /// than trusted from the DOM.
  final bool dimensionsVerified;
  final String? error;

  bool get isStored => status == AssetStatus.stored && relativePath != null;

  AssetEntry copyWith({
    AssetStatus? status,
    String? relativePath,
    String? mimeType,
    int? byteSize,
    int? width,
    int? height,
    int? domWidth,
    int? domHeight,
    bool? dimensionsVerified,
    String? error,
  }) => AssetEntry(
    index: index,
    sourceUrl: sourceUrl,
    status: status ?? this.status,
    relativePath: relativePath ?? this.relativePath,
    mimeType: mimeType ?? this.mimeType,
    byteSize: byteSize ?? this.byteSize,
    width: width ?? this.width,
    height: height ?? this.height,
    domWidth: domWidth ?? this.domWidth,
    domHeight: domHeight ?? this.domHeight,
    dimensionsVerified: dimensionsVerified ?? this.dimensionsVerified,
    error: error ?? this.error,
  );

  Map<String, dynamic> toJson() => {
    'index': index,
    'sourceUrl': sourceUrl,
    'status': status.name,
    if (relativePath != null) 'relativePath': relativePath,
    if (mimeType != null) 'mimeType': mimeType,
    if (byteSize != null) 'byteSize': byteSize,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (domWidth != null) 'domWidth': domWidth,
    if (domHeight != null) 'domHeight': domHeight,
    if (dimensionsVerified) 'dimensionsVerified': true,
    if (error != null) 'error': error,
  };
}

/// Self-describing chapter package descriptor, written into the chapter
/// directory. It is what lets the app reconcile files against the database
/// after a crash — and what would let an export work without the database.
class ChapterManifest {
  const ChapterManifest({
    required this.schemaVersion,
    required this.chapterId,
    required this.libraryItemId,
    required this.sourceUrl,
    required this.title,
    required this.capturedAt,
    required this.status,
    required this.detectedImageCount,
    required this.storedImageCount,
    required this.assets,
    this.canonicalUrl,
    this.nextUrl,
    this.sequence,
    this.statusReason,
  });

  factory ChapterManifest.fromJson(Map<String, dynamic> json) =>
      ChapterManifest(
        schemaVersion: (json['schemaVersion'] as num).toInt(),
        chapterId: json['chapterId'] as String,
        libraryItemId: json['libraryItemId'] as String,
        sourceUrl: json['sourceUrl'] as String,
        canonicalUrl: json['canonicalUrl'] as String?,
        title: json['title'] as String,
        capturedAt: DateTime.parse(json['capturedAt'] as String),
        status: captureStatusFromName(json['status'] as String?),
        statusReason: json['statusReason'] as String?,
        detectedImageCount: (json['detectedImageCount'] as num).toInt(),
        storedImageCount: (json['storedImageCount'] as num).toInt(),
        nextUrl: json['nextUrl'] as String?,
        sequence: (json['sequence'] as num?)?.toInt(),
        assets: (json['assets'] as List<dynamic>)
            .map(
              (e) => AssetEntry.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
      );

  factory ChapterManifest.decode(String jsonText) =>
      ChapterManifest.fromJson(jsonDecode(jsonText) as Map<String, dynamic>);

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String chapterId;
  final String libraryItemId;
  final String sourceUrl;
  final String? canonicalUrl;
  final String title;
  final DateTime capturedAt;
  final CaptureStatus status;
  final String? statusReason;
  final int detectedImageCount;
  final int storedImageCount;
  final String? nextUrl;
  final int? sequence;
  final List<AssetEntry> assets;

  List<AssetEntry> get storedAssets =>
      assets.where((a) => a.isStored).toList(growable: false);

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'chapterId': chapterId,
    'libraryItemId': libraryItemId,
    'sourceUrl': sourceUrl,
    if (canonicalUrl != null) 'canonicalUrl': canonicalUrl,
    'title': title,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'status': status.name,
    if (statusReason != null) 'statusReason': statusReason,
    'detectedImageCount': detectedImageCount,
    'storedImageCount': storedImageCount,
    if (nextUrl != null) 'nextUrl': nextUrl,
    if (sequence != null) 'sequence': sequence,
    'assets': assets.map((a) => a.toJson()).toList(),
  };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  ChapterManifest copyWith({
    CaptureStatus? status,
    String? statusReason,
    int? storedImageCount,
    String? nextUrl,
    List<AssetEntry>? assets,
  }) => ChapterManifest(
    schemaVersion: schemaVersion,
    chapterId: chapterId,
    libraryItemId: libraryItemId,
    sourceUrl: sourceUrl,
    canonicalUrl: canonicalUrl,
    title: title,
    capturedAt: capturedAt,
    status: status ?? this.status,
    statusReason: statusReason ?? this.statusReason,
    detectedImageCount: detectedImageCount,
    storedImageCount: storedImageCount ?? this.storedImageCount,
    nextUrl: nextUrl ?? this.nextUrl,
    sequence: sequence,
    assets: assets ?? this.assets,
  );
}
