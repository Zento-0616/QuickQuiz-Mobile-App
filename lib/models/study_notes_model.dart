import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class StudyNoteSection {
  final String heading; // 1. Term / Topic
  final String content; // Retained for backward compatibility
  final String? definition; // 2. Simple Definition
  final String?
      purpose; // 3. Purpose / Function (👉 What is it used for? Why is it important?)
  final List<String> keyPoints; // 4. Key Points (Short bullet points)
  final String?
      example; // 5. Example (Give a simple, real-life or technical example)
  final String? comparison; // 6. Difference / Comparison (when applicable)
  final String? rememberThis; // 7. Remember This ⭐
  final String?
      bottomLine; // MB Format: B - Bottom Line (Core takeaway for exam)
  final String? examQuestion; // 8. Possible Exam Question (Q: ... A: ...)

  const StudyNoteSection({
    required this.heading,
    required this.content,
    this.definition,
    this.purpose,
    this.keyPoints = const [],
    this.example,
    this.comparison,
    this.rememberThis,
    this.bottomLine,
    this.examQuestion,
  });

  factory StudyNoteSection.fromJson(Map<String, dynamic> json) {
    final heading =
        json['heading'] as String? ?? json['term'] as String? ?? 'Key Concept';
    final definition = json['definition'] as String? ?? '';
    final purpose = json['purpose'] as String? ?? '';
    final rawContent = json['content'] as String? ?? '';
    final effectiveContent = rawContent.isNotEmpty
        ? rawContent
        : (definition.isNotEmpty ? definition : '');

    final rawBottomLine = json['bottomLine'] as String? ??
        json['bottom'] as String? ??
        json['rememberThis'] as String? ??
        json['remember'] as String?;

    return StudyNoteSection(
      heading: heading,
      content: effectiveContent,
      definition: definition.isNotEmpty
          ? definition
          : (rawContent.isNotEmpty ? rawContent : null),
      purpose: purpose.isNotEmpty ? purpose : null,
      keyPoints:
          (json['keyPoints'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      example: (json['example'] as String?)?.isNotEmpty == true
          ? json['example'] as String
          : null,
      comparison: (json['comparison'] as String?)?.isNotEmpty == true
          ? json['comparison'] as String
          : null,
      rememberThis: (json['rememberThis'] as String?)?.isNotEmpty == true
          ? json['rememberThis'] as String
          : (json['remember'] as String?)?.isNotEmpty == true
              ? json['remember'] as String
              : rawBottomLine,
      bottomLine: rawBottomLine?.isNotEmpty == true ? rawBottomLine : null,
      examQuestion: (json['examQuestion'] as String?)?.isNotEmpty == true
          ? json['examQuestion'] as String
          : (json['possibleExamQuestion'] as String?)?.isNotEmpty == true
              ? json['possibleExamQuestion'] as String
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'heading': heading,
        'content': content,
        if (definition != null) 'definition': definition,
        if (purpose != null) 'purpose': purpose,
        'keyPoints': keyPoints,
        if (example != null) 'example': example,
        if (comparison != null) 'comparison': comparison,
        if (rememberThis != null) 'rememberThis': rememberThis,
        if (bottomLine != null) 'bottomLine': bottomLine,
        if (examQuestion != null) 'examQuestion': examQuestion,
      };
}

class StudyNoteTerm {
  final String term;
  final String definition;

  const StudyNoteTerm({
    required this.term,
    required this.definition,
  });

  factory StudyNoteTerm.fromJson(Map<String, dynamic> json) {
    return StudyNoteTerm(
      term: json['term'] as String? ?? '',
      definition: json['definition'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'term': term,
        'definition': definition,
      };
}

class StudyNotesModel {
  final String id;
  final String title;
  final String overview;
  final List<StudyNoteSection> sections;
  final List<StudyNoteTerm> glossary;
  final List<String> examTakeaways;
  final List<String> sourceFileNames;
  final DateTime createdAt;

  StudyNotesModel({
    String? id,
    required this.title,
    required this.overview,
    required this.sections,
    this.glossary = const [],
    this.examTakeaways = const [],
    this.sourceFileNames = const [],
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  factory StudyNotesModel.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'] as List? ?? const [];
    final rawGlossary = json['glossary'] as List? ?? const [];
    final rawTakeaways = json['bottomSummary'] as List? ??
        json['bottom'] as List? ??
        json['examTakeaways'] as List? ??
        const [];
    final rawSources = json['sourceFileNames'] as List? ?? const [];

    return StudyNotesModel(
      id: json['id'] as String?,
      title: json['title'] as String? ?? 'Study Notes',
      overview: json['overview'] as String? ?? '',
      sections: rawSections
          .whereType<Map<String, dynamic>>()
          .map((s) => StudyNoteSection.fromJson(s))
          .toList(),
      glossary: rawGlossary
          .whereType<Map<String, dynamic>>()
          .map((g) => StudyNoteTerm.fromJson(g))
          .toList(),
      examTakeaways: rawTakeaways.map((t) => t.toString()).toList(),
      sourceFileNames: rawSources.map((s) => s.toString()).toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'overview': overview,
        'sections': sections.map((s) => s.toJson()).toList(),
        'glossary': glossary.map((g) => g.toJson()).toList(),
        'examTakeaways': examTakeaways,
        'bottomSummary': examTakeaways,
        'sourceFileNames': sourceFileNames,
        'createdAt': createdAt.toIso8601String(),
      };

  /// Formats all notes as clean Markdown text strictly adhering to the MB Note Format (Main & Bottom).
  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# $title');
    if (sourceFileNames.isNotEmpty) {
      buffer.writeln('_Sources: ${sourceFileNames.join(", ")}_');
      buffer.writeln();
    }

    if (overview.isNotEmpty) {
      buffer.writeln('## Executive Overview');
      buffer.writeln(overview);
      buffer.writeln();
    }

    if (sections.isNotEmpty) {
      buffer.writeln('## MB Notes: Main & Bottom Format');
      buffer.writeln();
      for (int i = 0; i < sections.length; i++) {
        final s = sections[i];
        buffer.writeln('### ${i + 1}. ${s.heading}');
        buffer.writeln();

        if (s.definition != null && s.definition!.isNotEmpty) {
          buffer.writeln('**Definition:**');
          buffer.writeln(s.definition);
          buffer.writeln();
        } else if (s.content.isNotEmpty) {
          buffer.writeln('**Definition:**');
          buffer.writeln(s.content);
          buffer.writeln();
        }

        if (s.purpose != null && s.purpose!.isNotEmpty) {
          buffer.writeln('**Purpose / Function:**');
          buffer.writeln('👉 ${s.purpose}');
          buffer.writeln();
        }

        if (s.keyPoints.isNotEmpty) {
          buffer.writeln('**Key Points:**');
          for (final kp in s.keyPoints) {
            buffer.writeln('- $kp');
          }
          buffer.writeln();
        }

        if (s.example != null && s.example!.isNotEmpty) {
          buffer.writeln('**Example:**');
          buffer.writeln(s.example);
          buffer.writeln();
        }

        if (s.comparison != null && s.comparison!.isNotEmpty) {
          buffer.writeln('**Difference / Comparison:**');
          buffer.writeln(s.comparison);
          buffer.writeln();
        }

        if (s.rememberThis != null && s.rememberThis!.isNotEmpty) {
          buffer.writeln('**Remember ⭐:**');
          buffer.writeln(s.rememberThis);
          buffer.writeln();
        } else if (s.bottomLine != null && s.bottomLine!.isNotEmpty) {
          buffer.writeln('**💡 Key Takeaway:**');
          buffer.writeln(s.bottomLine);
          buffer.writeln();
        }

        if (s.examQuestion != null && s.examQuestion!.isNotEmpty) {
          buffer.writeln('**Possible Exam Question:**');
          buffer.writeln(s.examQuestion);
          buffer.writeln();
        }

        buffer.writeln('---');
        buffer.writeln();
      }
    }

    if (glossary.isNotEmpty) {
      buffer.writeln('## Key Definitions & Formulas');
      for (final g in glossary) {
        buffer.writeln('- **${g.term}**: ${g.definition}');
      }
      buffer.writeln();
    }

    if (examTakeaways.isNotEmpty) {
      buffer.writeln('## High-Yield Exam Takeaways');
      for (int i = 0; i < examTakeaways.length; i++) {
        buffer.writeln('${i + 1}. ${examTakeaways[i]}');
      }
      buffer.writeln();
    }

    return buffer.toString().trim();
  }
}
