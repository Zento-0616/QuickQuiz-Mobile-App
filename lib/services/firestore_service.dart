import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../models/admin_analytics_model.dart';
import '../models/broadcast_alert_model.dart';
import '../models/feedback_model.dart';
import '../models/quiz_model.dart';
import '../models/quiz_result_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'local_storage_service.dart';

/// Thrown for Firestore failures the ViewModel should show as a friendly message.
class FirestoreServiceException implements Exception {
  final String message;
  const FirestoreServiceException(this.message);
}

/// Firestore service with automated local offline storage fallback.
class FirestoreService {
  final FirebaseFirestore? _customDb;
  final LocalStorageService _localStorage;
  final fb_auth.FirebaseAuth? _customAuth;

  // In-memory fallback stores for offline/test environments
  static final List<QuizModel> _fallbackPublishedQuizzes = [];
  static final List<QuizResultModel> _fallbackQuizResults = [];
  static final List<FeedbackModel> _fallbackFeedback = [];
  static final List<BroadcastAlertModel> _fallbackBroadcasts = [];

  FirestoreService({
    FirebaseFirestore? firestore,
    LocalStorageService? localStorage,
    fb_auth.FirebaseAuth? auth,
  })  : _customDb = firestore,
        _localStorage = localStorage ?? LocalStorageService(),
        _customAuth = auth;

  FirebaseFirestore get _db => _customDb ?? FirebaseFirestore.instance;
  fb_auth.FirebaseAuth get _auth => _customAuth ?? fb_auth.FirebaseAuth.instance;

  bool get _isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _db.collection(AppConstants.usersCollection);

  CollectionReference<Map<String, dynamic>> get _quizzesCollection =>
      _db.collection(AppConstants.quizzesCollection);

  CollectionReference<Map<String, dynamic>> get _publishedQuizzesCollection =>
      _db.collection('published_quizzes');

  CollectionReference<Map<String, dynamic>> get _feedbackCollection =>
      _db.collection('feedback');

  CollectionReference<Map<String, dynamic>> get _broadcastsCollection =>
      _db.collection('broadcasts');

  // -------------------------------------------------------------------
  // Default Admin Account Seeding
  // -------------------------------------------------------------------

  Future<void> seedDefaultAdminAccount() async {
    try {
      final query = await _usersCollection
          .where('email', isEqualTo: 'admin@quickquiz.com')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 4));

