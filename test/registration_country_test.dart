import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_secure_docs/main.dart';

void main() {
  test('registration country follows the device locale', () {
    expect(
      registrationCountryForLocale(const Locale('en', 'NG')).name,
      'Nigeria',
    );
    expect(
      registrationCountryForLocale(const Locale('fr', 'FR')).name,
      'France',
    );
  });

  test('registration country has a neutral fallback', () {
    expect(registrationCountryForLocale(const Locale('en')).code, 'UN');
    expect(registrationCountryForLocale(const Locale('en', 'ZZ')).code, 'UN');
  });

  test('uses the first supported device locale without a Ghana default', () {
    expect(
      registrationCountryForLocales(const [
        Locale('en'),
        Locale('en', 'NG'),
      ]).code,
      'NG',
    );
    expect(registrationCountryForLocales(const [Locale('en')]).code, 'UN');
  });

  test('native device country takes an exact supported country code', () {
    expect(registrationCountryForCode('gh').name, 'Ghana');
    expect(registrationCountryForCode('NG').name, 'Nigeria');
    expect(registrationCountryForCode(null).code, 'UN');
  });
}
