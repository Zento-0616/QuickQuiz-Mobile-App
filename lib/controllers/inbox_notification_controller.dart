import 'package:flutter/foundation.dart';
import '../models/broadcast_alert_model.dart';
import '../models/friend_request_model.dart';
import '../services/firestore_service.dart';

class InboxNotificationController extends ChangeNotifier {
  final FirestoreService _firestoreService;

  List<BroadcastAlertModel> _alerts = [];
  List<FriendRequestModel> _pendingRequests = [];

  InboxNotificationController({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  List<BroadcastAlertModel> get alerts => List.unmodifiable(_alerts);
  List<FriendRequestModel> get pendingRequests =>
      List.unmodifiable(_pendingRequests);

  void setInboxData({
    required List<BroadcastAlertModel> alerts,
    required List<FriendRequestModel> requests,
  }) {
    _alerts = List.from(alerts);
    _pendingRequests = List.from(requests);
    notifyListeners();
  }

  int unreadAlertsCount(String? userId) {
    if (userId == null || userId.isEmpty) return 0;
    return _alerts.where((a) => !a.isReadBy(userId)).length;
  }

  int unreadTotalCount(String? userId) {
    final alertCount = unreadAlertsCount(userId);
    return _pendingRequests.length + alertCount;
  }

  String getTabTitle(String? userId) {
    final count = unreadTotalCount(userId);
    return count > 0 ? 'Inbox ($count)' : 'Inbox';
  }

  Future<void> markAlertAsRead({
    required String alertId,
    required String userId,
  }) async {
    if (alertId.isEmpty || userId.isEmpty) return;

    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index >= 0) {
      final alert = _alerts[index];
      if (!alert.isReadBy(userId)) {
        final updatedReadList = [...alert.readByUsers, userId];
        _alerts[index] = alert.copyWith(readByUsers: updatedReadList);
        notifyListeners();

        try {
          await _firestoreService.markAnnouncementRead(alertId, userId);
        } catch (_) {}
      }
    }
  }
}
