class ReaderProtectionPolicy {
  const ReaderProtectionPolicy({
    required this.documentAccessLevel,
    required this.hasActiveSubscription,
    required this.isAdmin,
  });

  final String documentAccessLevel;
  final bool hasActiveSubscription;
  final bool isAdmin;

  bool get isProtectedDocument {
    return documentAccessLevel.trim().toLowerCase() == 'premium';
  }

  bool get shouldShowWatermark => isProtectedDocument;

  bool get shouldBlurWhenInactive => isProtectedDocument;

  bool get shouldDeterCopying => isProtectedDocument;

  bool get shouldBlockContextMenu => isProtectedDocument;

  bool get shouldBlockClipboardShortcuts => isProtectedDocument;

  bool get hasElevatedAccess => isAdmin || hasActiveSubscription;

  String get protectionLabel {
    if (!isProtectedDocument) return 'Standard reader';
    if (isAdmin) return 'Admin protected reader';
    if (hasActiveSubscription) return 'Premium protected reader';
    return 'Protected reader';
  }

  String get inactiveShieldTitle => 'Protected document hidden';

  String get inactiveShieldMessage {
    return 'Return to this window to continue reading securely.';
  }

  String get protectedActionMessage {
    return 'Protected reader mode keeps this document inside Ancient Secure Docs.';
  }

  bool shouldBlockShortcut(String key, {required bool controlOrMetaPressed}) {
    if (!shouldBlockClipboardShortcuts || !controlOrMetaPressed) return false;

    return switch (key.trim().toLowerCase()) {
      'c' || 'x' || 's' || 'p' => true,
      _ => false,
    };
  }
}
