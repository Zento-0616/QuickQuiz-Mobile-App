import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/question_model.dart';
import '../../models/quiz_model.dart';
import '../../models/quiz_settings_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/social_service.dart';
import '../../utils/toast_helper.dart';
import '../../viewmodels/auth_viewmodel.dart';

class AdminView extends StatefulWidget {
  const AdminView({super.key});

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();

  List<QuizModel> _decks = [];
  List<UserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() => _isLoading = true);
    try {
      final decks = await _firestoreService.getPublishedQuizzes();
      final users = await _firestoreService.getAllUsers();
      if (mounted) {
        setState(() {
          _decks = decks;
          _users = users;
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
    final user = auth.currentUser;

    // RBAC: Check admin permissions
    if (user == null || !user.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gpp_bad_rounded, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  'Admin Permissions Required',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your account does not have administrator privileges to access this dashboard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('Return Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.deck_rounded), text: 'Decks'),
            Tab(icon: Icon(Icons.school_rounded), text: 'Scholars'),
            Tab(icon: Icon(Icons.analytics_rounded), text: 'Analytics'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDecksTab(context, user),
                _buildUsersTab(context),
                _buildAnalyticsTab(context),
              ],
            ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.primaryColor,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('New Quiz Deck', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              onPressed: () => _openCreateDeckModal(context, user),
            )
          : null,
    );
  }

  // -------------------------------------------------------------------
  // Tab 1: Quiz Deck Studio
  // -------------------------------------------------------------------

  Widget _buildDecksTab(BuildContext context, UserModel admin) {
    if (_decks.isEmpty) {
      return const Center(child: Text('No quiz decks available. Create one!'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _decks.length,
      itemBuilder: (context, index) {
        final deck = _decks[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(deck.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
              '${deck.difficulty.name.toUpperCase()} • ${deck.expMultiplier}x EXP • Tags: ${deck.topicTags.join(', ')}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              onPressed: () async {
                await _firestoreService.deletePublishedQuiz(deck.id);
                try {
                  await SocialService().deleteQuizChallengesForQuiz(deck.id);
                } catch (_) {}
                _loadAdminData();
                if (context.mounted) showSuccessToast(context, 'Deck removed.');
              },
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------
  // Tab 2: Scholar Management
  // -------------------------------------------------------------------

  Widget _buildUsersTab(BuildContext context) {
    if (_users.isEmpty) {
      return const Center(child: Text('No registered scholars found.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final u = _users[index];

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: u.isAdmin ? AppTheme.accentColor : AppTheme.primaryColor,
              child: Text(
                u.effectiveNickname.isNotEmpty ? u.effectiveNickname[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
            title: Text(u.effectiveNickname, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${u.email} • Level ${u.level} • ${u.globalAvgScore.toStringAsFixed(1)}% Global Avg • Role: ${u.role}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: u.isAdmin ? Colors.redAccent.withValues(alpha: 0.12) : AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                u.isAdmin ? 'ADMIN' : 'SCHOLAR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: u.isAdmin ? Colors.redAccent : AppTheme.primaryColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------
  // Tab 3: Platform Analytics
  // -------------------------------------------------------------------

  Widget _buildAnalyticsTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Platform Engagement', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _AnalyticsCard(
                  label: 'Total Scholars',
                  value: '${_users.isNotEmpty ? _users.length : 1}',
                  icon: Icons.people_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AnalyticsCard(
                  label: 'Published Decks',
                  value: '${_decks.length}',
                  icon: Icons.auto_awesome_motion_rounded,
                  color: AppTheme.secondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(
                child: _AnalyticsCard(
                  label: 'Active Challenges',
                  value: '14',
                  icon: Icons.flash_on_rounded,
                  color: AppTheme.accentColor,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _AnalyticsCard(
                  label: 'Avg Win Rate',
                  value: '78%',
                  icon: Icons.analytics_rounded,
                  color: AppTheme.successColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openCreateDeckModal(BuildContext context, UserModel admin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateDeckModal(admin: admin, firestoreService: _firestoreService),
    ).then((_) => _loadAdminData());
  }
}

class _CreateDeckModal extends StatefulWidget {
  final UserModel admin;
  final FirestoreService firestoreService;

  const _CreateDeckModal({required this.admin, required this.firestoreService});

  @override
  State<_CreateDeckModal> createState() => _CreateDeckModalState();
}

class _CreateDeckModalState extends State<_CreateDeckModal> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController(text: 'Science, Tech');
  QuizDifficulty _difficulty = QuizDifficulty.medium;
  int _expReward = 100;
  int _timeLimit = 60;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Publish MCQ Quiz Deck', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Quiz Title', hintText: 'e.g. Molecular Biology 101'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description', hintText: 'Brief summary of concepts tested'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagsCtrl,
              decoration: const InputDecoration(labelText: 'Topic Tags (comma-separated)', hintText: 'Biology, Genetics, Science'),
            ),
            const SizedBox(height: 16),

            // Difficulty
            const Text('Difficulty Tier:', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SegmentedButton<QuizDifficulty>(
              segments: const [
                ButtonSegment(value: QuizDifficulty.easy, label: Text('Easy')),
                ButtonSegment(value: QuizDifficulty.medium, label: Text('Medium')),
                ButtonSegment(value: QuizDifficulty.hard, label: Text('Hard')),
              ],
              selected: {_difficulty},
              onSelectionChanged: (val) => setState(() => _difficulty = val.first),
            ),
            const SizedBox(height: 16),

            // EXP Reward (1-1000)
            Text('EXP Reward: $_expReward EXP', style: const TextStyle(fontWeight: FontWeight.w700)),
            Slider(
              value: _expReward.toDouble(),
              min: 1,
              max: 1000,
              divisions: 100,
              label: '$_expReward EXP',
              onChanged: (v) => setState(() => _expReward = v.round()),
            ),

            // Time Limit
            Text('Time Limit: $_timeLimit seconds', style: const TextStyle(fontWeight: FontWeight.w700)),
            Slider(
              value: _timeLimit.toDouble(),
              min: 30,
              max: 180,
              divisions: 5,
              label: '$_timeLimit s',
              onChanged: (v) => setState(() => _timeLimit = v.round()),
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                child: const Text('Publish Deck to Arena', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                onPressed: () async {
                  if (_titleCtrl.text.trim().isEmpty) return;

                  final tags = _tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                  final newDeck = QuizModel(
                    title: _titleCtrl.text.trim(),
                    sourceFileName: _titleCtrl.text.trim(),
                    description: _descCtrl.text.trim(),
                    difficulty: _difficulty,
                    topicTags: tags.isNotEmpty ? tags : ['General'],
                    expReward: _expReward,
                    expMultiplier: (_expReward / 100.0).clamp(0.1, 10.0),
                    timeLimitSeconds: _timeLimit,
                    isPublished: true,
                    authorId: widget.admin.uid,
                    authorName: widget.admin.effectiveNickname,
                    questions: [
                      QuestionModel(
                        question: 'What is the primary power source of the cell?',
                        options: ['Mitochondria', 'Nucleus', 'Ribosome', 'Endoplasmic Reticulum'],
                        correctAnswerIndex: 0,
                        explanation: 'Mitochondria generate most of the chemical energy needed to power biochemical reactions.',
                      ),
                      QuestionModel(
                        question: 'Which molecule carries genetic information across generations?',
                        options: ['DNA', 'ATP', 'Hemoglobin', 'Insulin'],
                        correctAnswerIndex: 0,
                        explanation: 'Deoxyribonucleic acid (DNA) is the hereditary material in humans and almost all other organisms.',
                      ),
                    ],
                  );

                  await widget.firestoreService.savePublishedQuiz(
                    newDeck,
                    user: context.read<AuthViewModel>().currentUser,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    showSuccessToast(context, 'Quiz Deck successfully published!');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _AnalyticsCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }
}
