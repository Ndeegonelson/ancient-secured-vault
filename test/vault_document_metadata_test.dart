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
    final metadata = VaultDocumentMetadata.fromStorageMetadata(
      {'accessLevel': 'free', 'category': 'Legal'},
      fallbackAccessLevel: 'premium',
      sizeBytes: 1536,
      updatedAt: DateTime.utc(2026, 6, 9),
    );

    expect(metadata.accessLevel, 'free');
    expect(metadata.category, 'Legal');
    expect(metadata.sizeBytes, 1536);
    expect(metadata.updatedAt, DateTime.utc(2026, 6, 9));

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

  test('filters dashboard documents by category and search text', () {
    final documents = [
      {
        'name': 'Loan Proposal.pdf',
        'category': 'Finance',
        'storagePath': 'free_pdfs/loan.pdf',
        'sizeBytes': 1536,
        'updatedAt': DateTime.utc(2026, 6, 9),
      },
      {
        'name': 'Staff Meeting.pdf',
        'category': 'Operations',
        'storagePath': 'vault_pdfs/staff.pdf',
      },
    ];

    expect(
      filterVaultDocumentsForDashboard(
        documents,
        category: 'Finance',
        query: 'loan',
      ).map((document) => document['name']),
      ['Loan Proposal.pdf'],
    );
    expect(
      filterVaultDocumentsForDashboard(
        documents,
        query: '2026-06-09',
      ).map((document) => document['name']),
      ['Loan Proposal.pdf'],
    );
    expect(
      filterVaultDocumentsForDashboard(
        documents,
        query: 'operations',
      ).map((document) => document['name']),
      ['Staff Meeting.pdf'],
    );
    expect(
      filterVaultDocumentsForDashboard(documents, query: 'missing'),
      isEmpty,
    );
  });

  test('labels vault document sections with visible counts', () {
    expect(
      vaultDocumentSectionTitle(
        title: 'FREE ACCESS ZONE',
        visibleCount: 3,
        totalCount: 3,
      ),
      'FREE ACCESS ZONE (3 PDFs)',
    );
    expect(
      vaultDocumentSectionTitle(
        title: 'MAIN VAULT PDFs',
        visibleCount: 1,
        totalCount: 4,
        hasActiveFilter: true,
      ),
      'MAIN VAULT PDFs (1 of 4 PDFs)',
    );
    expect(
      vaultDocumentSectionTitle(
        title: 'MAIN VAULT PDFs',
        visibleCount: -1,
        totalCount: -1,
      ),
      'MAIN VAULT PDFs (0 PDFs)',
    );
  });

  test('builds compact active dashboard filter labels', () {
    expect(
      vaultDocumentActiveFilterLabels(
        query: ' loan ',
        freeCategory: 'Finance',
        premiumCategory: ' Research ',
      ),
      [
        'Search: loan',
        'Free category: Finance',
        'Protected category: Research',
      ],
    );
    expect(vaultDocumentActiveFilterLabels(), isEmpty);
  });

  test('sorts dashboard documents by category then name', () {
    final documents = [
      {'name': 'z-policy.pdf', 'category': 'Research'},
      {'name': 'Budget.pdf', 'category': 'Finance'},
      {'name': 'audit.pdf', 'category': 'finance'},
      {'name': 'welcome.pdf'},
    ];

    final sorted = sortVaultDocumentsForDisplay(documents);

    expect(sorted.map((document) => document['name']), [
      'audit.pdf',
      'Budget.pdf',
      'welcome.pdf',
      'z-policy.pdf',
    ]);
    expect(identical(sorted.first, documents[1]), isFalse);
  });

  test('formats vault document list details compactly', () {
    expect(formatVaultDocumentSize(null), '');
    expect(formatVaultDocumentSize(512), '512 B');
    expect(formatVaultDocumentSize(1536), '1.5 KB');
    expect(formatVaultDocumentSize(2 * 1024 * 1024), '2.0 MB');
    expect(formatVaultDocumentDate(DateTime.utc(2026, 6, 9)), '2026-06-09');
    expect(
      vaultDocumentListSubtitle({
        'category': 'Finance',
        'sizeBytes': 1536,
        'updatedAt': DateTime.utc(2026, 6, 9),
      }, accessLabel: 'Protected PDF'),
      'Protected PDF | Finance | 1.5 KB | Updated 2026-06-09',
    );
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

  test('chunks vault search index rows below Firestore write limits', () {
    final rows = List.generate(5, (index) => {'pageNumber': index + 1});
    final chunks = chunkVaultSearchIndexRows(rows, batchSize: 2);

    expect(chunks.length, 3);
    expect(chunks.map((chunk) => chunk.length), [2, 2, 1]);
    expect(chunks.first.first['pageNumber'], 1);
    expect(chunks.last.single['pageNumber'], 5);
    expect(chunkVaultSearchIndexRows(const [], batchSize: 2), isEmpty);
  });
}
