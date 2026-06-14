import 'package:ancient_secure_docs/services/user_subscription_request_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads subscription request data with safe defaults', () {
    final request = UserSubscriptionRequest.fromMap({
      'userEmail': ' Reader@Example.COM ',
      'requestedPlan': '',
      'status': 'in_review',
      'paymentMethod': 'ancient_coin',
      'paymentStatus': 'pending_confirmation',
      'paymentReference': ' AC-123 ',
      'message': 'I want premium access.',
      'source': 'dashboard',
    }, id: ' request-1 ');

    expect(request.id, 'request-1');
    expect(request.userEmail, 'reader@example.com');
    expect(request.requestedPlan, 'premium');
    expect(request.status, UserSubscriptionRequestStatus.reviewing);
    expect(request.paymentMethod, UserSubscriptionPaymentMethod.ancientCoin);
    expect(
      request.paymentStatus,
      UserSubscriptionPaymentStatus.pendingConfirmation,
    );
    expect(request.paymentReference, 'AC-123');
    expect(request.message, 'I want premium access.');
    expect(request.source, 'dashboard');
    expect(request.hasMessage, isTrue);
  });

  test('sorts subscription requests newest first and ignores empty users', () {
    final older = UserSubscriptionRequest.fromMap({
      'userEmail': 'older@example.com',
      'createdAt': Timestamp.fromDate(DateTime(2026, 6, 1)),
    }, id: 'older');
    final newer = UserSubscriptionRequest.fromMap({
      'userEmail': 'newer@example.com',
      'updatedAt': Timestamp.fromDate(DateTime(2026, 6, 8)),
    }, id: 'newer');
    final missingUser = UserSubscriptionRequest.fromMap({
      'message': 'No email.',
    }, id: 'missing');

    final sorted = UserSubscriptionRequest.sortNewest([
      older,
      missingUser,
      newer,
    ]);

    expect(sorted.map((request) => request.id), ['newer', 'older']);
  });

  test('builds subscription request payloads and labels statuses', () {
    final payload = const UserSubscriptionRequestDraft(
      userEmail: ' Reader@Example.COM ',
      requestedPlan: '',
      paymentMethod: UserSubscriptionPaymentMethod.stripe,
      paymentReference: ' pi_123 ',
      message: ' Please upgrade me. ',
    ).toFirestore(createdAt: 'now');

    expect(payload, {
      'userEmail': 'reader@example.com',
      'requestedPlan': 'premium',
      'paymentMethod': 'stripe',
      'paymentStatus': 'awaiting_payment',
      'paymentReference': 'pi_123',
      'message': 'Please upgrade me.',
      'source': 'reader_dashboard',
      'status': 'open',
      'createdAt': 'now',
    });
    expect(
      userSubscriptionRequestStatusKey(UserSubscriptionRequestStatus.approved),
      'approved',
    );
    expect(
      userSubscriptionRequestStatusLabel(
        UserSubscriptionRequestStatus.declined,
      ),
      'Declined',
    );
    expect(
      readUserSubscriptionRequestStatus('accepted'),
      UserSubscriptionRequestStatus.approved,
    );
    expect(
      readUserSubscriptionPaymentMethod('ancient coin'),
      UserSubscriptionPaymentMethod.ancientCoin,
    );
    expect(
      userSubscriptionPaymentMethodLabel(
        UserSubscriptionPaymentMethod.paystack,
      ),
      'Paystack',
    );
    expect(
      userSubscriptionPaymentMethodKey(UserSubscriptionPaymentMethod.manual),
      'manual',
    );
    expect(
      userSubscriptionPaymentMethodLabel(UserSubscriptionPaymentMethod.manual),
      'Manual proof',
    );
    expect(
      readUserSubscriptionPaymentMethod('bank transfer'),
      UserSubscriptionPaymentMethod.manual,
    );
    expect(
      readUserSubscriptionPaymentStatus('paid'),
      UserSubscriptionPaymentStatus.confirmed,
    );
    expect(
      userSubscriptionPaymentStatusKey(
        UserSubscriptionPaymentStatus.pendingConfirmation,
      ),
      'pending_confirmation',
    );
    expect(
      userSubscriptionPaymentStatusLabel(
        UserSubscriptionPaymentStatus.awaitingPayment,
      ),
      'Awaiting payment',
    );
  });

  test('manual payment proof starts in pending confirmation', () {
    final payload = const UserSubscriptionRequestDraft(
      userEmail: 'reader@example.com',
      paymentMethod: UserSubscriptionPaymentMethod.manual,
      paymentStatus: UserSubscriptionPaymentStatus.pendingConfirmation,
      paymentReference: 'MOMO-7788',
      message: 'Paid through mobile money.',
    ).toFirestore(createdAt: 'now');

    expect(payload['paymentMethod'], 'manual');
    expect(payload['paymentStatus'], 'pending_confirmation');
    expect(payload['paymentReference'], 'MOMO-7788');
    expect(payload['message'], 'Paid through mobile money.');
  });

  test('flags manual proofs that need admin review', () {
    final request = UserSubscriptionRequest.fromMap({
      'userEmail': 'reader@example.com',
      'paymentMethod': 'manual',
      'paymentStatus': 'pending_confirmation',
      'status': 'open',
    }, id: 'request-1');

    expect(request.isManualProof, isTrue);
    expect(request.isOpenForReview, isTrue);
    expect(request.isManualProofAwaitingReview, isTrue);
  });
}
