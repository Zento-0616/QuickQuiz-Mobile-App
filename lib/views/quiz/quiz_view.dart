import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/question_model.dart';
import '../../models/quiz_model.dart';
import '../../models/quiz_settings_model.dart';
import '../../services/ad_service.dart';
import '../../utils/nav_payloads.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/quiz_viewmodel.dart';
import '../../widgets/submit_quiz_dialog.dart';

/// Professional exam screen with live timer, question palette, review flags,
/// smooth animated transitions, and styled option selectors.
class QuizView extends StatelessWidget {
  final QuizModel? quiz;
  const QuizView({super.key, this.quiz});

  @override
  Widget build(BuildContext context) {
    final quizData = quiz;
    if (quizData == null) {
      return const Scaffold(body: Center(child: Text('No quiz data received.')));
    }
    return ChangeNotifierProvider(
      key: ValueKey(quizData.id),
      create: (context) => QuizViewModel(
        quizData,
        adService: context.read<AdService>(),
      ),
      child: const _QuizBody(),
    );
  }
}

class _QuizBody extends StatefulWidget {
  const _QuizBody();

  @override
  State<_QuizBody> createState() => _QuizBodyState();
}

class _QuizBodyState extends State<_QuizBody>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _transitionController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  int _lastIndex = 0;
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _fadeAnim =
        CurvedAnimation(parent: _transitionController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.04, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _transitionController, curve: Curves.easeOut));
    _transitionController.forward();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (mounted) {
        context.read<QuizViewModel>().recordAppSwitchAttempt();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewModel = context.read<QuizViewModel>();
    viewModel.onTimeUp = _submitOnTimeout;
  }

  void _submitOnTimeout() {
    if (!mounted) return;
    final viewModel = context.read<QuizViewModel>();
    final auth = context.read<AuthViewModel>();
    final user = auth.currentUser;
    final result = viewModel.submit(
      userId: user?.uid,
      userNickname: user?.effectiveNickname,
      userAvatar: user?.photoUrl,
    );
    final QuizResultPayload payload = (quiz: viewModel.quiz, result: result);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.alarm_off_rounded, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Time's up! Your exam has been automatically submitted.",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );

    viewModel.showPostQuizAd(() {
      if (mounted) context.go(AppRoutes.result, extra: payload);
    }, context: context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transitionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(BuildContext context) async {
    final viewModel = context.read<QuizViewModel>();
    final choice = await showSubmitQuizDialog(
      context,
      answeredCount: viewModel.answeredCount,
      totalCount: viewModel.totalQuestions,
      flaggedCount: viewModel.flaggedCount,
      timeElapsed: viewModel.formattedTime,
    );

    if (!context.mounted) return;

    if (choice == SubmitDialogChoice.submitQuiz) {
      final auth = context.read<AuthViewModel>();
      final user = auth.currentUser;
      final result = viewModel.submit(
        userId: user?.uid,
        userNickname: user?.effectiveNickname,
        userAvatar: user?.photoUrl,
      );
      final QuizResultPayload payload = (quiz: viewModel.quiz, result: result);

      viewModel.showPostQuizAd(() {
        if (context.mounted) context.go(AppRoutes.result, extra: payload);
      }, context: context);
    } else if (choice == SubmitDialogChoice.reviewAnswers) {
      _showQuestionPalette(context);
    }
  }

  void _animateToNextQuestion(VoidCallback action) {
    _transitionController.reverse().then((_) {
      action();
      _transitionController.forward();
    });
  }

  void _showQuestionPalette(BuildContext context) {
    final viewModel = context.read<QuizViewModel>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _QuestionPaletteSheet(
        viewModel: viewModel,
        onSelectQuestion: (index) {
          Navigator.of(sheetContext).pop();
          if (index != viewModel.currentIndex) {
            _animateToNextQuestion(() => viewModel.goToQuestion(index));
          }
        },
        onSubmitExam: () {
          Navigator.of(sheetContext).pop();
          _handleSubmit(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<QuizViewModel>();
    final question = viewModel.currentQuestion;
    final theme = Theme.of(context);

    // Trigger slide animation when question changes
    if (viewModel.currentIndex != _lastIndex) {
      _lastIndex = viewModel.currentIndex;
      _showHint = false;
      _transitionController
        ..reset()
        ..forward();
    }

    final difficulty = viewModel.quiz.difficulty;
    final Color diffColor = _difficultyColor(difficulty.name);
    final String diffLabel = difficulty.label.toUpperCase();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        viewModel.recordBackAttempt();
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
                SizedBox(width: 8),
                Text('Exit Quiz?'),
              ],
            ),
            content: const Text(
              'Warning: Exiting or navigating away deducts 10% from your exam integrity score. Are you sure you want to return to Home?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Stay & Continue'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Exit Anyway', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (shouldExit == true && context.mounted) {
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Exit Quiz',
            onPressed: () {
              Navigator.of(context).maybePop();
            },
          ),
          title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question ${viewModel.currentIndex + 1} of ${viewModel.totalQuestions}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            Row(
              children: [
                Text(
                  '${viewModel.answeredCount} answered',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                if (viewModel.flaggedCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flag_rounded, size: 10, color: AppTheme.warningColor),
                        const SizedBox(width: 2),
                        Text(
                          '${viewModel.flaggedCount}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.warningColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          // Live Exam Timer Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: viewModel.isTimeCritical
                  ? Colors.redAccent.withValues(alpha: 0.15)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: viewModel.isTimeCritical
                    ? Colors.redAccent
                    : theme.dividerColor.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  viewModel.isCountdown
                      ? Icons.timer_outlined
                      : Icons.all_inclusive_rounded,
                  size: 14,
                  color: viewModel.isTimeCritical
                      ? Colors.redAccent
                      : AppTheme.primaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  viewModel.formattedTime,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.5,
                    color: viewModel.isTimeCritical
                        ? Colors.redAccent
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Question Palette Grid Button
          IconButton(
            tooltip: 'Question Palette',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.grid_view_rounded, size: 22),
                if (viewModel.flaggedCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.warningColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => _showQuestionPalette(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: viewModel.progress),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: theme.dividerColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(diffColor),
              ),
            ),

            // Animated question area
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tag Header row: Difficulty + Question Type + Flag Button
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: diffColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                diffLabel,
                                style: TextStyle(
                                  color: diffColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Spacer(),

                            // Flag for Review Button
                            InkWell(
                              onTap: () => viewModel.toggleFlagCurrentQuestion(),
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: question.isFlagged
                                      ? AppTheme.warningColor.withValues(alpha: 0.15)
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: question.isFlagged
                                        ? AppTheme.warningColor
                                        : theme.dividerColor.withValues(alpha: 0.2),
                                    width: question.isFlagged ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      question.isFlagged
                                          ? Icons.flag_rounded
                                          : Icons.flag_outlined,
                                      size: 16,
                                      color: question.isFlagged
                                          ? AppTheme.warningColor
                                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      question.isFlagged ? 'Flagged' : 'Flag for review',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: question.isFlagged
                                            ? AppTheme.warningColor
                                            : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Question card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: question.isFlagged
                                  ? AppTheme.warningColor.withValues(alpha: 0.4)
                                  : theme.dividerColor.withValues(alpha: 0.15),
                              width: question.isFlagged ? 1.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: question.isFlagged
                                    ? AppTheme.warningColor.withValues(alpha: 0.08)
                                    : AppTheme.primaryColor.withValues(alpha: 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Question number badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'QUESTION ${viewModel.currentIndex + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                question.question,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // MCQ Hint: Strictly on Easy and Medium difficulty only
                        if (difficulty != QuizDifficulty.hard &&
                            question.difficulty != QuizDifficulty.hard) ...[
                          const SizedBox(height: 14),
                          _HintCard(
                            hint: question.effectiveHint,
                            isExpanded: _showHint,
                            onToggle: () {
                              setState(() {
                                _showHint = !_showHint;
                              });
                            },
                          ),
                        ],

                        const SizedBox(height: 18),

                        if (question.isFillInBlank) ...[
                          _FillInBlankWidget(
                            key: ValueKey('fib_${viewModel.currentIndex}'),
                            question: question,
                            isLocked: viewModel.isAnswerLocked,
                            onAnswerSubmitted: (val) {
                              viewModel.submitTextAnswer(val);
                            },
                          ),
                        ] else ...[
                          // Answer options for Multiple Choice
                          ...List.generate(question.options.length, (index) {
                            final letter = String.fromCharCode(65 + index);
                            final selected = question.selectedAnswerIndex == index;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _AnswerTile(
                                letter: letter,
                                text: question.options[index],
                                selected: selected,
                                isLocked: viewModel.isAnswerLocked,
                                index: index,
                                onTap: () {
                                  if (viewModel.isAnswerLocked) {
                                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Row(
                                          children: [
                                            Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Strict Mode: Answers are locked once selected on Hard difficulty.',
                                                style: TextStyle(fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                          ],
                                        ),
                                        duration: Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: Color(0xFFDC2626),
                                      ),
                                    );
                                    return;
                                  }
                                  viewModel.selectAnswer(index);
                                },
                              ),
                            );
                          }),
                        ],

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Navigation footer
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.12),
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Previous',
                              maxLines: 1,
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                          onPressed: viewModel.isFirstQuestion
                              ? null
                              : () => _animateToNextQuestion(viewModel.goToPrevious),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Palette shortcut button
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton.filledTonal(
                        tooltip: 'Overview',
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.apps_rounded, size: 20),
                        onPressed: () => _showQuestionPalette(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: viewModel.isLastQuestion ? const Color(0xFF10B981) : AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                          icon: Icon(
                            viewModel.isLastQuestion
                                ? Icons.assignment_turned_in_rounded
                                : Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              viewModel.isLastQuestion ? 'Submit Exam' : 'Next',
                              maxLines: 1,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ),
                          onPressed: viewModel.isLastQuestion
                              ? () => _handleSubmit(context)
                              : () => _animateToNextQuestion(viewModel.goToNext),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Color _difficultyColor(String name) {
    switch (name.toLowerCase()) {
      case 'easy':
        return AppTheme.successColor;
      case 'medium':
        return AppTheme.warningColor;
      case 'hard':
        return const Color(0xFFEF4444);
      default:
        return AppTheme.primaryColor;
    }
  }
}

/// Question Palette Sheet that displays all question numbers in a grid
/// with their answer/flag status and allows instant navigation.
class _QuestionPaletteSheet extends StatelessWidget {
  final QuizViewModel viewModel;
  final ValueChanged<int> onSelectQuestion;
  final VoidCallback onSubmitExam;

  const _QuestionPaletteSheet({
    required this.viewModel,
    required this.onSelectQuestion,
    required this.onSubmitExam,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questions = viewModel.quiz.questions;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Question Palette',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${viewModel.answeredCount} answered · ${viewModel.flaggedCount} flagged · ${viewModel.totalQuestions - viewModel.answeredCount} remaining',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Grid of questions
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(questions.length, (index) {
                  final q = questions[index];
                  final isCurrent = index == viewModel.currentIndex;
                  final isAnswered = q.isAnswered;
                  final isFlagged = q.isFlagged;

                  Color bg;
                  Color border;
                  Color text;

                  if (isAnswered) {
                    bg = AppTheme.primaryColor;
                    border = AppTheme.primaryColor;
                    text = Colors.white;
                  } else {
                    bg = theme.cardTheme.color!;
                    border = theme.dividerColor.withValues(alpha: 0.25);
                    text = theme.colorScheme.onSurface;
                  }

                  if (isCurrent) {
                    border = AppTheme.accentColor;
                  }

                  return InkWell(
                    onTap: () => onSelectQuestion(index),
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: border,
                              width: isCurrent ? 2.5 : 1.2,
                            ),
                            boxShadow: isCurrent
                                ? [
                                    BoxShadow(
                                      color: AppTheme.accentColor.withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: text,
                              ),
                            ),
                          ),
                        ),
                        if (isFlagged)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: AppTheme.warningColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.flag_rounded,
                                size: 11,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const _PaletteLegendItem(
                color: AppTheme.primaryColor,
                label: 'Answered',
                isFilled: true,
              ),
              _PaletteLegendItem(
                color: theme.dividerColor.withValues(alpha: 0.35),
                label: 'Unanswered',
                isFilled: false,
              ),
              const _PaletteLegendItem(
                color: AppTheme.warningColor,
                label: 'Flagged',
                hasFlag: true,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Submit Exam button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.assignment_turned_in_rounded),
              label: const Text(
                'Submit Exam Now',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              onPressed: onSubmitExam,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteLegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isFilled;
  final bool hasFlag;

  const _PaletteLegendItem({
    required this.color,
    required this.label,
    this.isFilled = false,
    this.hasFlag = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasFlag)
          const Icon(Icons.flag_rounded, size: 14, color: AppTheme.warningColor)
        else
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isFilled ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color, width: 1.5),
            ),
          ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _AnswerTile extends StatelessWidget {
  final String letter;
  final String text;
  final bool selected;
  final bool isLocked;
  final int index;
  final VoidCallback onTap;

  const _AnswerTile({
    required this.letter,
    required this.text,
    required this.selected,
    this.isLocked = false,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInactiveLocked = isLocked && !selected;

    return Opacity(
      opacity: isInactiveLocked ? 0.5 : 1.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : theme.cardTheme.color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryColor
                  : theme.dividerColor.withValues(alpha: 0.18),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: selected ? AppTheme.primaryGradient : null,
                  color: selected
                      ? null
                      : theme.colorScheme.onSurface.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: TextStyle(
                      color:
                          selected ? Colors.white : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
              if (selected && isLocked)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, color: Color(0xFFDC2626), size: 16),
                      SizedBox(width: 4),
                      Text(
                        'LOCKED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFDC2626),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                )
              else if (selected)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Interactive Hint Card exclusively available on Easy & Medium questions.
class _HintCard extends StatelessWidget {
  final String hint;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _HintCard({
    required this.hint,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const amberColor = Color(0xFFF59E0B);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isExpanded
            ? (isDark
                ? amberColor.withValues(alpha: 0.12)
                : amberColor.withValues(alpha: 0.08))
            : theme.colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isExpanded
              ? amberColor.withValues(alpha: 0.4)
              : theme.dividerColor.withValues(alpha: 0.18),
          width: isExpanded ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isExpanded
                            ? amberColor.withValues(alpha: 0.2)
                            : theme.colorScheme.onSurface.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isExpanded
                            ? Icons.lightbulb_rounded
                            : Icons.lightbulb_outline_rounded,
                        size: 18,
                        color: isExpanded
                            ? amberColor
                            : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isExpanded ? 'Question Hint' : 'Need a hint? Tap to reveal',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isExpanded ? FontWeight.w800 : FontWeight.w600,
                          color: isExpanded
                              ? amberColor
                              : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: isExpanded
                          ? amberColor
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color?.withValues(alpha: 0.7) ??
                          (isDark ? const Color(0xFF1E293B) : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: amberColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                          color: amberColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hint,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                            ),
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
      ),
    );
  }
}

class _FillInBlankWidget extends StatefulWidget {
  final QuestionModel question;
  final bool isLocked;
  final ValueChanged<String> onAnswerSubmitted;

  const _FillInBlankWidget({
    super.key,
    required this.question,
    required this.isLocked,
    required this.onAnswerSubmitted,
  });

  @override
  State<_FillInBlankWidget> createState() => _FillInBlankWidgetState();
}

class _FillInBlankWidgetState extends State<_FillInBlankWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.question.userTextAnswer ?? '');
  }

  @override
  void didUpdateWidget(covariant _FillInBlankWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.userTextAnswer != widget.question.userTextAnswer &&
        widget.question.userTextAnswer != _controller.text) {
      _controller.text = widget.question.userTextAnswer ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please type your answer before locking.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    widget.onAnswerSubmitted(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isAnswered = widget.question.isAnswered;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isLocked
              ? const Color(0xFFDC2626).withValues(alpha: 0.5)
              : isAnswered
                  ? AppTheme.primaryColor.withValues(alpha: 0.6)
                  : theme.dividerColor.withValues(alpha: 0.2),
          width: isAnswered || widget.isLocked ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isLocked
                ? const Color(0xFFDC2626).withValues(alpha: 0.08)
                : AppTheme.primaryColor.withValues(alpha: 0.05),
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
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fill-in-the-Blank Answer',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Enter the missing term, formula, or concept.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isLocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 14, color: Color(0xFFDC2626)),
                      SizedBox(width: 4),
                      Text(
                        'LOCKED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFDC2626),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            readOnly: widget.isLocked,
            onSubmitted: widget.isLocked ? null : (_) => _submit(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Type your answer here...',
              filled: true,
              fillColor: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.06),
              prefixIcon: const Icon(Icons.spellcheck_rounded, size: 22),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.25),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          if (!widget.isLocked) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.lock_outline_rounded, size: 18),
                label: const Text(
                  'Confirm & Lock Answer',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Note: In Hard mode, submitted answers are strictly locked.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 18, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your answer "${widget.question.userTextAnswer}" has been submitted.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

