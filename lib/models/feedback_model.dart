class FeedbackModel {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String type;
  final String title;
  final String message;
  final String status;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const FeedbackModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.type,
    required this.title,
    required this.message,
    this.status = 'pending',
    required this.createdAt,
    this.resolvedAt,
  });

  bool get isResolved => status == 'resolved';

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? 'Scholar',
      userEmail: json['userEmail'] as String? ?? '',
      type: json['type'] as String? ?? 'suggestion',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'type': type,
      'title': title,
      'message': message,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      if (resolvedAt != null) 'resolvedAt': resolvedAt!.toIso8601String(),
    };
  }

  FeedbackModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    String? type,
    String? title,
    String? message,
    String? status,
    DateTime? createdAt,
    DateTime? resolvedAt,
  }) {
    return FeedbackModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

class FeedbackMetrics {
  final int totalReceived;
  final int totalResolved;
  final int pending;

  const FeedbackMetrics({
    required this.totalReceived,
    required this.totalResolved,
    this.pending = 0,
  });
}

typedef FeedbackMetrics7Days = FeedbackMetrics;
