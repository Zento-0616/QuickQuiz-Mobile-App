import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HeadToHeadRecord {
  final String userId;
  final String opponentId;
  final String opponentName;
  final int wins;
  final int losses;
  final int draws;
  final DateTime updatedAt;

  const HeadToHeadRecord({
    required this.userId,
    required this.opponentId,
    required this.opponentName,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    required this.updatedAt,
  });

  int get totalMatches => wins + losses + draws;

  double get winRate => totalMatches > 0 ? (wins / totalMatches * 100) : 0.0;

  String get summary => '$wins W - $losses L${draws > 0 ? ' - $draws D' : ''}';

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'opponentId': opponentId,
        'opponentName': opponentName,
        'wins': wins,
        'losses': losses,
        'draws': draws,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory HeadToHeadRecord.fromJson(Map<String, dynamic> json) {
    return HeadToHeadRecord(
      userId: json['userId'] as String? ?? '',
      opponentId: json['opponentId'] as String? ?? '',
      opponentName: json['opponentName'] as String? ?? 'Opponent',
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      draws: (json['draws'] as num?)?.toInt() ?? 0,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  HeadToHeadRecord copyWith({
    String? userId,
    String? opponentId,
    String? opponentName,
    int? wins,
    int? losses,
    int? draws,
    DateTime? updatedAt,
  }) {
    return HeadToHeadRecord(
      userId: userId ?? this.userId,
      opponentId: opponentId ?? this.opponentId,
      opponentName: opponentName ?? this.opponentName,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Service managing persistent head-to-head win/loss scoring between scholars.
/// Caches records in local SharedPreferences for fast, offline-first access
/// and synchronizes with Cloud Firestore when network connectivity is available.
class HeadToHeadService {
  static final HeadToHeadService _instance = HeadToHeadService._internal();
  factory HeadToHeadService() => _instance;
  HeadToHeadService._internal();

  final Map<String, HeadToHeadRecord> _memoryCache = {};

  bool get _isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String _cacheKey(String userId, String opponentId) => 'h2h_${userId}_$opponentId';

  /// Synchronously gets cached record if already loaded into memory
  HeadToHeadRecord getCachedRecord({
    required String userId,
    required String opponentId,
    String opponentName = 'Opponent',
  }) {
    final key = _cacheKey(userId, opponentId);
    return _memoryCache[key] ??
        HeadToHeadRecord(
          userId: userId,
          opponentId: opponentId,
          opponentName: opponentName,
          wins: 0,
          losses: 0,
          draws: 0,
          updatedAt: DateTime.now(),
        );
  }

  /// Retrieves the head-to-head record between [userId] and [opponentId]
  Future<HeadToHeadRecord> getRecord({
    required String userId,
    required String opponentId,
    String opponentName = 'Opponent',
  }) async {
    if (userId.isEmpty || opponentId.isEmpty) {
      return HeadToHeadRecord(
        userId: userId,
        opponentId: opponentId,
        opponentName: opponentName,
        wins: 0,
        losses: 0,
        draws: 0,
        updatedAt: DateTime.now(),
      );
    }

    final key = _cacheKey(userId, opponentId);
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key]!;
    }

    // 1. Try reading from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final record = HeadToHeadRecord.fromJson(data);
        _memoryCache[key] = record;
        return record;
      }
    } catch (e) {
      debugPrint('[HeadToHeadService] Local read error: $e');
    }

    // 2. Try reading from Firestore
    if (_isFirebaseAvailable) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('head_to_head')
            .doc(opponentId)
            .get()
            .timeout(const Duration(seconds: 3));

        if (doc.exists && doc.data() != null) {
          final record = HeadToHeadRecord.fromJson(doc.data()!);
          _memoryCache[key] = record;
          _saveToLocal(key, record);
          return record;
        }
      } catch (e) {
        debugPrint('[HeadToHeadService] Firestore read error: $e');
      }
    }

    // 3. Fallback blank record
    final initial = HeadToHeadRecord(
      userId: userId,
      opponentId: opponentId,
      opponentName: opponentName,
      wins: 0,
      losses: 0,
      draws: 0,
      updatedAt: DateTime.now(),
    );
    _memoryCache[key] = initial;
    return initial;
  }

  /// Records a completed match outcome (win, loss, or draw) against [opponentId]
  Future<HeadToHeadRecord> recordMatchOutcome({
    required String userId,
    required String opponentId,
    required String opponentName,
    required bool isWin,
    required bool isDraw,
  }) async {
    if (userId.isEmpty || opponentId.isEmpty) {
      return HeadToHeadRecord(
        userId: userId,
        opponentId: opponentId,
        opponentName: opponentName,
        updatedAt: DateTime.now(),
      );
    }

    final current = await getRecord(
      userId: userId,
      opponentId: opponentId,
      opponentName: opponentName,
    );

    final updated = current.copyWith(
      opponentName: opponentName.isNotEmpty ? opponentName : current.opponentName,
      wins: isWin && !isDraw ? current.wins + 1 : current.wins,
      losses: !isWin && !isDraw ? current.losses + 1 : current.losses,
      draws: isDraw ? current.draws + 1 : current.draws,
      updatedAt: DateTime.now(),
    );

    final key = _cacheKey(userId, opponentId);
    _memoryCache[key] = updated;

    // Persist locally
    await _saveToLocal(key, updated);

    // Sync to Firestore
    if (_isFirebaseAvailable) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('head_to_head')
            .doc(opponentId)
            .set(updated.toJson(), SetOptions(merge: true))
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('[HeadToHeadService] Firestore save error: $e');
      }
    }

    return updated;
  }

  Future<void> _saveToLocal(String key, HeadToHeadRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(record.toJson()));
    } catch (_) {}
  }
}
