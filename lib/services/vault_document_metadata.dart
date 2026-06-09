const vaultDocumentCategories = [
  'General',
  'Education',
  'Finance',
  'Legal',
  'Operations',
  'Research',
];

const vaultSearchIndexWriteBatchLimit = 450;
const vaultDocumentMetadataSchemaVersion = '2';
const vaultReaderModeStandardPdf = 'standard-pdf';
const vaultReaderModeProtectedImage = 'protected-image';
const vaultDeliveryModeDirectStorage = 'direct-storage';
const vaultDeliveryModeProtectedStorage = 'protected-storage';
const vaultProtectionModeStandard = 'standard';
const vaultProtectionModeCopyDeterred = 'copy-deterred-watermarked';
const vaultSearchModeFullTextIndex = 'full-text-index';

class VaultUploadOptions {
  const VaultUploadOptions({required this.accessLevel, required this.category});

  final String accessLevel;
  final String category;

  VaultDocumentProfile get profile => VaultDocumentProfile.forAccessLevel(
    accessLevel: accessLevel,
    category: category,
  );

  String get storageFolder => profile.storageFolder;
}

class VaultDocumentProfile {
  const VaultDocumentProfile({
    required this.accessLevel,
    required this.category,
    required this.readerMode,
    required this.deliveryMode,
    required this.protectionMode,
    required this.searchMode,
    this.schemaVersion = vaultDocumentMetadataSchemaVersion,
  });

  factory VaultDocumentProfile.forAccessLevel({
    required String accessLevel,
    required String category,
  }) {
    final normalizedAccessLevel = normalizeVaultAccessLevel(accessLevel);
    final normalizedCategory = normalizeVaultDocumentCategory(category);
    final isFree = normalizedAccessLevel == 'free';

    return VaultDocumentProfile(
      accessLevel: normalizedAccessLevel,
      category: normalizedCategory,
      readerMode: isFree
          ? vaultReaderModeStandardPdf
          : vaultReaderModeProtectedImage,
      deliveryMode: isFree
          ? vaultDeliveryModeDirectStorage
          : vaultDeliveryModeProtectedStorage,
      protectionMode: isFree
          ? vaultProtectionModeStandard
          : vaultProtectionModeCopyDeterred,
      searchMode: vaultSearchModeFullTextIndex,
    );
  }

  final String schemaVersion;
  final String accessLevel;
  final String category;
  final String readerMode;
  final String deliveryMode;
  final String protectionMode;
  final String searchMode;

  String get storageFolder =>
      accessLevel == 'free' ? 'free_pdfs' : 'vault_pdfs';

  bool get usesProtectedImageReader =>
      readerMode == vaultReaderModeProtectedImage;

  Map<String, String> toStorageMetadata({
    String uploadedBy = '',
    String originalFileName = '',
  }) {
    return {
      'schemaVersion': schemaVersion,
      'accessLevel': accessLevel,
      'category': category,
      'readerMode': readerMode,
      'deliveryMode': deliveryMode,
      'protectionMode': protectionMode,
      'searchMode': searchMode,
      if (uploadedBy.trim().isNotEmpty) 'uploadedBy': uploadedBy.trim(),
      if (originalFileName.trim().isNotEmpty)
        'originalFileName': originalFileName.trim(),
    };
  }

  Map<String, dynamic> toDocumentMap() {
    return {
      'schemaVersion': schemaVersion,
      'accessLevel': accessLevel,
      'category': category,
      'readerMode': readerMode,
      'deliveryMode': deliveryMode,
      'protectionMode': protectionMode,
      'searchMode': searchMode,
    };
  }
}

class VaultDocumentMetadata {
  const VaultDocumentMetadata({
    required this.accessLevel,
    required this.category,
    required this.readerMode,
    required this.deliveryMode,
    required this.protectionMode,
    required this.searchMode,
    required this.schemaVersion,
    this.sizeBytes,
    this.updatedAt,
  });

  factory VaultDocumentMetadata.fromStorageMetadata(
    Map<String, String>? customMetadata, {
    required String fallbackAccessLevel,
    int? sizeBytes,
    DateTime? updatedAt,
  }) {
    final accessLevel = normalizeVaultAccessLevel(
      customMetadata?['accessLevel'],
      fallback: fallbackAccessLevel,
    );
    final category = normalizeVaultDocumentCategory(
      customMetadata?['category'],
    );
    final defaultProfile = VaultDocumentProfile.forAccessLevel(
      accessLevel: accessLevel,
      category: category,
    );

    return VaultDocumentMetadata(
      accessLevel: accessLevel,
      category: category,
      readerMode: normalizeVaultReaderMode(
        customMetadata?['readerMode'],
        fallback: defaultProfile.readerMode,
      ),
      deliveryMode: normalizeVaultDeliveryMode(
        customMetadata?['deliveryMode'],
        fallback: defaultProfile.deliveryMode,
      ),
      protectionMode: normalizeVaultProtectionMode(
        customMetadata?['protectionMode'],
        fallback: defaultProfile.protectionMode,
      ),
      searchMode: normalizeVaultSearchMode(
        customMetadata?['searchMode'],
        fallback: defaultProfile.searchMode,
      ),
      schemaVersion: normalizeVaultMetadataSchemaVersion(
        customMetadata?['schemaVersion'],
      ),
      sizeBytes: sizeBytes,
      updatedAt: updatedAt,
    );
  }

