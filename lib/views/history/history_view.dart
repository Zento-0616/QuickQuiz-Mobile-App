import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/flashcard_model.dart';
import '../../models/quiz_model.dart';
import '../../models/quiz_result_model.dart';
import '../../models/quiz_settings_model.dart';
import '../../models/study_notes_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/history_viewmodel.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/main_bottom_nav.dart';
import '../../widgets/quick_quiz_top_bar.dart';

/// Modern History screen displaying Quizzes, Structured Study Notes, and Flashcards
/// with dedicated tabs, distinct styling, and quick review/retake flows.
class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();

    return ChangeNotifierProvider(
      create: (context) {
        final vm = HistoryViewModel();
        final uid = auth.isAuthenticated ? auth.currentUser!.uid : '';
        vm.loadAllHistory(uid);
        return vm;
      },
      child: const _HistoryList(),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HistoryViewModel>();
    final auth = context.read<AuthViewModel>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go(AppRoutes.home);
      },
      child: Scaffold(
        appBar: QuickQuizTopBar(
          showBackButton: true,
          onBack: () => context.go(AppRoutes.home),
          extraActions: [
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(Icons.refresh_rounded, size: 21),
              tooltip: 'Refresh History',
              onPressed: () {
                final uid = auth.isAuthenticated ? auth.currentUser!.uid : '';
                viewModel.loadAllHistory(uid);
              },
            ),
          ],
        ),
        extendBody: true,
        bottomNavigationBar: const MainBottomNav(current: MainTab.history),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              BannerAdWidget(isVisible: !viewModel.isLoading),
              // Category Filter Tab Bar
              _buildCategoryTabs(context, viewModel),
              const SizedBox(height: 8),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    final uid = auth.isAuthenticated ? auth.currentUser!.uid : '';
                    await viewModel.loadAllHistory(uid);
                  },
                  child: _buildBody(context, viewModel, auth),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs(BuildContext context, HistoryViewModel viewModel) {
    final active = viewModel.activeFilter;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip(
            context,
            label: 'All (${viewModel.totalItems})',
            isSelected: active == HistoryCategoryFilter.all,
            onTap: () => viewModel.setFilter(HistoryCategoryFilter.all),
            color: AppTheme.primaryColor,
            icon: Icons.dashboard_rounded,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            context,
            label: 'Quizzes (${viewModel.totalQuizzes})',
            isSelected: active == HistoryCategoryFilter.quizzes,
            onTap: () => viewModel.setFilter(HistoryCategoryFilter.quizzes),
            color: const Color(0xFF8B5CF6),
            icon: Icons.quiz_rounded,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            context,
            label: 'Notes (${viewModel.totalNotes})',
            isSelected: active == HistoryCategoryFilter.notes,
            onTap: () => viewModel.setFilter(HistoryCategoryFilter.notes),
            color: const Color(0xFF10B981),
            icon: Icons.menu_book_rounded,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            context,
            label: 'Flashcards (${viewModel.totalFlashcards})',
            isSelected: active == HistoryCategoryFilter.flashcards,
            onTap: () => viewModel.setFilter(HistoryCategoryFilter.flashcards),
            color: const Color(0xFFF59E0B),
            icon: Icons.style_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : theme.dividerColor.withValues(alpha: 0.15),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, HistoryViewModel viewModel, AuthViewModel auth) {
    if (viewModel.isLoading && viewModel.totalItems == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    final active = viewModel.activeFilter;

    // Filter items based on selected tab
    List<Widget> cards = [];

    if (active == HistoryCategoryFilter.quizzes) {
      cards = viewModel.quizHistory.map((r) => _QuizHistoryCard(result: r)).toList();
    } else if (active == HistoryCategoryFilter.notes) {
      cards = viewModel.notesHistory.map((n) => _StudyNotesHistoryCard(notes: n)).toList();
    } else if (active == HistoryCategoryFilter.flashcards) {
      cards = viewModel.flashcardHistory.map((d) => _FlashcardDeckHistoryCard(deck: d)).toList();
    } else {
      // All items: combine and sort chronologically
      final unifiedItems = <({DateTime date, Widget widget})>[];

      for (final q in viewModel.quizHistory) {
        unifiedItems.add((date: q.createdAt, widget: _QuizHistoryCard(result: q)));
      }
      for (final n in viewModel.notesHistory) {
        unifiedItems.add((date: n.createdAt, widget: _StudyNotesHistoryCard(notes: n)));
      }
      for (final d in viewModel.flashcardHistory) {
        unifiedItems.add((date: d.createdAt, widget: _FlashcardDeckHistoryCard(deck: d)));
      }

      unifiedItems.sort((a, b) => b.date.compareTo(a.date));
      cards = unifiedItems.map((e) => e.widget).toList();
    }

    if (cards.isEmpty) {
      return _buildEmptyState(context, active);
    }

    return ListView.separated(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 104),
      itemCount: cards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => cards[index],
    );
  }

  Widget _buildEmptyState(BuildContext context, HistoryCategoryFilter filter) {
    final theme = Theme.of(context);

    String title;
    String subtitle;
    IconData icon;
    Color color;

    switch (filter) {
      case HistoryCategoryFilter.quizzes:
        title = 'No Quiz History Yet';
        subtitle = 'Generate and take an exam quiz from your notes to review your scores here.';
        icon = Icons.quiz_rounded;
        color = const Color(0xFF8B5CF6);
        break;
      case HistoryCategoryFilter.notes:
        title = 'No Study Notes Saved';
        subtitle = 'Synthesize academic study notes from uploaded materials to read and copy them anytime.';
        icon = Icons.menu_book_rounded;
        color = const Color(0xFF10B981);
        break;
      case HistoryCategoryFilter.flashcards:
        title = 'No Flashcards Created';
        subtitle = 'Generate 3D interactive flashcard decks from your study material to master key terms.';
        icon = Icons.style_rounded;
        color = const Color(0xFFF59E0B);
        break;
      case HistoryCategoryFilter.all:
        title = 'No Learning History Yet';
        subtitle = 'Upload your lecture slides or notes to generate quizzes, study notes, or flashcards.';
        icon = Icons.history_rounded;
        color = AppTheme.primaryColor;
        break;
    }

    return ListView(
      children: [
        const SizedBox(height: 60),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 48, color: color),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.go(AppRoutes.upload),
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('Upload Study Material'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Distinct Visual Card for Quiz Results
class _QuizHistoryCard extends StatelessWidget {
  final QuizResultModel result;
  const _QuizHistoryCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scoreColor = _colorForPercentage(result.roundedPercentage);
    final dateStr = DateFormat('MMM d, h:mm a').format(result.createdAt);

    return InkWell(
      onTap: () {
        final quiz = QuizModel(
          id: result.quizId,
          sourceFileName: result.fileName,
          difficulty: result.difficulty,
          questions: result.questions,
          createdAt: result.createdAt,
        );
        final payload = (quiz: quiz, result: result);
        context.go(AppRoutes.review, extra: payload);
      },
      borderRadius: BorderRadius.circular(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.quiz_rounded, color: Color(0xFF8B5CF6), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'QUIZ',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF8B5CF6),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          result.fileName,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              result.difficulty.label,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '• ${result.correctCount}/${result.questionCount} Correct',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${result.roundedPercentage}%',
                      style: TextStyle(
                        color: scoreColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tap to review questions',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                    tooltip: 'Delete Quiz Record',
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      final confirm = await _showDeleteConfirm(context, 'Delete this quiz result?');
                      if (confirm == true && context.mounted) {
                        context.read<HistoryViewModel>().deleteResult(result.quizId);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorForPercentage(int percentage) {
    if (percentage >= 75) return AppTheme.successColor;
    if (percentage >= 50) return AppTheme.warningColor;
    return const Color(0xFFEF4444);
  }
}

/// Distinct Visual Card for Structured Study Notes
class _StudyNotesHistoryCard extends StatelessWidget {
  final StudyNotesModel notes;
  const _StudyNotesHistoryCard({required this.notes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('MMM d, h:mm a').format(notes.createdAt);

    return InkWell(
      onTap: () {
        context.go(AppRoutes.studyNotes, extra: notes);
      },
      borderRadius: BorderRadius.circular(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: Color(0xFF10B981), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'STUDY NOTES',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF10B981),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notes.title,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${notes.sections.length} Chapters • ${notes.glossary.length} Key Terms',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (notes.overview.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  notes.overview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => context.go(AppRoutes.studyNotes, extra: notes),
                    icon: const Icon(Icons.visibility_rounded, size: 14),
                    label: const Text('Read Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                    tooltip: 'Delete Notes',
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      final confirm = await _showDeleteConfirm(context, 'Delete these study notes?');
                      if (confirm == true && context.mounted) {
                        context.read<HistoryViewModel>().deleteNotes(notes.id);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Distinct Visual Card for Flashcard Decks
class _FlashcardDeckHistoryCard extends StatelessWidget {
  final FlashcardDeckModel deck;
  const _FlashcardDeckHistoryCard({required this.deck});

  void _openDeck(BuildContext context) async {
    final historyVm = context.read<HistoryViewModel>();
    final auth = context.read<AuthViewModel>();
    final uid = auth.isAuthenticated ? auth.currentUser!.uid : '';
    await context.push(AppRoutes.flashcards, extra: deck);
    if (context.mounted) {
      historyVm.loadAllHistory(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('MMM d, h:mm a').format(deck.createdAt);

    return InkWell(
      onTap: () => _openDeck(context),
      borderRadius: BorderRadius.circular(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.style_rounded, color: Color(0xFFF59E0B), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'FLASHCARDS',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFF59E0B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          deck.title,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${deck.cardCount} Cards • ${deck.masteredCount} Mastered (${deck.masteryPercentage.round()}%)',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Mastery Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: deck.cardCount > 0 ? (deck.masteredCount / deck.cardCount) : 0,
                  minHeight: 4,
                  backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _openDeck(context),
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text('Practice Deck', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                    tooltip: 'Delete Deck',
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      final confirm = await _showDeleteConfirm(context, 'Delete this flashcard deck?');
                      if (confirm == true && context.mounted) {
                        context.read<HistoryViewModel>().deleteFlashcards(deck.id);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool?> _showDeleteConfirm(BuildContext context, String title) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
          SizedBox(width: 8),
          Text('Confirm Delete', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: Text(title, style: const TextStyle(fontSize: 13.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}