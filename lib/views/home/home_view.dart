import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/quiz_result_model.dart';
import '../../models/quiz_settings_model.dart';
import '../../models/user_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/history_viewmodel.dart';
import '../../services/local_storage_service.dart';
import '../../services/phone_notification_service.dart';
import '../../utils/constants.dart';
import '../../widgets/ai_provider_logo.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/gemini_api_key_dialog.dart';
import '../../widgets/main_bottom_nav.dart';
import '../../widgets/quick_quiz_top_bar.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with SingleTickerProviderStateMixin {
  DateTime? _lastBackPressTime;
  late final AnimationController _animController;
  late final Animation<Color?> _color1Anim;
  late final Animation<Color?> _color2Anim;
  late final Animation<Color?> _color3Anim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _color1Anim = ColorTween(
      begin: const Color(0xFF4F46E5),
      end: const Color(0xFF7C3AED),
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));

    _color2Anim = ColorTween(
      begin: const Color(0xFF7C3AED),
      end: const Color(0xFFD946EF),
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));

    _color3Anim = ColorTween(
      begin: const Color(0xFFD946EF),
      end: const Color(0xFF4F46E5),
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        PhoneNotificationService().checkAndPromptInitial(context);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final theme = Theme.of(context);
    final user = auth.currentUser;
    final userName = auth.isAuthenticated ? (user?.effectiveNickname ?? 'Scholar') : 'Scholar';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit QuickQuiz'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        extendBody: true,
        appBar: const QuickQuizTopBar(),
        bottomNavigationBar: const MainBottomNav(current: MainTab.home),
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 104),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, _) {
                    final c1 = _color1Anim.value ?? const Color(0xFF4F46E5);
                    final c2 = _color2Anim.value ?? const Color(0xFF7C3AED);
                    final c3 = _color3Anim.value ?? const Color(0xFFD946EF);

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [c1, c2, c3],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: c1.withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
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
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Text(
                                      '🔥 Daily Streak: ',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                    Text(
                                      '${user?.dailyStreak ?? 1} Days',
                                      style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w900, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              if (auth.isAuthenticated && user != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Level ${user.level}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Welcome back, $userName!',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),

                          if (auth.isAuthenticated && user != null) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${user.currentLevelExp} / ${user.expForNextLevel} EXP',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  'Next: Level ${user.level + 1}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: user.levelProgressFraction,
                                minHeight: 7,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ] else ...[
                            Text(
                              'Ready to convert your study material into an interactive quiz?',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: c3.withValues(alpha: 0.5),
                                  blurRadius: 14 + (6 * _animController.value),
                                  spreadRadius: 1 + _animController.value,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.upload_file_rounded, size: 20),
                              label: const Text(
                                'Upload Notes & Create Quiz',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              onPressed: () => context.go(AppRoutes.upload),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const _AiEngineStatusCard(),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Learning Dashboard',
                        style: theme.textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: TextButton.icon(
                        icon: const Icon(Icons.sports_esports_rounded, size: 16),
                        label: const Text(
                          'Arena & Rewards',
                          style: TextStyle(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () => context.go(AppRoutes.games),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (auth.isAuthenticated)
                  _GamifiedStatsSection(user: user!)
                else
                  _GuestCard(),

                const SizedBox(height: 24),
                Center(child: BannerAdWidget(isVisible: !auth.isLoading)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_clock_rounded, color: AppTheme.primaryColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Guest Mode',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sign in to level up, earn EXP, maintain daily streaks, and challenge friends.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 13,
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

class _GamifiedStatsSection extends StatelessWidget {
  final UserModel user;
  const _GamifiedStatsSection({required this.user});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HistoryViewModel()..loadHistory(user.uid),
      child: Consumer<HistoryViewModel>(
        builder: (context, viewModel, _) {
          final recentItems = viewModel.history.take(3).toList();
          final avgScore = viewModel.history.isNotEmpty
              ? viewModel.averageScore.round()
              : 0;
          final displayAvg = user.globalQuizCount > 0
              ? user.globalAvgScore.round()
              : avgScore;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TopPlayCard(
                user: user,
                avgScore: displayAvg,
              ),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Total Quizzes',
                      value: '${viewModel.totalQuizzes > 0 ? viewModel.totalQuizzes : user.quizzesPlayed}',
                      icon: Icons.quiz_rounded,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Global Avg',
                      value: '$displayAvg%',
                      icon: Icons.analytics_rounded,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Win Rate',
                      value: '${user.winRate}%',
                      icon: Icons.emoji_events_rounded,
                      color: AppTheme.successColor,
                    ),
                  ),
                ],
              ),
              if (recentItems.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Recent Quizzes',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ...recentItems.map((item) => _RecentQuizCard(result: item)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TopPlayCard extends StatelessWidget {
  final UserModel user;
  final int avgScore;

  const _TopPlayCard({
    required this.user,
    required this.avgScore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flag = user.regionFlag.isNotEmpty ? user.regionFlag : '🌐';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'TOP SCHOLAR',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.stars_rounded, size: 16, color: Color(0xFFF59E0B)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Global Quiz Average & Official Performance',
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
                  gradient: AppTheme.heroGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${user.exp} EXP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primaryColor,
                child: Text(
                  user.effectiveNickname.isNotEmpty
                      ? user.effectiveNickname[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          flag,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            user.effectiveNickname,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Lvl ${user.level}',
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Global Avg Score: $avgScore%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentQuizCard extends StatelessWidget {
  final QuizResultModel result;
  const _RecentQuizCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scoreColor = result.roundedPercentage >= 75
        ? AppTheme.successColor
        : result.roundedPercentage >= 50
            ? AppTheme.warningColor
            : const Color(0xFFEF4444);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: scoreColor.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    '${result.roundedPercentage}%',
                    style: TextStyle(color: scoreColor, fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${result.difficulty.label} • ${result.correctCount}/${result.questionCount} correct',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiEngineStatusCard extends StatefulWidget {
  const _AiEngineStatusCard();

  @override
  State<_AiEngineStatusCard> createState() => _AiEngineStatusCardState();
}

class _AiEngineStatusCardState extends State<_AiEngineStatusCard> {
  final _storage = LocalStorageService();
  AiProvider _provider = AiProvider.gemini;
  bool _hasKey = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = await _storage.getActiveAiProvider();
    final key = await _storage.getApiKeyForProvider(provider);
    if (mounted) {
      setState(() {
        _provider = provider;
        _hasKey = key != null && key.isNotEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _hasKey
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          AiProviderLogo(
            provider: _provider,
            size: 24,
            showBackground: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _provider.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _hasKey
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _hasKey ? 'Active' : 'No Key',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: _hasKey ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _hasKey
                      ? 'AI generation enabled with ${_provider.modelName}'
                      : 'Tap to connect Gemini, OpenAI, or DeepSeek',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () async {
              final changed = await showGeminiApiKeyDialog(context);
              if (changed == true || mounted) {
                _load();
              }
            },
            child: Text(
              _hasKey ? 'Change' : 'Connect',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
