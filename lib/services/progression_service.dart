import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/admin_settings_model.dart';
import '../models/user_model.dart';

class QuizExpResult {
  final int earnedExp;
  final int oldLevel;
  final int newLevel;
  final bool leveledUp;
  final int streakDays;

  const QuizExpResult({
    required this.earnedExp,
    required this.oldLevel,
    required this.newLevel,
    required this.leveledUp,
    required this.streakDays,
  });
}

class ProgressionService {
  static const String _prefLastRewardClaim = 'pref_last_daily_reward_claim';

  /// Calculates EXP earned from a completed quiz session, respecting repeat quiz rules.
  static int calculateExp({
    required int questionCount,
    required int correctCount,
    double multiplier = 1.0,
    int? customExpReward,
    bool isRepeat = false,
    bool repeatExpEnabled = true,
  }) {
    if (isRepeat && !repeatExpEnabled) {
      return 0;
    }
    if (questionCount <= 0) return 10;
    final accuracy = (correctCount / questionCount).clamp(0.0, 1.0);

    // If direct EXP reward is specified (1-1000 EXP), reward proportionally to score accuracy
    if (customExpReward != null && customExpReward > 0) {
      final reward = (customExpReward * accuracy).round();
      return max(accuracy > 0 ? 1 : 0, reward);
    }

    final baseExp = questionCount * 20;
    final perfectBonus = (correctCount == questionCount && questionCount >= 3) ? 50 : 0;
    final total = (baseExp * accuracy * multiplier).round() + perfectBonus;
    return max(15, total); // Minimum 15 EXP participation
  }

  /// Returns the start of the 4:00 PM (16:00) daily cycle containing [dateTime].
  ///
  /// The daily calendar cycle runs from 4:00 PM to 3:59:59 PM next day.
  /// If [dateTime] is before 16:00, it belongs to the cycle that started yesterday at 16:00.
  /// If [dateTime] is at or after 16:00, it belongs to the cycle starting today at 16:00.
  static DateTime getDailyCycleStart([DateTime? dateTime]) {
    final dt = dateTime ?? DateTime.now();
    if (dt.hour >= 16) {
      return DateTime(dt.year, dt.month, dt.day, 16);
    } else {
      final prev = dt.subtract(const Duration(days: 1));
      return DateTime(prev.year, prev.month, prev.day, 16);
    }
  }

  /// Checks if two timestamps belong to the same 4:00 PM daily cycle.
  static bool isSameDailyCycle(DateTime d1, DateTime d2) {
    final start1 = getDailyCycleStart(d1);
    final start2 = getDailyCycleStart(d2);
    return start1.year == start2.year &&
           start1.month == start2.month &&
           start1.day == start2.day;
  }

  static String _dailyExpKey(DateTime date) {
    final cycleStart = getDailyCycleStart(date);
    final y = cycleStart.year.toString().padLeft(4, '0');
    final m = cycleStart.month.toString().padLeft(2, '0');
    final d = cycleStart.day.toString().padLeft(2, '0');
    return 'daily_exp_earned_${y}_${m}_${d}_16h';
  }

  static Future<int> getTodayExpEarned() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_dailyExpKey(DateTime.now())) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> addTodayExpEarned(int amount) async {
    if (amount <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _dailyExpKey(DateTime.now());
      final current = prefs.getInt(key) ?? 0;
      await prefs.setInt(key, current + amount);
    } catch (_) {}
  }

  static int clampExpToDailyCap({
    required int proposedExp,
    required int currentDailyExp,
    required int dailyExpCap,
  }) {
    if (dailyExpCap <= 0) return proposedExp;
    final remainingAllowance = max(0, dailyExpCap - currentDailyExp);
    return min(proposedExp, remainingAllowance);
  }

  /// Calculates level based on cumulative EXP.
  /// Level 1: 0 - 149 EXP
  /// Level 2: 150 - 449 EXP (+300)
  /// Level 3: 450 - 899 EXP (+450)
  /// etc.
  static int calculateLevelFromExp(int exp) {
    if (exp <= 0) return 1;
    int currentExp = exp;
    int lvl = 1;
    while (true) {
      final needed = lvl * 150;
      if (currentExp < needed) {
        return lvl;
      }
      currentExp -= needed;
      lvl++;
    }
  }

  /// Calculates the new user state after completing a quiz.
  static QuizExpResult processQuizCompletion({
    required UserModel user,
    required int questionCount,
    required int correctCount,
    double deckMultiplier = 1.0,
    int? customExpReward,
    bool isRepeat = false,
    bool repeatExpEnabled = true,
    int? dailyExpCap,
    int currentDailyExp = 0,
  }) {
    int earnedExp = calculateExp(
      questionCount: questionCount,
      correctCount: correctCount,
      multiplier: deckMultiplier,
      customExpReward: customExpReward,
      isRepeat: isRepeat,
      repeatExpEnabled: repeatExpEnabled,
    );

    if (dailyExpCap != null && dailyExpCap > 0) {
      earnedExp = clampExpToDailyCap(
        proposedExp: earnedExp,
        currentDailyExp: currentDailyExp,
        dailyExpCap: dailyExpCap,
      );
    }

    final totalExp = user.exp + earnedExp;
    final oldLevel = user.level;
    final newLevel = calculateLevelFromExp(totalExp);
    final leveledUp = newLevel > oldLevel;

    // Check streak
    final updatedStreak = evaluateDailyStreak(
      lastActive: user.lastActive ?? user.lastLoginDate,
      currentStreak: user.dailyStreak,
    );

    return QuizExpResult(
      earnedExp: earnedExp,
      oldLevel: oldLevel,
      newLevel: newLevel,
      leveledUp: leveledUp,
      streakDays: updatedStreak,
    );
  }

  /// Evaluates consecutive day activity for the daily streak using the 4:00 PM cycle.
  static int evaluateDailyStreak({
    required DateTime? lastActive,
    required int currentStreak,
  }) {
    if (lastActive == null) return 1;

    final now = DateTime.now();
    final currentCycle = getDailyCycleStart(now);
    final lastCycle = getDailyCycleStart(lastActive);
    final diffDays = currentCycle.difference(lastCycle).inDays;

    if (diffDays == 0) {
      // Same 4:00 PM cycle: streak stays intact
      return max(1, currentStreak);
    } else if (diffDays == 1) {
      // Consecutive next 4:00 PM cycle: streak increment!
      return currentStreak + 1;
    } else {
      // Missed one or more cycles: reset to 1
      return 1;
    }
  }

  /// Returns the daily login reward EXP for day 1..7.
  static int getDailyRewardExp(int streakDay, {AdminSettingsModel? settings}) {
    final dayIndex = ((streakDay - 1) % 7) + 1;
    if (settings != null) {
      return settings.getDailyRewardForDay(dayIndex);
    }
    switch (dayIndex) {
      case 1: return 30;
      case 2: return 50;
      case 3: return 75;
      case 4: return 100;
      case 5: return 130;
      case 6: return 160;
      case 7: return 250;
      default: return 50;
    }
  }

  /// Checks whether the daily reward for the current 4:00 PM cycle has already been claimed.
  static Future<bool> isDailyRewardClaimedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastClaim = prefs.getString(_prefLastRewardClaim);
    if (lastClaim == null) return false;

    final claimDate = DateTime.tryParse(lastClaim);
    if (claimDate == null) return false;

    return isSameDailyCycle(claimDate, DateTime.now());
  }

  /// Marks today's daily reward as claimed.
  static Future<void> markDailyRewardClaimedToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLastRewardClaim, DateTime.now().toIso8601String());
  }
}