  final String accessLevel;
  final String category;
  final String readerMode;
  final String deliveryMode;
  final String protectionMode;
  final String searchMode;
  final String schemaVersion;
  final int? sizeBytes;
  final DateTime? updatedAt;

  bool get usesProtectedImageReader =>
      readerMode == vaultReaderModeProtectedImage;

  Map<String, dynamic> toDocumentMap() {
    return {
      'schemaVersion': schemaVersion,
      'accessLevel': accessLevel,
      'category': category,
      'readerMode': readerMode,
      'deliveryMode': deliveryMode,
      'protectionMode': protectionMode,
      'searchMode': searchMode,
      if (sizeBytes != null) 'sizeBytes': sizeBytes,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }
}

class VaultDocumentCategoryCount {
  const VaultDocumentCategoryCount({
    required this.category,
    required this.freeCount,
    required this.premiumCount,
  });

  final String category;
  final int freeCount;
  final int premiumCount;

  int get totalCount => freeCount + premiumCount;
}

class VaultRecentDocument {
  const VaultRecentDocument({
    required this.name,
    required this.accessLevel,
    required this.category,
    required this.updatedAt,
  });

  final String name;
  final String accessLevel;
  final String category;
  final DateTime updatedAt;

  String get accessLabel => accessLevel == 'free' ? 'Free' : 'Protected';
}

class VaultDocumentInventorySummary {
  const VaultDocumentInventorySummary({
    required this.freeCount,
    required this.premiumCount,
    required this.categoryCounts,
    required this.latestDocument,
  });

  factory VaultDocumentInventorySummary.fromDocuments({
    required Iterable<Map<String, dynamic>> freeDocuments,
    required Iterable<Map<String, dynamic>> premiumDocuments,
  }) {
    final categories = <String, ({int freeCount, int premiumCount})>{};
    VaultRecentDocument? latestDocument;

    void countDocument(Map<String, dynamic> document, {required bool isFree}) {
      final category = normalizeVaultDocumentCategory(
        document['category']?.toString(),
      );
      final current = categories[category] ?? (freeCount: 0, premiumCount: 0);
      categories[category] = (
        freeCount: current.freeCount + (isFree ? 1 : 0),
        premiumCount: current.premiumCount + (isFree ? 0 : 1),
      );

      final updatedAt = document['updatedAt'];
      if (updatedAt is DateTime &&
          (latestDocument == null ||
              updatedAt.isAfter(latestDocument!.updatedAt))) {
        latestDocument = VaultRecentDocument(
          name: document['name']?.toString().trim().isEmpty ?? true
              ? 'Untitled PDF'
              : document['name'].toString().trim(),
          accessLevel: isFree ? 'free' : 'premium',
          category: category,
          updatedAt: updatedAt,
        );
      }
    }

    for (final document in freeDocuments) {
      countDocument(document, isFree: true);
    }

    for (final document in premiumDocuments) {
      countDocument(document, isFree: false);
    }

    final categoryCounts =
        categories.entries
            .map(
              (entry) => VaultDocumentCategoryCount(
                category: entry.key,
                freeCount: entry.value.freeCount,
                premiumCount: entry.value.premiumCount,
              ),
            )
            .toList()
          ..sort(
            (a, b) =>
                a.category.toLowerCase().compareTo(b.category.toLowerCase()),
          );

    return VaultDocumentInventorySummary(
      freeCount: freeDocuments.length,
      premiumCount: premiumDocuments.length,
      categoryCounts: List.unmodifiable(categoryCounts),
      latestDocument: latestDocument,
    );
  }

  final int freeCount;
  final int premiumCount;
  final List<VaultDocumentCategoryCount> categoryCounts;
  final VaultRecentDocument? latestDocument;

  int get totalCount => freeCount + premiumCount;
  bool get hasDocuments => totalCount > 0;
  bool get hasDatedDocument => latestDocument != null;

  VaultDocumentCategoryCount? countForCategory(String category) {
    final normalizedCategory = normalizeVaultDocumentCategory(
      category,
    ).toLowerCase();

    for (final count in categoryCounts) {
      if (count.category.toLowerCase() == normalizedCategory) return count;
    }

    return null;
  }
}

class VaultDocumentIndexingSummary {
  const VaultDocumentIndexingSummary({
    this.indexedCount = 0,
    this.refreshedCount = 0,
    this.skippedCount = 0,
  });

