import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/document_model.dart';
import '../../models/quiz_settings_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/quiz_generator_viewmodel.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/gemini_api_key_dialog.dart';
import '../../widgets/pre_quiz_confirmation_dialog.dart';
import '../../widgets/sign_in_required_dialog.dart';

/// Modern Quiz Settings screen: configure question count and difficulty level.
class QuizSettingsView extends StatelessWidget {
  final DocumentModel? document;
  const QuizSettingsView({super.key, this.document});


  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => QuizGeneratorViewModel(
        authViewModel: context.read<AuthViewModel>(),
      ),
      child: _QuizSettingsBody(document: document),
    );
  }
}

class _QuizSettingsBody extends StatelessWidget {
  final DocumentModel? document;
  const _QuizSettingsBody({this.document});

  Future<void> _handleGenerate(BuildContext context) async {
    final doc = document;
    if (doc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file found. Please upload a file again.')),
      );
      context.go(AppRoutes.upload);
      return;
    }

    final viewModel = context.read<QuizGeneratorViewModel>();
    final success = await viewModel.generateQuiz(doc);

    if (!context.mounted) return;

    if (viewModel.requiresSignIn) {
      final signedIn = await showSignInRequiredDialog(context);
      viewModel.clearSignInRequired();
      if (signedIn == true && context.mounted) {
        await _handleGenerate(context);
      }
      return;
    }

    if (viewModel.requiresGeminiApiKey) {
      final keyProvided = await showGeminiApiKeyDialog(context);
      viewModel.clearGeminiApiKeyRequired();
      if (keyProvided == true && context.mounted) {
        await _handleGenerate(context);
      }
      return;
    }

