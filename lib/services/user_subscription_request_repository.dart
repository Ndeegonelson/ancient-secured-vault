import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_access_repository.dart';
import 'user_access_state.dart';

enum UserSubscriptionRequestStatus {
  open,
  reviewing,
  approved,
  declined,
  archived,
}

enum UserSubscriptionPaymentMethod { stripe, paystack, manual, ancientCoin }

enum UserSubscriptionPaymentStatus {
  awaitingPayment,
  pendingConfirmation,
  confirmed,
  failed,
  refunded,
}

class UserSubscriptionRequest {
  const UserSubscriptionRequest({
    required this.id,
    required this.userEmail,
    required this.requestedPlan,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    this.paymentReference = '',
    this.message = '',
    this.source = '',
    this.reviewedByEmail = '',
    this.createdAt,
    this.updatedAt,
  });

  factory UserSubscriptionRequest.fromMap(
    Map<String, dynamic> data, {
    required String id,
  }) {
    return UserSubscriptionRequest(
      id: id.trim(),
      userEmail: emailDocumentId(data['userEmail']?.toString()),
      requestedPlan: _readText(data['requestedPlan'], fallback: 'premium'),
      status: readUserSubscriptionRequestStatus(data['status']),
      paymentMethod: readUserSubscriptionPaymentMethod(
        data['paymentMethod'] ?? data['provider'],
      ),
      paymentStatus: readUserSubscriptionPaymentStatus(data['paymentStatus']),
      paymentReference: _readText(
        data['paymentReference'] ?? data['transactionReference'],
      ),
      message: _readText(data['message']),
      source: _readText(data['source']),
      reviewedByEmail: emailDocumentId(data['reviewedByEmail']?.toString()),
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
    );
  }

  final String id;
  final String userEmail;
  final String requestedPlan;
  final UserSubscriptionRequestStatus status;
  final UserSubscriptionPaymentMethod paymentMethod;
  final UserSubscriptionPaymentStatus paymentStatus;
  final String paymentReference;
  final String message;
  final String source;
  final String reviewedByEmail;
  final dynamic createdAt;
  final dynamic updatedAt;

  bool get hasMessage => message.trim().isNotEmpty;
  dynamic get latestTimestamp => updatedAt ?? createdAt;
  bool get isOpenForReview =>
      status == UserSubscriptionRequestStatus.open ||
      status == UserSubscriptionRequestStatus.reviewing;
  bool get isManualProof =>
      paymentMethod == UserSubscriptionPaymentMethod.manual;
  bool get isManualProofAwaitingReview =>
      isManualProof &&
      isOpenForReview &&
      paymentStatus == UserSubscriptionPaymentStatus.pendingConfirmation;
  bool get isReviewedManualProof =>
      isManualProof &&
      (status == UserSubscriptionRequestStatus.approved ||
          status == UserSubscriptionRequestStatus.declined);

  static List<UserSubscriptionRequest> sortNewest(
    Iterable<UserSubscriptionRequest> requests,
  ) {
    final sorted = requests
        .where((request) => request.userEmail.isNotEmpty)
        .toList();
    sorted.sort((a, b) {
      final aTime = a.latestTimestamp;
      final bTime = b.latestTimestamp;
      if (aTime is Timestamp && bTime is Timestamp) {
        return bTime.compareTo(aTime);
      }
      if (aTime is Timestamp) return -1;
      if (bTime is Timestamp) return 1;
      return a.userEmail.compareTo(b.userEmail);
    });

    return sorted;
  }

  static String _readText(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}

class UserSubscriptionRequestDraft {
  const UserSubscriptionRequestDraft({
    required this.userEmail,
    this.requestedPlan = 'premium',
    this.paymentMethod = UserSubscriptionPaymentMethod.paystack,
    this.paymentStatus = UserSubscriptionPaymentStatus.awaitingPayment,
    this.paymentReference = '',
    this.message = '',
    this.source = 'reader_dashboard',
  });

