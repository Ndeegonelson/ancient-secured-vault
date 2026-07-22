import 'package:flutter_test/flutter_test.dart';
import 'package:ancient_secure_docs/services/premium_subscription_offer.dart';

void main() {
  test('web and Android premium offer is USD 120 for 12 months', () {
    expect(webAndroidPremiumAnnualPriceUsd, 120);
    expect(webAndroidPremiumAnnualTermMonths, 12);
    expect(webAndroidPremiumAnnualPriceLabel, r'$120 USD per year');
    expect(webAndroidPremiumAnnualTermLabel, '12 months of premium access');
  });
}
