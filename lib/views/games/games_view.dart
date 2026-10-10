import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/admin_settings_model.dart';
import '../../models/quiz_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/progression_service.dart';
import '../../services/reward_effect_service.dart';
import '../../services/social_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/main_bottom_nav.dart';
import '../../widgets/pre_quiz_confirmation_dialog.dart';
import '../../widgets/quick_quiz_top_bar.dart';

class GamesView extends StatefulWidget {
  const GamesView({super.key});

  @override
  State<GamesView> createState() => _GamesViewState();
}

class _GamesViewState extends State<GamesView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();
  final SocialService _socialService = SocialService();

  List<QuizModel> _publishedQuizzes = [];
  List<UserModel> _leaderboardUsers = [];
  AdminSettingsModel? _adminSettings;
  bool _isLoading = true;
  bool _dailyRewardClaimed = false;
  int _globalQuizSubTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final quizzes = await _firestoreService.getPublishedQuizzes();
      final users = await _socialService.getLeaderboard();
      users.sort((a, b) => b.exp.compareTo(a.exp));
      final claimed = await ProgressionService.isDailyRewardClaimedToday();
      final settings = await AdminSettingsModel.loadSettings();
      if (mounted) {
        setState(() {
          _publishedQuizzes = quizzes;
          _leaderboardUsers = users;
          _dailyRewardClaimed = claimed;
          _adminSettings = settings;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go(AppRoutes.home);
      },
      child: Scaffold(
        extendBody: true,
        appBar: const QuickQuizTopBar(),
        bottomNavigationBar: const MainBottomNav(current: MainTab.games),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(icon: Icon(Icons.flash_on_rounded, size: 18), text: 'Quiz Arena'),
                    Tab(icon: Icon(Icons.public_rounded, size: 18), text: 'Global Quiz'),
                    Tab(icon: Icon(Icons.sports_esports_rounded, size: 18), text: 'Games'),
                    Tab(icon: Icon(Icons.card_giftcard_rounded, size: 18), text: 'Rewards'),
                  ],
                ),
              ),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildQuizArena(context, auth),
                          _buildGlobalQuizTab(context, auth),
                          _buildGamesHubTab(context, auth),
                          _buildRewardsTab(context, auth),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildQuizArena(BuildContext context, AuthViewModel auth) {
    final visibleQuizzes = _publishedQuizzes.where((q) => !q.isHiddenDueToExpiration).toList();

    if (visibleQuizzes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.quiz_rounded, size: 52, color: Theme.of(context).disabledColor),
              const SizedBox(height: 12),
              const Text(
                'No quizzes published by Admin yet.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Jump into the Games tab or wait for new quizzes!',
                style: TextStyle(fontSize: 12, color: Theme.of(context).disabledColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 104),
      itemCount: visibleQuizzes.length,
      itemBuilder: (context, index) {
        final quiz = visibleQuizzes[index];
            final user = auth.currentUser;
            final isCompleted = quiz.isPublished && !quiz.isUnlimitedPlay && (user?.completedOfficialQuizIds.contains(quiz.id) ?? false);
            final isStopped = quiz.isClosed;
            final rewardLabel = quiz.expReward != null && quiz.expReward! > 0
                ? '${quiz.expReward} EXP'
                : '${quiz.expMultiplier.toStringAsFixed(1)}x EXP';

            final remaining = quiz.timeRemaining;
            String? remainingLabel;
            if (remaining != null && !isStopped) {
              if (remaining.inDays > 0) {
                remainingLabel = '${remaining.inDays}d ${remaining.inHours % 24}h left';
              } else if (remaining.inHours > 0) {
                remainingLabel = '${remaining.inHours}h ${remaining.inMinutes % 60}m left';
              } else {
                remainingLabel = '${remaining.inMinutes}m left';
              }
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: quiz.isGlobal ? 3 : 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: quiz.isGlobal
                      ? const Color(0xFFF59E0B)
                      : Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
                  width: quiz.isGlobal ? 1.4 : 1.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (quiz.isGlobal) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.workspace_premium_rounded, size: 12, color: Colors.white),
                                SizedBox(width: 3),
                                Text(
                                  'GLOBAL',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9.5,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ] else if (quiz.quizScheduleType == 'daily') ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              '⚡ DAILY',
                              style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w900, fontSize: 9.5),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ] else if (quiz.quizScheduleType == 'weekly') ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              '🏆 WEEKLY',
                              style: TextStyle(color: Colors.purple, fontWeight: FontWeight.w900, fontSize: 9.5),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: AppTheme.heroGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            rewardLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const Spacer(),

                        if (isStopped)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'DONE',
                              style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w900, fontSize: 10),
                            ),
                          )
                        else if (isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.green, size: 12),
                                SizedBox(width: 3),
                                Text(
                                  'COMPLETED',
                                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 9.5),
                                ),
                              ],
                            ),
                          )
                        else if (remainingLabel != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer_outlined, size: 12, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 3),
                                Text(
                                  remainingLabel,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 9.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Text(
                      quiz.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    Text(
                      quiz.topicTags.isNotEmpty ? quiz.topicTags.first : quiz.category,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  quiz.difficulty.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.help_outline_rounded, size: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${quiz.questionCount} Qs',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.schedule_rounded, size: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${quiz.timeLimitSeconds}s/Q',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        if (isStopped)
                          IconButton(
                            icon: const Icon(Icons.leaderboard_rounded, color: Colors.blueGrey, size: 22),
                            tooltip: 'View Top Scholars',
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              final topScholars = _getTopScholarsForQuiz(quiz, index);
                              _showQuizDetailsAndTop5Modal(context, quiz, auth, topScholars);
                            },
                          )
                        else if (isCompleted)
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Done', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.green)),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('You have already completed this official challenge and claimed your reward!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          )
                        else
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 19),
                            label: const Text('Play', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                            onPressed: () async {
                              if (auth.isGuest) {
                                _showGuestRestrictedDialog(context);
                                return;
                              }
                              final confirmed = await PreQuizConfirmationDialog.show(
                                context: context,
                                difficulty: quiz.difficulty,
                                quizTitle: quiz.title,
                                questionCount: quiz.questionCount,
                                timeLimitSeconds: quiz.timeLimitSeconds,
                              );
                              if (confirmed && context.mounted) {
                                context.go(AppRoutes.quiz, extra: quiz);
                              }
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
  }

  Widget _buildGamesHubTab(BuildContext context, AuthViewModel auth) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 104),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sports_esports_rounded, color: Color(0xFF38BDF8), size: 14),
                        SizedBox(width: 5),
                        Text('GAMES & ARCADE', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w900, fontSize: 10.5)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Open 24/7 • 0 EXP', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Scholar Games Arena',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Play strategic permanent board games and mind challenges with scholars anytime. Practice tactics, invite friends, or compete vs Smart AI!',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        const Text('Available Games', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),

        _buildPermanentGameCard(
          context: context,
          title: 'Scholar Dama (8x8 Checkers)',
          subtitle: 'Classic tactical board game. Single & multi-jumps, flying kings, PvP matchmaking, invite challenges, and vs Smart AI bots.',
          tag: 'FEATURED BOARD GAME',
          tagColor: const Color(0xFFF59E0B),
          icon: Icons.grid_4x4_rounded,
          gradient: const [Color(0xFF18181B), Color(0xFF27272A)],
          buttonLabel: 'Play Dama',
          buttonColor: const Color(0xFFF59E0B),
          onTap: () {
            if (auth.isGuest) {
              _showGuestRestrictedDialog(context);
              return;
            }
            context.push(AppRoutes.dama);
          },
        ),
        const SizedBox(height: 14),

        _buildPermanentGameCard(
          context: context,
          title: 'Scholar Chess',
          subtitle: '8x8 Grandmaster Blitz & Tactical Matches. Castling, pawn promotions, legal move engine, PvP matchmaking, and Minimax AI.',
          tag: 'FEATURED BOARD GAME',
          tagColor: const Color(0xFF818CF8),
          icon: Icons.security_rounded,
          gradient: const [Color(0xFF0F172A), Color(0xFF1E1B4B)],
          buttonLabel: 'Play Chess',
          buttonColor: const Color(0xFF6366F1),
          onTap: () {
            if (auth.isGuest) {
              _showGuestRestrictedDialog(context);
              return;
            }
            context.push(AppRoutes.chess);
          },
        ),
        const SizedBox(height: 14),

        _buildPermanentGameCard(
          context: context,
          title: 'Word Grid Arena',
          subtitle: 'High-speed vocabulary and lexical puzzle battles. Connect letters, score anagram combos, and dominate the letter board.',
          tag: 'IN THE WORKS',
          tagColor: const Color(0xFF10B981),
          icon: Icons.spellcheck_rounded,
          gradient: const [Color(0xFF064E3B), Color(0xFF0F172A)],
          buttonLabel: 'Planned Game',
          buttonColor: Colors.grey.shade700,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Word Grid Arena is planned for an upcoming release!')),
          ),
        ),
      ],
    );
  }

  Widget _buildPermanentGameCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String tag,
    required Color tagColor,
    required IconData icon,
    required List<Color> gradient,
    required String buttonLabel,
    required Color buttonColor,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tagColor.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(color: tagColor.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
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
                  color: tagColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: tagColor, size: 22),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(tag, style: TextStyle(color: tagColor, fontWeight: FontWeight.w900, fontSize: 10)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('0 EXP', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onTap,
              child: Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }


  void _showGuestRestrictedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: AppTheme.primaryColor),
            SizedBox(width: 10),
            Text('Account Required'),
          ],
        ),
        content: const Text(
          'Guests cannot play multiplayer arenas, tournaments, or board games, and cannot earn EXP or climb leaderboards.\n\nPlease sign in or register to compete with scholars worldwide!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Stay as Guest'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go(AppRoutes.auth);
            },
            child: const Text('Sign In / Register'),
          ),
        ],
      ),
    );
  }

  List<UserModel> _getTopScholarsForQuiz(QuizModel quiz, int quizIndex) {
    if (_leaderboardUsers.isEmpty) return [];
    final playedScholars = _leaderboardUsers
        .where((u) => u.completedOfficialQuizIds.contains(quiz.id))
        .toList();
    if (playedScholars.isNotEmpty) {
      playedScholars.sort((a, b) => b.exp.compareTo(a.exp));
      return playedScholars.take(5).toList();
    }
    return [];
  }

  void _showQuizDetailsAndTop5Modal(
    BuildContext context,
    QuizModel quiz,
    AuthViewModel auth,
    List<UserModel> topScholars,
  ) {
    final isCompleted = quiz.isPublished &&
        !quiz.isUnlimitedPlay &&
        (auth.currentUser?.completedOfficialQuizIds.contains(quiz.id) ?? false);
    final isStopped = quiz.isClosed;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        final theme = Theme.of(modalCtx);
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(modalCtx).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                    color: theme.dividerColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      quiz.title,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(modalCtx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (isStopped) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_clock_rounded, size: 13, color: Colors.blueGrey),
                          SizedBox(width: 4),
                          Text(
                            'CONCLUDED / DONE',
                            style: TextStyle(
                              color: Colors.blueGrey,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (quiz.isGlobal ? Colors.indigo : AppTheme.primaryColor).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      quiz.isGlobal
                          ? 'GLOBAL QUIZ'
                          : (quiz.quizScheduleType == 'daily'
                              ? 'DAILY CHALLENGE'
                              : (quiz.quizScheduleType == 'weekly' ? 'WEEKLY TOURNAMENT' : 'ARENA DECK')),
                      style: TextStyle(
                        color: quiz.isGlobal ? Colors.indigo : AppTheme.primaryColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      quiz.difficulty.name.toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: AppTheme.heroGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${quiz.expMultiplier.toStringAsFixed(1)}x EXP',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${quiz.questionCount} Questions',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                  ),
                ],
              ),
              if (quiz.description != null && quiz.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  quiz.description!,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, size: 20, color: Color(0xFFFFD700)),
                  SizedBox(width: 8),
                  Text(
                    'Top 5 Scholars of This Quiz',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: topScholars.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Colors.grey),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No plays recorded yet. Be the first to claim #1 on this quiz!',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: topScholars.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (ctx, sIdx) {
                          final rank = sIdx + 1;
                          final scholar = topScholars[sIdx];
                          Color rankColor = const Color(0xFF64748B);
                          if (rank == 1) rankColor = const Color(0xFFFFD700);
                          if (rank == 2) rankColor = const Color(0xFFC0C0C0);
                          if (rank == 3) rankColor = const Color(0xFFCD7F32);

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.cardTheme.color,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: rank == 1
                                    ? const Color(0xFFFFD700).withValues(alpha: 0.4)
                                    : theme.dividerColor.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: rankColor.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$rank',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        color: rankColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppTheme.primaryColor,
                                  child: Text(
                                    scholar.effectiveNickname.isNotEmpty
                                        ? scholar.effectiveNickname[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          if (scholar.regionFlag.isNotEmpty) ...[
                                            Text(scholar.regionFlag, style: const TextStyle(fontSize: 14)),
                                            const SizedBox(width: 4),
                                          ],
                                          Flexible(
                                            child: Text(
                                              scholar.effectiveNickname,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'Level ${scholar.level} • ${scholar.winRate}% win rate',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${scholar.exp} EXP',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: isStopped
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: Colors.blueGrey,
                          side: BorderSide(color: Colors.blueGrey.shade400),
                        ),
                        icon: const Icon(Icons.lock_clock_rounded, color: Colors.blueGrey),
                        label: const Text('Concluded / Done (Leaderboard Finalized)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        onPressed: () {
                          Navigator.of(modalCtx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('This quiz tournament has concluded. Top scholars and scores are locked in the hall of fame!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      )
                    : isCompleted
                        ? OutlinedButton.icon(
                            icon: const Icon(Icons.verified_rounded, color: Colors.green),
                            label: const Text('Official Play Completed'),
                            onPressed: () {
                              Navigator.of(modalCtx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('You have already completed this official challenge and claimed your reward!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          )
                        : ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 20),
                            label: const Text('Play Challenge', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            onPressed: () async {
                              Navigator.of(modalCtx).pop();
                              if (auth.isGuest) {
                                _showGuestRestrictedDialog(context);
                                return;
                              }
                              final confirmed = await PreQuizConfirmationDialog.show(
                                context: context,
                                difficulty: quiz.difficulty,
                                quizTitle: quiz.title,
                                questionCount: quiz.questionCount,
                                timeLimitSeconds: quiz.timeLimitSeconds,
                              );
                              if (confirmed && context.mounted) {
                                context.go(AppRoutes.quiz, extra: quiz);
                              }
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlobalQuizTab(BuildContext context, AuthViewModel auth) {
    final user = auth.currentUser;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _globalQuizSubTab = 0),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _globalQuizSubTab == 0 ? AppTheme.primaryColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        'Quizzes',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          color: _globalQuizSubTab == 0
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _globalQuizSubTab = 1),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _globalQuizSubTab == 1 ? AppTheme.primaryColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        'Top Scholars',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          color: _globalQuizSubTab == 1
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _globalQuizSubTab == 0
              ? _buildQuizCardsList(context, auth)
              : _buildScholarRankingsList(context, user),
        ),
      ],
    );
  }

  Widget _buildQuizCardsList(BuildContext context, AuthViewModel auth) {
    if (_publishedQuizzes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.public_off_rounded, size: 54, color: Theme.of(context).disabledColor),
              const SizedBox(height: 12),
              const Text(
                'No quizzes published yet.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 104),
      itemCount: _publishedQuizzes.length,
      itemBuilder: (context, index) {
        final quiz = _publishedQuizzes[index];
        final topScholars = _getTopScholarsForQuiz(quiz, index);
        final top1 = topScholars.isNotEmpty ? topScholars.first : null;
        final isStopped = quiz.status.toLowerCase() == 'stopped' ||
            quiz.status.toLowerCase() == 'done' ||
            quiz.status.toLowerCase() == 'concluded';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showQuizDetailsAndTop5Modal(context, quiz, auth, topScholars),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isStopped) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'CONCLUDED',
                                  style: TextStyle(
                                    color: Colors.blueGrey,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: (quiz.isGlobal ? Colors.indigo : AppTheme.primaryColor).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                quiz.isGlobal
                                    ? 'GLOBAL'
                                    : (quiz.quizScheduleType == 'daily'
                                        ? 'DAILY'
                                        : (quiz.quizScheduleType == 'weekly' ? 'WEEKLY' : 'ARENA')),
                                style: TextStyle(
                                  color: quiz.isGlobal ? Colors.indigo : AppTheme.primaryColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              quiz.difficulty.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          quiz.title,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${quiz.questionCount} Questions • ${quiz.expMultiplier.toStringAsFixed(1)}x EXP',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Row(
                          children: [
                            Icon(Icons.touch_app_rounded, size: 12, color: AppTheme.primaryColor),
                            SizedBox(width: 4),
                            Text(
                              'Tap for Details & Top 5 Scholars',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: Theme.of(context).cardTheme.color,
                              child: top1 != null
                                  ? Text(
                                      top1.effectiveNickname.isNotEmpty
                                          ? top1.effectiveNickname[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFD97706),
                                        fontSize: 16,
                                      ),
                                    )
                                  : const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 22),
                            ),
                          ),
                          Positioned(
                            top: -8,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.workspace_premium_rounded, size: 10, color: Colors.black87),
                                  Text(
                                    '#1',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 78,
                        child: Text(
                          top1 != null ? top1.effectiveNickname : 'Be #1!',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (top1 != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${top1.regionFlag} Lvl ${top1.level}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScholarRankingsList(BuildContext context, UserModel? currentUser) {
    if (_leaderboardUsers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.leaderboard_rounded, size: 54, color: Theme.of(context).disabledColor),
              const SizedBox(height: 12),
              const Text(
                'No rankings yet. Play a quiz to claim #1!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 104),
      itemCount: _leaderboardUsers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final rank = index + 1;
        final u = _leaderboardUsers[index];
        final isMe = currentUser != null && currentUser.uid == u.uid;

        Color? rankColor;
        if (rank == 1) {
          rankColor = const Color(0xFFFFD700);
        } else if (rank == 2) {
          rankColor = const Color(0xFFC0C0C0);
        } else if (rank == 3) {
          rankColor = const Color(0xFFCD7F32);
        }

        return Card(
          color: isMe
              ? AppTheme.primaryColor.withValues(alpha: 0.12)
              : Theme.of(context).cardTheme.color,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: rankColor != null
                            ? rankColor.withValues(alpha: 0.25)
                            : (rank <= 10
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
                      ),
                      child: Center(
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: rankColor ?? (rank <= 10 ? const Color(0xFFD97706) : Theme.of(context).colorScheme.onSurface),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    if (rank <= 10) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.workspace_premium_rounded,
                        size: 18,
                        color: rank == 1
                            ? const Color(0xFFFFD700)
                            : (rank == 2
                                ? const Color(0xFFC0C0C0)
                                : (rank == 3 ? const Color(0xFFCD7F32) : const Color(0xFFF59E0B))),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 14),

                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    u.effectiveNickname.isNotEmpty ? u.effectiveNickname[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (u.regionFlag.isNotEmpty) ...[
                            Text(
                              u.regionFlag,
                              style: const TextStyle(fontSize: 15),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              u.effectiveNickname,
                              style: TextStyle(
                                fontWeight: isMe ? FontWeight.w900 : FontWeight.w700,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'YOU',
                                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Level ${u.level} • ${u.quizzesPlayed} quizzes • ${u.winRate}% win rate',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),

                Text(
                  '${u.exp} EXP',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }




  Widget _buildRewardsTab(BuildContext context, AuthViewModel auth) {
    final user = auth.currentUser;
    final currentStreak = user?.dailyStreak ?? 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 104),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF97316), Color(0xFFEF4444)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepOrange.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_fire_department_rounded, size: 40, color: Colors.white),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$currentStreak Day Streak!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Keep practicing quizzes daily to maintain your multiplier bonus.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daily Login Calendar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 13, color: AppTheme.primaryColor),
                    SizedBox(width: 4),
                    Text(
                      'Resets 4:00 PM',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.primaryColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Builder(builder: (context) {
            const dayNames = {
              1: 'Mon',
              2: 'Tue',
              3: 'Wed',
              4: 'Thu',
              5: 'Fri',
              6: 'Sat',
              7: 'Sun',
            };

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.80,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: 7,
              itemBuilder: (context, index) {
                final dayNumber = index + 1;
                final rewardExp = ProgressionService.getDailyRewardExp(dayNumber, settings: _adminSettings);
                final isCurrentDay = ((currentStreak - 1) % 7) + 1 == dayNumber;
                final isPastDay = ((currentStreak - 1) % 7) + 1 > dayNumber;

                return Container(
                  decoration: BoxDecoration(
                    color: isCurrentDay
                        ? AppTheme.primaryColor.withValues(alpha: 0.15)
                        : Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrentDay
                          ? AppTheme.primaryColor
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                      width: isCurrentDay ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Day $dayNumber',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        dayNames[dayNumber] ?? '',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isCurrentDay ? AppTheme.primaryColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        isPastDay ? Icons.check_circle_rounded : Icons.star_rounded,
                        color: isPastDay
                            ? AppTheme.successColor
                            : (isCurrentDay ? AppTheme.accentColor : Colors.amber),
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '+$rewardExp',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ],
                  ),
                );
              },
            );
          }),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _dailyRewardClaimed ? const Color(0xFF1E293B) : AppTheme.primaryColor,
                side: _dailyRewardClaimed
                    ? BorderSide(color: Colors.white.withValues(alpha: 0.15))
                    : BorderSide.none,
              ),
              icon: Icon(
                _dailyRewardClaimed ? Icons.check_circle_rounded : Icons.card_giftcard_rounded,
                color: _dailyRewardClaimed ? const Color(0xFF10B981) : Colors.white,
              ),
              label: Text(
                _dailyRewardClaimed ? 'Today\'s Reward Claimed (View Streak)' : 'Claim Daily Reward',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: _dailyRewardClaimed ? Colors.white70 : Colors.white,
                ),
              ),
              onPressed: (user == null || auth.isGuest)
                  ? null
                  : () async {
                      final claimExp = ProgressionService.getDailyRewardExp(currentStreak, settings: _adminSettings);
                      if (_dailyRewardClaimed) {
                        _showAlreadyClaimedStreakDialog(context, currentStreak, claimExp);
                        return;
                      }

                      await auth.claimDailyReward();
                      setState(() => _dailyRewardClaimed = true);
                      if (context.mounted) {
                        RewardEffectService().showCelebration(
                          context,
                          RewardCelebrationPayload(
                            id: 'daily_reward_${DateTime.now().year}_${DateTime.now().month}_${DateTime.now().day}_${DateTime.now().millisecondsSinceEpoch}',
                            title: 'Daily Streak Reward!',
                            rewardText: '+$claimExp EXP',
                            subtitle: '$currentStreak Day Streak! Consistency is key.',
                            icon: Icons.local_fire_department_rounded,
                            badgeColor: const Color(0xFFEF4444),
                          ),
                        );
                        _showClaimSuccessDialog(context, currentStreak, claimExp);
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  void _showAlreadyClaimedStreakDialog(BuildContext context, int currentStreak, int claimExp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFEF4444), size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Streak Maintained!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Day $currentStreak Reward Already Claimed (+$claimExp EXP).',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 10),
            const Text(
              'Keep up the great momentum! Come back tomorrow to claim your next streak reward.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got it!', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClaimSuccessDialog(BuildContext context, int currentStreak, int claimExp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.card_giftcard_rounded, color: Colors.amber, size: 52),
            ),
            const SizedBox(height: 16),
            const Text(
              '🎉 Daily Reward Claimed!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Text(
                '+$claimExp EXP Added to Profile',
                style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_fire_department_rounded, color: Color(0xFFEF4444), size: 18),
                const SizedBox(width: 4),
                Text(
                  '$currentStreak Day Streak Active!',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Consistency is key to mastering your studies. See you tomorrow!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Claim & Continue', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
