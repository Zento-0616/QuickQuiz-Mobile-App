import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/admin_settings_model.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/local_storage_service.dart';
import '../services/progression_service.dart';
import 'base_viewmodel.dart';

/// Owns authentication state for the whole app, plus guest gating,
/// native email/password auth, profile updates, and gamified EXP synchronization.
class AuthViewModel extends BaseViewModel {
  final AuthRepository _authRepository;
  final LocalStorageService _localStorage;
  final FirestoreService _firestoreService;

  StreamSubscription<UserModel?>? _authSub;

  UserModel? _currentUser;
  bool _guestQuizUsed = false;
  bool _authInitialized = false;
  DateTime? _lastAdminActivity;

  AuthViewModel({
    AuthRepository? authRepository,
    LocalStorageService? localStorage,
    FirestoreService? firestoreService,
  })  : _authRepository = authRepository ?? AuthRepository(),
        _localStorage = localStorage ?? LocalStorageService(),
        _firestoreService = firestoreService ?? FirestoreService() {
    _init();
  }

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isGuest => _currentUser == null;
  bool get authInitialized => _authInitialized;
  bool get guestQuizUsed => _guestQuizUsed;
  DateTime? get lastAdminActivity => _lastAdminActivity;

  void setCurrentUserForTesting(UserModel? user) {
    _currentUser = user;
    _authInitialized = true;
    notifyListeners();
  }

  Future<void> _init() async {
    _guestQuizUsed = await _localStorage.getGuestQuizUsed();

    // 1. Immediately hydrate session from local storage cache so phone close doesn't log user out
    try {
      final cached = await _localStorage.getCachedCurrentUser();
      if (cached != null) {
        if (cached.isAdmin) {
          // Check if admin inactivity exceeded 5 minutes while app was closed
          final lastActivity = await _localStorage.getLastAdminActivity();
          if (lastActivity != null &&
              DateTime.now().difference(lastActivity) > const Duration(minutes: 5)) {
            debugPrint('[AuthViewModel] Admin session expired while phone was closed (>5 mins).');
            await _localStorage.clearCachedCurrentUser();
            _currentUser = null;
          } else {
            _currentUser = cached;
            _lastAdminActivity = DateTime.now();
            await _localStorage.saveLastAdminActivity(_lastAdminActivity!);
          }
        } else {
          // Regular scholars: persist indefinitely across phone closes
          _currentUser = cached;
        }
        _authInitialized = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AuthViewModel] Error reading cached user: $e');
    }

    _seedDefaultAdmin();

    // 2. Listen to remote auth changes and keep cached profile synced
    _authSub = _authRepository.authStateChanges().listen((user) async {
      if (user != null) {
        // Fetch full profile from Firestore if available
        final fullProfile = await _firestoreService.getUserProfile(user.uid);
        if (fullProfile != null) {
          // Preserve full profile data and ensure photoUrl is synced from Google Auth if missing
          final effectivePhoto = (fullProfile.photoUrl != null && fullProfile.photoUrl!.isNotEmpty)
              ? fullProfile.photoUrl
              : user.photoUrl;
          final updated = fullProfile.copyWith(photoUrl: effectivePhoto);
          _currentUser = updated;
          if (fullProfile.photoUrl != effectivePhoto && effectivePhoto != null) {
            await _firestoreService.updateUserProfile(updated);
          }
        } else {
          _currentUser = user;
          await _firestoreService.upsertUserProfile(user);
        }
        await _localStorage.saveCurrentUser(_currentUser!);
        if (_currentUser!.isAdmin) {
          _lastAdminActivity = DateTime.now();
          await _localStorage.saveLastAdminActivity(_lastAdminActivity!);
        }
      } else {
        // Only clear if not in offline/fallback admin mode
        if (_currentUser == null || _currentUser!.uid != 'admin_default_uid') {
          // If we had no cached regular user or if Firebase explicitly reports signed out
          final cached = await _localStorage.getCachedCurrentUser();
          if (cached == null) {
            _currentUser = null;
          }
        }
      }
      _authInitialized = true;
      notifyListeners();
    });
  }

  /// Records recent interaction for administrator activity monitoring.
  void touchAdminActivity() {
    if (_currentUser?.isAdmin == true) {
      _lastAdminActivity = DateTime.now();
      _localStorage.saveLastAdminActivity(_lastAdminActivity!);
    }
  }

