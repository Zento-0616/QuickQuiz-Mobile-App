import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class MessageModel {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String senderNickname;
  final String? senderPhotoUrl;
  final String text;
  final DateTime createdAt;
  final bool isQuizChallenge;
  final Map<String, dynamic>? quizChallengeData;
  final bool isExpGift;
  final int? expGiftAmount;
  final bool expGiftClaimed;

  MessageModel({
    String? id,
    required this.chatRoomId,
    required this.senderId,
    required this.senderNickname,
    this.senderPhotoUrl,
    required this.text,
    DateTime? createdAt,
    this.isQuizChallenge = false,
    this.quizChallengeData,
    this.isExpGift = false,
    this.expGiftAmount,
    this.expGiftClaimed = false,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String? ?? _uuid.v4(),
      chatRoomId: json['chatRoomId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderNickname: json['senderNickname'] as String? ?? 'User',
      senderPhotoUrl: json['senderPhotoUrl'] as String?,
      text: json['text'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      isQuizChallenge: json['isQuizChallenge'] as bool? ?? false,
      quizChallengeData: json['quizChallengeData'] != null
          ? Map<String, dynamic>.from(json['quizChallengeData'] as Map)
          : null,
      isExpGift: json['isExpGift'] as bool? ?? false,
      expGiftAmount: json['expGiftAmount'] as int?,
      expGiftClaimed: json['expGiftClaimed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatRoomId': chatRoomId,
      'senderId': senderId,
      'senderNickname': senderNickname,
      'senderPhotoUrl': senderPhotoUrl,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'isQuizChallenge': isQuizChallenge,
      'quizChallengeData': quizChallengeData,
      'isExpGift': isExpGift,
      'expGiftAmount': expGiftAmount,
      'expGiftClaimed': expGiftClaimed,
    };
  }

  MessageModel copyWith({
    String? id,
    String? chatRoomId,
    String? senderId,
    String? senderNickname,
    String? senderPhotoUrl,
    String? text,
    DateTime? createdAt,
    bool? isQuizChallenge,
    Map<String, dynamic>? quizChallengeData,
    bool? isExpGift,
    int? expGiftAmount,
    bool? expGiftClaimed,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      senderId: senderId ?? this.senderId,
      senderNickname: senderNickname ?? this.senderNickname,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      isQuizChallenge: isQuizChallenge ?? this.isQuizChallenge,
      quizChallengeData: quizChallengeData ?? this.quizChallengeData,
      isExpGift: isExpGift ?? this.isExpGift,
      expGiftAmount: expGiftAmount ?? this.expGiftAmount,
      expGiftClaimed: expGiftClaimed ?? this.expGiftClaimed,
    );
  }
}
