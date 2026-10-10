import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firestore_service.dart';
import 'social_service.dart';

/// Singleton service managing notification badges for direct messages,
/// friend requests, and administrative announcements across bottom navigation.
class UnreadNotificationService {
  static final UnreadNotificationService _instance = UnreadNotificationService._internal();
  factory UnreadNotificationService() => _instance;
  UnreadNotificationService._internal();

  final SocialService _socialService = SocialService();
  final FirestoreService _firestoreService = FirestoreService();

  final ValueNotifier<bool> hasUnreadMessages = ValueNotifier<bool>(false);
  final ValueNotifier<int> totalUnreadCount = ValueNotifier<int>(0);

  DateTime? _lastSeenMessagesTime;
  Timer? _pollingTimer;
  String? _currentUserId;

  /// Starts polling for new notifications / messages for the authenticated user.
  void startMonitoring(String userId) {
    if (_currentUserId == userId && _pollingTimer != null) return;
    _currentUserId = userId;
    _loadLastSeenTime();
    checkUnread(userId);

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        checkUnread(_currentUserId!);
      }
    });
  }

  void stopMonitoring() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _currentUserId = null;
    hasUnreadMessages.value = false;
    totalUnreadCount.value = 0;
  }

  Future<void> _loadLastSeenTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt('last_seen_messages_timestamp_${_currentUserId ?? ""}');
      if (ms != null) {
        _lastSeenMessagesTime = DateTime.fromMillisecondsSinceEpoch(ms);
      }
    } catch (_) {}
  }

  /// Marks the messages tab as viewed at the current timestamp, clearing the dot.
  Future<void> markMessagesTabSeen() async {
    _lastSeenMessagesTime = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'last_seen_messages_timestamp_${_currentUserId ?? ""}',
        _lastSeenMessagesTime!.millisecondsSinceEpoch,
      );
    } catch (_) {}
    hasUnreadMessages.value = false;
    totalUnreadCount.value = 0;
  }

  /// Explicitly set unread state from active views (e.g. MessagesView)
  void setUnreadState({required bool unread, int count = 0}) {
    hasUnreadMessages.value = unread;
    totalUnreadCount.value = count;
  }

  /// Performs a check across pending requests, unread announcements, and chat rooms.
  Future<void> checkUnread(String? userId) async {
    if (userId == null || userId.isEmpty || userId.startsWith('guest_')) {
      hasUnreadMessages.value = false;
      totalUnreadCount.value = 0;
      return;
    }

    try {
      int count = 0;

      // 1. Pending friend requests
      final pending = await _socialService.getPendingRequests(userId);
      count += pending.length;

      // 2. Unread broadcast announcements
      final alerts = await _firestoreService.getBroadcastAlerts();
      final unreadAlerts = alerts.where((a) => !a.isReadBy(userId)).length;
      count += unreadAlerts;

      // 3. New incoming chat messages from other scholars
      final rooms = await _socialService.getChatRooms(userId);
      final cutoff = _lastSeenMessagesTime ?? DateTime.now().subtract(const Duration(hours: 12));
      
      final unreadRooms = rooms.where((r) {
        if (r.lastMessage == null || r.lastSenderId == null) return false;
        if (r.lastSenderId == userId) return false; // Sent by ourselves
        final msgTime = r.lastMessageTime;
        if (msgTime == null) return false;
        return msgTime.isAfter(cutoff);
      }).length;
      count += unreadRooms;

      totalUnreadCount.value = count;
      hasUnreadMessages.value = count > 0;
    } catch (_) {}
  }
}
