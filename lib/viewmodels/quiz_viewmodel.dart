import 'dart:async';
import 'package:flutter/widgets.dart';

import '../models/question_model.dart';
import '../models/quiz_model.dart';
import '../models/quiz_result_model.dart';
import '../models/quiz_settings_model.dart';
import '../services/ad_service.dart';
import 'base_viewmodel.dart';

/// Manages taking an already-generated quiz: current question, answer
/// selection, flagging questions, exam timer, navigation, and scoring.
class QuizViewModel extends BaseViewModel {
  QuizModel _quiz;
  int _currentIndex = 0;
  final AdService? _adService;

  Timer? _timer;
  int _secondsElapsed = 0;
  late final bool _isCountdown;
  int _remainingSeconds = 0;
  bool _isTimeUp = false;

  // Precision & Integrity Tracking
  int _answerChangesCount = 0;
  int _backAttemptsCount = 0;
  int _screenshotAttemptsCount = 0;
  int _delayDeductions = 0;

  int get answerChangesCount => _answerChangesCount;
  int get backAttemptsCount => _backAttemptsCount;
  int get screenshotAttemptsCount => _screenshotAttemptsCount;
  int get delayDeductions => _delayDeductions;

  /// Optional callback invoked when the countdown timer hits 0.
  VoidCallback? onTimeUp;

