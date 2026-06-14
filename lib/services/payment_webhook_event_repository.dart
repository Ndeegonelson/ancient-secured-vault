import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentWebhookProvider { stripe, paystack, unknown }

enum PaymentWebhookStatus { processing, processed, failed, unknown }

class PaymentWebhookEventRecord {
  const PaymentWebhookEventRecord({
    required this.id,
    required this.provider,
    required this.status,
    this.eventId = '',
    this.eventType = '',
    this.userEmail = '',
    this.requestId = '',
    this.paymentReference = '',
    this.subscriptionId = '',
    this.invoiceId = '',
    this.errorMessage = '',
    this.reason = '',
    this.receivedAt,
    this.updatedAt,
  });

  factory PaymentWebhookEventRecord.fromMap(
    Map<String, dynamic> data, {
    required String id,
  }) {
    return PaymentWebhookEventRecord(
      id: id.trim(),
      provider: readPaymentWebhookProvider(data['provider']),
      status: readPaymentWebhookStatus(data['status']),
      eventId: _readText(data['eventId']),
      eventType: _readText(data['eventType']),
      userEmail: _readEmail(data['userEmail']),
      requestId: _readText(data['requestId']),
      paymentReference: _readText(data['paymentReference']),
      subscriptionId: _readText(data['subscriptionId']),
      invoiceId: _readText(data['invoiceId']),
      errorMessage: _readText(data['errorMessage']),
      reason: _readText(data['reason']),
      receivedAt: data['receivedAt'],
      updatedAt: data['updatedAt'],
    );
  }

  final String id;
  final PaymentWebhookProvider provider;
  final PaymentWebhookStatus status;
  final String eventId;
  final String eventType;
  final String userEmail;
  final String requestId;
  final String paymentReference;
  final String subscriptionId;
  final String invoiceId;
  final String errorMessage;
  final String reason;
  final dynamic receivedAt;
  final dynamic updatedAt;

  dynamic get latestTimestamp => updatedAt ?? receivedAt;
  bool get isFailed => status == PaymentWebhookStatus.failed;
  bool get isProcessing => status == PaymentWebhookStatus.processing;
  bool get isProcessed => status == PaymentWebhookStatus.processed;
  bool get hasIssue => isFailed || errorMessage.isNotEmpty;

  String get providerLabel => paymentWebhookProviderLabel(provider);
  String get statusLabel => paymentWebhookStatusLabel(status);
  String get title {
    final type = eventType.trim();
    if (type.isNotEmpty) return type;
    return eventId.trim().isNotEmpty ? eventId : 'Webhook event';
  }

  String get primaryReference {
    for (final value in [
      paymentReference,
      subscriptionId,
      invoiceId,
      requestId,
      eventId,
    ]) {
      final cleanValue = value.trim();
      if (cleanValue.isNotEmpty) return cleanValue;
    }
    return '';
  }

  static List<PaymentWebhookEventRecord> sortNewest(
    Iterable<PaymentWebhookEventRecord> events,
  ) {
    final sorted = events.toList();
    sorted.sort((a, b) {
      final aTime = a.latestTimestamp;
      final bTime = b.latestTimestamp;
      if (aTime is Timestamp && bTime is Timestamp) {
        return bTime.compareTo(aTime);
      }
      if (aTime is Timestamp) return -1;
      if (bTime is Timestamp) return 1;
      return b.id.compareTo(a.id);
    });

    return sorted;
  }

  static String _readText(dynamic value) => value?.toString().trim() ?? '';

  static String _readEmail(dynamic value) => _readText(value).toLowerCase();
}

abstract interface class PaymentWebhookEventStore {
  Future<List<PaymentWebhookEventRecord>> listRecent({int limit = 50});
}

class PaymentWebhookEventRepository implements PaymentWebhookEventStore {
  PaymentWebhookEventRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<PaymentWebhookEventRecord>> listRecent({int limit = 50}) async {
    final safeLimit = limit < 1 ? 1 : limit;
    final snapshot = await _firestore
        .collection('payment_webhook_events')
        .orderBy('updatedAt', descending: true)
        .limit(safeLimit)
        .get();

    return List.unmodifiable(
      PaymentWebhookEventRecord.sortNewest(
        snapshot.docs.map(
          (doc) => PaymentWebhookEventRecord.fromMap(doc.data(), id: doc.id),
        ),
      ),
    );
  }
}

PaymentWebhookProvider readPaymentWebhookProvider(dynamic value) {
  return switch (value?.toString().trim().toLowerCase()) {
    'stripe' => PaymentWebhookProvider.stripe,
    'paystack' => PaymentWebhookProvider.paystack,
    _ => PaymentWebhookProvider.unknown,
  };
}

String paymentWebhookProviderLabel(PaymentWebhookProvider provider) {
  return switch (provider) {
    PaymentWebhookProvider.stripe => 'Stripe',
    PaymentWebhookProvider.paystack => 'Paystack',
    PaymentWebhookProvider.unknown => 'Unknown',
  };
}

PaymentWebhookStatus readPaymentWebhookStatus(dynamic value) {
  return switch (value?.toString().trim().toLowerCase()) {
    'processing' => PaymentWebhookStatus.processing,
    'processed' => PaymentWebhookStatus.processed,
    'failed' => PaymentWebhookStatus.failed,
    _ => PaymentWebhookStatus.unknown,
  };
}

String paymentWebhookStatusLabel(PaymentWebhookStatus status) {
  return switch (status) {
    PaymentWebhookStatus.processing => 'Processing',
    PaymentWebhookStatus.processed => 'Processed',
    PaymentWebhookStatus.failed => 'Failed',
    PaymentWebhookStatus.unknown => 'Unknown',
  };
}
