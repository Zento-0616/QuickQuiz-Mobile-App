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

class RewardEffectService {
  static final RewardEffectService _instance = RewardEffectService._internal();
  factory RewardEffectService() => _instance;
  RewardEffectService._internal();

  final Set<String> _awardedIds = {};

  bool isAlreadyAwarded(String id) => _awardedIds.contains(id);

  void markAwarded(String id) => _awardedIds.add(id);

  void clearHistory() => _awardedIds.clear();

  bool showCelebration(BuildContext context, RewardCelebrationPayload payload) {
    if (payload.id != null && payload.id!.isNotEmpty) {
      if (_awardedIds.contains(payload.id)) {
        debugPrint('[RewardEffectService] Ignored duplicate celebration for ID: ${payload.id}');
        return false;
      }
      _awardedIds.add(payload.id!);
    }

    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    showRewardCelebrationOverlay(context, payload);
    return true;
  }
}
