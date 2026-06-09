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
}
