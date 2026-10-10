class BroadcastAlertModel {
  final String id;
  final String title;
  final String message;
  final String authorName;
  final DateTime createdAt;
  final String priority;
  final List<String> readByUsers;

  const BroadcastAlertModel({
    required this.id,
    required this.title,
    required this.message,
    this.authorName = 'QuickQuiz Admin',
    required this.createdAt,
    this.priority = 'normal',
    this.readByUsers = const [],
  });

  bool isReadBy(String? userId) {
    if (userId == null || userId.isEmpty) return false;
    return readByUsers.contains(userId);
  }

  factory BroadcastAlertModel.fromJson(Map<String, dynamic> json) {
    return BroadcastAlertModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      authorName: json['authorName'] as String? ?? 'QuickQuiz Admin',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      priority: json['priority'] as String? ?? 'normal',
      readByUsers: (json['readByUsers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'authorName': authorName,
      'createdAt': createdAt.toIso8601String(),
      'priority': priority,
      'readByUsers': readByUsers,
    };
  }

  BroadcastAlertModel copyWith({
    String? id,
    String? title,
    String? message,
    String? authorName,
    DateTime? createdAt,
    String? priority,
    List<String>? readByUsers,
  }) {
    return BroadcastAlertModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      authorName: authorName ?? this.authorName,
      createdAt: createdAt ?? this.createdAt,
      priority: priority ?? this.priority,
      readByUsers: readByUsers ?? this.readByUsers,
    );
  }
}
