import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/quiz_result_model.dart';
import '../../services/progression_service.dart';
import '../../services/reward_effect_service.dart';
import '../../utils/nav_payloads.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/history_viewmodel.dart';
import '../../widgets/banner_ad_widget.dart';

/// Modern Result view: animated circular score gauge, grade letter, breakdown
/// metrics, confetti particles for high scores, animated reward & EXP celebration, and action buttons.
class ResultView extends StatefulWidget {
  final QuizResultPayload? payload;
  const ResultView({super.key, this.payload});

  @override
  State<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<ResultView>
    with TickerProviderStateMixin {
  late final HistoryViewModel _historyViewModel;
  late final AnimationController _controller;
  late final AnimationController _rewardController;
  late final Animation<double> _gaugeAnim;
  late final Animation<double> _fadeAnim;
  QuizExpResult? _expResult;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _historyViewModel = HistoryViewModel();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _gaugeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _controller.forward();

    _rewardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    final data = widget.payload;
    if (data != null && !_saved) {
      _saved = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          final auth = context.read<AuthViewModel>();
          QuizExpResult? res;

          // Check if this is an official / tournament / daily challenge quiz
          final isOfficialQuiz = data.quiz.isPublished ||
              data.quiz.quizScheduleType == 'daily' ||
              data.quiz.category == 'Daily Challenge';

          if (!auth.isGuest && auth.isAuthenticated) {
            _historyViewModel.saveResult(data.result);
            if (isOfficialQuiz) {
              res = await auth.recordQuizExp(
                questionCount: data.result.questionCount,
                correctCount: data.result.correctCount,
                multiplier: data.quiz.expMultiplier,
                expReward: data.quiz.expReward,
                allowRepeatExp: data.quiz.allowRepeatExp,
                quizId: data.quiz.id,
                isOfficial: data.quiz.isPublished,
                isGlobal: data.quiz.isGlobal,
                percentage: data.result.percentage,
              );
            } else {
              // Custom / Document Practice Quiz awards 0 EXP
              final u = auth.currentUser;
              res = QuizExpResult(
                earnedExp: 0,
                oldLevel: u?.level ?? 1,
                newLevel: u?.level ?? 1,
                leveledUp: false,
                streakDays: u?.dailyStreak ?? 1,
              );
            }
          } else {
            // Guest preview
            if (isOfficialQuiz) {
              final calculated = ProgressionService.calculateExp(
                questionCount: data.result.questionCount,
                correctCount: data.result.correctCount,
                multiplier: data.quiz.expMultiplier,
                customExpReward: data.quiz.expReward,
              );
              res = QuizExpResult(
                earnedExp: calculated,
                oldLevel: 1,
                newLevel: 1,
                leveledUp: false,
                streakDays: 1,
              );
            } else {
              res = QuizExpResult(
                earnedExp: 0,
                oldLevel: 1,
                newLevel: 1,
                leveledUp: false,
                streakDays: 1,
              );
            }
          }

          if (mounted && res != null) {
            setState(() {
              _expResult = res;
            });
            _rewardController.forward(from: 0.0);

            if (res.earnedExp > 0) {
              RewardEffectService().showCelebration(
                context,
                RewardCelebrationPayload(
                  id: 'quiz_exp_${data.quiz.id}_${DateTime.now().millisecondsSinceEpoch}',
                  title: res.leveledUp ? 'Level Up!' : 'Quiz Completed!',
                  rewardText: '+${res.earnedExp} XP',
                  subtitle: res.leveledUp
                      ? 'Congratulations! You reached Level ${res.newLevel}!'
                      : 'Knowledge points awarded for your performance.',
                  icon: res.leveledUp
                      ? Icons.military_tech_rounded
                      : Icons.workspace_premium_rounded,
                  badgeColor: res.leveledUp
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF6366F1),
                ),
              );
            }
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _rewardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.payload;
    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Result')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No result data received.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Home'),
              ),
            ],
          ),
        ),
      );
    }

    final result = data.result;
    final theme = Theme.of(context);
    final scoreColor = _colorForPercentage(result.roundedPercentage);
    final grade = _gradeFor(result.roundedPercentage);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go(AppRoutes.home);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quiz Summary'),
          leading: IconButton(
            icon: const Icon(Icons.home_rounded),
            onPressed: () => context.go(AppRoutes.home),
          ),
          automaticallyImplyLeading: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Grade $grade',
              style: TextStyle(
                color: scoreColor,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // Animated Score Gauge
                      AnimatedBuilder(
                        animation: _gaugeAnim,
                        builder: (context, _) {
                          final animatedPercent =
                              (result.roundedPercentage * _gaugeAnim.value)
                                  .round();
                          return _ScoreGauge(
                            percentage: result.roundedPercentage,
                            animatedPercent: animatedPercent,
                            progress: _gaugeAnim.value,
                            scoreColor: scoreColor,
                            grade: grade,
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      FadeTransition(
                        opacity: _fadeAnim,
                        child: Column(
                          children: [
                            Text(
                              '${result.correctCount} of ${result.questionCount} Correct',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Performance message
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: scoreColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: scoreColor.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _emojiForScore(result.roundedPercentage),
                                    style: const TextStyle(fontSize: 26),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      result.performanceMessage,
                                      style: TextStyle(
                                        color: scoreColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (_expResult != null && _expResult!.earnedExp > 0) ...[
                              const SizedBox(height: 20),
                              _CelebrationRewardCard(
                                expResult: _expResult!,
                                controller: _rewardController,
                                multiplier: data.quiz.expMultiplier,
                                customReward: data.quiz.expReward,
                              ),
                            ] else if (!data.quiz.isPublished &&
                                data.quiz.quizScheduleType != 'daily' &&
                                data.quiz.category != 'Daily Challenge') ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.school_rounded, size: 16, color: Colors.white60),
                                    SizedBox(width: 8),
                                    Text(
                                      'Personal Practice Quiz • 0 EXP',
                                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),

                            // Stats row
                            Builder(builder: (context) {
                              final skipped = result.questions
                                  .where((q) => !q.isAnswered)
                                  .length;
                              final wrong = result.questions
                                  .where((q) => q.isAnswered && !q.isCorrect)
                                  .length;
                              return Row(
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      label: 'Correct',
                                      value: '${result.correctCount}',
                                      color: AppTheme.successColor,
                                      icon: Icons.check_circle_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _StatCard(
                                      label: 'Wrong',
                                      value: '$wrong',
                                      color: const Color(0xFFEF4444),
                                      icon: Icons.cancel_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _StatCard(
                                      label: 'Skipped',
                                      value: '$skipped',
                                      color: AppTheme.warningColor,
                                      icon: Icons.remove_circle_rounded,
                                    ),
                                  ),
                                ],
                              );
                            }),

                            const SizedBox(height: 20),
                            _IntegrityCard(result: result),

                            if (result.suggestions.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              _TricksAndSuggestionsCard(suggestions: result.suggestions),
                            ],

                            const SizedBox(height: 20),
                            const BannerAdWidget(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Action buttons
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.fact_check_rounded, size: 18),
                          label: const Text('Review Answers'),
                          onPressed: () =>
                              context.go(AppRoutes.review, extra: data),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Try Again'),
                          onPressed: () {
                            if (data.quiz.isPublished && !data.quiz.isUnlimitedPlay) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Official challenges can only be played once for progression!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              return;
                            }
                            final freshQuiz = data.quiz.resetAnswers();
                            context.go(AppRoutes.quiz, extra: freshQuiz);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('New Quiz'),
                          onPressed: () => context.go(AppRoutes.upload),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.home_rounded, size: 18),
                          label: const Text('Home'),
                          onPressed: () => context.go(AppRoutes.home),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Color _colorForPercentage(int p) {
    if (p >= 75) return AppTheme.successColor;
    if (p >= 50) return AppTheme.warningColor;
    return const Color(0xFFEF4444);
  }

  String _gradeFor(int p) {
    if (p >= 95) return 'A+';
    if (p >= 90) return 'A';
    if (p >= 85) return 'A-';
    if (p >= 80) return 'B+';
    if (p >= 75) return 'B';
    if (p >= 70) return 'C+';
    if (p >= 65) return 'C';
    if (p >= 60) return 'D';
    return 'F';
  }

  String _emojiForScore(int p) {
    if (p >= 90) return '🏆';
    if (p >= 75) return '🎉';
    if (p >= 50) return '👍';
    return '📚';
  }
}

/// Animated gauge that draws its arc and ticks up the percentage number.
class _ScoreGauge extends StatelessWidget {
  final int percentage;
  final int animatedPercent;
  final double progress;
  final Color scoreColor;
  final String grade;

  const _ScoreGauge({
    required this.percentage,
    required this.animatedPercent,
    required this.progress,
    required this.scoreColor,
    required this.grade,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: 180,
            height: 180,
            child: CustomPaint(
              painter: _GaugePainter(
                progress: progress * (percentage / 100),
                trackColor: Theme.of(context).dividerColor.withValues(alpha: 0.12),
                fillColor: scoreColor,
              ),
            ),
          ),

          // Inner card
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).cardTheme.color,
              boxShadow: [
                BoxShadow(
                  color: scoreColor.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$animatedPercent%',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: scoreColor,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  'Grade $grade',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: scoreColor.withValues(alpha: 0.8),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for smooth arc gauge.
class _GaugePainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color fillColor;

  const _GaugePainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 14.0;
    const startAngle = -math.pi / 2;
    const fullSweep = 2 * math.pi;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      fullSweep,
      false,
      trackPaint,
    );

    // Fill
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        fullSweep * progress,
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress ||
      old.fillColor != fillColor ||
      old.trackColor != trackColor;
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntegrityCard extends StatelessWidget {
  final QuizResultModel result;
  const _IntegrityCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = result.integrityPercentage ?? 100.0;
    final int roundedScore = score.round();
    final isFlawless = roundedScore >= 95;
    final ratingColor = isFlawless
        ? AppTheme.successColor
        : roundedScore >= 70
            ? AppTheme.warningColor
            : const Color(0xFFEF4444);

    final hasPenalties = result.answerChangesCount > 0 ||
        result.backAttemptsCount > 0 ||
        result.screenshotAttemptsCount > 0 ||
        result.delayDeductions > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: ratingColor.withValues(alpha: 0.35),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: ratingColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ratingColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.verified_user_rounded, color: ratingColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Exam Integrity & Precision',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '100% baseline with proctoring deductions',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ratingColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ratingColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '$roundedScore%',
                  style: TextStyle(
                    color: ratingColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasPenalties)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Flawless 100% Integrity! No answer swaps or departures recorded.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.green),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (result.answerChangesCount > 0)
              _DeductionRow(
                icon: Icons.edit_note_rounded,
                title: 'Answer Modification',
                detail: '${result.answerChangesCount} changed answers',
                penaltyText: '-${result.answerChangesCount * 5}%',
              ),
            if (result.backAttemptsCount > 0)
              _DeductionRow(
                icon: Icons.arrow_back_rounded,
                title: 'Exit / Back Attempt',
                detail: '${result.backAttemptsCount} back navigation departures',
                penaltyText: '-${result.backAttemptsCount * 10}%',
              ),
            if (result.screenshotAttemptsCount > 0)
              _DeductionRow(
                icon: Icons.screenshot_monitor_rounded,
                title: 'App Switch / Phone Back',
                detail: '${result.screenshotAttemptsCount} background departures',
                penaltyText: '-${result.screenshotAttemptsCount * 10}%',
              ),
            if (result.delayDeductions > 0)
              _DeductionRow(
                icon: Icons.hourglass_bottom_rounded,
                title: 'Question Delay Deductions',
                detail: 'Speed & latency penalty',
                penaltyText: '-${result.delayDeductions}%',
              ),
          ],
        ],
      ),
    );
  }
}

class _DeductionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final String penaltyText;

  const _DeductionRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.penaltyText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: const Color(0xFFEF4444)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$title ($detail)',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            penaltyText,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }
}

