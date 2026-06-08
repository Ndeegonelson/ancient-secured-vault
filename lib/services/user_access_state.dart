class UserAccessState {
  const UserAccessState({
    this.isAdmin = false,
    this.hasActiveSubscription = false,
    this.accessLevel = 'free',
  });

  factory UserAccessState.fromFirestore(Map<String, dynamic>? data) {
    return UserAccessState(
      isAdmin: data?['role'] == 'admin',
      hasActiveSubscription: data?['subscriptionStatus'] == 'active',
      accessLevel: _readAccessLevel(data?['accessLevel']),
    );
  }

  final bool isAdmin;
  final bool hasActiveSubscription;
  final String accessLevel;

  bool get canAccessMainVault => isAdmin || hasActiveSubscription;

  bool get canManageVault => isAdmin;

  bool canOpenPdfWithAccessLevel(String documentAccessLevel) {
    final normalizedAccessLevel = documentAccessLevel.trim().toLowerCase();

    if (normalizedAccessLevel == 'premium') {
      return canAccessMainVault;
    }

    return true;
  }

  static String _readAccessLevel(dynamic value) {
    final accessLevel = value?.toString().trim().toLowerCase() ?? '';
    return accessLevel.isEmpty ? 'free' : accessLevel;
  }
}
