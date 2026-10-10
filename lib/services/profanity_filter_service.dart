/// Automated profanity filter and bad-word restriction engine.
///
/// Features:
/// - Leetspeak normalization (e.g. "@" -> "a", "$" -> "s", "0" -> "o", "1" -> "i", "3" -> "e")
/// - Word-boundary regex matching to avoid false positives (e.g. "classic" shouldn't trigger "ass")
/// - Nickname length & format validation
class ProfanityFilterService {
  ProfanityFilterService._();

  static final Set<String> _badWords = {
    'damn', 'hell', 'crap', 'bastard', 'bitch', 'shit', 'fuck', 'fck', 'ass', 'asshole',
    'dick', 'piss', 'cunt', 'whore', 'slut', 'fag', 'nigger', 'nigga', 'retard',
    'idiot', 'moron', 'dumbass', 'kill', 'hate', 'nazi', 'hitler', 'porn', 'sex',
  };

  /// Map common leetspeak substitutions to standard characters for inspection
  static String _normalizeLeetspeak(String input) {
    return input
        .toLowerCase()
        .replaceAll('@', 'a')
        .replaceAll('4', 'a')
        .replaceAll('8', 'b')
        .replaceAll('3', 'e')
        .replaceAll('1', 'i')
        .replaceAll('!', 'i')
        .replaceAll('|', 'i')
        .replaceAll('0', 'o')
        .replaceAll(r'$', 's')
        .replaceAll('5', 's')
        .replaceAll('7', 't')
        .replaceAll('+', 't')
        .replaceAll('*', 'u')
        .replaceAll(RegExp(r'[^a-z0-9]'), ''); // strip separators like underscores, dots, hyphens
  }

  /// Checks whether [text] contains prohibited profane or derogatory terms.
  static bool hasProfanity(String text) {
    if (text.trim().isEmpty) return false;

    // 1. Direct word check against tokens
    final tokens = text.toLowerCase().split(RegExp(r'[\s._\-+*!@#$%^&()]+'));
    for (final token in tokens) {
      if (_badWords.contains(token)) {
        return true;
      }
    }

    // 2. Normalized tokens check (each token normalized for leetspeak)
    for (final token in tokens) {
      final normToken = _normalizeLeetspeak(token);
      if (_badWords.contains(normToken)) {
        return true;
      }
    }

    // 3. Explicit profanity substring check
    final normalized = _normalizeLeetspeak(text);
    const explicitBadWords = {
      'bitch', 'shit', 'fuck', 'bastard', 'cunt', 'whore', 'slut',
      'nigger', 'nigga', 'retard', 'dumbass', 'asshole'
    };
    for (final bad in explicitBadWords) {
      if (normalized.contains(bad)) {
        return true;
      }
    }

    return false;
  }

  /// Replaces bad words with asterisks.
  static String cleanText(String text) {
    String result = text;
    for (final bad in _badWords) {
      final pattern = RegExp('\\b$bad\\b', caseSensitive: false);
      result = result.replaceAllMapped(pattern, (m) => '*' * m.group(0)!.length);
    }
    return result;
  }

  /// Validates a chosen nickname against length, character, and profanity constraints.
  /// Returns null if valid, or a descriptive error message if invalid.
  static String? validateNickname(String? nickname) {
    if (nickname == null || nickname.trim().isEmpty) {
      return 'Nickname cannot be empty.';
    }
    final trimmed = nickname.trim();
    if (trimmed.length < 3) {
      return 'Nickname must be at least 3 characters.';
    }
    if (trimmed.length > 20) {
      return 'Nickname cannot exceed 20 characters.';
    }
    if (!RegExp(r'^[a-zA-Z0-9_\- ]+$').hasMatch(trimmed)) {
      return 'Nickname can only contain letters, numbers, spaces, and hyphens.';
    }
    if (hasProfanity(trimmed)) {
      return 'Nickname contains restricted or offensive words. Please choose another.';
    }
    return null;
  }
}