  final String? userEmail;
  final String requestedPlan;
  final UserSubscriptionPaymentMethod paymentMethod;
  final UserSubscriptionPaymentStatus paymentStatus;
  final String paymentReference;
  final String message;
  final String source;

  Map<String, dynamic> toFirestore({required Object createdAt}) {
    return {
      'userEmail': emailDocumentId(userEmail),
      'requestedPlan': requestedPlan.trim().isEmpty
          ? 'premium'
          : requestedPlan.trim(),
      'paymentMethod': userSubscriptionPaymentMethodKey(paymentMethod),
      'paymentStatus': userSubscriptionPaymentStatusKey(paymentStatus),
      if (paymentReference.trim().isNotEmpty)
        'paymentReference': paymentReference.trim(),
      'message': message.trim(),
      'source': source.trim(),
      'status': userSubscriptionRequestStatusKey(
        UserSubscriptionRequestStatus.open,
      ),
      'createdAt': createdAt,
    };
  }
}

abstract interface class UserSubscriptionRequestStore {
  Future<List<UserSubscriptionRequest>> listRecent({int limit = 50});

  Future<List<UserSubscriptionRequest>> listForUser({
    required String userEmail,
    int limit = 8,
  });

  Future<void> save(UserSubscriptionRequestDraft request);

  Future<void> updateStatus({
    required String requestId,
    required UserSubscriptionRequestStatus status,
    String? changedByEmail,
  });

  Future<void> updatePaymentStatus({
    required String requestId,
    required UserSubscriptionPaymentStatus status,
    String paymentReference = '',
  });

