import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../controllers/inbox_notification_controller.dart';
import '../../models/broadcast_alert_model.dart';
import '../../models/chat_room_model.dart';
import '../../models/friend_request_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/social_service.dart';
import '../../services/unread_notification_service.dart';
import '../../utils/toast_helper.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/main_bottom_nav.dart';
import '../../widgets/quick_quiz_top_bar.dart';

/// Social & Messages panel adhering to Strict Friendship Rules:
/// - Chats list (1-on-1 & Group)
/// - Friends list with online status
/// - Inbox for Friend Requests & Broadcast Alerts
/// - Search with STRICT PRIVACY LOCK (chat button disabled for non-friends)
/// - Group Chat creation capped at 5 scholars (friends-only invitations)
class MessagesView extends StatefulWidget {
  const MessagesView({super.key});

  @override
  State<MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends State<MessagesView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SocialService _socialService = SocialService();
  final FirestoreService _firestoreService = FirestoreService();
  final InboxNotificationController _inboxController = InboxNotificationController();
  StreamSubscription<List<ChatRoomModel>>? _chatRoomsSub;
  Timer? _autoRefreshTimer;

  List<ChatRoomModel> _chatRooms = [];
  List<UserModel> _friends = [];
  List<FriendRequestModel> _pendingRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    UnreadNotificationService().markMessagesTabSeen();
    _loadData();

    final auth = context.read<AuthViewModel>();
    final user = auth.currentUser;
    if (user != null) {
      _chatRoomsSub = _socialService.streamChatRooms(user.uid).listen((rooms) {
        if (mounted) {
          setState(() {
            _chatRooms = rooms;
          });
        }
      });
    }

