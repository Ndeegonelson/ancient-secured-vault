const vaultDocumentCategories = [
  'General',
  'Education',
  'Finance',
  'Legal',
  'Operations',
  'Research',
];

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
  });

  factory VaultDocumentMetadata.fromStorageMetadata(
    Map<String, String>? customMetadata, {
    required String fallbackAccessLevel,
  }) {
    return VaultDocumentMetadata(
      accessLevel: normalizeVaultAccessLevel(
        customMetadata?['accessLevel'],
        fallback: fallbackAccessLevel,
      ),
      category: normalizeVaultDocumentCategory(customMetadata?['category']),
    );
  }

  final String accessLevel;
  final String category;
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
    this.skippedCount = 0,
  });

  final int indexedCount;
  final int skippedCount;

  int get inspectedCount => indexedCount + skippedCount;

  VaultDocumentIndexingSummary addIndexed() {
    return VaultDocumentIndexingSummary(
      indexedCount: indexedCount + 1,
      skippedCount: skippedCount,
    );
  }

  VaultDocumentIndexingSummary addSkipped() {
    return VaultDocumentIndexingSummary(
      indexedCount: indexedCount,
      skippedCount: skippedCount + 1,
    );
  }

  VaultDocumentIndexingSummary merge(VaultDocumentIndexingSummary other) {
    return VaultDocumentIndexingSummary(
      indexedCount: indexedCount + other.indexedCount,
      skippedCount: skippedCount + other.skippedCount,
    );
  }

  String get displayMessage {
    if (inspectedCount == 0) return 'No vault PDFs were found to index.';

    return 'Vault indexing complete: $indexedCount indexed, '
        '$skippedCount skipped.';
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
