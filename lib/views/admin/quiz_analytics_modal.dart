import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/admin_analytics_model.dart';
import '../../models/quiz_model.dart';
import '../../services/firestore_service.dart';

class QuizAnalyticsModal extends StatefulWidget {
  final QuizModel quiz;

  const QuizAnalyticsModal({super.key, required this.quiz});

  static Future<void> show(BuildContext context, QuizModel quiz) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuizAnalyticsModal(quiz: quiz),
    );
  }

  @override
  State<QuizAnalyticsModal> createState() => _QuizAnalyticsModalState();
}

class _QuizAnalyticsModalState extends State<QuizAnalyticsModal> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  QuizAnalyticsData? _analytics;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final data = await _firestoreService.getQuizPerformanceAnalytics(
        widget.quiz.id,
        fileName: widget.quiz.sourceFileName,
        quizTitle: widget.quiz.title,
      );
      if (mounted) {
        setState(() {
          _analytics = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Container(
      constraints: BoxConstraints(
        maxHeight: size.height * 0.90,
        minHeight: size.height * 0.50,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.quiz.category.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'LVL ${widget.quiz.minLevel}+',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.accentColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: widget.quiz.status == 'Active'
                                  ? Colors.green.withValues(alpha: 0.12)
                                  : Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.quiz.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: widget.quiz.status == 'Active' ? Colors.green : Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.quiz.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'View Quiz Answer Key',
                  icon: const Icon(Icons.menu_book_rounded, color: AppTheme.primaryColor),
                  onPressed: () => _showAnswerKeySheet(context),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildAnalyticsContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent(BuildContext context) {
    final data = _analytics;
    if (data == null || data.totalPlays == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.query_stats_rounded, size: 64, color: Colors.grey.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              const Text(
                'No Player Attempts Yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Players have not completed "${widget.quiz.title}" yet. Once students take this quiz, high scores, accuracy, and breakdown tables will automatically appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh Data'),
                onPressed: _loadAnalytics,
              ),
            ],
          ),
        ),
      );
    }

    final topPlayer = data.topPlayer;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (topPlayer != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOP HIGH SCORER',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          topPlayer.nickname,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF78350F),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Completed in ${topPlayer.formattedTime} • +${topPlayer.expEarned} EXP',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          topPlayer.formattedPercentage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          topPlayer.formattedScore,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Total Plays',
                  value: '${data.totalPlays}',
                  icon: Icons.play_circle_filled_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Average Score',
                  value: '${data.averageScore.toStringAsFixed(1)}%',
                  icon: Icons.analytics_rounded,
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Pass Rate',
                  value: '${data.passRate.toStringAsFixed(0)}%',
                  icon: Icons.verified_rounded,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pass / Fail Ratio', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    Text(
                      '${data.passCount} Passed (${data.passRate.toStringAsFixed(1)}%) • ${data.failCount} Failed',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 10,
                    child: Row(
                      children: [
                        Expanded(
                          flex: (data.passRate * 10).round().clamp(1, 1000),
                          child: Container(color: const Color(0xFF10B981)),
                        ),
                        if (data.failCount > 0)
                          Expanded(
                            flex: ((100 - data.passRate) * 10).round().clamp(1, 1000),
                            child: Container(color: Colors.redAccent),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Scholar Breakdown Table',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Text(
                '${data.playerBreakdown.length} records',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  AppTheme.primaryColor.withValues(alpha: 0.06),
                ),
                horizontalMargin: 16,
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('Scholar', style: TextStyle(fontWeight: FontWeight.w800))),
                  DataColumn(label: Text('Score', style: TextStyle(fontWeight: FontWeight.w800))),
                  DataColumn(label: Text('Time', style: TextStyle(fontWeight: FontWeight.w800))),
                  DataColumn(label: Text('EXP', style: TextStyle(fontWeight: FontWeight.w800))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w800))),
                  DataColumn(label: Text('Answer Sheet', style: TextStyle(fontWeight: FontWeight.w800))),
                  DataColumn(label: Text('Date Taken', style: TextStyle(fontWeight: FontWeight.w800))),
                ],
                rows: data.playerBreakdown.map((record) {
                  return DataRow(
                    cells: [
                      DataCell(
                        InkWell(
                          onTap: () => _showScholarAnswerReview(context, record),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppTheme.primaryColor,
                                child: Text(
                                  record.nickname.isNotEmpty ? record.nickname[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                record.nickname,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${record.formattedScore} (${record.formattedPercentage})',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataCell(Text(record.formattedTime)),
                      DataCell(
                        Text(
                          '+${record.expEarned}',
                          style: const TextStyle(
                            color: Color(0xFFD97706),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: record.isPass
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            record.isPass ? 'PASS' : 'FAIL',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: record.isPass ? const Color(0xFF059669) : Colors.redAccent,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                            foregroundColor: AppTheme.primaryColor,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.assignment_turned_in_rounded, size: 14),
                          label: const Text('View Answers', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                          onPressed: () => _showScholarAnswerReview(context, record),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${record.createdAt.year}-${record.createdAt.month.toString().padLeft(2, '0')}-${record.createdAt.day.toString().padLeft(2, '0')} ${record.createdAt.hour.toString().padLeft(2, '0')}:${record.createdAt.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showScholarAnswerReview(BuildContext context, PlayerScoreRecord record) {
    final questions = record.questions.isNotEmpty
        ? record.questions
        : (record.result?.questions.isNotEmpty ?? false)
            ? record.result!.questions
            : widget.quiz.questions;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        record.nickname.isNotEmpty ? record.nickname[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${record.nickname}'s Answer Breakdown",
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Score: ${record.formattedScore} (${record.formattedPercentage}) • Completed in ${record.formattedTime}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: questions.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text('No question breakdown recorded for this attempt.'),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: questions.length,
                        itemBuilder: (context, idx) {
                          final q = questions[idx];
                          final scholarChoice = q.selectedAnswerIndex;
                          final isCorrect = scholarChoice != null && scholarChoice == q.correctAnswerIndex;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isCorrect
                                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                    : Colors.redAccent.withValues(alpha: 0.3),
                                width: 1.2,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isCorrect
                                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                              : Colors.redAccent.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'QUESTION ${idx + 1}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            color: isCorrect ? const Color(0xFF059669) : Colors.redAccent,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                        color: isCorrect ? const Color(0xFF10B981) : Colors.redAccent,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    q.question,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 12),
                                  ...List.generate(q.options.length, (optIdx) {
                                    final optText = q.options[optIdx];
                                    final isScholarPick = scholarChoice == optIdx;
                                    final isRightAnswer = q.correctAnswerIndex == optIdx;

                                    Color borderColor = Colors.grey.withValues(alpha: 0.15);
                                    Color bgColor = Colors.transparent;
                                    Widget? tag;

                                    if (isRightAnswer) {
                                      borderColor = const Color(0xFF10B981);
                                      bgColor = const Color(0xFF10B981).withValues(alpha: 0.12);
                                      tag = Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isScholarPick ? 'Scholar Answer (Correct ✓)' : 'Correct Answer ✓',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                                        ),
                                      );
                                    } else if (isScholarPick) {
                                      borderColor = Colors.redAccent;
                                      bgColor = Colors.redAccent.withValues(alpha: 0.12);
                                      tag = Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Scholar Answer (Wrong ✗)',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                                        ),
                                      );
                                    }

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: bgColor,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: borderColor, width: 1.2),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              optText,
                                              style: TextStyle(
                                                fontWeight: (isRightAnswer || isScholarPick) ? FontWeight.w700 : FontWeight.normal,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          if (tag != null) ...[
                                            const SizedBox(width: 8),
                                            tag,
                                          ],
                                        ],
                                      ),
                                    );
                                  }),
                                  if (q.explanation.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.primaryColor),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Explanation: ${q.explanation}',
                                              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.8)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAnswerKeySheet(BuildContext context) {
    final questions = widget.quiz.questions;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: AppTheme.primaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Official Quiz Answer Key',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                          Text(
                            '${widget.quiz.title} • ${questions.length} Questions',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: questions.length,
                  itemBuilder: (context, idx) {
                    final q = questions[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Question ${idx + 1}: ${q.question}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 12),
                            ...List.generate(q.options.length, (optIdx) {
                              final isCorrect = q.correctAnswerIndex == optIdx;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isCorrect ? const Color(0xFF10B981).withValues(alpha: 0.12) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isCorrect ? const Color(0xFF10B981) : Colors.grey.withValues(alpha: 0.15),
                                    width: isCorrect ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        q.options[optIdx],
                                        style: TextStyle(
                                          fontWeight: isCorrect ? FontWeight.w800 : FontWeight.normal,
                                          fontSize: 13,
                                          color: isCorrect ? const Color(0xFF065F46) : null,
                                        ),
                                      ),
                                    ),
                                    if (isCorrect)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Correct Answer ✓',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                            if (q.explanation.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Rationale: ${q.explanation}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