    if (success && context.mounted) {
      final quiz = viewModel.generatedQuiz;
      if (quiz != null) {
        final confirmed = await PreQuizConfirmationDialog.show(
          context: context,
          difficulty: quiz.difficulty,
          quizTitle: quiz.title,
          questionCount: quiz.questionCount,
          timeLimitSeconds: quiz.timeLimitSeconds,
        );
        if (!confirmed || !context.mounted) return;
      }
      context.go(AppRoutes.quiz, extra: viewModel.generatedQuiz);
    } else if (!success && viewModel.hasError && context.mounted) {
      final error = viewModel.errorMessage ?? '';
      final isQuota = error.contains('Quota') ||
          error.contains('quota') ||
          error.contains('limit: 20') ||
          error.contains('rate-limits') ||
          error.contains('rate limit') ||
          error.contains('429');
      final isDemandOrBusy = error.contains('503') ||
          error.contains('demand') ||
          error.contains('Busy') ||
          isQuota;

      if (isQuota) {
        _showQuotaHelpSheet(context, error);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.isNotEmpty ? error : 'Failed to generate quiz with Google AI Studio.'),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: isDemandOrBusy ? 'Retry' : 'Set Key',
            textColor: Colors.white,
            onPressed: () async {
              if (isDemandOrBusy) {
                await _handleGenerate(context);
              } else {
                final keyProvided = await showGeminiApiKeyDialog(context);
                if (keyProvided == true && context.mounted) {
                  await _handleGenerate(context);
                }
              }
            },
          ),
        ),
      );
    }
  }

  void _showQuotaHelpSheet(BuildContext context, String error) {
    final retryMatch = RegExp(r'retry in ([0-9\.]+)s').firstMatch(error);
    final seconds = retryMatch != null ? (double.tryParse(retryMatch.group(1) ?? '')?.ceil() ?? 45) : 45;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Colors.amber, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Google AI Studio Quota Limit',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Text(
                        'Free tier rate limit reached',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Google AI Studio free tier limits requests to 20 per day (or bursts per minute). You can wait for the cooldown (~$seconds seconds) and tap Retry, or provide your personal Gemini API key from https://aistudio.google.com/.',
              style: const TextStyle(fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.key_rounded, size: 18),
                    label: const Text('Set Key'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final keyProvided = await showGeminiApiKeyDialog(context);
                      if (keyProvided == true && context.mounted) {
                        await _handleGenerate(context);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry Now'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _handleGenerate(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<QuizGeneratorViewModel>();
    final settings = viewModel.settings;
    final theme = Theme.of(context);

    void handleBack() {
      if (document != null) {
        context.go(AppRoutes.generationMethod, extra: document);
      } else if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.home);
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quiz Configuration'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: document != null ? 'Back to Method Options' : 'Back',
            onPressed: handleBack,
          ),
          actions: [
            if (document != null)
              IconButton(
                icon: const Icon(Icons.alt_route_rounded),
                tooltip: 'Change Learning Method',
                onPressed: () => context.go(AppRoutes.generationMethod, extra: document),
              ),
            IconButton(
              icon: const Icon(Icons.key_rounded),
              tooltip: 'Google AI Studio Key',
              onPressed: () async {
                final keyProvided = await showGeminiApiKeyDialog(context);
                if (keyProvided == true && context.mounted && document != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Google AI Studio API key updated successfully!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ],
        ),
        body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (document != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.description_rounded, color: AppTheme.primaryColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                document!.fileName,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    Text(
                      'Number of Questions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Drag the slider to choose how many questions to include in your quiz (5 to 50):',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Interactive Slider Control (Drag-to-select)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: AppTheme.primaryColor,
                                    inactiveTrackColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                                    thumbColor: AppTheme.primaryColor,
                                    overlayColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                                    trackHeight: 8,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                                  ),
                                  child: Slider(
                                    value: settings.questionCount.toDouble().clamp(
                                          QuizSettingsModel.minQuestions.toDouble(),
                                          QuizSettingsModel.maxQuestions.toDouble(),
                                        ),
                                    min: QuizSettingsModel.minQuestions.toDouble(),
                                    max: QuizSettingsModel.maxQuestions.toDouble(),
                                    divisions: 9, // Steps of 5: 5, 10, 15, 20, 25, 30, 35, 40, 45, 50
                                    onChanged: viewModel.isLoading
                                        ? null
                                        : (value) => viewModel.updateQuestionCount(value.round()),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${settings.questionCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                        height: 1.1,
                                      ),
                                    ),
                                    const Text(
                                      'Questions',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Min: 5',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: settings.difficulty == QuizDifficulty.easy
                                        ? AppTheme.successColor.withValues(alpha: 0.12)
                                        : AppTheme.primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        settings.difficulty == QuizDifficulty.easy
                                            ? Icons.all_inclusive_rounded
                                            : Icons.timer_outlined,
                                        size: 13,
                                        color: settings.difficulty == QuizDifficulty.easy
                                            ? AppTheme.successColor
                                            : AppTheme.primaryColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Timer: ${settings.formattedEstimatedTime}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: settings.difficulty == QuizDifficulty.easy
                                              ? AppTheme.successColor
                                              : AppTheme.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'Max: 50',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    Text(
                      'Select Difficulty',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...QuizDifficulty.values.map((difficulty) {
                      final selected = settings.difficulty == difficulty;
                      final Color diffColor = _colorForDifficulty(difficulty);
                      final IconData diffIcon = _iconForDifficulty(difficulty);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: viewModel.isLoading
                              ? null
                              : () => viewModel.updateDifficulty(difficulty),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: selected
                                  ? diffColor.withValues(alpha: 0.08)
                                  : theme.cardTheme.color,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected ? diffColor : theme.dividerColor.withValues(alpha: 0.2),
                                width: selected ? 2 : 1,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: diffColor.withValues(alpha: 0.12),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: diffColor.withValues(alpha: selected ? 0.2 : 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(diffIcon, color: diffColor, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            difficulty.label,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: selected ? diffColor : theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          if (difficulty == QuizDifficulty.hard) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'MCQ + FILL-IN-THE-BLANK',
                                                style: TextStyle(
                                                  color: Color(0xFFEF4444),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        difficulty.description,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: diffColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              difficulty == QuizDifficulty.easy
                                                  ? Icons.all_inclusive_rounded
                                                  : Icons.timer_outlined,
                                              size: 12,
                                              color: diffColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                difficulty == QuizDifficulty.easy
                                                    ? 'Unlimited Time (Timer Disabled)'
                                                    : '${QuizSettingsModel.calculateTimeLimitInSeconds(settings.questionCount, difficulty)! ~/ 60} min countdown timer',
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: diffColor,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // ignore: deprecated_member_use
                                Radio<QuizDifficulty>(
                                  value: difficulty,
                                  // ignore: deprecated_member_use
                                  groupValue: settings.difficulty,
                                  activeColor: diffColor,
                                  // ignore: deprecated_member_use
                                  onChanged: viewModel.isLoading
                                      ? null
                                      : (value) => viewModel.updateDifficulty(value!),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    if (viewModel.isLoading) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                viewModel.loadingMessage ?? 'Generating your quiz...',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (viewModel.hasError) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          viewModel.errorMessage ?? '',
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    Center(child: BannerAdWidget(isVisible: !viewModel.isLoading)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                onPressed: viewModel.isLoading ? null : () => _handleGenerate(context),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_rounded),
                    SizedBox(width: 10),
                    Text(
                      'Generate Quiz',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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

  Color _colorForDifficulty(QuizDifficulty diff) {
    switch (diff) {
      case QuizDifficulty.easy:
        return AppTheme.successColor;
      case QuizDifficulty.medium:
        return AppTheme.warningColor;
      case QuizDifficulty.hard:
        return const Color(0xFFEF4444);
    }
  }

  IconData _iconForDifficulty(QuizDifficulty diff) {
    switch (diff) {
      case QuizDifficulty.easy:
        return Icons.lightbulb_outline_rounded;
      case QuizDifficulty.medium:
        return Icons.psychology_outlined;
      case QuizDifficulty.hard:
        return Icons.local_fire_department_outlined;
    }
  }
}


