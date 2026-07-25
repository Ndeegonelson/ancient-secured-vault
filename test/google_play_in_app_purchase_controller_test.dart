import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:ancient_secure_docs/services/google_play_in_app_purchase_controller.dart';

void main() {
  group('isGooglePlayAlreadyOwnedError', () {
    test('recognizes Google Play already-subscribed messages', () {
      expect(
        isGooglePlayAlreadyOwnedError(
          "You're already subscribed to Ancient Secured Vault Premium.",
        ),
        isTrue,
      );
    });

    test('recognizes billing response codes', () {
      expect(isGooglePlayAlreadyOwnedError('ITEM_ALREADY_OWNED'), isTrue);
      expect(
        isGooglePlayAlreadyOwnedError('billing_response_item_already_owned'),
        isTrue,
      );
      expect(
        isGooglePlayAlreadyOwnedError(
          IAPError(
            source: 'google_play',
            code: 'billing_response_item_already_owned',
            message: 'Item is already owned.',
          ),
        ),
        isTrue,
      );
    });

    test('does not treat unrelated billing failures as ownership', () {
      expect(isGooglePlayAlreadyOwnedError('SERVICE_UNAVAILABLE'), isFalse);
      expect(isGooglePlayAlreadyOwnedError('User cancelled'), isFalse);
    });
  });
}
