enum ReaderNarrationPlan { free, premium, admin }

class ReaderNarrationAccessPolicy {
  const ReaderNarrationAccessPolicy._(this.plan);

  factory ReaderNarrationAccessPolicy.fromUserAccess({
    required bool isAdmin,
    required bool hasActiveSubscription,
  }) {
    if (isAdmin) {
      return const ReaderNarrationAccessPolicy._(ReaderNarrationPlan.admin);
    }

    if (hasActiveSubscription) {
      return const ReaderNarrationAccessPolicy._(ReaderNarrationPlan.premium);
    }

    return const ReaderNarrationAccessPolicy._(ReaderNarrationPlan.free);
  }

  final ReaderNarrationPlan plan;

  bool get canChooseVoice => plan != ReaderNarrationPlan.free;

  String get summary {
    switch (plan) {
      case ReaderNarrationPlan.admin:
        return 'Admin narration | Selectable voice catalog';
      case ReaderNarrationPlan.premium:
        return 'Premium narration | Selectable voice catalog';
      case ReaderNarrationPlan.free:
        return 'Free narration | Assigned bilingual voices';
    }
  }

  String get upgradeMessage {
    return 'Premium narration is required to choose from multiple narrator '
        'voices and accents.';
  }
}