class _TricksAndSuggestionsCard extends StatelessWidget {
  final List<String> suggestions;
  const _TricksAndSuggestionsCard({required this.suggestions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Exam Tricks & Study Advice',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    Text(
                      'Strategies to improve your next attempt',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...suggestions.map((suggestion) {
            final isTrick = suggestion.toLowerCase().startsWith('trick');
            final icon = isTrick ? Icons.psychology_rounded : Icons.auto_stories_rounded;
            final badgeColor = isTrick ? const Color(0xFF6366F1) : const Color(0xFF10B981);
            final badgeLabel = isTrick ? 'QUESTION TRICK' : 'STUDY TIP';

            final colonIndex = suggestion.indexOf(':');
            final title = colonIndex != -1 ? suggestion.substring(0, colonIndex).trim() : '';
            final body = colonIndex != -1 ? suggestion.substring(colonIndex + 1).trim() : suggestion;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.04)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: badgeColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 16, color: badgeColor),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: badgeColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (title.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title.replaceAll(RegExp(r'^(Trick|Study Strategy)\s*-\s*', caseSensitive: false), ''),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Celebratory animated card displaying rewards, EXP count-up, streak flame,
/// level progression, and level-up congratulations.
class _CelebrationRewardCard extends StatelessWidget {
  final QuizExpResult expResult;
  final AnimationController controller;
  final double multiplier;
  final int? customReward;

  const _CelebrationRewardCard({
    required this.expResult,
    required this.controller,
    this.multiplier = 1.0,
    this.customReward,
  });

  @override
  Widget build(BuildContext context) {
    final scaleAnim = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
    );
    final fadeAnim = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );

    return ScaleTransition(
      scale: scaleAnim,
      child: FadeTransition(
        opacity: fadeAnim,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 24),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'REWARD & EXP EARNED',
                      style: TextStyle(
                        color: Color(0xFFFBBF24),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  if (multiplier > 1.0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        '${multiplier.toStringAsFixed(1)}x Bonus',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Animated EXP Counter
              AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final displayExp = (expResult.earnedExp * controller.value).round();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '+$displayExp',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'EXP',
                        style: TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // Streaks & Bonus Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: Colors.deepOrangeAccent, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${expResult.streakDays} Day Streak',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.military_tech_rounded, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Level ${expResult.newLevel}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Level Up Celebration Callout
              if (expResult.leveledUp) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepOrange.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '🎉 LEVEL UP! You reached Level ${expResult.newLevel}! 🎉',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