  final int indexedCount;
  final int refreshedCount;
  final int skippedCount;

  int get inspectedCount => indexedCount + refreshedCount + skippedCount;

  VaultDocumentIndexingSummary addIndexed() {
    return VaultDocumentIndexingSummary(
      indexedCount: indexedCount + 1,
      refreshedCount: refreshedCount,
      skippedCount: skippedCount,
    );
  }

  VaultDocumentIndexingSummary addRefreshed() {
    return VaultDocumentIndexingSummary(
      indexedCount: indexedCount,
      refreshedCount: refreshedCount + 1,
      skippedCount: skippedCount,
    );
  }

  VaultDocumentIndexingSummary addSkipped() {
    return VaultDocumentIndexingSummary(
      indexedCount: indexedCount,
      refreshedCount: refreshedCount,
      skippedCount: skippedCount + 1,
    );
  }

  VaultDocumentIndexingSummary merge(VaultDocumentIndexingSummary other) {
    return VaultDocumentIndexingSummary(
      indexedCount: indexedCount + other.indexedCount,
      refreshedCount: refreshedCount + other.refreshedCount,
      skippedCount: skippedCount + other.skippedCount,
    );
  }

  String get displayMessage {
    if (inspectedCount == 0) return 'No vault PDFs were found to index.';

    return 'Vault indexing complete: $indexedCount indexed, '
        '$refreshedCount refreshed, $skippedCount skipped.';
  }
}

String normalizeVaultAccessLevel(String? value, {String fallback = 'premium'}) {
  final normalized = value?.trim().toLowerCase() ?? '';
  if (normalized == 'free' || normalized == 'premium') return normalized;

  return fallback.trim().toLowerCase() == 'free' ? 'free' : 'premium';
}

String normalizeVaultMetadataSchemaVersion(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? '1' : normalized;
}

String normalizeVaultReaderMode(String? value, {required String fallback}) {
  final normalized = value?.trim().toLowerCase() ?? '';
  if (normalized == vaultReaderModeStandardPdf ||
      normalized == vaultReaderModeProtectedImage) {
    return normalized;
  }

  return fallback;
}

String normalizeVaultDeliveryMode(String? value, {required String fallback}) {
  final normalized = value?.trim().toLowerCase() ?? '';
  if (normalized == vaultDeliveryModeDirectStorage ||
      normalized == vaultDeliveryModeProtectedStorage) {
    return normalized;
  }

  return fallback;
}

String normalizeVaultProtectionMode(String? value, {required String fallback}) {
  final normalized = value?.trim().toLowerCase() ?? '';
  if (normalized == vaultProtectionModeStandard ||
      normalized == vaultProtectionModeCopyDeterred) {
    return normalized;
  }

  return fallback;
}

String normalizeVaultSearchMode(String? value, {required String fallback}) {
  final normalized = value?.trim().toLowerCase() ?? '';
  if (normalized == vaultSearchModeFullTextIndex) return normalized;

  return fallback;
}

String normalizeVaultDocumentCategory(String? value) {
  final category = value?.trim() ?? '';
  if (category.isEmpty) return vaultDocumentCategories.first;

  for (final option in vaultDocumentCategories) {
    if (option.toLowerCase() == category.toLowerCase()) return option;
  }

  return category;
}

List<String> vaultDocumentCategoryOptions(
  Iterable<Map<String, dynamic>> documents,
) {
  final categories = documents
      .map(
        (document) =>
            normalizeVaultDocumentCategory(document['category']?.toString()),
      )
      .where((category) => category.isNotEmpty)
      .toSet()
      .toList();

  categories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return List.unmodifiable(categories);
}

List<Map<String, dynamic>> filterVaultDocumentsByCategory(
  Iterable<Map<String, dynamic>> documents,
  String category,
) {
  final normalizedCategory = category.trim().toLowerCase();
  if (normalizedCategory.isEmpty) return List.unmodifiable(documents);

  return List.unmodifiable(
    documents.where((document) {
      return normalizeVaultDocumentCategory(
            document['category']?.toString(),
          ).toLowerCase() ==
          normalizedCategory;
    }),
  );
}

List<Map<String, dynamic>> filterVaultDocumentsForDashboard(
  Iterable<Map<String, dynamic>> documents, {
  String category = '',
  String query = '',
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final categoryMatches = filterVaultDocumentsByCategory(documents, category);
  if (normalizedQuery.isEmpty) return categoryMatches;

  return List.unmodifiable(
    categoryMatches.where((document) {
      final searchableText = [
        document['name']?.toString() ?? '',
        document['storagePath']?.toString() ?? '',
        normalizeVaultDocumentCategory(document['category']?.toString()),
        formatVaultDocumentSize(document['sizeBytes'] as num?),
        formatVaultDocumentDate(
          document['updatedAt'] is DateTime
              ? document['updatedAt'] as DateTime
              : null,
        ),
      ].join(' ').toLowerCase();

      return searchableText.contains(normalizedQuery);
    }),
  );
}

String vaultDocumentSectionTitle({
  required String title,
  required int visibleCount,
  required int totalCount,
  bool hasActiveFilter = false,
}) {
  final safeVisibleCount = visibleCount < 0 ? 0 : visibleCount;
  final safeTotalCount = totalCount < 0 ? 0 : totalCount;
  final visibleLabel = safeVisibleCount == 1 ? 'PDF' : 'PDFs';

  if (!hasActiveFilter || safeVisibleCount == safeTotalCount) {
    return '$title ($safeVisibleCount $visibleLabel)';
  }

  return '$title ($safeVisibleCount of $safeTotalCount PDFs)';
}

List<String> vaultDocumentActiveFilterLabels({
  String query = '',
  String freeCategory = '',
  String premiumCategory = '',
}) {
  final labels = <String>[];
  final cleanQuery = query.trim();
  final cleanFreeCategory = freeCategory.trim();
  final cleanPremiumCategory = premiumCategory.trim();

  if (cleanQuery.isNotEmpty) {
    labels.add('Search: $cleanQuery');
  }
  if (cleanFreeCategory.isNotEmpty) {
    labels.add('Free category: $cleanFreeCategory');
  }
  if (cleanPremiumCategory.isNotEmpty) {
    labels.add('Protected category: $cleanPremiumCategory');
  }

  return List.unmodifiable(labels);
}

List<Map<String, dynamic>> sortVaultDocumentsForDisplay(
  Iterable<Map<String, dynamic>> documents,
) {
  final sortedDocuments = documents
      .map((document) => Map<String, dynamic>.from(document))
      .toList();

  sortedDocuments.sort((left, right) {
    final categoryComparison =
        normalizeVaultDocumentCategory(
          left['category']?.toString(),
        ).toLowerCase().compareTo(
          normalizeVaultDocumentCategory(
            right['category']?.toString(),
          ).toLowerCase(),
        );
    if (categoryComparison != 0) return categoryComparison;

    final leftName = left['name']?.toString().trim().toLowerCase() ?? '';
    final rightName = right['name']?.toString().trim().toLowerCase() ?? '';
    return leftName.compareTo(rightName);
  });

  return List.unmodifiable(sortedDocuments);
}

String formatVaultDocumentSize(num? sizeBytes) {
  if (sizeBytes == null || sizeBytes <= 0) return '';

  const units = ['B', 'KB', 'MB', 'GB'];
  var size = sizeBytes.toDouble();
  var unitIndex = 0;

  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }

  final precision = unitIndex == 0 || size >= 10 ? 0 : 1;
  return '${size.toStringAsFixed(precision)} ${units[unitIndex]}';
}

String formatVaultDocumentDate(DateTime? updatedAt) {
  if (updatedAt == null) return '';

  final month = updatedAt.month.toString().padLeft(2, '0');
  final day = updatedAt.day.toString().padLeft(2, '0');
  return '${updatedAt.year}-$month-$day';
}

String vaultDocumentListSubtitle(
  Map<String, dynamic> document, {
  required String accessLabel,
}) {
  final details = <String>[
    accessLabel,
    normalizeVaultDocumentCategory(document['category']?.toString()),
  ];
  final sizeLabel = formatVaultDocumentSize(document['sizeBytes'] as num?);
  final updatedLabel = formatVaultDocumentDate(
    document['updatedAt'] is DateTime
        ? document['updatedAt'] as DateTime
        : null,
  );

  if (sizeLabel.isNotEmpty) details.add(sizeLabel);
  if (updatedLabel.isNotEmpty) details.add('Updated $updatedLabel');

  return details.join(' | ');
}

List<List<Map<String, dynamic>>> chunkVaultSearchIndexRows(
  Iterable<Map<String, dynamic>> rows, {
  int batchSize = vaultSearchIndexWriteBatchLimit,
}) {
  assert(batchSize > 0);

  final chunks = <List<Map<String, dynamic>>>[];
  var currentChunk = <Map<String, dynamic>>[];

  for (final row in rows) {
    if (currentChunk.length >= batchSize) {
      chunks.add(List.unmodifiable(currentChunk));
      currentChunk = <Map<String, dynamic>>[];
    }
    currentChunk.add(row);
  }

  if (currentChunk.isNotEmpty) {
    chunks.add(List.unmodifiable(currentChunk));
  }

  return List.unmodifiable(chunks);
}
