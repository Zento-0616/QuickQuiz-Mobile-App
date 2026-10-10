import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/quiz_settings_model.dart';

class PreQuizConfirmationDialog extends StatelessWidget {
  final QuizDifficulty difficulty;
  final String quizTitle;
  final int questionCount;
  final int? timeLimitSeconds;

  const PreQuizConfirmationDialog({
    super.key,
    required this.difficulty,
    this.quizTitle = 'QuickQuiz Deck',
    this.questionCount = 10,
    this.timeLimitSeconds,
  });

  static Future<bool> show({
    required BuildContext context,
    required QuizDifficulty difficulty,
    String? quizTitle,
    int? questionCount,
    int? timeLimitSeconds,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PreQuizConfirmationDialog(
        difficulty: difficulty,
        quizTitle: quizTitle ?? 'QuickQuiz Deck',
        questionCount: questionCount ?? 10,
        timeLimitSeconds: timeLimitSeconds,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHard = difficulty == QuizDifficulty.hard;
    final isMedium = difficulty == QuizDifficulty.medium;
    final isEasy = difficulty == QuizDifficulty.easy;

    final primaryColor = isHard
        ? const Color(0xFFDC2626)
        : (isMedium ? AppTheme.primaryColor : const Color(0xFF059669));

    final badgeBg = isHard
        ? const Color(0xFFFEE2E2)
        : (isMedium ? AppTheme.primaryColor.withValues(alpha: 0.12) : const Color(0xFFD1FAE5));

    final badgeTextColor = isHard
        ? const Color(0xFFB91C1C)
        : (isMedium ? AppTheme.primaryColor : const Color(0xFF047857));

    String difficultyBadge = isHard ? 'STRICT MODE • HARD' : (isMedium ? 'TIMED • MEDIUM' : 'UNLIMITED • EASY');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isHard
                        ? Icons.lock_clock_rounded
                        : (isMedium ? Icons.timer_outlined : Icons.all_inclusive_rounded),
                    color: primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          difficultyBadge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: badgeTextColor,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        quizTitle,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  _buildRuleRow(
                    icon: isEasy ? Icons.all_inclusive_rounded : Icons.timer_rounded,
                    color: isHard ? const Color(0xFFDC2626) : primaryColor,
                    title: 'Timer Rules',
                    desc: isEasy
                        ? 'Unlimited Time: No countdown timer. Proceed at your own pace.'
                        : 'Countdown Timer: Complete all $questionCount questions before the clock hits zero.',
                  ),
                  const Divider(height: 16),
                  _buildRuleRow(
                    icon: isHard ? Icons.lock_outline_rounded : Icons.edit_note_rounded,
                    color: isHard ? const Color(0xFFDC2626) : primaryColor,
                    title: 'Answer Selection',
                    desc: isHard
                        ? 'NO CHANGING ANSWERS: Once you tap an option, your answer is permanently locked in!'
                        : 'Answer Flexibility: You can change your selected answers freely before submitting.',
                  ),
                  const Divider(height: 16),
                  _buildRuleRow(
                    icon: isHard ? Icons.highlight_off_rounded : Icons.lightbulb_outline_rounded,
                    color: isHard ? Colors.grey : const Color(0xFFF59E0B),
                    title: 'Hints & Assistance',
                    desc: isHard
                        ? 'No Hints Allowed: Strictly testing advanced recall and concepts.'
                        : 'MCQ Hints Available: Tap the lightbulb on any question for guidance.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isHard
                    ? const Color(0xFFFEF2F2)
                    : (isMedium ? const Color(0xFFF5F3FF) : const Color(0xFFECFDF5)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isHard
                      ? const Color(0xFFF87171)
                      : (isMedium ? AppTheme.primaryColor.withValues(alpha: 0.3) : const Color(0xFF6EE7B7)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isHard ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                    color: isHard ? const Color(0xFFDC2626) : primaryColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isHard
                          ? 'Warning: Strict Mode! You CANNOT change your answers once selected, and the timer is active. Are you ready?'
                          : (isMedium
                              ? 'Medium Mode: You have a countdown timer, but you can change your answers before time expires. Are you ready?'
                              : 'Easy Mode: No timer! Take your time, and you can change your answers whenever you like. Are you ready?'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isHard
                            ? const Color(0xFF991B1B)
                            : (isMedium ? const Color(0xFF5B21B6) : const Color(0xFF065F46)),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Start Quiz', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _buildRuleRow({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 2),
              Text(desc, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}
