import 'package:ancient_secure_docs/services/vault_search_snippet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds stable search terms from a phrase', () {
    expect(vaultSearchTerms('New loan, loan proposal for STEM!'), [
      'proposal',
      'loan',
      'stem',
      'for',
      'new',
    ]);
  });

  test('uses the strongest indexed term for Firestore search', () {
    expect(vaultPrimarySearchTerm('school improvement loan'), 'improvement');
    expect(vaultPrimarySearchTerm(' ? '), '');
  });

  test('builds a bounded list of searched vault terms', () {
    expect(vaultSearchQueryTerms('new loan proposal for school'), [
      'proposal',
      'school',
      'loan',
      'for',
    ]);
    expect(vaultSearchQueryTerms('AI'), ['ai']);
    expect(vaultSearchQueryTerms(' ? '), isEmpty);
  });

  test('describes searched terms and visible results', () {
    expect(
      vaultSearchTermsLabel('school improvement loan'),
      'Matching: improvement, school, loan',
    );
    expect(
      vaultSearchResultsLabel(visibleCount: 3, totalCount: 3),
      '3 matches',
    );
    expect(
      vaultSearchResultsLabel(visibleCount: 1, totalCount: 4),
      '1 of 4 matches',
    );
  });

  test('matches document titles through normalized search terms', () {
    expect(
      vaultTextMatchesSearchTerm('Loan Proposal 2026.pdf', 'proposal'),
      isTrue,
    );
    expect(vaultTextMatchesSearchTerm('Staff Meeting.pdf', 'loan'), isFalse);
  });

  test('matches any useful term from a multi-word query', () {
    expect(
      vaultTextMatchesAnySearchTerm('School loan agreement.pdf', 'bank loan'),
      isTrue,
    );
    expect(
      vaultIndexedTermsMatchQuery(['agenda', 'meeting'], 'staff agenda'),
      isTrue,
    );
    expect(
      vaultIndexedTermsMatchQuery(['minutes', 'meeting'], 'loan agreement'),
      isFalse,
    );
  });

  test('scores stronger title and phrase matches above page-only matches', () {
    final titleScore = vaultSearchMatchScore(
      query: 'loan proposal',
      title: 'Loan Proposal 2026.pdf',
      titleKeywords: ['loan', 'proposal'],
    );
    final pageScore = vaultSearchMatchScore(
      query: 'loan proposal',
      text: 'The page mentions a loan for equipment.',
      pageKeywords: ['loan'],
    );

    expect(titleScore, greaterThan(pageScore));
  });

  test('selects the best matching snippet keyword from a full query', () {
    expect(
      vaultBestSnippetKeyword(
        'This document explains the scholarship proposal.',
        'loan scholarship proposal',
      ),
      'scholarship',
    );
  });

  test('builds a focused snippet around the matching keyword', () {
    final snippet = buildVaultSearchSnippet(
      'Ancient Secure Docs protects files and helps readers find scholarship records quickly.',
      'readers',
      contextCharacters: 12,
    );

    expect(snippet, contains('readers'));
    expect(snippet.startsWith('...'), isTrue);
    expect(snippet.endsWith('...'), isTrue);
  });

  test('falls back to the opening text when the keyword is absent', () {
    final snippet = buildVaultSearchSnippet(
      'A secure vault with carefully indexed documents.',
      'missing',
      contextCharacters: 10,
    );

    expect(snippet, 'A secure vault with ...');
  });

  test('normalizes extracted PDF whitespace before previewing results', () {
    final snippet = buildVaultSearchSnippet(
      'Loan\n\nproposal     prepared\tfor academy expansion.',
      'prepared',
      contextCharacters: 8,
    );

    expect(snippet, '... roposal prepared for aca ...');
  });
  test('groups multiple hits under one document', () {
    final groups = groupVaultSearchResultsByDocument([
      {
        'pdfTitle': 'Finance Guide.pdf',
        'storagePath': 'vault_pdfs/finance-guide.pdf',
        'pageNumber': 2,
        'accessLevel': 'free',
        'category': 'Finance',
      },
      {
        'pdfTitle': 'Finance Guide.pdf',
        'storagePath': 'vault_pdfs/finance-guide.pdf',
        'pageNumber': 5,
        'accessLevel': 'free',
        'category': 'Finance',
      },
    ]);

    expect(groups, hasLength(1));
    expect(groups.single.documentKey, 'storage:vault_pdfs/finance-guide.pdf');
    expect(groups.single.title, 'Finance Guide.pdf');
    expect(groups.single.detailLabel, '2 matches | Free | Finance');
    expect(groups.single.matches.map((result) => result['pageNumber']), [2, 5]);
  });

  test('separates same-title documents when storage paths differ', () {
    final groups = groupVaultSearchResultsByDocument([
      {
        'pdfTitle': 'Policy.pdf',
        'storagePath': 'vault_pdfs/free/policy.pdf',
        'pageNumber': 1,
      },
      {
        'pdfTitle': 'Policy.pdf',
        'storagePath': 'vault_pdfs/premium/policy.pdf',
        'pageNumber': 3,
      },
    ]);

    expect(groups, hasLength(2));
    expect(groups.map((group) => group.documentKey), [
      'storage:vault_pdfs/free/policy.pdf',
      'storage:vault_pdfs/premium/policy.pdf',
    ]);
  });

  test(
    'uses pdf URL before normalized title when grouping fallback results',
    () {
      final groups = groupVaultSearchResultsByDocument([
        {
          'pdfTitle': 'Policy Guide.pdf',
          'pdfUrl': 'https://example.com/free-policy.pdf',
          'pageNumber': 1,
        },
        {
          'pdfTitle': ' Policy   Guide.pdf ',
          'pdfUrl': 'https://example.com/premium-policy.pdf',
          'pageNumber': 3,
        },
      ]);

      expect(groups, hasLength(2));
      expect(groups.map((group) => group.documentKey), [
        'url:https://example.com/free-policy.pdf',
        'url:https://example.com/premium-policy.pdf',
      ]);
    },
  );

  test('groups title-only fallback results by normalized title', () {
    final groups = groupVaultSearchResultsByDocument([
      {'pdfTitle': ' Policy   Guide.pdf ', 'pageNumber': 1},
      {'pdfTitle': 'policy guide.pdf', 'pageNumber': 4},
    ]);

    expect(groups, hasLength(1));
    expect(groups.single.documentKey, 'title:policy guide.pdf');
    expect(groups.single.matches.map((result) => result['pageNumber']), [1, 4]);
  });

  test('builds safe global search result display labels', () {
    final missingData = <String, dynamic>{'pageNumber': '0'};

    expect(vaultSearchDocumentTitle(missingData), 'Untitled document');
    expect(vaultSearchAccessLabel(null), 'Free');
    expect(vaultSearchAccessLabel('premium'), 'Premium');
    expect(vaultSearchCategoryLabel('  '), 'General');
    expect(vaultSearchMatchRowLabel(missingData), 'Page 1 | Free | General');
  });

  test('normalizes global search page numbers for labels and opening', () {
    expect(vaultSearchPageNumber(5), 5);
    expect(vaultSearchPageNumber('7'), 7);
    expect(vaultSearchPageNumber('0'), 1);
    expect(vaultSearchPageNumber(null), 1);
    expect(
      vaultSearchMatchRowLabel({
        'pageNumber': '5',
        'accessLevel': 'free',
        'category': 'Finance',
      }),
      'Page 5 | Free | Finance',
    );
  });
}
