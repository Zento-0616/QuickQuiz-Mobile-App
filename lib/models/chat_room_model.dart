import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class ChatRoomModel {
  final String id;
  final bool isGroup;
  final String name;
  final List<String> memberIds;
  final Map<String, String> memberNicknames;
  final Map<String, String?> memberPhotos;
  final String adminId;
  final DateTime createdAt;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastSenderId;
  final String? lastSenderNickname;

  ChatRoomModel({
    String? id,
    this.isGroup = false,
    required this.name,
    required this.memberIds,
    required this.memberNicknames,
    this.memberPhotos = const {},
    required this.adminId,
    DateTime? createdAt,
    this.lastMessage,
    this.lastMessageTime,
    this.lastSenderId,
    this.lastSenderNickname,
  })  : assert(memberIds.length <= 5, 'Group chats cannot exceed 5 players'),
        id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  factory ChatRoomModel.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['memberIds'] as List? ?? [];
    final memberIds = rawMembers.map((e) => e.toString()).toList();

    final rawNicknames = json['memberNicknames'] as Map? ?? {};
    final memberNicknames = rawNicknames.map((k, v) => MapEntry(k.toString(), v.toString()));

    final rawPhotos = json['memberPhotos'] as Map? ?? {};
    final memberPhotos = rawPhotos.map((k, v) => MapEntry(k.toString(), v?.toString()));

    return ChatRoomModel(
      id: json['id'] as String? ?? _uuid.v4(),
      isGroup: json['isGroup'] as bool? ?? false,
      name: json['name'] as String? ?? 'Chat',
      memberIds: memberIds,
      memberNicknames: memberNicknames,
      memberPhotos: memberPhotos,
      adminId: json['adminId'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      lastMessage: json['lastMessage'] as String?,
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.tryParse(json['lastMessageTime'].toString())
          : null,
      lastSenderId: json['lastSenderId'] as String?,
      lastSenderNickname: json['lastSenderNickname'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'isGroup': isGroup,
      'name': name,
      'memberIds': memberIds,
      'memberNicknames': memberNicknames,
      'memberPhotos': memberPhotos,
      'adminId': adminId,
      'createdAt': createdAt.toIso8601String(),
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'lastSenderId': lastSenderId,
      'lastSenderNickname': lastSenderNickname,
    };
  }

  ChatRoomModel copyWith({
    String? id,
    bool? isGroup,
    String? name,
    List<String>? memberIds,
    Map<String, String>? memberNicknames,
    Map<String, String?>? memberPhotos,
    String? adminId,
    DateTime? createdAt,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastSenderId,
    String? lastSenderNickname,
  }) {
    return ChatRoomModel(
      id: id ?? this.id,
      isGroup: isGroup ?? this.isGroup,
      name: name ?? this.name,
      memberIds: memberIds ?? this.memberIds,
      memberNicknames: memberNicknames ?? this.memberNicknames,
      memberPhotos: memberPhotos ?? this.memberPhotos,
      adminId: adminId ?? this.adminId,
      createdAt: createdAt ?? this.createdAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      lastSenderNickname: lastSenderNickname ?? this.lastSenderNickname,
    );
  }

  /// Helper to get the display name for a given user.
  /// If it's a 1-on-1 chat, returns the other person's nickname.
  String getDisplayName(String currentUserId) {
    if (isGroup) return name;
    final otherUserId = memberIds.firstWhere((id) => id != currentUserId, orElse: () => '');
    return memberNicknames[otherUserId] ?? name;
  }

  String? getDisplayPhoto(String currentUserId) {
    if (isGroup) return null;
    final otherUserId = memberIds.firstWhere((id) => id != currentUserId, orElse: () => '');
    return memberPhotos[otherUserId];
  }
}