  /// Evaluates whether the active administrator session has exceeded 5 minutes
  /// of inactivity. If timed out, signs out and returns true.
  Future<bool> checkAdminInactivityTimeout() async {
    if (_currentUser == null || !_currentUser!.isAdmin) {
      return false;
    }
    final last = _lastAdminActivity ?? await _localStorage.getLastAdminActivity();
    if (last == null) {
      _lastAdminActivity = DateTime.now();
      await _localStorage.saveLastAdminActivity(_lastAdminActivity!);
      return false;
    }
    final elapsed = DateTime.now().difference(last);
    if (elapsed >= const Duration(minutes: 5)) {
      debugPrint('[AuthViewModel] Admin session timed out after 5 minutes of inactivity ($elapsed).');
      await signOut();
      return true;
    }
    return false;
  }

  Future<void> _seedDefaultAdmin() async {
    try {
      await _firestoreService.seedDefaultAdminAccount();
      await _authRepository.seedDefaultAdminAccount();
    } catch (_) {}
  }

  /// Free-quiz + auth gate.
  Future<bool> canCreateQuiz() async {
    if (isAuthenticated) return true;
    _guestQuizUsed = await _localStorage.getGuestQuizUsed();
    return !_guestQuizUsed;
  }

  Future<void> markGuestQuizUsedAfterSuccess() async {
    if (isAuthenticated) return;
    await _localStorage.markGuestQuizUsed();
    _guestQuizUsed = true;
    notifyListeners();
  }

  // -------------------------------------------------------------------
  // Native Email & Password Registration & Login
  // -------------------------------------------------------------------

  Future<bool> registerWithEmailPassword({
    required String email,
    required String password,
    required String realName,
    required int age,
    required String nickname,
  }) async {
    if (isLoading) return false;
    setLoading('Creating your account...');
    try {
      final user = await _authRepository.registerWithEmailPassword(
        email: email,
        password: password,
        realName: realName,
        age: age,
        nickname: nickname,
      );

      final fullUser = user.copyWith(
        name: realName,
        nickname: nickname,
        age: age,
        level: 1,
        exp: 0,
        dailyStreak: 1,
        lastLoginDate: DateTime.now(),
      );

      _currentUser = fullUser;
      await _firestoreService.upsertUserProfile(fullUser);
      await _firestoreService.syncGuestHistoryToUser(fullUser.uid);
      await _localStorage.saveCurrentUser(fullUser);

      setSuccess();
      return true;
    } on AuthException catch (e) {
      setError(e.message);
      return false;
    } catch (e) {
      setError('Registration failed: ${e.toString().replaceAll('Exception: ', '')}');
      return false;
    }
  }

