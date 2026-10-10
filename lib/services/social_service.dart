import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_room_model.dart';
import '../models/friend_request_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

enum FriendshipState { none, pendingSent, pendingReceived, friends }

class SocialService {
  final FirebaseFirestore? _customDb;

  SocialService({FirebaseFirestore? firestore}) : _customDb = firestore;

  FirebaseFirestore get _db => _customDb ?? FirebaseFirestore.instance;

  bool get _isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // In-memory fallback stores for offline/test environments
  static final List<FriendRequestModel> _fallbackRequests = [];
  static final Map<String, Set<String>> _fallbackFriends = {};
  static final List<ChatRoomModel> _fallbackRooms = [];
  static final Map<String, List<MessageModel>> _fallbackMessages = {};

  // -------------------------------------------------------------------
  // Friend Search & Status
  // -------------------------------------------------------------------

  Future<List<UserModel>> searchUsers(String query, String currentUserId) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return [];

    try {
      final snapshot = await _db
          .collection('users')
          .limit(20)
          .get()
          .timeout(const Duration(seconds: 4));

      if (snapshot.docs.isNotEmpty) {
        final users = snapshot.docs
            .map((doc) => UserModel.fromJson(doc.data()))
            .where((u) => u.uid != currentUserId)
            .where((u) =>
                u.nickname.toLowerCase().contains(cleanQuery) ||
                u.name.toLowerCase().contains(cleanQuery))
            .toList();
        return users;
      }
    } catch (_) {}

