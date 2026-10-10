import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum FriendRequestStatus { pending, accepted, rejected }

class FriendRequestModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String senderNickname;
  final String? senderPhotoUrl;
  final String receiverNickname;
  final String? receiverPhotoUrl;
  final FriendRequestStatus status;
  final DateTime createdAt;

  FriendRequestModel({
    String? id,
    required this.senderId,
    required this.receiverId,
    required this.senderNickname,
    this.senderPhotoUrl,
    required this.receiverNickname,
    this.receiverPhotoUrl,
    this.status = FriendRequestStatus.pending,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestModel(
      id: json['id'] as String? ?? _uuid.v4(),
      senderId: json['senderId'] as String? ?? '',
      receiverId: json['receiverId'] as String? ?? '',
      senderNickname: json['senderNickname'] as String? ?? 'User',
      senderPhotoUrl: json['senderPhotoUrl'] as String?,
      receiverNickname: json['receiverNickname'] as String? ?? 'User',
      receiverPhotoUrl: json['receiverPhotoUrl'] as String?,
      status: FriendRequestStatus.values.firstWhere(
        (s) => s.name == (json['status'] as String? ?? 'pending'),
        orElse: () => FriendRequestStatus.pending,
      ),
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'senderNickname': senderNickname,
      'senderPhotoUrl': senderPhotoUrl,
      'receiverNickname': receiverNickname,
      'receiverPhotoUrl': receiverPhotoUrl,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  FriendRequestModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? senderNickname,
    String? senderPhotoUrl,
    String? receiverNickname,
    String? receiverPhotoUrl,
    FriendRequestStatus? status,
    DateTime? createdAt,
  }) {
    return FriendRequestModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      senderNickname: senderNickname ?? this.senderNickname,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      receiverNickname: receiverNickname ?? this.receiverNickname,
      receiverPhotoUrl: receiverPhotoUrl ?? this.receiverPhotoUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
