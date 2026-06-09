import 'package:ancient_secure_docs/services/vault_document_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes vault access levels safely', () {
    expect(normalizeVaultAccessLevel('FREE'), 'free');
    expect(normalizeVaultAccessLevel('premium'), 'premium');
    expect(normalizeVaultAccessLevel('unknown', fallback: 'free'), 'free');
    expect(normalizeVaultAccessLevel(null), 'premium');
  });

  test('normalizes known document categories without losing custom values', () {
    expect(normalizeVaultDocumentCategory(null), 'General');
    expect(normalizeVaultDocumentCategory(' research '), 'Research');
    expect(normalizeVaultDocumentCategory('Scholarship'), 'Scholarship');
  });

  test('reads storage metadata with fallbacks for older documents', () {
    final metadata = VaultDocumentMetadata.fromStorageMetadata({
      'accessLevel': 'free',
      'category': 'Legal',
    }, fallbackAccessLevel: 'premium');

    expect(metadata.accessLevel, 'free');
    expect(metadata.category, 'Legal');

    final legacyMetadata = VaultDocumentMetadata.fromStorageMetadata(
      const {},
      fallbackAccessLevel: 'premium',
    );

    expect(legacyMetadata.accessLevel, 'premium');
    expect(legacyMetadata.category, 'General');
  });

  test('builds and applies category filters for dashboard documents', () {
    final documents = [
      {'name': 'A.pdf', 'category': 'Finance'},
      {'name': 'B.pdf', 'category': 'Research'},
      {'name': 'C.pdf', 'category': 'finance'},
    ];

    expect(vaultDocumentCategoryOptions(documents), ['Finance', 'Research']);
    expect(
      filterVaultDocumentsByCategory(
        documents,
        'Finance',
      ).map((document) => document['name']),
      ['A.pdf', 'C.pdf'],
    );
    expect(filterVaultDocumentsByCategory(documents, ''), documents);
  });

  test('summarizes vault inventory by access level and category', () {
    final summary = VaultDocumentInventorySummary.fromDocuments(
      freeDocuments: [
        {'name': 'A.pdf', 'category': 'Finance'},
        {'name': 'B.pdf', 'category': 'finance'},
      ],
      premiumDocuments: [
        {'name': 'C.pdf', 'category': 'Research'},
        {'name': 'D.pdf', 'category': 'Finance'},
        {'name': 'E.pdf'},
      ],
    );

    expect(summary.freeCount, 2);
    expect(summary.premiumCount, 3);
    expect(summary.totalCount, 5);
    expect(summary.hasDocuments, isTrue);
    expect(summary.categoryCounts.map((count) => count.category), [
      'Finance',
      'General',
      'Research',
    ]);
    expect(summary.categoryCounts.first.freeCount, 2);
    expect(summary.categoryCounts.first.premiumCount, 1);
    expect(summary.categoryCounts.first.totalCount, 3);
    expect(summary.countForCategory('finance')?.totalCount, 3);
    expect(summary.countForCategory('Unknown'), isNull);
  });

  test('summarizes vault indexing results for admin feedback', () {
    final summary = const VaultDocumentIndexingSummary()
        .addIndexed()
        .addRefreshed()
        .addSkipped()
        .merge(const VaultDocumentIndexingSummary(indexedCount: 2));

    expect(summary.indexedCount, 3);
    expect(summary.refreshedCount, 1);
    expect(summary.skippedCount, 1);
    expect(summary.inspectedCount, 5);
    expect(
      summary.displayMessage,
      'Vault indexing complete: 3 indexed, 1 refreshed, 1 skipped.',
    );
    expect(
      const VaultDocumentIndexingSummary().displayMessage,
      'No vault PDFs were found to index.',
    );
  });
}