  Future<void> approveRequest({
    required UserSubscriptionRequest request,
    String? changedByEmail,
  });
}

class UserSubscriptionRequestRepository
    implements UserSubscriptionRequestStore {
  UserSubscriptionRequestRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<UserSubscriptionRequest>> listRecent({int limit = 50}) async {
    final safeLimit = limit < 1 ? 1 : limit;
    final snapshot = await _collection
        .orderBy('createdAt', descending: true)
        .limit(safeLimit)
        .get();

    return List.unmodifiable(
      UserSubscriptionRequest.sortNewest(
        snapshot.docs.map(
          (doc) => UserSubscriptionRequest.fromMap(doc.data(), id: doc.id),
        ),
      ),
    );
  }

  @override
  Future<List<UserSubscriptionRequest>> listForUser({
    required String userEmail,
    int limit = 8,
  }) async {
    final normalizedEmail = emailDocumentId(userEmail);
    if (normalizedEmail.isEmpty) return const [];

    final safeLimit = limit < 1 ? 1 : limit;
    final snapshot = await _collection
        .where('userEmail', isEqualTo: normalizedEmail)
        .limit(safeLimit)
        .get();

    return List.unmodifiable(
      UserSubscriptionRequest.sortNewest(
        snapshot.docs.map(
          (doc) => UserSubscriptionRequest.fromMap(doc.data(), id: doc.id),
        ),
      ),
    );
  }

  @override
  Future<void> save(UserSubscriptionRequestDraft request) {
    return _collection.add(
      request.toFirestore(createdAt: FieldValue.serverTimestamp()),
    );
  }

  @override
  Future<void> updateStatus({
    required String requestId,
    required UserSubscriptionRequestStatus status,
    String? changedByEmail,
  }) {
    final documentId = requestId.trim();
    if (documentId.isEmpty) {
      throw ArgumentError('A subscription request id is required.');
    }

    final normalizedChangedByEmail = emailDocumentId(changedByEmail);
    return _collection.doc(documentId).update({
      'status': userSubscriptionRequestStatusKey(status),
      if (normalizedChangedByEmail.isNotEmpty)
        'reviewedByEmail': normalizedChangedByEmail,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updatePaymentStatus({
    required String requestId,
    required UserSubscriptionPaymentStatus status,
    String paymentReference = '',
  }) {
    final documentId = requestId.trim();
    if (documentId.isEmpty) {
      throw ArgumentError('A subscription request id is required.');
    }

    final reference = paymentReference.trim();
    return _collection.doc(documentId).update({
      'paymentStatus': userSubscriptionPaymentStatusKey(status),
      if (reference.isNotEmpty) 'paymentReference': reference,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> approveRequest({
    required UserSubscriptionRequest request,
    String? changedByEmail,
  }) async {
    final requestId = request.id.trim();
    final userEmail = emailDocumentId(request.userEmail);
    if (requestId.isEmpty) {
      throw ArgumentError('A subscription request id is required.');
    }
    if (userEmail.isEmpty) {
      throw ArgumentError('A request user email is required.');
    }

    final userDoc = _firestore.collection('users').doc(userEmail);
    final requestDoc = _collection.doc(requestId);
    final userSnapshot = await userDoc.get();
    final previousStatus = UserAccessState.fromFirestore(
      userSnapshot.data(),
    ).subscriptionStatus;
    final batch = _firestore.batch();
    final paymentMethod = userSubscriptionPaymentMethodKey(
      request.paymentMethod,
    );
    final paymentReference = request.paymentReference.trim();

    batch.set(requestDoc, {
      'status': userSubscriptionRequestStatusKey(
        UserSubscriptionRequestStatus.approved,
      ),
      'paymentStatus': userSubscriptionPaymentStatusKey(
        UserSubscriptionPaymentStatus.confirmed,
      ),
      'reviewedByEmail': emailDocumentId(changedByEmail),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(userDoc, {
      'email': userEmail,
      'accessLevel': 'premium',
      'subscriptionStatus': userSubscriptionStatusKey(
        UserSubscriptionStatus.active,
      ),
      'subscriptionProvider': paymentMethod,
      if (paymentMethod == 'paystack' && paymentReference.isNotEmpty)
        'paystackReference': paymentReference,
      if (paymentMethod == 'manual' && paymentReference.isNotEmpty)
        'manualPaymentReference': paymentReference,
      if (paymentMethod == 'ancient_coin' && paymentReference.isNotEmpty)
        'ancientCoinReference': paymentReference,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final normalizedChangedByEmail = emailDocumentId(changedByEmail);
    if (normalizedChangedByEmail.isNotEmpty) {
      batch.set(_firestore.collection('user_subscription_audit_logs').doc(), {
        'targetEmail': userEmail,
        'changedByEmail': normalizedChangedByEmail,
        'previousSubscriptionStatus': userSubscriptionStatusKey(previousStatus),
        'nextSubscriptionStatus': userSubscriptionStatusKey(
          UserSubscriptionStatus.active,
        ),
        'subscriptionChangeType': 'manual_payment_approval',
        'paymentMethod': paymentMethod,
        if (paymentReference.isNotEmpty) 'paymentReference': paymentReference,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('user_subscription_requests');
}

UserSubscriptionRequestStatus readUserSubscriptionRequestStatus(dynamic value) {
  return switch (value?.toString().trim().toLowerCase()) {
    'reviewing' || 'in_review' => UserSubscriptionRequestStatus.reviewing,
    'approved' || 'accepted' => UserSubscriptionRequestStatus.approved,
    'declined' || 'rejected' => UserSubscriptionRequestStatus.declined,
    'archived' => UserSubscriptionRequestStatus.archived,
    _ => UserSubscriptionRequestStatus.open,
  };
}

String userSubscriptionRequestStatusKey(UserSubscriptionRequestStatus status) {
  return switch (status) {
    UserSubscriptionRequestStatus.open => 'open',
    UserSubscriptionRequestStatus.reviewing => 'reviewing',
    UserSubscriptionRequestStatus.approved => 'approved',
    UserSubscriptionRequestStatus.declined => 'declined',
    UserSubscriptionRequestStatus.archived => 'archived',
  };
}

String userSubscriptionRequestStatusLabel(
  UserSubscriptionRequestStatus status,
) {
  return switch (status) {
    UserSubscriptionRequestStatus.open => 'Open',
    UserSubscriptionRequestStatus.reviewing => 'Reviewing',
    UserSubscriptionRequestStatus.approved => 'Approved',
    UserSubscriptionRequestStatus.declined => 'Declined',
    UserSubscriptionRequestStatus.archived => 'Archived',
  };
}

UserSubscriptionPaymentMethod readUserSubscriptionPaymentMethod(dynamic value) {
  return switch (value?.toString().trim().toLowerCase()) {
    'stripe' => UserSubscriptionPaymentMethod.stripe,
    'manual' ||
    'manual_payment' ||
    'manual-payment' ||
    'offline' ||
    'bank_transfer' ||
    'bank-transfer' ||
    'bank transfer' => UserSubscriptionPaymentMethod.manual,
    'ancient_coin' ||
    'ancient-coin' ||
    'ancientcoin' ||
    'ancient coin' => UserSubscriptionPaymentMethod.ancientCoin,
    _ => UserSubscriptionPaymentMethod.paystack,
  };
}

String userSubscriptionPaymentMethodKey(UserSubscriptionPaymentMethod method) {
  return switch (method) {
    UserSubscriptionPaymentMethod.stripe => 'stripe',
    UserSubscriptionPaymentMethod.paystack => 'paystack',
    UserSubscriptionPaymentMethod.manual => 'manual',
    UserSubscriptionPaymentMethod.ancientCoin => 'ancient_coin',
  };
}

String userSubscriptionPaymentMethodLabel(
  UserSubscriptionPaymentMethod method,
) {
  return switch (method) {
    UserSubscriptionPaymentMethod.stripe => 'Stripe',
    UserSubscriptionPaymentMethod.paystack => 'Paystack',
    UserSubscriptionPaymentMethod.manual => 'Manual proof',
    UserSubscriptionPaymentMethod.ancientCoin => 'Ancient Coin',
  };
}

UserSubscriptionPaymentStatus readUserSubscriptionPaymentStatus(dynamic value) {
  return switch (value?.toString().trim().toLowerCase()) {
    'pending_confirmation' ||
    'pending-confirmation' ||
    'pending confirmation' => UserSubscriptionPaymentStatus.pendingConfirmation,
    'confirmed' ||
    'paid' ||
    'success' ||
    'succeeded' => UserSubscriptionPaymentStatus.confirmed,
    'failed' ||
    'cancelled' ||
    'canceled' => UserSubscriptionPaymentStatus.failed,
    'refunded' => UserSubscriptionPaymentStatus.refunded,
    _ => UserSubscriptionPaymentStatus.awaitingPayment,
  };
}

String userSubscriptionPaymentStatusKey(UserSubscriptionPaymentStatus status) {
  return switch (status) {
    UserSubscriptionPaymentStatus.awaitingPayment => 'awaiting_payment',
    UserSubscriptionPaymentStatus.pendingConfirmation => 'pending_confirmation',
    UserSubscriptionPaymentStatus.confirmed => 'confirmed',
    UserSubscriptionPaymentStatus.failed => 'failed',
    UserSubscriptionPaymentStatus.refunded => 'refunded',
  };
}

String userSubscriptionPaymentStatusLabel(
  UserSubscriptionPaymentStatus status,
) {
  return switch (status) {
    UserSubscriptionPaymentStatus.awaitingPayment => 'Awaiting payment',
    UserSubscriptionPaymentStatus.pendingConfirmation => 'Pending confirmation',
    UserSubscriptionPaymentStatus.confirmed => 'Confirmed',
    UserSubscriptionPaymentStatus.failed => 'Failed',
    UserSubscriptionPaymentStatus.refunded => 'Refunded',
  };
}
