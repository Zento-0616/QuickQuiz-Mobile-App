import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class FlashcardModel {
  final String id;
  final String front; // Question, Term, Concept, or Formula Name
  final String back; // Answer, Definition, Explanation, or Formula Details
  final String? hint;
  final String? category;
  final bool isMastered;

  const FlashcardModel({
    required this.id,
    required this.front,
    required this.back,
    this.hint,
    this.category,
    this.isMastered = false,
  });

  FlashcardModel copyWith({
    String? id,
    String? front,
    String? back,
    String? hint,
    String? category,
    bool? isMastered,
  }) {
    return FlashcardModel(
      id: id ?? this.id,
      front: front ?? this.front,
      back: back ?? this.back,
      hint: hint ?? this.hint,
      category: category ?? this.category,
      isMastered: isMastered ?? this.isMastered,
    );
  }

  factory FlashcardModel.fromJson(Map<String, dynamic> json) {
    return FlashcardModel(
      id: json['id'] as String? ?? _uuid.v4(),
      front: json['front'] as String? ?? (json['term'] as String? ?? (json['question'] as String? ?? '')),
      back: json['back'] as String? ?? (json['definition'] as String? ?? (json['answer'] as String? ?? '')),
      hint: json['hint'] as String?,
      category: json['category'] as String?,
      isMastered: json['isMastered'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'front': front,
    'back': back,
    if (hint != null) 'hint': hint,
    if (category != null) 'category': category,
    'isMastered': isMastered,
  };
}

class FlashcardDeckModel {
  final String id;
  final String title;
  final String sourceFileName;
  final List<FlashcardModel> cards;
  final DateTime createdAt;

  FlashcardDeckModel({
    String? id,
    required this.title,
    required this.sourceFileName,
    required this.cards,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  int get cardCount => cards.length;
  int get masteredCount => cards.where((c) => c.isMastered).length;
  double get masteryPercentage => cardCount > 0 ? (masteredCount / cardCount) * 100 : 0.0;

  factory FlashcardDeckModel.fromJson(Map<String, dynamic> json) {
    final rawCards = json['cards'] as List? ?? json['flashcards'] as List? ?? [];
    return FlashcardDeckModel(
      id: json['id'] as String?,
      title: json['title'] as String? ?? json['deckTitle'] as String? ?? 'Study Flashcards',
      sourceFileName: json['sourceFileName'] as String? ?? 'Document',
      cards: rawCards
          .map((c) => FlashcardModel.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'sourceFileName': sourceFileName,
    'cards': cards.map((c) => c.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  FlashcardDeckModel copyWith({
    String? id,
    String? title,
    String? sourceFileName,
    List<FlashcardModel>? cards,
    DateTime? createdAt,
  }) {
    return FlashcardDeckModel(
      id: id ?? this.id,
      title: title ?? this.title,
      sourceFileName: sourceFileName ?? this.sourceFileName,
      cards: cards ?? this.cards,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String toMarkdown() {
    final buffer = StringBuffer('# $title\n\n');
    buffer.writeln('_Generated from: $sourceFileName • Total Cards: ${cardCount}_\n');
    for (int i = 0; i < cards.length; i++) {
      final card = cards[i];
      buffer.writeln('### Card ${i + 1}: ${card.front}');
      buffer.writeln('**Answer / Explanation**: ${card.back}\n');
      if (card.hint != null && card.hint!.isNotEmpty) {
        buffer.writeln('> Hint: ${card.hint}\n');
      }
      buffer.writeln('---\n');
    }
    return buffer.toString();
  }
}
