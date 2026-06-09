import 'dart:math';

import 'package:ancient_secure_docs/services/reader_device_identity.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryDeviceStorage implements ReaderDeviceIdentityStorage {
  final Map<String, String> values = {};

  @override
  String? read(String key) => values[key];

  @override
  void write(String key, String value) {
    values[key] = value;
  }
}

void main() {
  test('reuses a stored browser device id', () {
    final storage = MemoryDeviceStorage()..write('device-key', 'stored-device');
    final resolver = ReaderDeviceIdentityResolver(
      storage: storage,
      storageKey: 'device-key',
      platformProvider: () => 'Windows Chrome',
      deviceIdFactory: () => 'new-device',
    );

    final identity = resolver.resolve();

    expect(identity.id, 'stored-device');
    expect(identity.label, 'Windows browser');
    expect(identity.platform, 'Windows Chrome');
    expect(identity.isKnown, isTrue);
    expect(storage.values['device-key'], 'stored-device');
  });

  test('creates and stores a device id when none exists', () {
    final storage = MemoryDeviceStorage();
    final resolver = ReaderDeviceIdentityResolver(
      storage: storage,
      storageKey: 'device-key',
      platformProvider: () => 'Android WebView',
      deviceIdFactory: () => 'created-device',
    );

    final identity = resolver.resolve();

    expect(identity.id, 'created-device');
    expect(identity.label, 'Android browser');
    expect(storage.values['device-key'], 'created-device');
  });

  test('labels common browser platforms compactly', () {
    expect(readerDeviceLabel('MacIntel'), 'Mac browser');
    expect(readerDeviceLabel('iPhone'), 'iOS browser');
    expect(readerDeviceLabel('Linux x86_64'), 'Linux browser');
    expect(readerDeviceLabel(''), 'Unknown browser device');
    expect(readerDeviceLabel('SomethingElse'), 'Browser device');
  });

  test('creates stable-looking device ids with entropy', () {
    final id = createReaderDeviceId(random: Random(1));

    expect(id.startsWith('device-'), isTrue);
    expect(id.split('-'), hasLength(3));
    expect(id.length, greaterThan(20));
  });
}