  Future<bool> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (isLoading) return false;
    setLoading('Signing in...');
    final cleanEmail = email.trim();
    try {
      UserModel? user;
      try {
        user = await _authRepository.signInWithEmailPassword(
          email: cleanEmail,
          password: password,
        );
      } catch (authError) {
        // Fallback for default seeded Admin account
        if (cleanEmail.toLowerCase() == 'admin@quickquiz.com' && password == 'admin123') {
          user = UserModel(
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
        } else {
          rethrow;
        }
      }

      // Load or create profile
      final fullProfile = await _firestoreService.getUserProfile(user.uid);
      final streak = ProgressionService.evaluateDailyStreak(
        lastActive: fullProfile?.lastActive ?? fullProfile?.lastLoginDate,
        currentStreak: fullProfile?.dailyStreak ?? 1,
      );

      final resolvedUser = (fullProfile ?? user).copyWith(
        dailyStreak: streak,
        lastLoginDate: DateTime.now(),
        lastActive: DateTime.now(),
        isOnline: true,
        role: (cleanEmail.toLowerCase() == 'admin@quickquiz.com') ? 'admin' : (fullProfile?.role ?? user.role),
      );

      _currentUser = resolvedUser;
      await _firestoreService.updateUserProfile(resolvedUser);
      await _firestoreService.syncGuestHistoryToUser(user.uid);
      await _localStorage.saveCurrentUser(resolvedUser);

      if (resolvedUser.isAdmin) {
        _lastAdminActivity = DateTime.now();
        await _localStorage.saveLastAdminActivity(_lastAdminActivity!);
      }

      setSuccess();
      return true;
    } on AuthException catch (e) {
      setError(e.message);
      return false;
    } catch (e) {
      setError('Sign-in failed: ${e.toString().replaceAll('Exception: ', '')}');
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (isLoading) return false;
    setLoading('Updating password...');
    try {
      if (_currentUser?.email.toLowerCase() == 'admin@quickquiz.com' && currentPassword == 'admin123') {
        // Seeded admin password verification succeeds in fallback
        setSuccess();
        return true;
      }

      await _authRepository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      setSuccess();
      return true;
    } on AuthException catch (e) {
      setError(e.message);
      return false;
    } catch (e) {
      setError('Could not update password. Please verify your current password.');
      return false;
    }
  }

  /// Verifies administrator credentials before critical system maintenance actions.
  Future<bool> verifyAdminPassword(String password) async {
    if (_currentUser == null || !_currentUser!.isAdmin) {
      return false;
    }

    final cleanEmail = _currentUser!.email.trim().toLowerCase();
    // Default fallback admin account check
    if (cleanEmail == 'admin@quickquiz.com' && password == 'admin123') {
      return true;
    }

    try {
      await _authRepository.signInWithEmailPassword(
        email: cleanEmail,
        password: password,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    if (isLoading) return false;
    setLoading('Sending password reset email...');
    try {
      await _authRepository.sendPasswordResetEmail(email);
      setSuccess();
      return true;
    } on AuthException catch (e) {
      setError(e.message);
      return false;
    } catch (_) {
      setError('Could not send password reset email. Please verify your address.');
      return false;
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      await _authRepository.sendEmailVerification();
    } catch (_) {}
  }

  // -------------------------------------------------------------------
  // Google Sign-In
  // -------------------------------------------------------------------

  Future<bool> signInWithGoogle() async {
    if (isLoading) return false;
    setLoading('Signing in...');
    try {
      final user = await _authRepository.signInWithGoogle();
      final fullProfile = await _firestoreService.getUserProfile(user.uid);
      final effectivePhoto = (user.photoUrl != null && user.photoUrl!.isNotEmpty)
          ? user.photoUrl
          : fullProfile?.photoUrl;
      final resolvedUser = (fullProfile ?? user).copyWith(
        photoUrl: effectivePhoto,
        lastLoginDate: DateTime.now(),
        lastActive: DateTime.now(),
        isOnline: true,
      );

      _currentUser = resolvedUser;
      await _firestoreService.upsertUserProfile(resolvedUser);
      await _firestoreService.syncGuestHistoryToUser(user.uid);
      await _localStorage.saveCurrentUser(resolvedUser);
      setSuccess();
      return true;
    } on AuthException catch (e) {
      if (e.userCancelled) {
        setIdle();
      } else {
        setError(e.message);
      }
      return false;
    } catch (_) {
      setError('Something went wrong signing in. Please try again.');
      return false;
    }
  }

  /// Synchronizes Google Profile Picture & Account metadata with the current UserModel.
  Future<bool> syncGoogleAccountProfile() async {
    try {
      final fbUser = _authRepository.rawFirebaseUser;
      if (fbUser == null || _currentUser == null) return false;

      final googlePhoto = fbUser.photoURL;
      final googleName = fbUser.displayName;

      bool hasChanges = false;
      var updated = _currentUser!;

      if (googlePhoto != null && googlePhoto.isNotEmpty && updated.photoUrl != googlePhoto) {
        updated = updated.copyWith(photoUrl: googlePhoto);
        hasChanges = true;
      }

      if (googleName != null && googleName.isNotEmpty &&
          (updated.name.isEmpty || updated.name == 'Student' || updated.name == 'Scholar')) {
        updated = updated.copyWith(name: googleName);
        hasChanges = true;
      }

      if (hasChanges) {
        _currentUser = updated;
        await _firestoreService.updateUserProfile(updated);
        await _localStorage.saveCurrentUser(updated);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[AuthViewModel] syncGoogleAccountProfile error: $e');
      return false;
    }
  }

  // -------------------------------------------------------------------
  // Progression & Profile Updates
  // -------------------------------------------------------------------

  Future<QuizExpResult?> recordQuizExp({
    required int questionCount,
    required int correctCount,
    double multiplier = 1.0,
    int? expReward,
    bool allowRepeatExp = false,
    String? quizId,
    bool isOfficial = false,
    bool isGlobal = false,
    double percentage = 0.0,
  }) async {
    // Admins and Guests are excluded from earning EXP, maintaining streaks, or levelling up
    if (_currentUser == null || _currentUser!.isAdmin || _currentUser!.isGuest) return null;

    final adminSettings = await AdminSettingsModel.loadSettings();
    final isRepeat = quizId != null && _currentUser!.completedOfficialQuizIds.contains(quizId);
    final currentDailyExp = await ProgressionService.getTodayExpEarned();
    final todayCap = adminSettings.getDailyCapForDay(DateTime.now().weekday);

    final result = ProgressionService.processQuizCompletion(
      user: _currentUser!,
      questionCount: questionCount,
      correctCount: correctCount,
      deckMultiplier: multiplier,
      customExpReward: expReward,
      isRepeat: isRepeat,
      repeatExpEnabled: allowRepeatExp || adminSettings.repeatQuizExpEnabled,
      dailyExpCap: todayCap,
      currentDailyExp: currentDailyExp,
    );

    if (result.earnedExp > 0) {
      await ProgressionService.addTodayExpEarned(result.earnedExp);
    }

    final List<String> updatedCompletedQuizzes =
        (quizId != null && isOfficial && !_currentUser!.completedOfficialQuizIds.contains(quizId))
            ? [..._currentUser!.completedOfficialQuizIds, quizId]
            : _currentUser!.completedOfficialQuizIds;

    final updatedGlobalCount = isGlobal ? _currentUser!.globalQuizCount + 1 : _currentUser!.globalQuizCount;
    final updatedGlobalTotal = isGlobal ? _currentUser!.globalTotalScore + percentage : _currentUser!.globalTotalScore;

    final updated = _currentUser!.copyWith(
      exp: _currentUser!.exp + result.earnedExp,
      level: result.newLevel,
      dailyStreak: result.streakDays,
      quizzesPlayed: _currentUser!.quizzesPlayed + 1,
      totalCorrect: _currentUser!.totalCorrect + correctCount,
      totalQuestions: _currentUser!.totalQuestions + questionCount,
      lastActive: DateTime.now(),
      completedOfficialQuizIds: updatedCompletedQuizzes,
      globalQuizCount: updatedGlobalCount,
      globalTotalScore: updatedGlobalTotal,
    );

    _currentUser = updated;
    notifyListeners();

    await _firestoreService.updateUserStats(
      uid: updated.uid,
      exp: updated.exp,
      level: updated.level,
      dailyStreak: updated.dailyStreak,
      quizzesPlayed: updated.quizzesPlayed,
      totalCorrect: updated.totalCorrect,
      totalQuestions: updated.totalQuestions,
      globalQuizCount: updated.globalQuizCount,
      globalTotalScore: updated.globalTotalScore,
      globalAvgScore: updated.globalAvgScore,
    );

    if (isOfficial && quizId != null) {
      await _firestoreService.updateUserProfile(updated);
    }

    return result;
  }

  Future<void> claimDailyReward() async {
    // Admins and Guests are excluded from daily streak rewards
    if (_currentUser == null || _currentUser!.isAdmin || _currentUser!.isGuest) return;
    final claimed = await ProgressionService.isDailyRewardClaimedToday();
    if (claimed) return;

    final adminSettings = await AdminSettingsModel.loadSettings();
    final rewardExp = ProgressionService.getDailyRewardExp(_currentUser!.dailyStreak, settings: adminSettings);
    final totalExp = _currentUser!.exp + rewardExp;
    final newLevel = ProgressionService.calculateLevelFromExp(totalExp);

    final updated = _currentUser!.copyWith(
      exp: totalExp,
      level: newLevel,
      lastActive: DateTime.now(),
    );

    _currentUser = updated;
    notifyListeners();

    await ProgressionService.markDailyRewardClaimedToday();
    await _firestoreService.updateUserStats(
      uid: updated.uid,
      exp: updated.exp,
      level: updated.level,
      dailyStreak: updated.dailyStreak,
    );
  }

  Future<void> awardExpGift(int expAmount) async {
    if (_currentUser == null || expAmount <= 0) return;
    final totalExp = _currentUser!.exp + expAmount;
    final newLevel = ProgressionService.calculateLevelFromExp(totalExp);

    final updated = _currentUser!.copyWith(
      exp: totalExp,
      level: newLevel,
      lastActive: DateTime.now(),
    );

    _currentUser = updated;
    notifyListeners();

    await _firestoreService.updateUserStats(
      uid: updated.uid,
      exp: updated.exp,
      level: updated.level,
      dailyStreak: updated.dailyStreak,
    );
  }

  Future<bool> updateProfile({
    String? name,
    int? age,
    String? nickname,
    String? bio,
    String? photoUrl,
    bool? darkMode,
    bool? hapticsEnabled,
    bool? soundEnabled,
    bool? notifyQuizDrops,
    bool? notifyFriendRequests,
    bool? notifyChatMessages,
    String? role,
    String? region,
  }) async {
    if (_currentUser == null) return false;
    final updated = _currentUser!.copyWith(
      name: name,
      age: age,
      nickname: nickname,
      bio: bio,
      photoUrl: photoUrl,
      darkMode: darkMode,
      hapticsEnabled: hapticsEnabled,
      soundEnabled: soundEnabled,
      notifyQuizDrops: notifyQuizDrops,
      notifyFriendRequests: notifyFriendRequests,
      notifyChatMessages: notifyChatMessages,
      role: role,
      region: region,
      lastActive: DateTime.now(),
    );

    _currentUser = updated;
    notifyListeners();
    await _firestoreService.updateUserProfile(updated);
    await _localStorage.saveCurrentUser(updated);
    return true;
  }

  /// Periodically refreshes online heartbeat and lastActive timestamp in Firestore
  Future<void> refreshHeartbeat() async {
    if (_currentUser == null || _currentUser!.isGuest) return;
    try {
      final updated = _currentUser!.copyWith(
        isOnline: true,
        lastActive: DateTime.now(),
      );
      _currentUser = updated;
      await _firestoreService.updateUserProfile(updated);
    } catch (_) {}
  }

  /// Records a completed Dama match result (win, loss, or draw).
  /// Updates local UserModel, persists to local storage, and syncs to Firestore.
  Future<void> recordDamaMatchResult({required bool isWin, required bool isDraw}) async {
    if (_currentUser == null) return;

    final currentWins = _currentUser!.damaWins;
    final currentLosses = _currentUser!.damaLosses;
    final currentDraws = _currentUser!.damaDraws;

    final updated = _currentUser!.copyWith(
      damaWins: isWin && !isDraw ? currentWins + 1 : currentWins,
      damaLosses: !isWin && !isDraw ? currentLosses + 1 : currentLosses,
      damaDraws: isDraw ? currentDraws + 1 : currentDraws,
      isInMatch: false,
      lastActive: DateTime.now(),
    );

    _currentUser = updated;
    notifyListeners();

    try {
      await _firestoreService.updateUserProfile(updated);
      await _localStorage.saveCurrentUser(updated);
    } catch (e) {
      debugPrint('[AuthViewModel] Error recording Dama match result: $e');
    }
  }

  /// Sets the player's active in-match status to suppress challenge pop-ups during active gameplay.
  Future<void> setInMatchStatus(bool inMatch) async {
    if (_currentUser == null) return;
    if (_currentUser!.isInMatch == inMatch) return;

    final updated = _currentUser!.copyWith(
      isInMatch: inMatch,
      lastActive: DateTime.now(),
    );

    _currentUser = updated;
    notifyListeners();

    try {
      await _firestoreService.updateUserProfile(updated);
      await _localStorage.saveCurrentUser(updated);
    } catch (e) {
      debugPrint('[AuthViewModel] Error setting inMatch status: $e');
    }
  }

  Future<void> signOut() async {
    if (isLoading) return;
    setLoading();
    try {
      if (_currentUser != null) {
        try {
          await _firestoreService.updateUserProfile(
            _currentUser!.copyWith(isOnline: false, lastActive: DateTime.now()),
          );
        } catch (_) {}
      }
      try {
        await _authRepository.signOut();
      } catch (_) {}
      await _localStorage.clearCachedCurrentUser();
      _lastAdminActivity = null;
      _currentUser = null;
      setSuccess();
    } on AuthException catch (e) {
      await _localStorage.clearCachedCurrentUser();
      _lastAdminActivity = null;
      _currentUser = null;
      setError(e.message);
    } catch (_) {
      await _localStorage.clearCachedCurrentUser();
      _lastAdminActivity = null;
      _currentUser = null;
      setError('Could not sign out. Please try again.');
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
