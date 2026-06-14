import 'package:ancient_secure_docs/services/payment_webhook_event_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads webhook event records with safe defaults', () {
    final event = PaymentWebhookEventRecord.fromMap({
      'provider': ' Stripe ',
      'status': 'failed',
      'eventId': ' evt_123 ',
      'eventType': ' checkout.session.completed ',
      'userEmail': ' Reader@Example.COM ',
      'requestId': ' request-1 ',
      'paymentReference': ' cs_test_123 ',
      'subscriptionId': ' sub_test_123 ',
      'invoiceId': ' in_test_123 ',
      'errorMessage': ' duplicate issue ',
      'reason': ' retry ',
    }, id: ' webhook-1 ');

    expect(event.id, 'webhook-1');
    expect(event.provider, PaymentWebhookProvider.stripe);
    expect(event.status, PaymentWebhookStatus.failed);
    expect(event.eventId, 'evt_123');
    expect(event.eventType, 'checkout.session.completed');
    expect(event.userEmail, 'reader@example.com');
    expect(event.requestId, 'request-1');
    expect(event.paymentReference, 'cs_test_123');
    expect(event.subscriptionId, 'sub_test_123');
    expect(event.invoiceId, 'in_test_123');
    expect(event.errorMessage, 'duplicate issue');
    expect(event.reason, 'retry');
    expect(event.providerLabel, 'Stripe');
    expect(event.statusLabel, 'Failed');
    expect(event.title, 'checkout.session.completed');
    expect(event.primaryReference, 'cs_test_123');
    expect(event.hasIssue, isTrue);
  });

  test('sorts webhook events newest first', () {
    final older = PaymentWebhookEventRecord.fromMap({
      'provider': 'paystack',
      'status': 'processed',
      'updatedAt': Timestamp.fromDate(DateTime(2026, 6, 13, 10)),
    }, id: 'older');
    final newer = PaymentWebhookEventRecord.fromMap({
      'provider': 'stripe',
      'status': 'processing',
      'receivedAt': Timestamp.fromDate(DateTime(2026, 6, 13, 11)),
    }, id: 'newer');

    final sorted = PaymentWebhookEventRecord.sortNewest([older, newer]);

    expect(sorted.map((event) => event.id), ['newer', 'older']);
  });

  test('labels unknown webhook values safely', () {
    final event = PaymentWebhookEventRecord.fromMap({
      'provider': 'other',
      'status': 'held',
      'eventId': 'evt_other',
    }, id: 'unknown');

    expect(event.provider, PaymentWebhookProvider.unknown);
    expect(event.status, PaymentWebhookStatus.unknown);
    expect(paymentWebhookProviderLabel(event.provider), 'Unknown');
    expect(paymentWebhookStatusLabel(event.status), 'Unknown');
    expect(event.title, 'evt_other');
    expect(event.primaryReference, 'evt_other');
  });
}