  QuizViewModel(QuizModel quiz, {AdService? adService})
      : _quiz = quiz.copyWith(
          questions: quiz.questions.map((q) => q.randomizeAnswers()).toList(),
        ),
        _adService = adService {
    // Preload ad
    _adService?.preloadInterstitial();

    // Determine if countdown timer should be enabled:
    // Easy mode has unlimited time (no countdown).
    // Medium and Hard modes use the dynamic countdown timer.
    _isCountdown = _quiz.difficulty != QuizDifficulty.easy;

    if (_isCountdown) {
      final totalSeconds = _quiz.timeLimitSeconds ??
          QuizSettingsModel.calculateTimeLimitInSeconds(
            _quiz.questionCount,
            _quiz.difficulty,
          ) ??
          (10 * 60);
      _remainingSeconds = totalSeconds;
    }

    // Start exam session timer
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _secondsElapsed++;

      if (_isCountdown) {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
          notifyListeners();
        }

        if (_remainingSeconds <= 0 && !_isTimeUp) {
          _isTimeUp = true;
          _timer?.cancel();
          notifyListeners();
          onTimeUp?.call();
        }
      } else {
        notifyListeners();
      }
    });
  }

  QuizModel get quiz => _quiz;
  int get currentIndex => _currentIndex;
  QuestionModel get currentQuestion => _quiz.questions[_currentIndex];

  int get totalQuestions => _quiz.questionCount;
  bool get isFirstQuestion => _currentIndex == 0;
  bool get isLastQuestion => _currentIndex == totalQuestions - 1;
  int get answeredCount => _quiz.answeredCount;
  int get flaggedCount => _quiz.flaggedCount;
  bool get isCurrentFlagged => currentQuestion.isFlagged;

  bool get isCountdown => _isCountdown;
  int get secondsElapsed => _secondsElapsed;
  int get remainingSeconds => _remainingSeconds;
  bool get isTimeUp => _isTimeUp;
  bool get isTimeCritical => _isCountdown && _remainingSeconds <= 60 && !_isTimeUp;

  String get formattedTime {
    if (!_isCountdown) {
      return 'Unlimited';
    }
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  double get progress => (_currentIndex + 1) / totalQuestions;

  bool get isAnswerLocked =>
      _quiz.difficulty == QuizDifficulty.hard && currentQuestion.isAnswered;

  void selectAnswer(int optionIndex) {
    // Hard Tier (Strict Mode): Once a player taps an answer option, it is permanently locked in
    if (_quiz.difficulty == QuizDifficulty.hard && currentQuestion.isAnswered) {
      return;
    }
    // Track answer modification penalty (-5% integrity per answer change)
    if (currentQuestion.isAnswered && currentQuestion.selectedAnswerIndex != optionIndex) {
      _answerChangesCount++;
    }
    _quiz = _quiz.updateAnswer(_currentIndex, optionIndex);
    notifyListeners();
  }

  void submitTextAnswer(String answer) {
    // Hard Tier (Strict Mode): Locked once submitted
    if (_quiz.difficulty == QuizDifficulty.hard && currentQuestion.isAnswered) {
      return;
    }
    final trimmed = answer.trim();
    if (trimmed.isEmpty) return;
    if (currentQuestion.isAnswered && currentQuestion.userTextAnswer != trimmed) {
      _answerChangesCount++;
    }
    _quiz = _quiz.updateTextAnswer(_currentIndex, trimmed);
    notifyListeners();
  }

  void recordBackAttempt() {
    _backAttemptsCount++;
    notifyListeners();
  }

  void recordAppSwitchAttempt() {
    _screenshotAttemptsCount++;
    notifyListeners();
  }

  void recordDelayDeduction(int deduction) {
    _delayDeductions += deduction;
    notifyListeners();
  }

  /// Calculates the integrity & precision rating starting from a 100% baseline:
  /// - 5% penalty per answer change
  /// - 10% penalty per exit or back quiz navigation attempt
  /// - 10% penalty per phone back / backgrounding / screenshot attempt
  /// - Delay penalty if elapsed time per question exceeds normal limits
  double calculateIntegrity() {
    int delayPenalty = _delayDeductions;
    if (_quiz.questionCount > 0) {
      final avgSecondsPerQ = _secondsElapsed / _quiz.questionCount;
      if (avgSecondsPerQ > 45) {
        final excess = ((avgSecondsPerQ - 45) / 10).floor();
        delayPenalty += excess.clamp(0, 20);
      }
    }
    final totalPenalties = (_answerChangesCount * 5.0) +
        (_backAttemptsCount * 10.0) +
        (_screenshotAttemptsCount * 10.0) +
        delayPenalty;
    return (100.0 - totalPenalties).clamp(0.0, 100.0);
  }

  void toggleFlagCurrentQuestion() {
    _quiz = _quiz.toggleFlag(_currentIndex);
    notifyListeners();
  }

  void toggleFlagAt(int index) {
    if (index >= 0 && index < totalQuestions) {
      _quiz = _quiz.toggleFlag(index);
      notifyListeners();
    }
  }

  void goToNext() {
    if (!isLastQuestion) {
      _currentIndex++;
      notifyListeners();
    }
  }

  void goToPrevious() {
    if (!isFirstQuestion) {
      _currentIndex--;
      notifyListeners();
    }
  }

  /// Jumps directly to a question — used by the Review screen's
  /// "go fix this answer" affordance if you wire that up later.
  void goToQuestion(int index) {
    if (index >= 0 && index < totalQuestions) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  /// Scores the quiz and returns the result with full integrity metrics.
  QuizResultModel submit({
    String? userId,
    String? userNickname,
    String? userAvatar,
    int? expEarned,
  }) {
    final integrity = calculateIntegrity();
    return QuizResultModel.fromQuiz(
      _quiz,
      userId: userId,
      timeElapsedSeconds: _secondsElapsed,
      expEarned: expEarned,
      userNickname: userNickname,
      userAvatar: userAvatar,
      integrityPercentage: integrity,
      answerChangesCount: _answerChangesCount,
      backAttemptsCount: _backAttemptsCount,
      screenshotAttemptsCount: _screenshotAttemptsCount,
      delayDeductions: _delayDeductions,
    );
  }

  /// Shows the interstitial (if one loaded in time) right after quiz
  /// completion, then calls [onComplete]. Per spec this fires "after
  /// completing a quiz" — exactly once per quiz, never mid-question. If
  /// no ad is ready, [onComplete] fires immediately so navigation is
  /// never blocked waiting on ads.
  void showPostQuizAd(VoidCallback onComplete, {BuildContext? context, bool isAdmin = false}) {
    final adService = _adService;
    if (adService == null || isAdmin) {
      onComplete();
      return;
    }
    adService.showInterstitial(onComplete: onComplete, context: context, isAdmin: isAdmin);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
