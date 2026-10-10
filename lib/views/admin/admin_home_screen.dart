import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/admin_analytics_model.dart';
import '../../models/broadcast_alert_model.dart';
import '../../models/chat_room_model.dart';
import '../../models/feedback_model.dart';
import '../../models/quiz_model.dart';
import '../../models/user_model.dart';
import '../../providers/theme_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/social_service.dart';
import '../../utils/toast_helper.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/admin_bottom_nav.dart';
import 'admin_settings_screen.dart';
import 'ai_quiz_studio_modal.dart';
import 'quiz_analytics_modal.dart';
import 'dama_tournament_modal.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final SocialService _socialService = SocialService();

  AdminTab _currentTab = AdminTab.home;

  AdminLiveMetrics _metrics = AdminLiveMetrics.initial();
  List<QuizModel> _quizzes = [];
  List<UserModel> _scholars = [];
  FeedbackMetrics _feedbackMetrics = const FeedbackMetrics(totalReceived: 0, totalResolved: 0, pending: 0);
  List<FeedbackModel> _feedbackList = [];
  List<ChatRoomModel> _supportChatRooms = [];
  bool _isLoading = true;
  Timer? _liveMetricsTimer;

  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedStatus = 'All';
  String _dateFilterLabel = 'All Time';
  DateTimeRange? _selectedDateRange;

  final TextEditingController _scholarSearchCtrl = TextEditingController();

  String _feedbackFilter = 'All';

  bool _soundEnabled = true;
  bool _hapticsEnabled = true;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadDashboardData();

    _liveMetricsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshMetricsSilently();
    });
  }

  @override
  void dispose() {
    _liveMetricsTimer?.cancel();
    _pulseController.dispose();
    _searchCtrl.dispose();
    _scholarSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      await _firestoreService.autoMarkExpiredQuizzesAsDone();
      final metrics = await _firestoreService.getAdminLiveMetrics();
      final quizzes = await _firestoreService.getAdminQuizzes(
        query: _searchCtrl.text,
        status: _selectedStatus,
        dateRange: _selectedDateRange,
      );
      final users = await _firestoreService.getAllUsers();
      final feedbackStats = await _firestoreService.getFeedbackMetrics();
      final feedbackItems = await _firestoreService.getFeedbackList();

      if (!mounted) return;
      final auth = context.read<AuthViewModel>();
      final adminUid = auth.currentUser?.uid ?? '';
      final chatRooms = adminUid.isNotEmpty ? await _socialService.getChatRooms(adminUid) : <ChatRoomModel>[];

      if (mounted) {
        setState(() {
          _metrics = metrics;
          _quizzes = quizzes;
          _scholars = users;
          _feedbackMetrics = feedbackStats;
          _feedbackList = feedbackItems;
          _supportChatRooms = chatRooms;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshMetricsSilently() async {
    try {
      final metrics = await _firestoreService.getAdminLiveMetrics();
      if (mounted) {
        setState(() => _metrics = metrics);
      }
    } catch (_) {}
  }

  void _onSearchChanged(String _) {
    _loadFilteredQuizzes();
  }

  Future<void> _loadFilteredQuizzes() async {
    try {
      await _firestoreService.autoMarkExpiredQuizzesAsDone();
      final quizzes = await _firestoreService.getAdminQuizzes(
        query: _searchCtrl.text,
        status: _selectedStatus,
        dateRange: _selectedDateRange,
      );
      if (mounted) {
        setState(() => _quizzes = quizzes);
      }
    } catch (_) {}
  }

  void _setDateFilter(String label, DateTimeRange? range) {
    setState(() {
      _dateFilterLabel = label;
      _selectedDateRange = range;
    });
    _loadFilteredQuizzes();
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
    );

    if (picked != null) {
      _setDateFilter(
        '${picked.start.month}/${picked.start.day} - ${picked.end.month}/${picked.end.day}',
        picked,
      );
    }
  }

  void _openCreateQuizStudio() {
    AiQuizStudioModal.show(context, onPublished: () {
      _loadDashboardData();
    });
  }

  Future<void> _handleArchiveAllDone() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.archive_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Archive All Done Quizzes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Are you sure you want to archive all completed and closed quizzes (both Global and Normal)? They will be moved to the Archived tab.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive All Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final count = await _firestoreService.archiveAllDoneQuizzes();
      if (mounted) {
        showSuccessToast(context, 'Archived $count completed/done quizzes.');
        _loadFilteredQuizzes();
        _loadDashboardData();
      }
    }
  }


  void _showFeedbackManagementDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final pendingCount = _feedbackList.where((f) => f.status == 'pending').length;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.rate_review_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 10),
                const Text('Scholar Feedback', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_feedbackList.length} total',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withValues(alpha: 0.08),
                          AppTheme.secondaryColor.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              '${_feedbackList.length}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.primaryColor),
                            ),
                            const Text('Received', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Container(width: 1, height: 28, color: Colors.grey.withValues(alpha: 0.3)),
                        Column(
                          children: [
                            Text(
                              '${_feedbackList.where((f) => f.isResolved).length}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF10B981)),
                            ),
                            const Text('Resolved', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Container(width: 1, height: 28, color: Colors.grey.withValues(alpha: 0.3)),
                        Column(
                          children: [
                            Text(
                              '${_feedbackList.where((f) => !f.isResolved).length}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFFF59E0B)),
                            ),
                            const Text('Pending', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Scholar Submissions:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),

                  if (_feedbackList.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('No scholar feedback recorded yet.', style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _feedbackList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final item = _feedbackList[idx];
                          final isResolved = item.status == 'resolved';

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isResolved
                                    ? Colors.green.withValues(alpha: 0.3)
                                    : Colors.orange.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      item.type == 'suggestion'
                                          ? Icons.lightbulb_outline_rounded
                                          : Icons.bug_report_outlined,
                                      size: 16,
                                      color: item.type == 'suggestion' ? Colors.green : Colors.redAccent,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (isResolved ? Colors.green : Colors.orange).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: isResolved ? Colors.green : Colors.orange,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.message,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'From: ${item.userName} (${item.userEmail})',
                                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isResolved)
                                      const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                                          SizedBox(width: 4),
                                          Text(
                                            'Fixed / Done',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.green,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                          size: 14,
                                          color: Colors.green,
                                        ),
                                        label: const Text(
                                          'Mark Fixed',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.green,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        onPressed: () async {
                                          await _firestoreService.updateFeedbackStatus(item.id, 'resolved');
                                          final updatedList = await _firestoreService.getFeedbackList();
                                          final updatedMetrics = await _firestoreService.getFeedbackMetrics();
                                          setDialogState(() {
                                            _feedbackList = updatedList;
                                            _feedbackMetrics = updatedMetrics;
                                          });
                                          setState(() {
                                            _feedbackList = updatedList;
                                            _feedbackMetrics = updatedMetrics;
                                          });
                                        },
                                      ),
                                  ],
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
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBroadcastAnnouncementDialog() {
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.campaign_rounded, color: AppTheme.primaryColor),
            SizedBox(width: 10),
            Text('Broadcast Announcement', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Announcement Title',
                hintText: 'e.g. Weekly Arena Tournament Starting!',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Broadcast Message',
                hintText: 'Enter message to alert all active scholars...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
            label: const Text('Send Broadcast', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              final alert = BroadcastAlertModel(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: titleCtrl.text.trim(),
                message: messageCtrl.text.trim(),
                authorName: 'Administrator',
                createdAt: DateTime.now(),
                priority: 'high',
              );
              await _firestoreService.sendBroadcastAlert(alert);
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) {
                showSuccessToast(context, 'Announcement broadcasted to all active scholars!');
              }
            },
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: AppTheme.primaryColor),
            SizedBox(width: 10),
            Text('Change Admin Password', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: Icon(Icons.key_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password (min 6 chars)',
                  prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: Icon(Icons.check_circle_outline_rounded, size: 20),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPassCtrl.text.trim().length < 6) {
                showErrorToast(context, 'New password must be at least 6 characters.');
                return;
              }
              if (newPassCtrl.text.trim() != confirmPassCtrl.text.trim()) {
                showErrorToast(context, 'New passwords do not match.');
                return;
              }

              final authVM = context.read<AuthViewModel>();
              final success = await authVM.changePassword(
                currentPassword: oldPassCtrl.text.trim(),
                newPassword: newPassCtrl.text.trim(),
              );

              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                if (success) {
                  showSuccessToast(context, 'Admin password successfully updated.');
                } else {
                  showErrorToast(context, authVM.errorMessage ?? 'Failed to update password.');
                }
              }
            },
            child: const Text('Update Password'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final user = auth.currentUser;

    if (user == null || !user.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Restricted')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gpp_bad_rounded, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  'Administrator Privileges Required',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your account does not have admin permissions to access this control room.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('Return to Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/icons/quickquiz_logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'ADMIN DASHBOARD',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    _getTabSubtitle(_currentTab),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Data',
            onPressed: _loadDashboardData,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'sign_out') {
                auth.signOut();
                context.go(AppRoutes.auth);
              } else if (val == 'settings') {
                setState(() => _currentTab = AdminTab.settings);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'admin_info',
                enabled: false,
                child: Text('Logged in: ${user.effectiveNickname}', style: const TextStyle(fontSize: 12)),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Admin Settings'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'sign_out',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: _buildCurrentTabContent(context, user),
            ),
      bottomNavigationBar: AdminBottomNavBar(
        currentTab: _currentTab,
        onTabSelected: (tab) => setState(() => _currentTab = tab),
      ),
      floatingActionButton: (_currentTab == AdminTab.quizzes)
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.primaryColor,
              icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
              label: const Text(
                'Create AI Quiz',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              onPressed: _openCreateQuizStudio,
            )
          : null,
    );
  }

  String _getTabSubtitle(AdminTab tab) {
    switch (tab) {
      case AdminTab.home:
        return 'QuickQuiz Control Center • Ad-Free Mode';
      case AdminTab.quizzes:
        return 'Created Quizzes & Deep-Dive Analytics';
      case AdminTab.scholars:
        return 'Scholar Profiles & Moderation';
      case AdminTab.messages:
        return 'Scholar Inquiries & Support Messages';
      case AdminTab.feedback:
        return 'Scholar Feedback, Issues & Resolution Hub';
      case AdminTab.expControls:
        return 'Daily Scholar EXP Cap';
      case AdminTab.settings:
        return 'Security, Preferences & Platform Hygiene';
    }
  }

  Widget _buildCurrentTabContent(BuildContext context, UserModel admin) {
    switch (_currentTab) {
      case AdminTab.home:
        return _buildHomeTab(context);
      case AdminTab.quizzes:
        return _buildQuizzesTab(context);
      case AdminTab.scholars:
        return _buildScholarsTab(context);
      case AdminTab.messages:
        return _buildMessagesTab(context);
      case AdminTab.feedback:
        return _buildFeedbackTab(context);
      case AdminTab.expControls:
        return const AdminSettingsScreen();
      case AdminTab.settings:
        return _buildSettingsTab(context, admin);
    }
  }


  Widget _buildHomeTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildLiveMetricsBar(context),
        const SizedBox(height: 20),

        _buildQuickActionsHub(context),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Decks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            TextButton(
              child: const Text('View All', style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () => setState(() => _currentTab = AdminTab.quizzes),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_quizzes.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No quizzes created yet. Click "Create AI Quiz" to start!'),
            ),
          )
        else
          ..._quizzes.take(3).map((quiz) => _buildQuizCard(context, quiz)),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildLiveMetricsBar(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Platform Live Metrics',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Row(
              children: [
                FadeTransition(
                  opacity: _pulseAnimation,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Live Feed',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Active Online',
                value: '${_metrics.activeScholarsOnline}',
                icon: Icons.wifi_tethering_rounded,
                color: const Color(0xFF10B981),
                isPulsing: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Total Scholars',
                value: '${_metrics.totalRegisteredScholars}',
                icon: Icons.people_alt_rounded,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Quizzes Today',
                value: '${_metrics.quizzesPlayedToday}',
                icon: Icons.play_lesson_rounded,
                color: const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Avg Accuracy',
                value: '${_metrics.platformAverageAccuracy.toStringAsFixed(1)}%',
                icon: Icons.insights_rounded,
                color: const Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionsHub(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions Hub',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                label: 'Create AI Quiz',
                icon: Icons.auto_awesome_rounded,
                gradient: const [AppTheme.primaryColor, Color(0xFF7C3AED)],
                onTap: _openCreateQuizStudio,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionButton(
                label: 'Scholar Feedback',
                icon: Icons.rate_review_rounded,
                gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                onTap: _showFeedbackManagementDialog,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionButton(
                label: 'Broadcast Alert',
                icon: Icons.campaign_rounded,
                gradient: const [Color(0xFF06B6D4), Color(0xFF0284C7)],
                onTap: _showBroadcastAnnouncementDialog,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                label: 'Dama Tournament',
                icon: Icons.grid_4x4_rounded,
                gradient: const [Color(0xFFD97706), Color(0xFFB45309)],
                onTap: () => DamaTournamentModal.show(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _showFeedbackManagementDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.feedback_rounded, color: Color(0xFFD97706), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scholar Feedback (Real-Time)',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${_feedbackList.length} Received',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const Text(' • ', style: TextStyle(color: Colors.grey)),
                          Text(
                            '${_feedbackList.where((f) => f.isResolved).length} Resolved',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          if (_feedbackList.any((f) => !f.isResolved)) ...[
                            const Text(' • ', style: TextStyle(color: Colors.grey)),
                            Text(
                              '${_feedbackList.where((f) => !f.isResolved).length} Pending',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildQuizzesTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildQuizzesSectionHeader(context),
        const SizedBox(height: 12),

        _buildSearchAndFilters(context),
        const SizedBox(height: 16),

        _buildQuizzesList(context),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildQuizzesSectionHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text(
              'Created Quizzes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_quizzes.length}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppTheme.primaryColor),
              ),
            ),
          ],
        ),
        PopupMenuButton<String>(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.date_range_rounded, size: 14),
                const SizedBox(width: 6),
                Text(_dateFilterLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const Icon(Icons.arrow_drop_down_rounded, size: 18),
              ],
            ),
          ),
          onSelected: (choice) {
            final now = DateTime.now();
            if (choice == 'all') {
              _setDateFilter('All Time', null);
            } else if (choice == 'today') {
              _setDateFilter('Today', DateTimeRange(start: DateTime(now.year, now.month, now.day), end: now));
            } else if (choice == 'week') {
              _setDateFilter('Last 7 Days', DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now));
            } else if (choice == 'custom') {
              _pickCustomDateRange();
            }
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'all', child: Text('All Time')),
            PopupMenuItem(value: 'today', child: Text('Today')),
            PopupMenuItem(value: 'week', child: Text('Last 7 Days')),
            PopupMenuItem(value: 'custom', child: Text('Custom Date Range...')),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search quizzes by title or category...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      _loadFilteredQuizzes();
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Active', 'Done', 'Draft', 'Archived'].map((status) {
                    final isSel = _selectedStatus == status;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(status),
                        selected: isSel,
                        onSelected: (val) {
                          setState(() => _selectedStatus = status);
                          _loadFilteredQuizzes();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.archive_rounded, size: 14, color: Colors.orange),
              label: const Text(
                'Archive All Done',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Colors.orange),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: _handleArchiveAllDone,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuizzesList(BuildContext context) {
    if (_quizzes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              const Text('No Quizzes Found', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 6),
              Text(
                'No quizzes match your search or filter settings.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create First AI Quiz'),
                onPressed: _openCreateQuizStudio,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _quizzes.map((quiz) => _buildQuizCard(context, quiz)).toList(),
    );
  }

  Widget _buildQuizCard(BuildContext context, QuizModel quiz) {
    final isGlobal = quiz.isGlobal;
    final isDone = quiz.status.toLowerCase() == 'done' ||
        quiz.status.toLowerCase() == 'stopped' ||
        quiz.isClosed;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isGlobal
            ? BorderSide(color: Colors.amber.withValues(alpha: 0.75), width: 1.5)
            : (isDone
                ? BorderSide(color: Colors.grey.withValues(alpha: 0.2))
                : BorderSide.none),
      ),
      elevation: isGlobal ? 2 : 0,
      shadowColor: isGlobal ? Colors.amber.withValues(alpha: 0.3) : Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => QuizAnalyticsModal.show(context, quiz),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isGlobal) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.amber.shade700.withValues(alpha: 0.25),
                        Colors.amber.shade900.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.workspace_premium_rounded, size: 14, color: Colors.amber),
                      SizedBox(width: 6),
                      Text(
                        '★ GLOBAL CHAMPIONSHIP ARENA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.amber,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isGlobal
                                    ? Colors.amber.withValues(alpha: 0.15)
                                    : AppTheme.primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                quiz.category.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isGlobal ? Colors.amber.shade800 : AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'LVL ${quiz.minLevel}+',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.accentColor,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDone
                                    ? Colors.redAccent.withValues(alpha: 0.12)
                                    : (quiz.status.toLowerCase() == 'active'
                                        ? Colors.green.withValues(alpha: 0.12)
                                        : (quiz.status.toLowerCase() == 'draft'
                                            ? Colors.orange.withValues(alpha: 0.12)
                                            : Colors.grey.withValues(alpha: 0.12))),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isDone ? 'DONE' : quiz.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isDone
                                      ? Colors.redAccent
                                      : (quiz.status.toLowerCase() == 'active'
                                          ? Colors.green
                                          : (quiz.status.toLowerCase() == 'draft' ? Colors.orange : Colors.grey)),
                                ),
                              ),
                            ),

                            if (quiz.isClosed) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock_clock_rounded, size: 11, color: Colors.redAccent),
                                    SizedBox(width: 3),
                                    Text(
                                      'CLOSED',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.redAccent),
                                    ),
                                  ],
                                ),
                              ),
                              if (quiz.isHiddenDueToExpiration)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'HIDDEN (>24h)',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey),
                                  ),
                                ),
                            ] else if (quiz.expiresAt != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 11, color: Colors.blueAccent),
                                    const SizedBox(width: 3),
                                    Text(
                                      quiz.timeRemainingFormatted,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.blueAccent),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),

                        Text(
                          quiz.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (action) async {
                      if (action == 'analytics') {
                        QuizAnalyticsModal.show(context, quiz);
                      } else if (action == 'activate') {
                        await _firestoreService.updateQuizStatus(quiz.id, 'Active');
                        _loadFilteredQuizzes();
                        if (context.mounted) showSuccessToast(context, 'Quiz marked as Active.');
                      } else if (action == 'done') {
                        await _firestoreService.updateQuizStatus(quiz.id, 'Done');
                        _loadFilteredQuizzes();
                        if (context.mounted) showSuccessToast(context, 'Quiz marked as Done.');
                      } else if (action == 'archive') {
                        await _firestoreService.updateQuizStatus(quiz.id, 'Archived');
                        _loadFilteredQuizzes();
                        if (context.mounted) showSuccessToast(context, 'Quiz moved to Archived.');
                      } else if (action == 'delete') {
                        await _firestoreService.deletePublishedQuiz(quiz.id);
                        await _socialService.deleteQuizChallengesForQuiz(quiz.id);
                        _loadDashboardData();
                        if (context.mounted) showSuccessToast(context, 'Quiz deleted.');
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'analytics',
                        child: Row(
                          children: [
                            Icon(Icons.analytics_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('View Analytics'),
                          ],
                        ),
                      ),
                      if (quiz.status != 'Active' || quiz.isClosed)
                        const PopupMenuItem(
                          value: 'activate',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Set as Active'),
                            ],
                          ),
                        ),
                      if (!isDone)
                        const PopupMenuItem(
                          value: 'done',
                          child: Row(
                            children: [
                              Icon(Icons.stop_circle_outlined, size: 18, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Mark as Done'),
                            ],
                          ),
                        ),
                      if (quiz.status != 'Archived')
                        const PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(Icons.archive_outlined, size: 18, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Archive Quiz'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (quiz.description != null && quiz.description!.isNotEmpty) ...[
                Text(
                  quiz.description!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
              ],

              Row(
                children: [
                  Icon(Icons.format_list_bulleted_rounded, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text('${quiz.questionCount} Qs', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(width: 12),
                  const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFD97706)),
                  const SizedBox(width: 2),
                  Text(
                    '${quiz.effectiveExpReward} EXP',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
                  ),
                  if (quiz.allowRepeatExp) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('🔄 Repeat EXP', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.purple)),
                    ),
                  ],
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.insights_rounded, size: 16),
                    label: const Text('Analytics', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    onPressed: () => QuizAnalyticsModal.show(context, quiz),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildScholarsTab(BuildContext context) {
    final query = _scholarSearchCtrl.text.trim().toLowerCase();

    UserModel? canonicalAdmin;
    final regularScholars = <UserModel>[];

    for (final s in _scholars) {
      if (s.isAdmin || s.email.toLowerCase() == 'admin@quickquiz.com') {
        if (canonicalAdmin == null) {
          canonicalAdmin = s;
        } else {
          if (s.effectiveNickname.toLowerCase() == 'admin' || s.level > canonicalAdmin.level) {
            canonicalAdmin = s;
          }
        }
      } else {
        regularScholars.add(s);
      }
    }

    regularScholars.sort((a, b) => a.effectiveNickname.toLowerCase().compareTo(b.effectiveNickname.toLowerCase()));

    final allScholarsOrdered = [
      if (canonicalAdmin != null) canonicalAdmin,
      ...regularScholars,
    ];

    final scholars = allScholarsOrdered.where((s) {
      if (query.isEmpty) return true;
      return s.effectiveNickname.toLowerCase().contains(query) ||
          s.email.toLowerCase().contains(query) ||
          s.name.toLowerCase().contains(query);
    }).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Scholars & Leaderboard', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            Text('${scholars.length} scholars', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _scholarSearchCtrl,
          onChanged: (val) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search scholars by nickname or email...',
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 12),

        if (scholars.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text('No scholars found matching your search query.'),
            ),
          )
        else
          ...scholars.map((scholar) {
            final globalAvg = scholar.globalQuizCount > 0
                ? scholar.globalAvgScore.toStringAsFixed(1)
                : (scholar.totalQuestions > 0
                    ? ((scholar.totalCorrect / scholar.totalQuestions) * 100).toStringAsFixed(1)
                    : '0.0');

            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: scholar.isAdmin ? AppTheme.accentColor : AppTheme.primaryColor,
                          child: Text(
                            scholar.effectiveNickname.isNotEmpty ? scholar.effectiveNickname[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                        ),
                        if (scholar.isOnline)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  scholar.effectiveNickname,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (scholar.isAdmin) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('ADMIN', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.redAccent)),
                                ),
                              ],
                            ],
                          ),
                          Text(scholar.email, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(
                            'Lvl ${scholar.level} • ${scholar.exp} EXP • $globalAvg% Global Avg • ${scholar.quizzesPlayed} Quizzes',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (scholar.isAdmin)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.redAccent,
                              ),
                            ),
                          )
                        else ...[
                          IconButton(
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppTheme.primaryColor),
                            tooltip: 'Direct Message Scholar & Gift EXP',
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(3),
                            constraints: const BoxConstraints(),
                            onPressed: () => _openDirectMessageWithScholar(scholar),
                          ),
                          const SizedBox(width: 2),
                          IconButton(
                            icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: Colors.amber),
                            tooltip: 'Purge Scholar Documents',
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(3),
                            constraints: const BoxConstraints(),
                            onPressed: () => _confirmAndPurgeScholarDocs(scholar),
                          ),
                          const SizedBox(width: 2),
                          IconButton(
                            icon: const Icon(Icons.delete_forever_rounded, size: 17, color: Colors.redAccent),
                            tooltip: 'Delete Scholar Account',
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(3),
                            constraints: const BoxConstraints(),
                            onPressed: () => _confirmAndDeleteScholar(scholar),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 80),
      ],
    );
  }

  Future<void> _openDirectMessageWithScholar(UserModel scholar) async {
    final auth = context.read<AuthViewModel>();
    final adminUser = auth.currentUser;
    if (adminUser == null) return;
    try {
      final room = await _socialService.getOrCreateOneOnOneChat(
        currentUser: adminUser,
        friendUser: scholar,
      );
      if (mounted) {
        context.push('/chat/${room.id}', extra: room);
      }
    } catch (e) {
      if (mounted) {
        showWarningToast(context, 'Unable to open chat: $e');
      }
    }
  }

  Future<void> _confirmAndDeleteScholar(UserModel scholar) async {
    final passwordCtrl = TextEditingController();
    bool isVerifying = false;
    String? errorMsg;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.security_rounded, color: Colors.redAccent, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Delete Scholar Account', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(text: 'Permanently delete account for '),
                        TextSpan(
                          text: scholar.effectiveNickname,
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.redAccent),
                        ),
                        TextSpan(
                          text: ' (${scholar.email})?\n\n'
                              '⚠️ This action cannot be undone. All profile data, quiz records, EXP, and leaderboard rankings will be permanently wiped.\n\n'
                              'Enter your administrator password to authorize this deletion:',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Admin Password',
                      hintText: 'Enter your administrator password...',
                      prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                      errorText: errorMsg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: isVerifying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_forever_rounded, size: 18),
                  label: const Text('Delete Scholar Account', style: TextStyle(fontWeight: FontWeight.w800)),
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final entered = passwordCtrl.text.trim();
                          if (entered.isEmpty) {
                            setModalState(() => errorMsg = 'Please enter your administrator password.');
                            return;
                          }

                          setModalState(() {
                            isVerifying = true;
                            errorMsg = null;
                          });

                          final authVM = Provider.of<AuthViewModel>(context, listen: false);
                          final isValid = await authVM.verifyAdminPassword(entered);

                          if (!isValid) {
                            setModalState(() {
                              isVerifying = false;
                              errorMsg = 'Incorrect admin password. Action aborted.';
                            });
                            return;
                          }

                          if (dialogCtx.mounted) {
                            Navigator.of(dialogCtx).pop();
                          }

                          try {
                            await _firestoreService.deleteScholarAccount(scholar.uid);
                            if (mounted) {
                              setState(() {
                                _scholars.removeWhere((s) => s.uid == scholar.uid);
                              });
                              showSuccessToast(context, 'Scholar "${scholar.effectiveNickname}" has been permanently deleted.');
                              _loadDashboardData();
                            }
                          } catch (e) {
                            if (mounted) showErrorToast(context, 'Deletion failed: $e');
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmAndPurgeScholarDocs(UserModel scholar) async {
    final passwordCtrl = TextEditingController();
    bool isVerifying = false;
    String? errorMsg;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.security_rounded, color: Colors.redAccent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Purge Scholar Documents', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delete all generated documents and quiz attempts for "${scholar.effectiveNickname}" (${scholar.email})? Their account, level, and credentials will not be deleted.',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8), height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Admin Password',
                      hintText: 'Enter your administrator password...',
                      prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                      errorText: errorMsg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final entered = passwordCtrl.text.trim();
                          if (entered.isEmpty) {
                            setModalState(() => errorMsg = 'Please enter your password.');
                            return;
                          }

                          setModalState(() {
                            isVerifying = true;
                            errorMsg = null;
                          });

                          final authVM = Provider.of<AuthViewModel>(context, listen: false);
                          final isValid = await authVM.verifyAdminPassword(entered);

                          if (!isValid) {
                            setModalState(() {
                              isVerifying = false;
                              errorMsg = 'Incorrect admin password. Action aborted.';
                            });
                            return;
                          }

                          if (dialogCtx.mounted) {
                            Navigator.of(dialogCtx).pop();
                          }

                          try {
                            final count = await _firestoreService.clearScholarQuizDocuments(scholar.uid);
                            if (mounted) {
                              showSuccessToast(context, 'Purged $count document records for ${scholar.effectiveNickname}.');
                              _loadDashboardData();
                            }
                          } catch (e) {
                            if (mounted) showErrorToast(context, 'Purge failed: $e');
                          }
                        },
                  child: isVerifying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Purge Documents'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleSystemRefreshInSettings(BuildContext context) async {
    final passwordCtrl = TextEditingController();
    bool isVerifying = false;
    String? errorMsg;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.cleaning_services_rounded, color: Colors.redAccent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('System Refresh & Cleanup', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will delete all user-uploaded document extractions and generated quiz records from the database. All scholar accounts, levels, EXP, and login credentials remain 100% safe.',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8), height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Admin Password',
                      hintText: 'Enter your administrator password...',
                      prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                      errorText: errorMsg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final entered = passwordCtrl.text.trim();
                          if (entered.isEmpty) {
                            setModalState(() => errorMsg = 'Please enter your password.');
                            return;
                          }

                          setModalState(() {
                            isVerifying = true;
                            errorMsg = null;
                          });

                          final authVM = Provider.of<AuthViewModel>(context, listen: false);
                          final isValid = await authVM.verifyAdminPassword(entered);

                          if (!isValid) {
                            setModalState(() {
                              isVerifying = false;
                              errorMsg = 'Incorrect admin password. Action aborted.';
                            });
                            return;
                          }

                          if (dialogCtx.mounted) {
                            Navigator.of(dialogCtx).pop();
                          }

                          try {
                            final count = await _firestoreService.clearAllGeneratedQuizDocuments();
                            if (context.mounted) {
                              showSuccessToast(context, 'System Refreshed! Cleared $count generated records.');
                              _loadDashboardData();
                            }
                          } catch (e) {
                            if (context.mounted) showErrorToast(context, 'Refresh failed: $e');
                          }
                        },
                  child: isVerifying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Refresh Database'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleScholarDocumentCleanupInSettings(BuildContext context) async {
    final scholars = _scholars.where((u) => !u.isAdmin).toList();
    if (scholars.isEmpty) {
      showWarningToast(context, 'No registered scholars found.');
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Select Scholar for Document Cleanup',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose a scholar to purge their generated quizzes and document extractions:',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: scholars.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final s = scholars[idx];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryColor,
                            child: Text(
                              s.effectiveNickname.isNotEmpty ? s.effectiveNickname[0].toUpperCase() : 'S',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(s.effectiveNickname, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(s.email, style: const TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.delete_sweep_rounded, color: Colors.amber),
                          onTap: () {
                            Navigator.of(sheetCtx).pop();
                            _confirmAndPurgeScholarDocs(s);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildMessagesTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Scholar Support & Messages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${_supportChatRooms.length} active threads', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text('DM Scholar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
              onPressed: _openScholarPickerForDM,
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_supportChatRooms.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                const Icon(Icons.mark_chat_read_rounded, size: 48, color: Color(0xFF10B981)),
                const SizedBox(height: 12),
                const Text('No Active Support Inquiries', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 6),
                Text(
                  'When scholars open inquiries or direct conversations with admin, threads appear here directly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          )
        else
          ..._supportChatRooms.map((room) {
            final auth = context.read<AuthViewModel>();
            final adminUid = auth.currentUser?.uid ?? '';
            final displayName = room.getDisplayName(adminUid);

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: room.isGroup ? AppTheme.secondaryColor : AppTheme.primaryColor,
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
                title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(
                  room.lastMessage ?? 'No messages yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                onTap: () => context.push('/chat/${room.id}', extra: room),
              ),
            );
          }),
        const SizedBox(height: 80),
      ],
    );
  }

  void _openScholarPickerForDM() {
    final searchCtrl = TextEditingController();
    final nonAdminScholars = _scholars.where((s) => !s.isAdmin).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final query = searchCtrl.text.trim().toLowerCase();
            final filtered = nonAdminScholars.where((s) {
              if (query.isEmpty) return true;
              return s.effectiveNickname.toLowerCase().contains(query) ||
                  s.email.toLowerCase().contains(query) ||
                  s.name.toLowerCase().contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primaryColor, size: 24),
                      const SizedBox(width: 8),
                      const Text('Direct Message Scholar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select any scholar to start chatting with them and send EXP gifts:',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search scholars by name or email...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Text('No scholars found matching your search.', style: TextStyle(color: Colors.grey)),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, idx) {
                              final s = filtered[idx];
                              return Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.primaryColor,
                                    child: Text(
                                      s.effectiveNickname.isNotEmpty ? s.effectiveNickname[0].toUpperCase() : 'S',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  title: Text(s.effectiveNickname, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  subtitle: Text('${s.email} • Level ${s.level} • ${s.exp} EXP', style: const TextStyle(fontSize: 11)),
                                  trailing: const Icon(Icons.send_rounded, color: AppTheme.primaryColor, size: 18),
                                  onTap: () {
                                    Navigator.pop(modalCtx);
                                    _openDirectMessageWithScholar(s);
                                  },
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
      },
    );
  }


  Widget _buildFeedbackTab(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = _feedbackMetrics;

    final filtered = _feedbackList.where((item) {
      if (_feedbackFilter == 'Pending') return !item.isResolved;
      if (_feedbackFilter == 'Resolved') return item.isResolved;
      if (_feedbackFilter == 'Suggestions') return item.type == 'suggestion';
      if (_feedbackFilter == 'Issue Reports') return item.type == 'issue_report';
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          Row(
            children: [
              Expanded(
                child: _buildFeedbackMetricTile(
                  label: 'Received',
                  value: '${_feedbackList.length}',
                  color: AppTheme.primaryColor,
                  icon: Icons.inbox_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFeedbackMetricTile(
                  label: 'Resolved',
                  value: '${_feedbackList.where((f) => f.isResolved).length}',
                  color: const Color(0xFF10B981),
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFeedbackMetricTile(
                  label: 'Pending',
                  value: '${_feedbackList.where((f) => !f.isResolved).length}',
                  color: Colors.orange,
                  icon: Icons.pending_actions_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeedbackChip('All', _feedbackList.length),
              _buildFeedbackChip('Pending', _feedbackList.where((f) => !f.isResolved).length, color: Colors.orange),
              _buildFeedbackChip('Resolved', _feedbackList.where((f) => f.isResolved).length, color: const Color(0xFF10B981)),
              _buildFeedbackChip('Suggestions', _feedbackList.where((f) => f.type == 'suggestion').length, color: const Color(0xFF6366F1)),
              _buildFeedbackChip('Issue Reports', _feedbackList.where((f) => f.type == 'issue_report').length, color: Colors.redAccent),
            ],
          ),
          const SizedBox(height: 16),

          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.mark_email_read_rounded, size: 54, color: theme.disabledColor),
                    const SizedBox(height: 12),
                    const Text('No feedback in this category', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('Scholars will see resolved feedback updated in real time.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
            )
          else
            ...filtered.map((item) {
              final isResolved = item.isResolved;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isResolved
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : Colors.orange.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            item.type == 'suggestion'
                                ? Icons.lightbulb_outline_rounded
                                : Icons.bug_report_outlined,
                            size: 18,
                            color: item.type == 'suggestion' ? const Color(0xFF10B981) : Colors.redAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isResolved ? const Color(0xFF10B981) : Colors.orange).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isResolved ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                                  size: 11,
                                  color: isResolved ? const Color(0xFF10B981) : Colors.orange,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  isResolved ? 'FIXED / DONE' : 'PENDING',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: isResolved ? const Color(0xFF10B981) : Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Text(
                        item.message,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'From: ${item.userName} (${item.userEmail})',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isResolved)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                                  SizedBox(width: 5),
                                  Text(
                                    'Fixed / Done',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                visualDensity: VisualDensity.compact,
                                elevation: 1,
                              ),
                              icon: const Icon(
                                Icons.check_circle_rounded,
                                size: 15,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Mark as Fixed',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              onPressed: () async {
                                await _firestoreService.updateFeedbackStatus(item.id, 'resolved');
                                final updatedList = await _firestoreService.getFeedbackList();
                                final updatedMetrics = await _firestoreService.getFeedbackMetrics();
                                setState(() {
                                  _feedbackList = updatedList;
                                  _feedbackMetrics = updatedMetrics;
                                });
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildFeedbackChip(String label, int count, {Color? color}) {
    final isSelected = _feedbackFilter == label;
    final baseColor = color ?? AppTheme.primaryColor;
    return ChoiceChip(
      avatar: isSelected
          ? Icon(Icons.check_rounded, size: 14, color: baseColor)
          : null,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: isSelected ? baseColor : Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
      selected: isSelected,
      selectedColor: baseColor.withValues(alpha: 0.15),
      backgroundColor: Theme.of(context).cardColor,
      side: BorderSide(
        color: isSelected ? baseColor : Colors.grey.withValues(alpha: 0.25),
        width: isSelected ? 1.5 : 1.0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        fontSize: 12,
        color: isSelected ? baseColor : null,
      ),
      onSelected: (_) => setState(() => _feedbackFilter = label),
    );
  }

  Widget _buildFeedbackMetricTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }


  Widget _buildSettingsTab(BuildContext context, UserModel admin) {
    final themeProvider = context.watch<ThemeProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF312E81), Color(0xFF4F46E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Text(
                  admin.effectiveNickname.isNotEmpty ? admin.effectiveNickname[0].toUpperCase() : 'A',
                  style: const TextStyle(color: Color(0xFF4F46E5), fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          admin.effectiveNickname,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('ADMIN', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(admin.email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('UID: ${admin.uid}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const Text('Security & Credentials', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 8),

        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: const Icon(Icons.password_rounded, color: AppTheme.primaryColor),
            title: const Text('Change Admin Password', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Update authentication password for this admin account'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () => _showChangePasswordDialog(context),
          ),
        ),
        const SizedBox(height: 20),

        const Text('Appearance & App Preferences', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 8),

        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_rounded, color: Color(0xFF8B5CF6)),
                title: const Text('Dark Theme', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Toggle between sleek dark and radiant light theme'),
                value: themeProvider.isDarkMode,
                onChanged: (val) => themeProvider.toggleTheme(val),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.volume_up_rounded, color: Color(0xFF10B981)),
                title: const Text('Sound Effects', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Play subtle audio cues upon button interactions'),
                value: _soundEnabled,
                onChanged: (val) => setState(() => _soundEnabled = val),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.vibration_rounded, color: Color(0xFFF59E0B)),
                title: const Text('Haptic Feedback', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Vibrate device on key actions and submissions'),
                value: _hapticsEnabled,
                onChanged: (val) => setState(() => _hapticsEnabled = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text('Database Maintenance & Refresh', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 8),

        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.25), width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.cleaning_services_rounded, color: Colors.redAccent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Database Hygiene & Cleanup',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Password-protected hygiene. User accounts, EXP & logins remain 100% safe.',
                            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.refresh_rounded, size: 16, color: Colors.redAccent),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'System Refresh (Purge All Generated Quizzes)',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Deletes all user-uploaded document extractions and generated quiz records to refresh the system. All scholar accounts and logins stay intact.',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                          label: const Text('System Refresh & Cleanup', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          onPressed: () => _handleSystemRefreshInSettings(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_remove_rounded, size: 16, color: Colors.amber.shade800),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Scholar Document Cleanup',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Colors.amber.shade900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select a specific scholar to purge only their generated documents and quiz attempts. Their account and profile will not be deleted.',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.amber.shade900,
                            side: BorderSide(color: Colors.amber.shade800),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          icon: const Icon(Icons.manage_accounts_rounded, size: 20),
                          label: const Text('Purge Specific Scholar Documents', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          onPressed: () => _handleScholarDocumentCleanupInSettings(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        const Text('Platform Hygiene & Policy', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 8),

        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Column(
            children: [
              ListTile(
                leading: Icon(Icons.block_rounded, color: Colors.green),
                title: Text('Ad-Free Interface Active', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('All AdMob banners, interstitials & rewards are disabled'),
                trailing: Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.leaderboard_rounded, color: Colors.green),
                title: Text('Leaderboard Exclusion Enforced', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Admin accounts do not earn EXP or appear in scholar rankings'),
                trailing: Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign Out of Admin Console', style: TextStyle(fontWeight: FontWeight.w800)),
            onPressed: () {
              context.read<AuthViewModel>().signOut();
              context.go(AppRoutes.auth);
            },
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}


class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isPulsing;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isPulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
