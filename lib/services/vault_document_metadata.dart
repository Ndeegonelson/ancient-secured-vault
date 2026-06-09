const vaultDocumentCategories = [
  'General',
  'Education',
  'Finance',
  'Legal',
  'Operations',
  'Research',
];

const vaultSearchIndexWriteBatchLimit = 450;

class VaultUploadOptions {
  const VaultUploadOptions({required this.accessLevel, required this.category});

  final String accessLevel;
  final String category;

  String get storageFolder =>
      accessLevel == 'free' ? 'free_pdfs' : 'vault_pdfs';
}

class VaultDocumentMetadata {
  const VaultDocumentMetadata({
    required this.accessLevel,
    required this.category,
    this.sizeBytes,
    this.updatedAt,
  });

  factory VaultDocumentMetadata.fromStorageMetadata(
    Map<String, String>? customMetadata, {
    required String fallbackAccessLevel,
    int? sizeBytes,
    DateTime? updatedAt,
  }) {
    return VaultDocumentMetadata(
      accessLevel: normalizeVaultAccessLevel(
        customMetadata?['accessLevel'],
        fallback: fallbackAccessLevel,
      ),
      category: normalizeVaultDocumentCategory(customMetadata?['category']),
      sizeBytes: sizeBytes,
      updatedAt: updatedAt,
    );
  }

  final String accessLevel;
  final String category;
  final int? sizeBytes;
  final DateTime? updatedAt;
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

class VaultDocumentInventorySummary {
  const VaultDocumentInventorySummary({
    required this.freeCount,
    required this.premiumCount,
    required this.categoryCounts,
  });

  factory VaultDocumentInventorySummary.fromDocuments({
    required Iterable<Map<String, dynamic>> freeDocuments,
    required Iterable<Map<String, dynamic>> premiumDocuments,
  }) {
    final categories = <String, ({int freeCount, int premiumCount})>{};

    void countDocument(Map<String, dynamic> document, {required bool isFree}) {
      final category = normalizeVaultDocumentCategory(
        document['category']?.toString(),
      );
      final current = categories[category] ?? (freeCount: 0, premiumCount: 0);
      categories[category] = (
        freeCount: current.freeCount + (isFree ? 1 : 0),
        premiumCount: current.premiumCount + (isFree ? 0 : 1),
      );
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
    );
  }

  final int freeCount;
  final int premiumCount;
  final List<VaultDocumentCategoryCount> categoryCounts;

  int get totalCount => freeCount + premiumCount;
  bool get hasDocuments => totalCount > 0;

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
