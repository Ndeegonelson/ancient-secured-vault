import 'dart:math';

class ReaderDeviceIdentity {
  const ReaderDeviceIdentity({
    required this.id,
    required this.label,
    required this.platform,
  });

  final String id;
  final String label;
  final String platform;

  bool get isKnown => id.trim().isNotEmpty;
}

abstract interface class ReaderDeviceIdentityStorage {
  String? read(String key);

  void write(String key, String value);
}

class ReaderDeviceIdentityResolver {
  ReaderDeviceIdentityResolver({
    required this.storage,
    required this.platformProvider,
    required this.deviceIdFactory,
    this.storageKey = 'ancientSecureDocs.deviceId',
  });

  final ReaderDeviceIdentityStorage storage;
  final String Function() platformProvider;
  final String Function() deviceIdFactory;
  final String storageKey;

  ReaderDeviceIdentity resolve() {
    final existingId = storage.read(storageKey)?.trim();
    final id = existingId == null || existingId.isEmpty
        ? _createAndStoreDeviceId()
        : existingId;
    final platform = platformProvider().trim();

    return ReaderDeviceIdentity(
      id: id,
      label: readerDeviceLabel(platform),
      platform: platform,
    );
  }

  String _createAndStoreDeviceId() {
    final id = deviceIdFactory().trim();
    if (id.isNotEmpty) {
      storage.write(storageKey, id);
    }

    return id;
  }
}

String createReaderDeviceId({Random? random}) {
  final generator = random ?? Random.secure();
  final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final entropy = List.generate(
    4,
    (_) => generator.nextInt(0x100000000).toRadixString(36).padLeft(7, '0'),
  ).join();

  return 'device-$timestamp-$entropy';
}

String readerDeviceLabel(String platform) {
  final normalized = platform.trim();
  if (normalized.isEmpty) return 'Unknown browser device';

  final lower = normalized.toLowerCase();
  if (lower.contains('windows')) return 'Windows browser';
  if (lower.contains('mac')) return 'Mac browser';
  if (lower.contains('iphone') || lower.contains('ipad')) {
    return 'iOS browser';
  }
  if (lower.contains('android')) return 'Android browser';
  if (lower.contains('linux')) return 'Linux browser';

  return 'Browser device';
}
