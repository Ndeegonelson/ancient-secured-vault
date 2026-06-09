import 'package:ancient_secure_docs/services/vault_search_snippet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
