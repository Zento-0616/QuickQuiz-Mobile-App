import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Data model and persistent manager for Admin EXP and Game Control settings.
/// Supports day-by-day EXP caps (Day 1 Monday to Day 7 Sunday) synchronized
/// across all scholar devices via Firestore with local SharedPreferences cache.
class AdminSettingsModel {
  final bool repeatQuizExpEnabled;
  final Map<int, int> dailyExpCaps; // 1 = Monday, ..., 7 = Sunday
  final Map<int, int> dailyLoginRewards; // 1 = Monday, ..., 7 = Sunday

  AdminSettingsModel({
    this.repeatQuizExpEnabled = false,
    Map<int, int>? dailyExpCaps,
    Map<int, int>? dailyLoginRewards,
    int? dailyExpCap,
  })  : dailyExpCaps = dailyExpCaps ??
            (dailyExpCap != null
                ? {for (int d = 1; d <= 7; d++) d: dailyExpCap}
                : const {
                    1: 500,
                    2: 500,
                    3: 500,
                    4: 500,
                    5: 500,
                    6: 500,
                    7: 500,
                  }),
        dailyLoginRewards = dailyLoginRewards ??
            dailyExpCaps ??
            const {
              1: 30,
              2: 50,
              3: 75,
              4: 100,
              5: 130,
              6: 160,
              7: 250,
            };

  /// Legacy dailyExpCap getter returning today's active cap
  int get dailyExpCap => getDailyCapForDay(DateTime.now().weekday);

  int getDailyCapForDay(int weekday) {
    return dailyExpCaps[weekday] ?? 500;
  }

  int getDailyRewardForDay(int weekday) {
    if (dailyLoginRewards.containsKey(weekday)) {
      return dailyLoginRewards[weekday]!;
    }
    if (dailyExpCaps.containsKey(weekday)) {
      return dailyExpCaps[weekday]!;
    }
    return 50;
  }

  static const String _keyRepeatExp = 'admin_pref_repeat_quiz_exp';
  static const String _keyDailyExpCap = 'admin_pref_daily_exp_cap';
  static const String _keyDailyExpCapsMap = 'admin_pref_daily_exp_caps_map';
  static const String _keyDailyLoginRewardsMap = 'admin_pref_daily_login_rewards_map';