    return [];
  }

  Future<FriendshipState> getFriendshipStatus(String currentUserId, String targetUserId) async {
    if (currentUserId == targetUserId) return FriendshipState.none;

    // Check fallback first for testing/offline
    if (_fallbackFriends[currentUserId]?.contains(targetUserId) == true) {
      return FriendshipState.friends;
    }

    try {
      // 1. Check accepted friendships
      final friendDoc = await _db
          .collection('friends')
          .doc('${currentUserId}_$targetUserId')
          .get()
          .timeout(const Duration(seconds: 3));

      if (friendDoc.exists) return FriendshipState.friends;

      // 2. Check pending requests sent
      final sentDoc = await _db
          .collection('friend_requests')
          .where('senderId', isEqualTo: currentUserId)
          .where('receiverId', isEqualTo: targetUserId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 3));

      if (sentDoc.docs.isNotEmpty) return FriendshipState.pendingSent;

      // 3. Check pending requests received
      final recvDoc = await _db
          .collection('friend_requests')
          .where('senderId', isEqualTo: targetUserId)
          .where('receiverId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 3));

      if (recvDoc.docs.isNotEmpty) return FriendshipState.pendingReceived;
    } catch (_) {}

    // In-memory fallback check
    for (final req in _fallbackRequests) {
      if (req.status == FriendRequestStatus.pending) {
        if (req.senderId == currentUserId && req.receiverId == targetUserId) {
          return FriendshipState.pendingSent;
        }
        if (req.senderId == targetUserId && req.receiverId == currentUserId) {
          return FriendshipState.pendingReceived;
        }
      }
    }

    return FriendshipState.none;
  }

  // -------------------------------------------------------------------
  // Friend Request Lifecycle
  // -------------------------------------------------------------------

  Future<void> sendFriendRequest({
    required UserModel currentUser,
    required UserModel targetUser,
  }) async {
    final request = FriendRequestModel(
      senderId: currentUser.uid,
      receiverId: targetUser.uid,
      senderNickname: currentUser.effectiveNickname,
      senderPhotoUrl: currentUser.photoUrl,
      receiverNickname: targetUser.effectiveNickname,
      receiverPhotoUrl: targetUser.photoUrl,
      status: FriendRequestStatus.pending,
    );

    _fallbackRequests.add(request);

    try {
      await _db
          .collection('friend_requests')
          .doc(request.id)
          .set(request.toJson())
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[SocialService] Cloud sendFriendRequest failed: $e');
    }
  }

  Future<void> acceptFriendRequest(FriendRequestModel request) async {
    final updated = request.copyWith(status: FriendRequestStatus.accepted);

    // Fallback store update
    _fallbackRequests.removeWhere((r) => r.id == request.id);
    _fallbackRequests.add(updated);

    _fallbackFriends.putIfAbsent(request.senderId, () => {}).add(request.receiverId);
    _fallbackFriends.putIfAbsent(request.receiverId, () => {}).add(request.senderId);

    try {
      final batch = _db.batch();
      batch.update(
        _db.collection('friend_requests').doc(request.id),
        {'status': 'accepted'},
      );

      // Mutual friendship entries
      batch.set(_db.collection('friends').doc('${request.senderId}_${request.receiverId}'), {
        'userId1': request.senderId,
        'userId2': request.receiverId,
        'createdAt': DateTime.now().toIso8601String(),
      });
      batch.set(_db.collection('friends').doc('${request.receiverId}_${request.senderId}'), {
        'userId1': request.receiverId,
        'userId2': request.senderId,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await batch.commit().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[SocialService] Cloud acceptFriendRequest failed: $e');
    }
  }

  Future<void> rejectFriendRequest(String requestId) async {
    _fallbackRequests.removeWhere((r) => r.id == requestId);

    try {
      await _db
          .collection('friend_requests')
          .doc(requestId)
          .update({'status': 'rejected'})
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  Future<List<FriendRequestModel>> getPendingRequests(String currentUserId) async {
    try {
      final snapshot = await _db
          .collection('friend_requests')
          .where('receiverId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .get()
          .timeout(const Duration(seconds: 4));

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((d) => FriendRequestModel.fromJson(d.data())).toList();
      }
    } catch (_) {}

    return _fallbackRequests
        .where((r) => r.receiverId == currentUserId && r.status == FriendRequestStatus.pending)
        .toList();
  }

  Future<List<UserModel>> getFriendsList(String currentUserId) async {
    final friendUids = <String>{};

    if (_fallbackFriends.containsKey(currentUserId)) {
      friendUids.addAll(_fallbackFriends[currentUserId]!);
    }

    try {
      final snapshot = await _db
          .collection('friends')
          .where('userId1', isEqualTo: currentUserId)
          .get()
          .timeout(const Duration(seconds: 4));

      for (final doc in snapshot.docs) {
        final u2 = doc.data()['userId2'] as String?;
        if (u2 != null) friendUids.add(u2);
      }
    } catch (_) {}

    if (friendUids.isEmpty) {
      return [];
    }

    // Resolve user models
    final friends = <UserModel>[];
    for (final uid in friendUids) {
      try {
        final doc = await _db.collection('users').doc(uid).get().timeout(const Duration(seconds: 3));
        if (doc.exists && doc.data() != null) {
          friends.add(UserModel.fromJson(doc.data()!));
          continue;
        }
      } catch (_) {}

      friends.add(
        UserModel(
          uid: uid,
          name: 'Friend ($uid)',
          email: '$uid@example.com',
          createdAt: DateTime.now(),
          nickname: uid,
          level: 1,
          exp: 0,
        ),
      );
    }
    return friends;
  }

  // -------------------------------------------------------------------
  // Strict 1-on-1 and Group Messaging
  // -------------------------------------------------------------------

  /// Opens or creates a 1-on-1 chat room with [friendUser].
  ///
  /// STRICT PRIVACY LOCK: Users CANNOT message any player who is not on
  /// their accepted Friends list. Throws an exception if privacy lock is violated.
  Future<ChatRoomModel> getOrCreateOneOnOneChat({
    required UserModel currentUser,
    required UserModel friendUser,
  }) async {
    // 1. Verify Friendship Status (Admins can direct-message any scholar)
    final isAdminInvolved = currentUser.isAdmin || friendUser.isAdmin;
    if (!isAdminInvolved) {
      final status = await getFriendshipStatus(currentUser.uid, friendUser.uid);
      if (status != FriendshipState.friends) {
        throw Exception(
          'STRICT PRIVACY LOCK: You can only direct-message players on your accepted Friends list.',
        );
      }
    }

    final roomId = _getOneOnOneRoomId(currentUser.uid, friendUser.uid);

    // Check existing in fallback
    final existingFallback = _fallbackRooms.where((r) => r.id == roomId);
    if (existingFallback.isNotEmpty) {
      return existingFallback.first;
    }

    final newRoom = ChatRoomModel(
      id: roomId,
      isGroup: false,
      name: friendUser.effectiveNickname,
      memberIds: [currentUser.uid, friendUser.uid],
      memberNicknames: {
        currentUser.uid: currentUser.effectiveNickname,
        friendUser.uid: friendUser.effectiveNickname,
      },
      memberPhotos: {
        currentUser.uid: currentUser.photoUrl,
        friendUser.uid: friendUser.photoUrl,
      },
      adminId: currentUser.uid,
    );

    _fallbackRooms.add(newRoom);

    try {
      await _db
          .collection('chat_rooms')
          .doc(roomId)
          .set(newRoom.toJson())
          .timeout(const Duration(seconds: 4));
    } catch (_) {}

    return newRoom;
  }

  /// Creates a group chat room capped at a maximum of 5 players per room.
  ///
  /// FRIEND-ONLY INVITATIONS: Group hosts can ONLY add or invite users
  /// from their accepted Friends list.
  Future<ChatRoomModel> createGroupChat({
    required UserModel currentUser,
    required String groupName,
    required List<UserModel> invitedFriends,
  }) async {
    // 1. Enforce max 5 players
    final totalPlayers = invitedFriends.length + 1;
    if (totalPlayers > 5) {
      throw Exception('Group chats cannot exceed 5 players (current selection: $totalPlayers).');
    }

    // 2. Enforce Friend-Only Invitations
    for (final friend in invitedFriends) {
      final status = await getFriendshipStatus(currentUser.uid, friend.uid);
      if (status != FriendshipState.friends) {
        throw Exception(
          'Friend-Only Invitations: "${friend.effectiveNickname}" is not on your accepted Friends list.',
        );
      }
    }

    final memberIds = [currentUser.uid, ...invitedFriends.map((f) => f.uid)];
    final memberNicknames = {
      currentUser.uid: currentUser.effectiveNickname,
      for (final f in invitedFriends) f.uid: f.effectiveNickname,
    };
    final memberPhotos = {
      currentUser.uid: currentUser.photoUrl,
      for (final f in invitedFriends) f.uid: f.photoUrl,
    };

    final newGroup = ChatRoomModel(
      isGroup: true,
      name: groupName.trim().isNotEmpty ? groupName.trim() : 'Quiz Squad',
      memberIds: memberIds,
      memberNicknames: memberNicknames,
      memberPhotos: memberPhotos,
      adminId: currentUser.uid,
    );

    _fallbackRooms.add(newGroup);

    try {
      await _db
          .collection('chat_rooms')
          .doc(newGroup.id)
          .set(newGroup.toJson())
          .timeout(const Duration(seconds: 4));
    } catch (_) {}

    return newGroup;
  }

  Future<List<ChatRoomModel>> getChatRooms(String currentUserId) async {
    try {
      final snapshot = await _db
          .collection('chat_rooms')
          .where('memberIds', arrayContains: currentUserId)
          .get()
          .timeout(const Duration(seconds: 4));

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((d) => ChatRoomModel.fromJson(d.data())).toList();
      }
    } catch (_) {}

    return _fallbackRooms.where((r) => r.memberIds.contains(currentUserId)).toList();
  }

  Stream<List<ChatRoomModel>> streamChatRooms(String currentUserId) {
    if (_customDb != null || _isFirebaseAvailable) {
      return _db
          .collection('chat_rooms')
          .where('memberIds', arrayContains: currentUserId)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((d) => ChatRoomModel.fromJson(d.data())).toList());
    }
    return Stream.periodic(
      const Duration(seconds: 3),
      (_) => _fallbackRooms.where((r) => r.memberIds.contains(currentUserId)).toList(),
    );
  }

  // -------------------------------------------------------------------
  // Messages & In-Chat Challenge
  // -------------------------------------------------------------------

  Future<List<MessageModel>> getMessages(String chatRoomId) async {
    try {
      final snapshot = await _db
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .limit(50)
          .get()
          .timeout(const Duration(seconds: 4));

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((d) => MessageModel.fromJson(d.data())).toList();
      }
    } catch (_) {}

    return _fallbackMessages[chatRoomId] ?? [];
  }

  Stream<List<MessageModel>> streamMessages(String chatRoomId) {
    if (_customDb != null || _isFirebaseAvailable) {
      return _db
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .limit(100)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((d) => MessageModel.fromJson(d.data())).toList());
    }
    return Stream.periodic(
      const Duration(seconds: 2),
      (_) => _fallbackMessages[chatRoomId] ?? [],
    );
  }

  Future<void> sendMessage({
    required String chatRoomId,
    required UserModel sender,
    required String text,
    bool isQuizChallenge = false,
    Map<String, dynamic>? quizChallengeData,
    bool isExpGift = false,
    int? expGiftAmount,
    bool expGiftClaimed = false,
  }) async {
    final message = MessageModel(
      chatRoomId: chatRoomId,
      senderId: sender.uid,
      senderNickname: sender.effectiveNickname,
      senderPhotoUrl: sender.photoUrl,
      text: text.trim(),
      isQuizChallenge: isQuizChallenge,
      quizChallengeData: quizChallengeData,
      isExpGift: isExpGift,
      expGiftAmount: expGiftAmount,
      expGiftClaimed: expGiftClaimed,
    );

    // Fallback store
    _fallbackMessages.putIfAbsent(chatRoomId, () => []).add(message);

    final previewText = isExpGift
        ? '🎁 EXP Gift: +$expGiftAmount EXP'
        : (isQuizChallenge ? '⚡ Quiz Challenge: ${quizChallengeData?['title'] ?? 'MCQ'}' : text);

    // Update last message in room
    final roomIdx = _fallbackRooms.indexWhere((r) => r.id == chatRoomId);
    if (roomIdx != -1) {
      _fallbackRooms[roomIdx] = _fallbackRooms[roomIdx].copyWith(
        lastMessage: previewText,
        lastMessageTime: DateTime.now(),
        lastSenderId: sender.uid,
        lastSenderNickname: sender.effectiveNickname,
      );
    }

    try {
      final roomRef = _db.collection('chat_rooms').doc(chatRoomId);
      final batch = _db.batch();
      batch.set(roomRef.collection('messages').doc(message.id), message.toJson());
      batch.update(roomRef, {
        'lastMessage': previewText,
        'lastMessageTime': DateTime.now().toIso8601String(),
        'lastSenderId': sender.uid,
        'lastSenderNickname': sender.effectiveNickname,
      });
      await batch.commit().timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  Future<void> claimExpGift(String chatRoomId, String messageId) async {
    final list = _fallbackMessages[chatRoomId];
    if (list != null) {
      final idx = list.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(expGiftClaimed: true);
      }
    }

    try {
      await _db
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .update({'expGiftClaimed': true})
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  Future<void> deleteMessage(String chatRoomId, String messageId) async {
    final list = _fallbackMessages[chatRoomId];
    if (list != null) {
      list.removeWhere((m) => m.id == messageId);
    }

    try {
      await _db
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .delete()
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  Future<void> deleteQuizChallengesForQuiz(String quizId) async {
    for (final entry in _fallbackMessages.entries) {
      entry.value.removeWhere((m) =>
          m.isQuizChallenge &&
          (m.quizChallengeData?['id'] == quizId || m.quizChallengeData?['quizId'] == quizId));
    }

    try {
      final roomsSnap = await _db.collection('chat_rooms').limit(50).get().timeout(const Duration(seconds: 4));
      for (final roomDoc in roomsSnap.docs) {
        final messagesSnap = await roomDoc.reference
            .collection('messages')
            .where('isQuizChallenge', isEqualTo: true)
            .get()
            .timeout(const Duration(seconds: 4));
        for (final msgDoc in messagesSnap.docs) {
          final data = msgDoc.data();
          final qData = data['quizChallengeData'] as Map<String, dynamic>?;
          if (qData?['id'] == quizId || qData?['quizId'] == quizId) {
            await msgDoc.reference.delete();
          }
        }
      }
    } catch (_) {}
  }

  // -------------------------------------------------------------------
  // Leaderboards
  // -------------------------------------------------------------------

  Future<List<UserModel>> getLeaderboard({bool weekly = false}) async {
    if (_customDb == null && !_isFirebaseAvailable) return [];
    try {
      final snapshot = await _db
          .collection('users')
          .orderBy('exp', descending: true)
          .limit(30)
          .get()
          .timeout(const Duration(seconds: 4));

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map((d) => UserModel.fromJson(d.data()))
            .where((u) => !u.isAdmin && u.role != 'admin')
            .take(20)
            .toList();
      }
    } catch (_) {}

    return [];
  }

  /// Fetches real registered community scholars for multiplayer arenas without mock players.
  Future<List<UserModel>> getActiveCommunityScholars({int limit = 20, String? excludeUserId}) async {
    try {
      if (_customDb != null || _isFirebaseAvailable) {
        final snapshot = await _db
            .collection('users')
            .limit(limit + 15)
            .get()
            .timeout(const Duration(seconds: 4));

        if (snapshot.docs.isNotEmpty) {
          final users = snapshot.docs
              .map((d) => UserModel.fromJson(d.data()))
              .where((u) => !u.isAdmin && u.role != 'admin' && (excludeUserId == null || u.uid != excludeUserId))
              .toList();

          users.sort((a, b) => b.exp.compareTo(a.exp));
          return users.take(limit).toList();
        }
      }
    } catch (_) {}

    return [];
  }

  /// Fetches scholars who are strictly currently online for live PvP matchmaking.
  Future<List<UserModel>> getActiveOnlineScholars({int limit = 20, String? excludeUserId}) async {
    try {
      if (_customDb != null || _isFirebaseAvailable) {
        final snapshot = await _db
            .collection('users')
            .limit(40)
            .get()
            .timeout(const Duration(seconds: 4));

        if (snapshot.docs.isNotEmpty) {
          final users = snapshot.docs
              .map((d) => UserModel.fromJson(d.data()))
              .where((u) => !u.isAdmin && u.role != 'admin' && (excludeUserId == null || u.uid != excludeUserId))
              .toList();

          // Strictly filter for genuinely active online scholars only (within 5 minutes)
          final online = users.where((u) => u.isCurrentlyOnline).toList();
          online.sort((a, b) => (b.lastActive ?? b.lastLoginDate ?? DateTime.now())
              .compareTo(a.lastActive ?? a.lastLoginDate ?? DateTime.now()));
          return online.take(limit).toList();
        }
      }
    } catch (_) {}

    return [];
  }

  String _getOneOnOneRoomId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '1on1_${sorted[0]}_${sorted[1]}';
  }
}
