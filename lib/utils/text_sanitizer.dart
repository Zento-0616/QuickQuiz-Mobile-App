class TextSanitizer {
  static final RegExp _simpleBulletPattern = RegExp(
    r'^[\s\u2022\u25E6\u2023\u2043\u2219\*\-\–\—\:\>\s]+',
  );

  static final RegExp _letterPrefixPattern = RegExp(
    r'^(?:\([A-Da-d0-9]\)|\[[A-Da-d0-9]\]|[A-Da-d0-9][\.\)\:\-])\s+',
  );

  static final RegExp _multiPeriodPattern = RegExp(r'\.{2,}');

  static final RegExp _datePattern = RegExp(
    r'\b(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\.?\s+\d{1,2}(?:\s*[-–—]\s*\d{1,2})?,?\s+\d{2,4}\b',
    caseSensitive: false,
  );

  static final RegExp _numericDatePattern = RegExp(
    r'\b(?:\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}[/-]\d{1,2}[/-]\d{1,2})\b',
  );

  static final RegExp _slideHeaderKeywordPattern = RegExp(
    r'\b(?:OVERVIEW|AGENDA|SUMMARY|CHAPTER|MODULE|LECTURE|SECTION|SLIDE|PAGE|PART|UNIT|COURSE|SYLLABUS)\s*[:\-\d]',
    caseSensitive: false,
  );

  static final RegExp _pageNumberPattern = RegExp(
    r'^(?:page\s+)?\d+\s*(?:of|/)\s*\d+$|^slide\s+\d+$|^\d+$',
    caseSensitive: false,
  );

  static final RegExp _danglingConjunctionPattern = RegExp(
    r'\s+(?:and|or|the|of|for|with|to|in|at|by)\s*[\.\:\-]?$',
    caseSensitive: false,
  );

  static bool isMetadataOrHeader(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return true;

    if (_pageNumberPattern.hasMatch(trimmed)) return true;

    if (trimmed.length < 60 && (_datePattern.hasMatch(trimmed) || _numericDatePattern.hasMatch(trimmed))) {
      return true;
    }

    if (_slideHeaderKeywordPattern.hasMatch(trimmed) && trimmed.length < 80) {
      return true;
    }

    if (trimmed.length < 90 &&
        trimmed == trimmed.toUpperCase() &&
        RegExp(r'[A-Z]{3,}').hasMatch(trimmed) &&
        !trimmed.endsWith('.')) {
      return true;
    }

    if (_danglingConjunctionPattern.hasMatch(trimmed) && trimmed.length < 60) {
      return true;
    }

    return false;
  }

  static String cleanMetadataArtifacts(String text) {
    var cleaned = text;

    cleaned = cleaned.replaceAll(_datePattern, ' ');
    cleaned = cleaned.replaceAll(_numericDatePattern, ' ');

    cleaned = cleaned.replaceAll(
      RegExp(r'\b(?:OVERVIEW|AGENDA|SUMMARY|CHAPTER \d+|SLIDE \d+|PAGE \d+)\s*[:\-]?\s*', caseSensitive: false),
      ' ',
    );

    cleaned = cleaned.replaceAll(_danglingConjunctionPattern, '');

    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    return cleaned;
  }

  static String stripLeadingArtifacts(String text) {
    var cleaned = text.trim();
    if (cleaned.isEmpty) return cleaned;

    if (_letterPrefixPattern.hasMatch(cleaned)) {
      cleaned = cleaned.replaceFirst(_letterPrefixPattern, '').trim();
    }

    if (_simpleBulletPattern.hasMatch(cleaned)) {
      cleaned = cleaned.replaceFirst(_simpleBulletPattern, '').trim();
    }

    cleaned = cleaned.replaceAll(RegExp(r'^[\u2022\u25E6\u2023\u2043\u2219\*\-\–\—]+\s*'), '').trim();

    return cleaned;
  }

  static String cleanDoublePeriods(String text) {
    var cleaned = text.trim();
    if (cleaned.isEmpty) return cleaned;

    cleaned = cleaned.replaceAll(_multiPeriodPattern, '.');

    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\.([A-Z])'),
      (match) => '. ${match.group(1)}',
    );

    return cleaned;
  }

  static String sanitizeText(String text) {
    var cleaned = stripLeadingArtifacts(text);
    cleaned = cleanMetadataArtifacts(cleaned);
    cleaned = cleanDoublePeriods(cleaned);
    return cleaned.trim();
  }

  static String sanitizeQuestion(String question) {
    var cleaned = sanitizeText(question);
    if (cleaned.isEmpty) return cleaned;

    if (!cleaned.endsWith('?') && !cleaned.endsWith('.')) {
      cleaned = '$cleaned?';
    }

    return cleaned;
  }

  static ({List<String> options, int correctAnswerIndex}) deduplicateAndSanitizeOptions({
    required List<String> rawOptions,
    int? rawCorrectAnswerIndex,
    String? rawCorrectAnswerText,
  }) {
    if (rawOptions.isEmpty) {
      return (options: <String>[], correctAnswerIndex: 0);
    }

    String? targetAnswerText = rawCorrectAnswerText?.trim();
    if (targetAnswerText == null &&
        rawCorrectAnswerIndex != null &&
        rawCorrectAnswerIndex >= 0 &&
        rawCorrectAnswerIndex < rawOptions.length) {
      targetAnswerText = rawOptions[rawCorrectAnswerIndex];
    }
    if (targetAnswerText != null) {
      targetAnswerText = sanitizeText(targetAnswerText);
    }

    final sanitizedList = rawOptions.map((o) => sanitizeText(o)).toList();

    while (sanitizedList.length < 4) {
      sanitizedList.add('Alternative evaluation consideration ${sanitizedList.length + 1}');
    }
    final options = sanitizedList.take(4).toList();

    final seen = <String>{};
    int resolvedCorrectIndex = rawCorrectAnswerIndex ?? 0;
    if (resolvedCorrectIndex < 0 || resolvedCorrectIndex >= 4) {
      resolvedCorrectIndex = 0;
    }

    if (targetAnswerText != null && targetAnswerText.isNotEmpty) {
      final matchIdx = options.indexWhere(
        (opt) => opt.toLowerCase() == targetAnswerText!.toLowerCase(),
      );
      if (matchIdx != -1) {
        resolvedCorrectIndex = matchIdx;
      }
    }

    final fallbackAlternatives = [
      'Comprehensive system validation',
      'Minimizing operational overhead',
      'Maintaining structural integrity',
      'Continuous contextual analysis',
      'Standardizing baseline thresholds',
      'Iterative optimization protocol',
    ];

    int fallbackCounter = 0;

    for (int i = 0; i < options.length; i++) {
      final current = options[i];
      final normalized = current.toLowerCase().trim();

      if (normalized.isEmpty || seen.contains(normalized)) {
        if (i == resolvedCorrectIndex) {
          for (int prev = 0; prev < i; prev++) {
            if (options[prev].toLowerCase().trim() == normalized) {
              String replacement = fallbackAlternatives[fallbackCounter % fallbackAlternatives.length];
              fallbackCounter++;
              while (seen.contains(replacement.toLowerCase().trim()) ||
                  options.any((o) => o.toLowerCase().trim() == replacement.toLowerCase().trim())) {
                replacement = '${fallbackAlternatives[fallbackCounter % fallbackAlternatives.length]} (Mode ${fallbackCounter + 1})';
                fallbackCounter++;
              }
              options[prev] = replacement;
              seen.add(replacement.toLowerCase().trim());
            }
          }
          seen.add(normalized);
        } else {
          String replacement = fallbackAlternatives[fallbackCounter % fallbackAlternatives.length];
          fallbackCounter++;
          while (seen.contains(replacement.toLowerCase().trim()) ||
              options.any((o) => o.toLowerCase().trim() == replacement.toLowerCase().trim())) {
            replacement = '${fallbackAlternatives[fallbackCounter % fallbackAlternatives.length]} (Variant ${fallbackCounter + 1})';
            fallbackCounter++;
          }
          options[i] = replacement;
          seen.add(replacement.toLowerCase().trim());
        }
      } else {
        seen.add(normalized);
      }
    }

    if (targetAnswerText != null && targetAnswerText.isNotEmpty) {
      final finalIdx = options.indexWhere(
        (opt) => opt.toLowerCase() == targetAnswerText!.toLowerCase(),
      );
      if (finalIdx != -1) {
        resolvedCorrectIndex = finalIdx;
      }
    }

    return (
      options: options,
      correctAnswerIndex: resolvedCorrectIndex,
    );
  }
}
