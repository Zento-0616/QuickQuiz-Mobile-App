import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/reward_celebration_widget.dart';

enum RewardType { xp, coin, achievement, quizComplete }

class RewardCelebrationPayload {
  final String? id;
  final String title;
  final String rewardText;
  final String? subtitle;
  final RewardType type;
  final IconData? customIcon;
  final Color? accentColor;

  const RewardCelebrationPayload({
    this.id,
    required this.title,
    required this.rewardText,
    this.subtitle,
    this.type = RewardType.xp,
    IconData? customIcon,
    Color? accentColor,
    IconData? icon,
    Color? badgeColor,
  })  : customIcon = customIcon ?? icon,
        accentColor = accentColor ?? badgeColor;

  IconData? get icon => customIcon;
  Color? get badgeColor => accentColor;
}

/// Service that triggers celebratory visual animations (confetti, sparkles, floating badge)
/// whenever a user earns or receives a reward, ensuring no duplicate triggers.
class RewardEffectService {
  static final RewardEffectService _instance = RewardEffectService._internal();
  factory RewardEffectService() => _instance;
  RewardEffectService._internal();

  /// Set of unique reward IDs that have already played to prevent duplicate animations.
  final Set<String> _awardedIds = {};

  bool isAlreadyAwarded(String id) => _awardedIds.contains(id);

  void markAwarded(String id) => _awardedIds.add(id);

  void clearHistory() => _awardedIds.clear();

  /// Displays the reward celebration overlay immediately if not already awarded.
  bool showCelebration(BuildContext context, RewardCelebrationPayload payload) {
    // 1. Deduplication check: prevent triggering multiple times for the same reward
    if (payload.id != null && payload.id!.isNotEmpty) {
      if (_awardedIds.contains(payload.id)) {
        debugPrint('[RewardEffectService] Ignored duplicate celebration for ID: ${payload.id}');
        return false;
      }
      _awardedIds.add(payload.id!);
    }

    // 2. Play subtle haptic feedback
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    // 3. Show celebration overlay
    showRewardCelebrationOverlay(context, payload);
    return true;
  }
}