    // Auto-refresh notifications and friend requests silently every 5 seconds
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _refreshSilently();
    });
  }

  Future<void> _refreshSilently() async {
    final auth = context.read<AuthViewModel>();
    final user = auth.currentUser;
    if (user == null || !mounted) return;
    try {
      final friends = await _socialService.getFriendsList(user.uid);
      final requests = await _socialService.getPendingRequests(user.uid);
      final alerts = await _firestoreService.getBroadcastAlerts();
      if (mounted) {
        setState(() {
          _friends = friends;
          _pendingRequests = requests;
          _inboxController.setInboxData(alerts: alerts, requests: requests);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthViewModel>();
    final user = auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final rooms = await _socialService.getChatRooms(user.uid);
      final friends = await _socialService.getFriendsList(user.uid);
      final requests = await _socialService.getPendingRequests(user.uid);
      final alerts = await _firestoreService.getBroadcastAlerts();

      if (mounted) {
        setState(() {
          _chatRooms = rooms;
          _friends = friends;
          _pendingRequests = requests;
          _inboxController.setInboxData(alerts: alerts, requests: requests);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _chatRoomsSub?.cancel();
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    _inboxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final user = auth.currentUser;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go(AppRoutes.home);
      },
      child: Scaffold(
        appBar: QuickQuizTopBar(
          extraActions: [
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 21),
              tooltip: 'Find Friends',
              onPressed: () => _openSearchFriendsSheet(context, user),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(Icons.group_add_rounded, size: 21),
              tooltip: 'New Group Chat (Max 5)',
              onPressed: () => _openCreateGroupDialog(context, user),
            ),
          ],
        ),
        extendBody: true,
        bottomNavigationBar: const MainBottomNav(current: MainTab.messages),
        body: SafeArea(
          bottom: false,
          child: user == null
              ? _buildGuestMessageLock(context)
              : Column(
                  children: [
                    // Tab Selector
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListenableBuilder(
                        listenable: _inboxController,
                        builder: (context, _) {
                          final unreadCount = _inboxController.unreadTotalCount(user.uid);
                          return TabBar(
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
                            tabs: [
                              const Tab(icon: Icon(Icons.chat_bubble_outline_rounded, size: 18), text: 'Chats'),
                              Tab(
                                icon: const Icon(Icons.people_alt_outlined, size: 18),
                                text: 'Friends (${_friends.length})',
                              ),
                              Tab(
                                icon: Badge(
                                  isLabelVisible: unreadCount > 0,
                                  label: Text('$unreadCount'),
                                  child: const Icon(Icons.mail_outline_rounded, size: 18),
                                ),
                                text: _inboxController.getTabTitle(user.uid),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                _buildChatsTab(context, user),
                                _buildFriendsTab(context, user),
                                _buildRequestsTab(context, user),
                              ],
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildGuestMessageLock(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded, size: 52, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sign In to Access Social & Messaging',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Chat with friends, invite them to 5-player group rooms, and send quiz challenges.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.auth),
              child: const Text('Sign In / Register', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // Tab 1: Chats
  // -------------------------------------------------------------------

  Widget _buildChatsTab(BuildContext context, UserModel currentUser) {
    if (_chatRooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 54, color: Theme.of(context).disabledColor),
            const SizedBox(height: 12),
            const Text(
              'No Conversations Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add friends from the top-right button to start chatting!',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 104),
      itemCount: _chatRooms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final room = _chatRooms[index];
        final displayName = room.getDisplayName(currentUser.uid);

        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: room.isGroup ? AppTheme.secondaryColor : AppTheme.primaryColor,
              child: Icon(
                room.isGroup ? Icons.groups_rounded : Icons.person_rounded,
                color: Colors.white,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                if (room.isGroup) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${room.memberIds.length}/5',
                      style: const TextStyle(
                        color: AppTheme.secondaryColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              room.lastMessage ?? 'No messages yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () {
              context.push('/chat/${room.id}', extra: room);
            },
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------
  // Tab 2: Friends
  // -------------------------------------------------------------------

  Widget _buildFriendsTab(BuildContext context, UserModel currentUser) {
    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded, size: 54, color: Theme.of(context).disabledColor),
            const SizedBox(height: 12),
            const Text(
              'Your Friends List is Empty',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_search_rounded, size: 18),
              label: const Text('Search Users by Nickname'),
              onPressed: () => _openSearchFriendsSheet(context, currentUser),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 104),
      itemCount: _friends.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final friend = _friends[index];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar with online status
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        friend.effectiveNickname.isNotEmpty ? friend.effectiveNickname[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: friend.isOnline ? AppTheme.successColor : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.effectiveNickname,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Level ${friend.level} • ${friend.exp} EXP',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),

                // Chat button (ENABLED because this user is on Friends list)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                  label: const Text('Chat', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  onPressed: () async {
                    try {
                      final room = await _socialService.getOrCreateOneOnOneChat(
                        currentUser: currentUser,
                        friendUser: friend,
                      );
                      if (context.mounted) {
                        context.push('/chat/${room.id}', extra: room);
                      }
                    } catch (e) {
                      if (context.mounted) showWarningToast(context, e.toString());
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------
  // Tab 3: Inbox (Broadcast Alerts & Friend Requests)
  // -------------------------------------------------------------------

  void _openAnnouncementDetailDialog(BuildContext context, BroadcastAlertModel alert, String userId) {
    _inboxController.markAlertAsRead(alertId: alert.id, userId: userId);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                alert.title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${alert.authorName} • ${_formatAlertDate(alert.createdAt)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                  if (alert.priority == 'high')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PRIORITY',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 9),
                      ),
                    ),
                ],
              ),
              const Divider(height: 24),
              Text(
                alert.message,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsTab(BuildContext context, UserModel currentUser) {
    return ListenableBuilder(
      listenable: _inboxController,
      builder: (context, _) {
        final alerts = _inboxController.alerts;
        final unreadAlertCount = _inboxController.unreadAlertsCount(currentUser.uid);

        if (_pendingRequests.isEmpty && alerts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mail_outline_rounded, size: 54, color: Theme.of(context).disabledColor),
                const SizedBox(height: 12),
                const Text(
                  'Inbox is Clear',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'No new broadcast announcements or friend requests.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 104),
          children: [
            // Broadcast Announcements
            if (alerts.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.campaign_rounded, size: 18, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Announcements & Broadcasts',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: unreadAlertCount > 0
                          ? AppTheme.primaryColor.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unreadAlertCount > 0 ? '$unreadAlertCount UNREAD' : '${alerts.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: unreadAlertCount > 0 ? AppTheme.primaryColor : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...alerts.map((alert) {
                final isUnread = !alert.isReadBy(currentUser.uid);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openAnnouncementDetailDialog(context, alert, currentUser.uid),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isUnread
                                ? AppTheme.primaryColor.withValues(alpha: 0.6)
                                : (alert.priority == 'high'
                                    ? Colors.redAccent.withValues(alpha: 0.4)
                                    : Colors.grey.withValues(alpha: 0.2)),
                            width: isUnread ? 1.8 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isUnread
                                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.campaign_rounded, size: 16, color: Colors.white),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              alert.title,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isUnread) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'NEW',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 9,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        '${alert.authorName} • ${_formatAlertDate(alert.createdAt)}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                if (alert.priority == 'high') ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'PRIORITY',
                                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 9),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              alert.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, height: 1.4),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Tap to view announcement',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryColor.withValues(alpha: 0.85),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppTheme.primaryColor),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],

        // Friend Requests
        if (_pendingRequests.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.person_add_rounded, size: 18, color: AppTheme.secondaryColor),
              const SizedBox(width: 8),
              const Text(
                'Friend Requests',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_pendingRequests.length}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppTheme.secondaryColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._pendingRequests.map((req) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppTheme.primaryColor,
                        child: Text(
                          req.senderNickname.isNotEmpty ? req.senderNickname[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req.senderNickname,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Sent you a friend request',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 28),
                        tooltip: 'Accept',
                        onPressed: () async {
                          await _socialService.acceptFriendRequest(req);
                          _loadData();
                          if (context.mounted) {
                            showSuccessToast(context, 'You and ${req.senderNickname} are now friends!');
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 28),
                        tooltip: 'Decline',
                        onPressed: () async {
                          await _socialService.rejectFriendRequest(req.id);
                          _loadData();
                        },
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ],
    );
      },
    );
  }

  String _formatAlertDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${date.month}/${date.day}';
    }
  }

  // -------------------------------------------------------------------
  // STRICT PRIVACY LOCK: Search Sheet
  // -------------------------------------------------------------------

  void _openSearchFriendsSheet(BuildContext context, UserModel? currentUser) {
    if (currentUser == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SearchFriendsModal(currentUser: currentUser, socialService: _socialService),
    ).then((_) => _loadData());
  }

  // -------------------------------------------------------------------
  // Group Chat Modal (Max 5 Players, Friends-Only)
  // -------------------------------------------------------------------

  void _openCreateGroupDialog(BuildContext context, UserModel? currentUser) {
    if (currentUser == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateGroupModal(
        currentUser: currentUser,
        friends: _friends,
        socialService: _socialService,
      ),
    ).then((_) => _loadData());
  }
}

/// Search Friends Modal with STRICT PRIVACY LOCK
class _SearchFriendsModal extends StatefulWidget {
  final UserModel currentUser;
  final SocialService socialService;

  const _SearchFriendsModal({
    required this.currentUser,
    required this.socialService,
  });

  @override
  State<_SearchFriendsModal> createState() => _SearchFriendsModalState();
}

class _SearchFriendsModalState extends State<_SearchFriendsModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<UserModel> _results = [];
  final Map<String, FriendshipState> _statuses = {};
  bool _isSearching = false;

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isSearching = true);
    final users = await widget.socialService.searchUsers(query, widget.currentUser.uid);

    final statusMap = <String, FriendshipState>{};
    for (final u in users) {
      statusMap[u.uid] = await widget.socialService.getFriendshipStatus(widget.currentUser.uid, u.uid);
    }

    if (mounted) {
      setState(() {
        _results = users;
        _statuses.addAll(statusMap);
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
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
          const Text(
            'Find Scholars',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Search by Nickname. Non-friends must accept your request before messaging.',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 16),

          // Search Box
          TextField(
            controller: _searchCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter nickname...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchCtrl.clear();
                        _performSearch('');
                      },
                    )
                  : null,
            ),
            onChanged: _performSearch,
          ),
          const SizedBox(height: 16),

          // Results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          _searchCtrl.text.isEmpty ? 'Type a nickname to search' : 'No users found.',
                          style: TextStyle(color: theme.disabledColor),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final target = _results[index];
                          final status = _statuses[target.uid] ?? FriendshipState.none;
                          final isFriend = status == FriendshipState.friends;
                          final isPendingSent = status == FriendshipState.pendingSent;

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppTheme.primaryColor,
                                    child: Text(
                                      target.effectiveNickname.isNotEmpty
                                          ? target.effectiveNickname[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          target.effectiveNickname,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                        ),
                                        Text(
                                          'Level ${target.level} • ${target.exp} EXP',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // STRICT PRIVACY LOCK ACTION:
                                  if (isFriend) ...[
                                    // Friends: Enabled Chat Button
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      ),
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        final room = await widget.socialService.getOrCreateOneOnOneChat(
                                          currentUser: widget.currentUser,
                                          friendUser: target,
                                        );
                                        if (context.mounted) {
                                          context.push('/chat/${room.id}', extra: room);
                                        }
                                      },
                                      child: const Text('Chat', style: TextStyle(fontWeight: FontWeight.w800)),
                                    ),
                                  ] else ...[
                                    // Non-Friend: Chat is LOCKED. Only "Add Friend" or "Pending"
                                    if (isPendingSent) ...[
                                      const OutlinedButton(
                                        onPressed: null,
                                        child: Text('Pending...'),
                                      ),
                                    ] else ...[
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.secondaryColor,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        icon: const Icon(Icons.person_add_rounded, size: 16),
                                        label: const Text('Add Friend', style: TextStyle(fontWeight: FontWeight.w800)),
                                        onPressed: () async {
                                          await widget.socialService.sendFriendRequest(
                                            currentUser: widget.currentUser,
                                            targetUser: target,
                                          );
                                          setState(() {
                                            _statuses[target.uid] = FriendshipState.pendingSent;
                                          });
                                          if (context.mounted) {
                                            showSuccessToast(context, 'Friend request sent!');
                                          }
                                        },
                                      ),
                                    ],
                                    const SizedBox(width: 6),
                                    // Disabled Lock Chat Button
                                    Tooltip(
                                      message: 'STRICT PRIVACY LOCK: Must be accepted friends to chat',
                                      child: IconButton(
                                        icon: const Icon(Icons.lock_rounded, color: Colors.grey, size: 20),
                                        onPressed: () {
                                          showWarningToast(
                                            context,
                                            'Privacy Lock: You cannot message ${target.effectiveNickname} until your friend request is accepted.',
                                          );
                                        },
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
  }
}

/// Create Group Modal (Max 5 Players, Friends-Only Invitations)
class _CreateGroupModal extends StatefulWidget {
  final UserModel currentUser;
  final List<UserModel> friends;
  final SocialService socialService;

  const _CreateGroupModal({
    required this.currentUser,
    required this.friends,
    required this.socialService,
  });

  @override
  State<_CreateGroupModal> createState() => _CreateGroupModalState();
}

class _CreateGroupModalState extends State<_CreateGroupModal> {
  final TextEditingController _groupNameCtrl = TextEditingController();
  final Set<String> _selectedFriendUids = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMembers = _selectedFriendUids.length + 1; // +1 for host

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
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
              const Expanded(
                child: Text(
                  'Create Group Chat',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: totalMembers > 5 ? Colors.redAccent : AppTheme.secondaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalMembers/5 Scholars',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Friend-Only Invitations: Choose up to 4 friends to join your group room.',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 16),

          // Group Name
          TextField(
            controller: _groupNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Group Name',
              hintText: 'e.g. Study Squad, Quiz Masters',
              prefixIcon: Icon(Icons.edit_rounded),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Select Friends:',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: widget.friends.isEmpty
                ? const Center(child: Text('Add friends first before creating a group chat.'))
                : ListView.builder(
                    itemCount: widget.friends.length,
                    itemBuilder: (context, index) {
                      final friend = widget.friends[index];
                      final isSelected = _selectedFriendUids.contains(friend.uid);

                      return CheckboxListTile(
                        value: isSelected,
                        title: Text(friend.effectiveNickname, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('Level ${friend.level} • ${friend.exp} EXP'),
                        secondary: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor,
                          child: Text(
                            friend.effectiveNickname.isNotEmpty ? friend.effectiveNickname[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        onChanged: (val) {
                          if (val == true) {
                            if (_selectedFriendUids.length >= 4) {
                              showWarningToast(context, 'Group chats are strictly capped at 5 scholars (host + 4 friends).');
                              return;
                            }
                            setState(() => _selectedFriendUids.add(friend.uid));
                          } else {
                            setState(() => _selectedFriendUids.remove(friend.uid));
                          }
                        },
                      );
                    },
                  ),
          ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _selectedFriendUids.isEmpty
                  ? null
                  : () async {
                      final selectedFriends = widget.friends
                          .where((f) => _selectedFriendUids.contains(f.uid))
                          .toList();
                      try {
                        final room = await widget.socialService.createGroupChat(
                          currentUser: widget.currentUser,
                          groupName: _groupNameCtrl.text.trim().isNotEmpty
                              ? _groupNameCtrl.text.trim()
                              : 'Quiz Squad',
                          invitedFriends: selectedFriends,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          context.push('/chat/${room.id}', extra: room);
                        }
                      } catch (e) {
                        if (context.mounted) showWarningToast(context, e.toString());
                      }
                    },
              child: const Text('Create Group Room', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
