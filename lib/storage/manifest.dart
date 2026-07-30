import 'dart:convert';

/// Save outcome for an entry. `complete` is only ever written after every
/// required asset is on disk and verified.
enum SaveStatus { saving, complete, partial, failed }

SaveStatus saveStatusFromName(String? name) => SaveStatus.values.firstWhere(
  (s) => s.name == name,
  orElse: () => SaveStatus.failed,
);

enum AssetStatus { pending, fetching, stored, failed }

AssetStatus assetStatusFromName(String? name) => AssetStatus.values.firstWhere(
  (s) => s.name == name,
  orElse: () => AssetStatus.failed,
);

class EntryAsset {
  const EntryAsset({
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

  factory EntryAsset.fromJson(Map<String, dynamic> json) => EntryAsset(
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

  /// Relative to the entry directory, e.g. `assets/001.png`. Never absolute:
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

  EntryAsset copyWith({
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
  }) => EntryAsset(
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

/// Self-describing entry package descriptor, written into the entry directory.
///
/// This is also where an entry's **pages** live: [assets] is the ordered page
/// list, next to the bytes it describes, rather than a second copy in SQLite
/// that could disagree with the files. It is what lets the app reconcile files
/// against the database after a crash, and what would let an export work
/// without the database at all.
class EntryManifest {
  const EntryManifest({
    required this.schemaVersion,
    required this.entryId,
    required this.sourceUrl,
    required this.title,
    required this.savedAt,
    required this.status,
    required this.detectedAssetCount,
    required this.storedAssetCount,
    required this.assets,
    this.collectionId,
    this.canonicalUrl,
    this.nextUrl,
    this.entryOrder,
    this.statusReason,
    this.contentKind,
    this.contentKindConfidence,
    this.contentKindIsUserSet,
    this.host,
    this.publishedAt,
    this.sourceMarker,
    this.entryNumber,
  });

  factory EntryManifest.fromJson(Map<String, dynamic> json) => EntryManifest(
    schemaVersion: (json['schemaVersion'] as num).toInt(),
    entryId: json['entryId'] as String,
    collectionId: json['collectionId'] as String?,
    sourceUrl: json['sourceUrl'] as String,
    host: json['host'] as String?,
    canonicalUrl: json['canonicalUrl'] as String?,
    title: json['title'] as String,
    savedAt: DateTime.parse(json['savedAt'] as String),
    status: saveStatusFromName(json['status'] as String?),
    statusReason: json['statusReason'] as String?,
    detectedAssetCount: (json['detectedAssetCount'] as num).toInt(),
    storedAssetCount: (json['storedAssetCount'] as num).toInt(),
    nextUrl: json['nextUrl'] as String?,
    entryOrder: (json['entryOrder'] as num?)?.toInt(),
    contentKind: json['contentKind'] as String?,
    contentKindConfidence: json['contentKindConfidence'] as String?,
    contentKindIsUserSet: json['contentKindIsUserSet'] as bool?,
    publishedAt: json['publishedAt'] == null
        ? null
        : DateTime.tryParse(json['publishedAt'] as String),
    sourceMarker: json['sourceMarker'] as String?,
    entryNumber: (json['entryNumber'] as num?)?.toDouble(),
    assets: (json['assets'] as List<dynamic>)
        .map((e) => EntryAsset.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );

  factory EntryManifest.decode(String jsonText) =>
      EntryManifest.fromJson(jsonDecode(jsonText) as Map<String, dynamic>);

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String entryId;

  /// Null for a standalone entry. The manifest records the same nullable
  /// relationship the schema does, so a recovered entry stays standalone
  /// instead of being adopted by whichever collection happens to be nearby.
  final String? collectionId;
  final String sourceUrl;

  /// Source domain, for attribution when the database row is gone.
  final String? host;
  final String? canonicalUrl;
  final String title;
  final DateTime savedAt;
  final SaveStatus status;
  final String? statusReason;
  final int detectedAssetCount;
  final int storedAssetCount;
  final String? nextUrl;
  final int? entryOrder;

  /// The detected content shape at save time (`ContentKind.name`), how much it
  /// was trusted, and whether a person set it. Recorded rather than re-derived:
  /// a guess made later, with no page to look at, would be weaker than the one
  /// the save already made.
  final String? contentKind;
  final String? contentKindConfidence;
  final bool? contentKindIsUserSet;

  /// Publication date, only when the page stated one unambiguously.
  final DateTime? publishedAt;

  /// The marker the source printed, kept verbatim, and the number it carried.
  final String? sourceMarker;
  final double? entryNumber;

  /// The entry's ordered pages. `index` is reading order.
  final List<EntryAsset> assets;

  /// How many pages this entry has. The honest count comes from the files.
  int get pageCount => storedAssets.length;

  List<EntryAsset> get storedAssets =>
      assets.where((a) => a.isStored).toList(growable: false);

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'entryId': entryId,
    if (collectionId != null) 'collectionId': collectionId,
    'sourceUrl': sourceUrl,
    if (host != null) 'host': host,
    if (canonicalUrl != null) 'canonicalUrl': canonicalUrl,
    'title': title,
    'savedAt': savedAt.toUtc().toIso8601String(),
    'status': status.name,
    if (statusReason != null) 'statusReason': statusReason,
    'detectedAssetCount': detectedAssetCount,
    'storedAssetCount': storedAssetCount,
    if (nextUrl != null) 'nextUrl': nextUrl,
    if (entryOrder != null) 'entryOrder': entryOrder,
    if (contentKind != null) 'contentKind': contentKind,
    if (contentKindConfidence != null)
      'contentKindConfidence': contentKindConfidence,
    if (contentKindIsUserSet == true) 'contentKindIsUserSet': true,
    if (publishedAt != null)
      'publishedAt': publishedAt!.toUtc().toIso8601String(),
    if (sourceMarker != null) 'sourceMarker': sourceMarker,
    if (entryNumber != null) 'entryNumber': entryNumber,
    'assets': assets.map((a) => a.toJson()).toList(),
  };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  EntryManifest copyWith({
    SaveStatus? status,
    String? statusReason,
    int? storedAssetCount,
    String? nextUrl,
    List<EntryAsset>? assets,
  }) => EntryManifest(
    schemaVersion: schemaVersion,
    entryId: entryId,
    collectionId: collectionId,
    sourceUrl: sourceUrl,
    canonicalUrl: canonicalUrl,
    title: title,
    savedAt: savedAt,
    status: status ?? this.status,
    statusReason: statusReason ?? this.statusReason,
    detectedAssetCount: detectedAssetCount,
    storedAssetCount: storedAssetCount ?? this.storedAssetCount,
    nextUrl: nextUrl ?? this.nextUrl,
    entryOrder: entryOrder,
    contentKind: contentKind,
    contentKindConfidence: contentKindConfidence,
    contentKindIsUserSet: contentKindIsUserSet,
    host: host,
    publishedAt: publishedAt,
    sourceMarker: sourceMarker,
    entryNumber: entryNumber,
    assets: assets ?? this.assets,
  );
}
