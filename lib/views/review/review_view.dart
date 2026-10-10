import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/question_model.dart';
import '../../models/quiz_result_model.dart';
import '../../utils/nav_payloads.dart';

/// Modern Answer Review screen.
class ReviewView extends StatelessWidget {
  final QuizResultPayload? payload;
  const ReviewView({super.key, this.payload});

  @override
  Widget build(BuildContext context) {
    final data = payload;
    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Answers')),
        body: const Center(child: Text('No quiz data received.')),
      );
    }

    final questions = data.quiz.questions;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detailed Review'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.home);
              }
            },
          ),
          actions: [
          if (data.result.suggestions.isNotEmpty)
            IconButton(
              tooltip: 'Study Tricks & Advice',
              icon: const Icon(Icons.lightbulb_rounded, color: AppTheme.warningColor),
              onPressed: () => _showReviewSuggestionsSheet(context, data.result),
            ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${data.result.correctCount}/${data.result.questionCount} Correct',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: questions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          return _ReviewCard(
            questionNumber: index + 1,
            question: questions[index],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.home_rounded),
            label: const Text('Back to Home'),
            onPressed: () => context.go(AppRoutes.home),
          ),
        ),
      ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final int questionNumber;
  final QuestionModel question;
  const _ReviewCard({required this.questionNumber, required this.question});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrect = question.isCorrect;
    final wasAnswered = question.isAnswered;

    final Color statusColor = !wasAnswered
        ? Colors.grey
        : (isCorrect ? AppTheme.successColor : const Color(0xFFEF4444));
    final IconData statusIcon = !wasAnswered
        ? Icons.remove_circle_outline_rounded
        : (isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded);
    final String statusLabel =
        !wasAnswered ? 'Unanswered' : (isCorrect ? 'Correct' : 'Incorrect');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'Q$questionNumber',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              question.question,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),

            if (question.isFillInBlank) ...[
              // Fill-in-the-Blank review view
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? AppTheme.successColor.withValues(alpha: 0.1)
                      : (wasAnswered
                          ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCorrect
                        ? AppTheme.successColor
                        : (wasAnswered ? const Color(0xFFEF4444) : Colors.white24),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCorrect ? Icons.check_circle_rounded : Icons.edit_note_rounded,
                      color: isCorrect ? AppTheme.successColor : (wasAnswered ? const Color(0xFFEF4444) : Colors.grey),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Answer:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            wasAnswered ? question.userTextAnswer! : '(No answer entered)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isCorrect
                                  ? AppTheme.successColor
                                  : (wasAnswered ? const Color(0xFFEF4444) : Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isCorrect) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.successColor, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: AppTheme.successColor, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Correct Term / Answer:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              question.effectiveCorrectAnswerText,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.successColor,
                              ),
                            ),
                            if (question.acceptableAnswers.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Accepted variations: ${question.acceptableAnswers.join(", ")}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              // Options list with highlights for Multiple Choice
              ...List.generate(question.options.length, (idx) {
                final isUserChoice = question.selectedAnswerIndex == idx;
                final isCorrectChoice = question.correctAnswerIndex == idx;
                final letter = String.fromCharCode(65 + idx);

                Color bg = Colors.transparent;
                Color border = theme.dividerColor.withValues(alpha: 0.2);
                Color textColor = theme.colorScheme.onSurface;

                if (isCorrectChoice) {
                  bg = AppTheme.successColor.withValues(alpha: 0.12);
                  border = AppTheme.successColor;
                  textColor = AppTheme.successColor;
                } else if (isUserChoice && !isCorrect) {
                  bg = const Color(0xFFEF4444).withValues(alpha: 0.12);
                  border = const Color(0xFFEF4444);
                  textColor = const Color(0xFFEF4444);
                }

                String? badge;
                if (isUserChoice) {
                  badge = 'Your answer';
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border, width: (isCorrectChoice || isUserChoice) ? 1.5 : 1),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '$letter.',
                        style: TextStyle(fontWeight: FontWeight.w800, color: textColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          question.options[idx],
                          style: TextStyle(
                            fontWeight: (isCorrectChoice || isUserChoice) ? FontWeight.w700 : FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                      ),
                      if (badge != null)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isCorrect ? AppTheme.successColor : const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_rounded, color: AppTheme.primaryColor, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Explanation',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    question.explanation,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showReviewSuggestionsSheet(BuildContext context, QuizResultModel result) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(ctx).size.height * 0.78,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
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
                child: const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Exam Tricks & Study Advice',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Strategies to improve your next attempt',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              itemCount: result.suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final suggestion = result.suggestions[index];
                final isTrick = suggestion.toLowerCase().startsWith('trick');
                final icon = isTrick ? Icons.psychology_rounded : Icons.auto_stories_rounded;
                final badgeColor = isTrick ? const Color(0xFF6366F1) : const Color(0xFF10B981);
                final badgeLabel = isTrick ? 'QUESTION TRICK' : 'STUDY TIP';

                final colonIndex = suggestion.indexOf(':');
                final title = colonIndex != -1 ? suggestion.substring(0, colonIndex).trim() : '';
                final body = colonIndex != -1 ? suggestion.substring(colonIndex + 1).trim() : suggestion;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
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
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
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
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}