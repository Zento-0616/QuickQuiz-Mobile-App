import 'package:flutter/material.dart';
import '../app/theme.dart';

enum SubmitDialogChoice { reviewAnswers, submitQuiz, cancel }

Future<SubmitDialogChoice> showSubmitQuizDialog(
  BuildContext context, {
  required int answeredCount,
  required int totalCount,
  int flaggedCount = 0,
  String? timeElapsed,
}) async {
  final unansweredCount = totalCount - answeredCount;
  final theme = Theme.of(context);

  final result = await showDialog<SubmitDialogChoice>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.assignment_turned_in_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Submit Exam?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review your exam progress before final submission:',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                _StatusRow(
                  icon: Icons.check_circle_rounded,
                  color: AppTheme.successColor,
                  label: 'Answered',
                  value: '$answeredCount / $totalCount',
                ),
                if (flaggedCount > 0) ...[
                  const Divider(height: 18),
                  _StatusRow(
                    icon: Icons.flag_rounded,
                    color: AppTheme.warningColor,
                    label: 'Flagged for Review',
                    value: '$flaggedCount',
                  ),
                ],
                if (unansweredCount > 0) ...[
                  const Divider(height: 18),
                  _StatusRow(
                    icon: Icons.error_outline_rounded,
                    color: const Color(0xFFEF4444),
                    label: 'Unanswered',
                    value: '$unansweredCount',
                  ),
                ],
                if (timeElapsed != null) ...[
                  const Divider(height: 18),
                  _StatusRow(
                    icon: Icons.timer_outlined,
                    color: AppTheme.primaryColor,
                    label: 'Time Taken',
                    value: timeElapsed,
                  ),
                ],
              ],
            ),
          ),

          if (unansweredCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Unanswered questions will be scored as 0.',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.of(context).pop(SubmitDialogChoice.reviewAnswers),
                child: const Text('Review Questions', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.of(context).pop(SubmitDialogChoice.submitQuiz),
                child: const Text('Submit Exam', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return result ?? SubmitDialogChoice.cancel;
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatusRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