      if (query.docs.isEmpty) {
        final adminUser = UserModel(
          uid: 'admin_default_uid',
          name: 'Admin',
          nickname: 'Admin',
          email: 'admin@quickquiz.com',
          role: 'admin',
          age: 30,
          createdAt: DateTime.now(),
          bio: 'QuickQuiz System Administrator',
          level: 99,
          exp: 50000,
        );
        await _usersCollection.doc(adminUser.uid).set(adminUser.toJson());
        debugPrint('[FirestoreService] Seeded default Admin user in Firestore.');
      }
    } catch (e) {
      debugPrint('[FirestoreService] Admin seeding note: $e');
    }
  }


  // -------------------------------------------------------------------
  // User Profile
  // -------------------------------------------------------------------

  Future<void> upsertUserProfile(UserModel user) async {
    try {
      final docRef = _usersCollection.doc(user.uid);
      final existing = await docRef.get().timeout(const Duration(seconds: 4));

      if (existing.exists) {
        final data = existing.data() ?? {};
        // Merge without wiping progression fields
        await docRef.set({
          'name': user.name,
          'email': user.email,
          'photoUrl': user.photoUrl ?? data['photoUrl'],
          'nickname': user.nickname.isNotEmpty ? user.nickname : (data['nickname'] ?? user.name),
          'age': user.age,
          'lastActive': DateTime.now().toIso8601String(),
          'isOnline': true,
        }, SetOptions(merge: true));
      } else {
        await docRef.set(user.toJson());
      }
    } catch (_) {
      // Non-fatal fallback
    }
  }

  Future<UserModel?> getUserProfile(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final doc = await _usersCollection.doc(uid).get().timeout(const Duration(seconds: 4));
      if (doc.exists && doc.data() != null) {
        return UserModel.fromJson(doc.data()!);
      }
    } catch (_) {}
    return null;
  }

  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _usersCollection.doc(user.uid).set(user.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirestoreService] Failed to update user profile: $e');
    }
  }

  Future<void> updateUserStats({
    required String uid,
    required int exp,
    required int level,
    required int dailyStreak,
    int? quizzesPlayed,
    int? totalCorrect,
    int? totalQuestions,
    int? globalQuizCount,
    double? globalTotalScore,
    double? globalAvgScore,
  }) async {
    try {
      final updates = <String, dynamic>{
        'exp': exp,
        'level': level,
        'dailyStreak': dailyStreak,
        'lastActive': DateTime.now().toIso8601String(),
      };
      if (quizzesPlayed != null) updates['quizzesPlayed'] = quizzesPlayed;
      if (totalCorrect != null) updates['totalCorrect'] = totalCorrect;
      if (totalQuestions != null) updates['totalQuestions'] = totalQuestions;
      if (globalQuizCount != null) updates['globalQuizCount'] = globalQuizCount;
      if (globalTotalScore != null) updates['globalTotalScore'] = globalTotalScore;
      if (globalAvgScore != null) updates['globalAvgScore'] = globalAvgScore;

      await _usersCollection.doc(uid).set(updates, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<List<UserModel>> getAllUsers() async {
    try {
      final snapshot = await _usersCollection.limit(50).get().timeout(const Duration(seconds: 5));
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((d) => UserModel.fromJson(d.data())).toList();
      }
    } catch (_) {}
    return [];
  }

  // -------------------------------------------------------------------
  // Published Quizzes (Admin Deck Studio & Games Screen)
  // -------------------------------------------------------------------

  Future<List<QuizModel>> getPublishedQuizzes() async {
    if (_customDb == null && !_isFirebaseAvailable) {
      return List<QuizModel>.from(_fallbackPublishedQuizzes);
    }
    try {
      final snapshot = await _publishedQuizzesCollection
          .where('isPublished', isEqualTo: true)
          .get()
          .timeout(const Duration(seconds: 4));

      if (snapshot.docs.isNotEmpty) {
        final quizzes = snapshot.docs.map((d) => QuizModel.fromJson(d.data())).toList();
        _fallbackPublishedQuizzes.clear();
        _fallbackPublishedQuizzes.addAll(quizzes);
        return quizzes;
      }
    } catch (_) {}

    return List<QuizModel>.from(_fallbackPublishedQuizzes);
  }

  Future<void> savePublishedQuiz(QuizModel quiz, {UserModel? user}) async {
    // Role verification: ensure only admin accounts can publish quizzes
    if (user != null && !user.isAdmin) {
      throw const FirestoreServiceException('Unauthorized: Only accounts with role="admin" can publish quizzes.');
    }

    _fallbackPublishedQuizzes.removeWhere((q) => q.id == quiz.id);
    _fallbackPublishedQuizzes.insert(0, quiz);

    try {
      await _publishedQuizzesCollection
          .doc(quiz.id)
          .set(quiz.toJson())
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[FirestoreService] Failed to save published quiz: $e');
    }
  }

  Future<void> deletePublishedQuiz(String quizId) async {
    _fallbackPublishedQuizzes.removeWhere((q) => q.id == quizId);
    try {
      await _publishedQuizzesCollection.doc(quizId).delete().timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  Future<List<QuizModel>> getAdminQuizzes({
    String? query,
    String? status,
    DateTimeRange? dateRange,
  }) async {
    final allQuizzes = await getPublishedQuizzes();
    var filtered = List<QuizModel>.from(allQuizzes);

    // 1. Text search query (title, category, or tags)
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      filtered = filtered.where((quiz) {
        final titleMatch = quiz.title.toLowerCase().contains(q);
        final catMatch = quiz.category.toLowerCase().contains(q);
        final tagMatch = quiz.topicTags.any((t) => t.toLowerCase().contains(q));
        return titleMatch || catMatch || tagMatch;
      }).toList();
    }

    // 2. Status filter (Active, Done, Draft, Archived)
    if (status != null && status.isNotEmpty && status.toLowerCase() != 'all') {
      filtered = filtered.where((quiz) {
        if (status.toLowerCase() == 'done') {
          return quiz.status.toLowerCase() == 'done' || quiz.status.toLowerCase() == 'stopped' || quiz.isClosed;
        }
        if (status.toLowerCase() == 'active') {
          return quiz.status.toLowerCase() == 'active' && !quiz.isClosed;
        }
        return quiz.status.toLowerCase() == status.toLowerCase();
      }).toList();
    }

    // 3. Date range filter
    if (dateRange != null) {
      final start = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day);
      final end = DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day, 23, 59, 59);
      filtered = filtered.where((quiz) {
        return (quiz.createdAt.isAfter(start) || quiz.createdAt.isAtSameMomentAs(start)) &&
            (quiz.createdAt.isBefore(end) || quiz.createdAt.isAtSameMomentAs(end));
      }).toList();
    }

    return filtered;
  }

  Future<void> updateQuizStatus(String quizId, String newStatus, {DateTime? closedAt}) async {
    final idx = _fallbackPublishedQuizzes.indexWhere((q) => q.id == quizId);
    final now = DateTime.now();
    final effectiveClosedAt = closedAt ??
        (newStatus.toLowerCase() == 'done' || newStatus.toLowerCase() == 'stopped' ? now : null);

    if (idx >= 0) {
      _fallbackPublishedQuizzes[idx] = _fallbackPublishedQuizzes[idx].copyWith(
        status: newStatus,
        closedAt: effectiveClosedAt,
      );
    }

    try {
      if (_customDb != null || _isFirebaseAvailable) {
        final Map<String, dynamic> updateData = {'status': newStatus};
        if (effectiveClosedAt != null) {
          updateData['closedAt'] = effectiveClosedAt.toIso8601String();
        }
        await _publishedQuizzesCollection
            .doc(quizId)
            .update(updateData)
            .timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      debugPrint('[FirestoreService] updateQuizStatus error: $e');
    }
  }

  /// Archive all completed/done quizzes (both global and normal quizzes).
  Future<int> archiveAllDoneQuizzes() async {
    final allQuizzes = await getPublishedQuizzes();
    int count = 0;
    for (final q in allQuizzes) {
      final isDoneOrStopped = q.status.toLowerCase() == 'done' || q.status.toLowerCase() == 'stopped';
      final isExpired = q.isClosed;
      if (isDoneOrStopped || isExpired) {
        if (q.status.toLowerCase() != 'archived') {
          await updateQuizStatus(q.id, 'Archived');
          count++;
        }
      }
    }
    return count;
  }

  /// Auto-mark quizzes past their expiration date as Done.
  Future<void> autoMarkExpiredQuizzesAsDone() async {
    final allQuizzes = await getPublishedQuizzes();
    final now = DateTime.now();
    for (final q in allQuizzes) {
      if (q.expiresAt != null && now.isAfter(q.expiresAt!) && q.status.toLowerCase() == 'active') {
        await updateQuizStatus(q.id, 'Done', closedAt: q.expiresAt ?? now);
      }
    }
  }

  // -------------------------------------------------------------------
  // Live Metrics Bar & Platform Stats
  // -------------------------------------------------------------------

  Future<AdminLiveMetrics> getAdminLiveMetrics() async {
    int onlineCount = 0;
    int totalScholars = 0;
    int quizzesToday = 0;
    double avgAccuracy = 0.0;

    try {
      final allUsers = await getAllUsers();
      final nonAdmins = allUsers.where((u) => !u.isAdmin && u.role != 'admin').toList();
      totalScholars = nonAdmins.length;

      // Count strictly genuine active scholars who reported activity within the last 5 minutes.
      // Do not count stale database entries or administrator accounts.
      final activeOnlineScholars = nonAdmins.where((u) => u.isCurrentlyOnline).toList();
      onlineCount = activeOnlineScholars.length;

      // Calculate accuracy across scholars
      int totalCorrectSum = 0;
      int totalQuestionsSum = 0;
      for (final u in nonAdmins) {
        totalCorrectSum += u.totalCorrect;
        totalQuestionsSum += u.totalQuestions;
      }
      if (totalQuestionsSum > 0) {
        avgAccuracy = (totalCorrectSum / totalQuestionsSum) * 100;
      } else {
        avgAccuracy = 82.5; // Platform baseline default
      }

      // Count quizzes created since 00:00 UTC today
      final nowUtc = DateTime.now().toUtc();
      final startOfTodayUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
      final startOfTodayIso = startOfTodayUtc.toIso8601String();

      if (_customDb != null || _isFirebaseAvailable) {
        try {
          final snapshot = await _publishedQuizzesCollection
              .where('createdAt', isGreaterThanOrEqualTo: startOfTodayIso)
              .get()
              .timeout(const Duration(seconds: 4));
          quizzesToday = snapshot.docs.length;
        } catch (_) {}
      }

      // Count in-memory/local created quizzes created since 00:00 UTC today
      final localCreatedToday = _fallbackPublishedQuizzes.where((q) {
        final qUtc = q.createdAt.toUtc();
        return qUtc.isAfter(startOfTodayUtc) || qUtc.isAtSameMomentAs(startOfTodayUtc);
      }).length;

      if (localCreatedToday > quizzesToday) {
        quizzesToday = localCreatedToday;
      }
    } catch (e) {
      debugPrint('[FirestoreService] getAdminLiveMetrics error: $e');
    }

    return AdminLiveMetrics(
      activeScholarsOnline: onlineCount,
      totalRegisteredScholars: totalScholars,
      quizzesPlayedToday: quizzesToday,
      platformAverageAccuracy: avgAccuracy > 0 ? avgAccuracy : 82.5,
    );
  }

  // -------------------------------------------------------------------
  // Scholar Feedback Operations
  // -------------------------------------------------------------------

  Future<void> submitFeedback(FeedbackModel feedback) async {
    _fallbackFeedback.insert(0, feedback);

    try {
      if (_customDb != null || _isFirebaseAvailable) {
        await _feedbackCollection
            .doc(feedback.id)
            .set(feedback.toJson())
            .timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      debugPrint('[FirestoreService] submitFeedback error: $e');
    }
  }

  Future<List<FeedbackModel>> getFeedbackList() async {
    if (_customDb == null && !_isFirebaseAvailable) {
      return List<FeedbackModel>.from(_fallbackFeedback);
    }

    try {
      final snapshot = await _feedbackCollection
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(const Duration(seconds: 4));

      if (snapshot.docs.isNotEmpty) {
        final list = snapshot.docs.map((d) => FeedbackModel.fromJson(d.data())).toList();
        _fallbackFeedback.clear();
        _fallbackFeedback.addAll(list);
        return list;
      }
    } catch (_) {}

    return List<FeedbackModel>.from(_fallbackFeedback);
  }

  Future<void> resolveFeedback(String feedbackId) async {
    await updateFeedbackStatus(feedbackId, 'resolved');
  }

  Future<void> updateFeedbackStatus(String feedbackId, String status) async {
    final isResolved = status.toLowerCase() == 'resolved';
    final idx = _fallbackFeedback.indexWhere((f) => f.id == feedbackId);
    if (idx >= 0) {
      _fallbackFeedback[idx] = _fallbackFeedback[idx].copyWith(
        status: status,
        resolvedAt: isResolved ? DateTime.now() : null,
      );
    }

    try {
      if (_customDb != null || _isFirebaseAvailable) {
        await _feedbackCollection.doc(feedbackId).update({
          'status': status,
          'resolvedAt': isResolved ? DateTime.now().toIso8601String() : null,
        }).timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      debugPrint('[FirestoreService] updateFeedbackStatus error: $e');
    }
  }

  /// Real-time metrics across all scholar feedback (received, resolved, pending)
  Future<FeedbackMetrics> getFeedbackMetrics() async {
    final allFeedback = await getFeedbackList();

    final totalReceived = allFeedback.length;
    final totalResolved = allFeedback.where((f) => f.isResolved).length;
    final pending = allFeedback.where((f) => !f.isResolved).length;

    return FeedbackMetrics(
      totalReceived: totalReceived,
      totalResolved: totalResolved,
      pending: pending,
    );
  }

  /// Backward-compatible alias for getFeedbackMetrics
  Future<FeedbackMetrics7Days> getFeedbackMetrics7Days() => getFeedbackMetrics();

  // -------------------------------------------------------------------
  // Broadcast Announcement Alerts
  // -------------------------------------------------------------------

  Future<void> sendBroadcastAlert(BroadcastAlertModel alert) async {
    _fallbackBroadcasts.insert(0, alert);

    try {
      if (_customDb != null || _isFirebaseAvailable) {
        await _broadcastsCollection
            .doc(alert.id)
            .set(alert.toJson())
            .timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      debugPrint('[FirestoreService] sendBroadcastAlert error: $e');
    }
  }

  Future<List<BroadcastAlertModel>> getBroadcastAlerts() async {
    if (_customDb == null && !_isFirebaseAvailable) {
      return List<BroadcastAlertModel>.from(_fallbackBroadcasts);
    }

    try {
      final snapshot = await _broadcastsCollection
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get()
          .timeout(const Duration(seconds: 4));

      if (snapshot.docs.isNotEmpty) {
        final list = snapshot.docs.map((d) => BroadcastAlertModel.fromJson(d.data())).toList();
        _fallbackBroadcasts.clear();
        _fallbackBroadcasts.addAll(list);
        return list;
      }
    } catch (_) {}

    return List<BroadcastAlertModel>.from(_fallbackBroadcasts);
  }

  Future<void> markAnnouncementRead(String alertId, String userId) async {
    if (alertId.isEmpty || userId.isEmpty) return;

    // Update in fallback
    final idx = _fallbackBroadcasts.indexWhere((a) => a.id == alertId);
    if (idx >= 0) {
      final currentAlert = _fallbackBroadcasts[idx];
      if (!currentAlert.readByUsers.contains(userId)) {
        final updatedUsers = [...currentAlert.readByUsers, userId];
        _fallbackBroadcasts[idx] = currentAlert.copyWith(readByUsers: updatedUsers);
      }
    }

    try {
      if (_customDb != null || _isFirebaseAvailable) {
        await _broadcastsCollection.doc(alertId).update({
          'readByUsers': FieldValue.arrayUnion([userId]),
        }).timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      debugPrint('[FirestoreService] markAnnouncementRead error: $e');
    }
  }

  // -------------------------------------------------------------------
  // Quiz Deep-Dive Inspection View (Analytics Modal Data)
  // -------------------------------------------------------------------

  Future<QuizAnalyticsData> getQuizPerformanceAnalytics(
    String quizId, {
    String? fileName,
    String? quizTitle,
  }) async {
    final title = quizTitle ?? fileName ?? 'Quiz Deck';
    final List<QuizResultModel> results = [];

    try {
      if (_customDb != null || _isFirebaseAvailable) {
        final querySnapshot = await _quizzesCollection
            .where('quizId', isEqualTo: quizId)
            .get()
            .timeout(const Duration(seconds: 4));
        for (final doc in querySnapshot.docs) {
          results.add(QuizResultModel.fromJson(doc.data()));
        }
      }
    } catch (_) {}

    // Include local and in-memory results strictly matching quizId
    final localHistory = await _localStorage.getQuizHistoryLocally();
    final combinedHistory = [..._fallbackQuizResults, ...localHistory];
    for (final res in combinedHistory) {
      if (res.quizId == quizId &&
          !results.any((r) => r.createdAt == res.createdAt && r.userId == res.userId)) {
        results.add(res);
      }
    }

    if (results.isEmpty) {
      return QuizAnalyticsData.empty(quizId: quizId, quizTitle: title);
    }

    // Sort by createdAt descending
    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Calculate player records
    final records = <PlayerScoreRecord>[];
    int passCount = 0;
    int failCount = 0;
    double totalPctSum = 0.0;

    for (final r in results) {
      final isPass = r.percentage >= 60.0;
      if (isPass) {
        passCount++;
      } else {
        failCount++;
      }
      totalPctSum += r.percentage;

      final elapsed = r.timeElapsedSeconds ?? (r.questionCount * 14);
      final earned = r.expEarned ?? (r.correctCount * 15);
      final rawUid = r.userId ?? '';
      final uidSnippet = rawUid.length >= 4 ? rawUid.substring(0, 4) : rawUid;
      final nickname = r.userNickname ?? (uidSnippet.isNotEmpty ? 'Scholar_$uidSnippet' : 'Scholar');

      records.add(
        PlayerScoreRecord(
          userId: rawUid,
          nickname: nickname,
          avatar: r.userAvatar,
          score: r.correctCount,
          questionCount: r.questionCount,
          percentage: r.percentage,
          timeElapsedSeconds: elapsed,
          expEarned: earned,
          createdAt: r.createdAt,
          isPass: isPass,
          questions: r.questions,
          result: r,
        ),
      );
    }

    // Top player: highest score, then fastest completion time
    final sortedRecords = List<PlayerScoreRecord>.from(records)
      ..sort((a, b) {
        final cmp = b.score.compareTo(a.score);
        if (cmp != 0) return cmp;
        return a.timeElapsedSeconds.compareTo(b.timeElapsedSeconds);
      });

    final topPlayer = sortedRecords.first;
    final avgScore = totalPctSum / results.length;
    final passRate = (passCount / results.length) * 100;

    return QuizAnalyticsData(
      quizId: quizId,
      quizTitle: title,
      totalPlays: results.length,
      topPlayer: topPlayer,
      averageScore: avgScore,
      passCount: passCount,
      failCount: failCount,
      passRate: passRate,
      playerBreakdown: records,
    );
  }

  // -------------------------------------------------------------------
  // Quiz Results & History
  // -------------------------------------------------------------------

  Future<void> saveQuizResult(QuizResultModel result) async {
    var resolvedResult = result;
    if (resolvedResult.userId == null || resolvedResult.userId!.isEmpty) {
      final currentUid = _auth.currentUser?.uid;
      if (currentUid != null && currentUid.isNotEmpty) {
        resolvedResult = resolvedResult.copyWith(userId: currentUid);
      }
    }

    final isGuest = resolvedResult.userId == null ||
        resolvedResult.userId!.isEmpty ||
        resolvedResult.userId!.startsWith('guest_');

    if (isGuest) {
      debugPrint('[FirestoreService] Guest mode: Quiz result is unrecorded per guest privacy policy.');
      return;
    }

    await _localStorage.saveQuizResultLocally(resolvedResult);
    _fallbackQuizResults.add(resolvedResult);

    try {
      final docId = '${resolvedResult.quizId}_${resolvedResult.userId ?? 'user'}_${resolvedResult.createdAt.millisecondsSinceEpoch}';
      await _quizzesCollection
          .doc(docId)
          .set(resolvedResult.toJson())
          .timeout(const Duration(seconds: 8));
      debugPrint('[FirestoreService] Successfully saved quiz attempt $docId for user ${resolvedResult.userId}');
    } catch (e) {
      debugPrint('[FirestoreService] Failed to save quiz to Firestore: $e');
    }
  }

  Future<List<QuizResultModel>> getQuizHistory(String userId) async {
    if (userId.isEmpty) {
      return _localStorage.getQuizHistoryLocally(userId: '');
    }

    try {
      final snapshot = await _quizzesCollection
          .where('userId', isEqualTo: userId)
          .get()
          .timeout(const Duration(seconds: 8));

      final remoteResults = snapshot.docs
          .map((doc) => QuizResultModel.fromJson(doc.data()))
          .toList();

      remoteResults.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      for (final res in remoteResults) {
        await _localStorage.saveQuizResultLocally(res);
      }

      return remoteResults;
    } catch (e) {
      debugPrint('[FirestoreService] Firestore history fetch error: $e. Falling back to local storage.');
      return _localStorage.getQuizHistoryLocally(userId: userId);
    }
  }

  Future<void> syncGuestHistoryToUser(String userId) async {
    // Guest activity is intentionally not recorded; no sync required.
    return;
  }

  Future<void> deleteQuizResult(String quizId) async {
    await _localStorage.deleteQuizResultLocally(quizId);
    try {
      await _quizzesCollection
          .doc(quizId)
          .delete()
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // -------------------------------------------------------------------
  // System Refresh & Scholar Data Purge Operations
  // -------------------------------------------------------------------

  /// Purges all generated quizzes and attempt records from Firestore (`quizzes` collection)
  /// and local storage. Leaves the `users` collection completely untouched.
  Future<int> clearAllGeneratedQuizDocuments() async {
    int deletedCount = _fallbackQuizResults.length;
    _fallbackQuizResults.clear();
    await _localStorage.clearAllQuizHistoryLocally();

    try {
      if (_customDb != null || _isFirebaseAvailable) {
        final snapshot = await _quizzesCollection.get().timeout(const Duration(seconds: 8));
        deletedCount = snapshot.docs.length;

        final docs = snapshot.docs;
        for (int i = 0; i < docs.length; i += 400) {
          final chunk = docs.sublist(i, (i + 400 > docs.length) ? docs.length : i + 400);
          final batch = _db.batch();
          for (final doc in chunk) {
            batch.delete(doc.reference);
          }
          await batch.commit().timeout(const Duration(seconds: 8));
        }
      }
    } catch (e) {
      debugPrint('[FirestoreService] clearAllGeneratedQuizDocuments note: $e');
    }

    return deletedCount;
  }

  /// Purges all generated quiz attempts and records belonging to a specific scholar.
  /// Preserves the scholar's profile and account in the `users` collection.
  Future<int> clearScholarQuizDocuments(String userId) async {
    if (userId.isEmpty) return 0;
    int deletedCount = _fallbackQuizResults.where((q) => q.userId == userId).length;
    _fallbackQuizResults.removeWhere((q) => q.userId == userId);
    await _localStorage.clearScholarQuizHistoryLocally(userId);

    try {
      if (_customDb != null || _isFirebaseAvailable) {
        final snapshot = await _quizzesCollection
            .where('userId', isEqualTo: userId)
            .get()
            .timeout(const Duration(seconds: 8));
        deletedCount = snapshot.docs.length;

        final docs = snapshot.docs;
        for (int i = 0; i < docs.length; i += 400) {
          final chunk = docs.sublist(i, (i + 400 > docs.length) ? docs.length : i + 400);
          final batch = _db.batch();
          for (final doc in chunk) {
            batch.delete(doc.reference);
          }
          await batch.commit().timeout(const Duration(seconds: 8));
        }
      }
    } catch (e) {
      debugPrint('[FirestoreService] clearScholarQuizDocuments note: $e');
    }

    return deletedCount;
  }

  /// Permanently deletes a scholar's user profile, statistics, and all associated quiz attempts.
  Future<void> deleteScholarAccount(String userId) async {
    if (userId.isEmpty) return;

    // 1. Purge their quiz attempts & history
    await clearScholarQuizDocuments(userId);

    // 2. Remove from Firestore users collection
    try {
      if (_customDb != null || _isFirebaseAvailable) {
        await _usersCollection.doc(userId).delete().timeout(const Duration(seconds: 6));
      }
    } catch (e) {
      debugPrint('[FirestoreService] deleteScholarAccount note: $e');
    }
  }
}