  factory AdminSettingsModel.fromJson(Map<String, dynamic> json) {
    Map<int, int> caps = {
      1: 500,
      2: 500,
      3: 500,
      4: 500,
      5: 500,
      6: 500,
      7: 500,
    };

    if (json['dailyExpCaps'] is Map) {
      final rawMap = json['dailyExpCaps'] as Map;
      rawMap.forEach((k, v) {
        final day = int.tryParse(k.toString());
        final cap = int.tryParse(v.toString());
        if (day != null && cap != null && day >= 1 && day <= 7) {
          caps[day] = cap;
        }
      });
    } else if (json['dailyExpCap'] != null) {
      final fallbackCap = (json['dailyExpCap'] as num).toInt();
      caps = {for (int d = 1; d <= 7; d++) d: fallbackCap};
    }

    Map<int, int> rewards = Map<int, int>.from(caps);
    if (json['dailyLoginRewards'] is Map) {
      final rawMap = json['dailyLoginRewards'] as Map;
      rawMap.forEach((k, v) {
        final day = int.tryParse(k.toString());
        final rew = int.tryParse(v.toString());
        if (day != null && rew != null && day >= 1 && day <= 7) {
          rewards[day] = rew;
        }
      });
    }

    return AdminSettingsModel(
      repeatQuizExpEnabled: json['repeatQuizExpEnabled'] as bool? ?? false,
      dailyExpCaps: caps,
      dailyLoginRewards: rewards,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'repeatQuizExpEnabled': repeatQuizExpEnabled,
      'dailyExpCap': dailyExpCap,
      'dailyExpCaps': dailyExpCaps.map((k, v) => MapEntry(k.toString(), v)),
      'dailyLoginRewards': dailyLoginRewards.map((k, v) => MapEntry(k.toString(), v)),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  AdminSettingsModel copyWith({
    bool? repeatQuizExpEnabled,
    Map<int, int>? dailyExpCaps,
    Map<int, int>? dailyLoginRewards,
    int? singleDailyExpCap,
  }) {
    Map<int, int>? updatedCaps = dailyExpCaps;
    Map<int, int>? updatedRewards = dailyLoginRewards;
    if (singleDailyExpCap != null) {
      updatedCaps = {for (int d = 1; d <= 7; d++) d: singleDailyExpCap};
      updatedRewards = {for (int d = 1; d <= 7; d++) d: singleDailyExpCap};
    }

    return AdminSettingsModel(
      repeatQuizExpEnabled: repeatQuizExpEnabled ?? this.repeatQuizExpEnabled,
      dailyExpCaps: updatedCaps ?? this.dailyExpCaps,
      dailyLoginRewards: updatedRewards ?? this.dailyLoginRewards,
    );
  }

  /// Loads admin settings from Firestore first for true multi-device sync,
  /// falling back to local persistent storage.
  static Future<AdminSettingsModel> loadSettings() async {
    // 1. Try Firestore remote fetch first
    try {
      if (Firebase.apps.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('system_settings')
            .doc('progression')
            .get()
            .timeout(const Duration(seconds: 3));

        if (doc.exists && doc.data() != null) {
          final settings = AdminSettingsModel.fromJson(doc.data()!);
          // Cache locally
          await settings._saveLocally();
          return settings;
        }
      }
    } catch (e) {
      debugPrint('[AdminSettingsModel] Remote settings load fallback: $e');
    }

    // 2. Local SharedPreferences fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      final repeat = prefs.getBool(_keyRepeatExp) ?? false;
      final rawMapStr = prefs.getString(_keyDailyExpCapsMap);
      final rawRewardsStr = prefs.getString(_keyDailyLoginRewardsMap);

      Map<int, int>? caps;
      if (rawMapStr != null && rawMapStr.isNotEmpty) {
        final decoded = jsonDecode(rawMapStr) as Map<String, dynamic>;
        caps = {};
        decoded.forEach((k, v) {
          final day = int.tryParse(k);
          final cap = int.tryParse(v.toString());
          if (day != null && cap != null) caps![day] = cap;
        });
      }

      Map<int, int>? rewards;
      if (rawRewardsStr != null && rawRewardsStr.isNotEmpty) {
        final decoded = jsonDecode(rawRewardsStr) as Map<String, dynamic>;
        rewards = {};
        decoded.forEach((k, v) {
          final day = int.tryParse(k);
          final exp = int.tryParse(v.toString());
          if (day != null && exp != null) rewards![day] = exp;
        });
      }

      final cap = prefs.getInt(_keyDailyExpCap) ?? 500;
      return AdminSettingsModel(
        repeatQuizExpEnabled: repeat,
        dailyExpCaps: caps ?? {for (int d = 1; d <= 7; d++) d: cap},
        dailyLoginRewards: rewards ?? const {
          1: 25,
          2: 50,
          3: 75,
          4: 100,
          5: 150,
          6: 200,
          7: 350,
        },
      );
    } catch (_) {
      return AdminSettingsModel();
    }
  }

  /// Persists admin settings both locally and to Firestore for instant global sync.
  Future<void> saveSettings() async {
    await _saveLocally();

    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('system_settings')
            .doc('progression')
            .set(toJson(), SetOptions(merge: true))
            .timeout(const Duration(seconds: 5));
        debugPrint('[AdminSettingsModel] Successfully synced settings to Firestore.');
      }
    } catch (e) {
      debugPrint('[AdminSettingsModel] Failed to sync settings to Firestore: $e');
    }
  }

  Future<void> _saveLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyRepeatExp, repeatQuizExpEnabled);
      await prefs.setInt(_keyDailyExpCap, dailyExpCap);
      final mapStr = jsonEncode(dailyExpCaps.map((k, v) => MapEntry(k.toString(), v)));
      await prefs.setString(_keyDailyExpCapsMap, mapStr);
      final rewardsStr = jsonEncode(dailyLoginRewards.map((k, v) => MapEntry(k.toString(), v)));
      await prefs.setString(_keyDailyLoginRewardsMap, rewardsStr);
    } catch (_) {}
  }
}
