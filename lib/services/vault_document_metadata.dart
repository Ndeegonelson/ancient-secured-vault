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
