import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/flashcard_model.dart';
import '../models/question_model.dart';
import '../models/quiz_model.dart';
import '../models/quiz_settings_model.dart';
import '../models/study_notes_model.dart';
import '../utils/constants.dart';
import '../utils/text_sanitizer.dart';

import 'local_storage_service.dart';
import 'question_history_service.dart';

class GeminiApiKeyMissingException implements Exception {
  final String message;
  const GeminiApiKeyMissingException([
    this.message =
        'Google AI Studio API key is missing. Please provide your Gemini API key from https://aistudio.google.com/.',
  ]);
  @override
  String toString() => message;
}

class GeminiGenerationException implements Exception {
  final String message;
  const GeminiGenerationException(this.message);
  @override
  String toString() => message;
}

class DocumentAnalysisResult {
  final String summary;
  final List<String> keyTopics;
  final String detectedSubject;
  final String recommendedDifficulty;

  const DocumentAnalysisResult({
    required this.summary,
    required this.keyTopics,
    required this.detectedSubject,
    required this.recommendedDifficulty,
  });

  factory DocumentAnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawSummary =
        json['summary'] as String? ?? 'Document analysis complete.';
    final rawTopics = json['keyTopics'] as List? ?? const [];
    final rawSubject =
        json['detectedSubject'] as String? ?? 'General Study Material';
    final rawDifficulty = json['recommendedDifficulty'] as String? ?? 'medium';

    final cleanSummary = TextSanitizer.cleanDoublePeriods(rawSummary.trim());
    final cleanTopics = rawTopics
        .map((t) => TextSanitizer.stripLeadingArtifacts(t.toString()))
        .where((t) => t.isNotEmpty)
        .toList();

    return DocumentAnalysisResult(
      summary: cleanSummary,
      keyTopics: cleanTopics,
      detectedSubject: TextSanitizer.stripLeadingArtifacts(rawSubject),
      recommendedDifficulty: rawDifficulty,
    );
  }
}

class GeminiService {
  String? _apiKey;
  final String _modelName;
  final LocalStorageService _storageService;

  static const List<String> _fallbackModels = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
    'gemini-flash-latest',
  ];

  final bool _explicitlyPassedEmptyKey;

  GeminiService({
    String? apiKey,
    String? modelName,
    LocalStorageService? storageService,
  })  : _apiKey = apiKey,
        _explicitlyPassedEmptyKey = apiKey != null && apiKey.trim().isEmpty,
        _modelName =
            modelName ?? _getEnvVar('GEMINI_MODEL') ?? 'gemini-2.5-flash',
        _storageService = storageService ?? LocalStorageService();

  String get modelName => _modelName;

  static String? _getEnvVar(String name) {
    try {
      if (dotenv.isInitialized) {
        return dotenv.env[name];
      }
    } catch (_) {}
    return null;
  }

  Future<String?> getEffectiveApiKey() async {
    final activeProvider = await _storageService.getActiveAiProvider();

    if (_explicitlyPassedEmptyKey) {
      final savedKey =
          await _storageService.getApiKeyForProvider(activeProvider);
      if (savedKey != null && savedKey.trim().isNotEmpty) {
        _apiKey = savedKey.trim();
        return _apiKey;
      }
      return null;
    }

    final savedKey = await _storageService.getApiKeyForProvider(activeProvider);
    if (savedKey != null && savedKey.trim().isNotEmpty) {
      _apiKey = savedKey.trim();
      return _apiKey;
    }

    if (_apiKey != null && _apiKey!.trim().isNotEmpty) {
      return _apiKey!.trim();
    }

    String? envKey;
    switch (activeProvider) {
      case AiProvider.gemini:
        envKey = _getEnvVar('GEMINI_API_KEY') ?? _getEnvVar('GOOGLE_API_KEY');
        break;
      case AiProvider.openAi:
        envKey = _getEnvVar('OPENAI_API_KEY');
        break;
      case AiProvider.deepSeek:
        envKey = _getEnvVar('DEEPSEEK_API_KEY');
        break;
      case AiProvider.grok:
        envKey = _getEnvVar('GROK_API_KEY') ?? _getEnvVar('XAI_API_KEY');
        break;
      case AiProvider.groq:
        envKey = _getEnvVar('GROQ_API_KEY');
        break;
      case AiProvider.anthropic:
        envKey =
            _getEnvVar('ANTHROPIC_API_KEY') ?? _getEnvVar('CLAUDE_API_KEY');
        break;
    }

    if (envKey != null && envKey.trim().isNotEmpty) {
      _apiKey = envKey.trim();
      return _apiKey;
    }
    return null;
  }

  Future<AiProvider> getActiveProvider() async {
    return _storageService.getActiveAiProvider();
  }

  Future<String?> _callOpenAiCompatibleApi({
    required String url,
    required String model,
    required String apiKey,
    required String prompt,
    String? systemPrompt,
    double temperature = 0.7,
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
    );

    final payload = {
      'model': model,
      'messages': [
        if (systemPrompt != null && systemPrompt.isNotEmpty)
          {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': prompt},
      ],
      'response_format': {'type': 'json_object'},
      'max_tokens': 4096,
      'temperature': temperature,
    };

    final response = await dio.post<Map<String, dynamic>>(
      url,
      data: payload,
    );

    if (response.statusCode == 200 && response.data != null) {
      final choices = response.data!['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        final first = choices.first as Map<String, dynamic>;
        final message = first['message'] as Map<String, dynamic>?;
        final content = message?['content'] as String?;
        return content;
      }
    }
    return null;
  }

  Future<String?> _callAnthropicApi({
    required String apiKey,
    required String prompt,
    String? systemPrompt,
    String model = 'claude-3-5-sonnet-20241022',
    double temperature = 0.7,
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
      ),
    );

    final payload = {
      'model': model,
      'max_tokens': 4096,
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        'system': systemPrompt,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
      'temperature': temperature,
    };

    final response = await dio.post<Map<String, dynamic>>(
      'https://api.anthropic.com/v1/messages',
      data: payload,
    );

    if (response.statusCode == 200 && response.data != null) {
      final contentList = response.data!['content'] as List?;
      if (contentList != null && contentList.isNotEmpty) {
        final textParts = <String>[];
        for (final item in contentList) {
          if (item is Map<String, dynamic> && item['type'] == 'text') {
            textParts.add(item['text'] as String? ?? '');
          }
        }
        return textParts.join();
      }
    }
    return null;
  }

  Future<String?> _executeLlmCall({
    required AiProvider provider,
    required String apiKey,
    required String prompt,
    String? systemPrompt,
    double temperature = 0.7,
  }) async {
    if (provider == AiProvider.anthropic) {
      return _callAnthropicApi(
        apiKey: apiKey,
        prompt: prompt,
        systemPrompt: systemPrompt,
        temperature: temperature,
      );
    }

    String url;
    String model;
    switch (provider) {
      case AiProvider.openAi:
        url = 'https://api.openai.com/v1/chat/completions';
        model = 'gpt-4o-mini';
        break;
      case AiProvider.deepSeek:
        url = 'https://api.deepseek.com/chat/completions';
        model = 'deepseek-chat';
        break;
      case AiProvider.grok:
        url = 'https://api.x.ai/v1/chat/completions';
        model = 'grok-2';
        break;
      case AiProvider.groq:
        url = 'https://api.groq.com/openai/v1/chat/completions';
        model = 'llama-3.3-70b-versatile';
        break;
      case AiProvider.gemini:
      case AiProvider.anthropic:
        return null;
    }

    return _callOpenAiCompatibleApi(
      url: url,
      model: model,
      apiKey: apiKey,
      prompt: prompt,
      systemPrompt: systemPrompt,
      temperature: temperature,
    );
  }

  Future<bool> get isConfiguredAsync async {
    final key = await getEffectiveApiKey();
    return key != null && key.isNotEmpty;
  }

  bool get isConfigured {
    if (_apiKey != null && _apiKey!.trim().isNotEmpty) return true;
    final envKey = _getEnvVar('GEMINI_API_KEY') ?? _getEnvVar('GOOGLE_API_KEY');
    return envKey != null && envKey.trim().isNotEmpty;
  }

  void setApiKey(String key) {
    _apiKey = key.trim();
  }

  Future<DocumentAnalysisResult> analyzeDocument(String documentText) async {
    final key = await getEffectiveApiKey();
    if (key == null || key.isEmpty) {
      return _buildLocalAnalysisFallback(documentText);
    }

    final cleanedDoc = TextSanitizer.cleanMetadataArtifacts(documentText);
    final truncatedText =
        cleanedDoc.length > 8000 ? cleanedDoc.substring(0, 8000) : cleanedDoc;

    const prompt = '''
You are an expert academic curriculum analyzer. Read the provided study text and extract an analytical overview.
CRITICAL: Ignore page numbers, course headers, slide dates, and administrative footers.
Focus strictly on core technical and conceptual knowledge.
Do not use bullet points or artifact symbols. Return a strictly valid JSON object matching this schema:
{
  "summary": "2-3 concise, professional sentences summarizing the educational core of the material",
  "keyTopics": ["Topic 1", "Topic 2", "Topic 3", "Topic 4"],
  "detectedSubject": "Academic domain or subject area (e.g., Computer Science, Organic Chemistry, Economics)",
  "recommendedDifficulty": "easy" or "medium" or "hard"
}
''';

    final provider = await getActiveProvider();
    if (provider != AiProvider.gemini) {
      try {
        final jsonText = await _executeLlmCall(
          provider: provider,
          apiKey: key,
          prompt: '$prompt\n\nSTUDY TEXT:\n$truncatedText',
          systemPrompt:
              'You are an expert academic curriculum analyzer. Respond strictly in valid JSON.',
          temperature: 0.2,
        );
        if (jsonText != null && jsonText.trim().isNotEmpty) {
          final cleanJson = _extractJson(jsonText);
          final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;
          return DocumentAnalysisResult.fromJson(decoded);
        }
      } catch (e) {
        debugPrint('[AiService] ${provider.displayName} analysis failed: $e');
      }
      return _buildLocalAnalysisFallback(documentText);
    }

    final modelsToTry = [
      _modelName,
      ..._fallbackModels.where((m) => m != _modelName),
    ];

    for (final candidateModel in modelsToTry) {
      try {
        final model = GenerativeModel(
          model: candidateModel,
          apiKey: key,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.2,
            maxOutputTokens: 600,
          ),
        );
        final response = await model.generateContent([
          Content.text('$prompt\n\nSTUDY TEXT:\n$truncatedText'),
        ]).timeout(const Duration(seconds: 8));

        final text = response.text;
        if (text != null && text.trim().isNotEmpty) {
          final cleanJson = _extractJson(text);
          final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;
          return DocumentAnalysisResult.fromJson(decoded);
        }
      } catch (e) {
        debugPrint(
            '[GeminiService] Model $candidateModel failed for document analysis: $e');
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }

    return _buildLocalAnalysisFallback(documentText);
  }

  Future<QuizModel> generateQuiz({
    required String documentText,
    required String sourceFileName,
    required int questionCount,
    required QuizDifficulty difficulty,
  }) async {
    final key = await getEffectiveApiKey();
    if (key == null || key.isEmpty) {
      throw const GeminiApiKeyMissingException(
        'Google AI Studio API key not found. Please provide your Gemini API key from https://aistudio.google.com/ to analyze documents and generate real MCQs.',
      );
    }

    final cleanedDoc = TextSanitizer.cleanMetadataArtifacts(documentText);
    final truncated =
        cleanedDoc.length > 14000 ? cleanedDoc.substring(0, 14000) : cleanedDoc;

    final historyService = QuestionHistoryService();
    final previousStems =
        await historyService.getPreviousQuestionStems(sourceFileName);

    final lenses = [
      'Focus primarily on operational mechanisms, practical cause-and-effect scenarios, and troubleshooting applications.',
      'Focus on formal definitions, fundamental axioms, formula relationships, and key terminology.',
      'Focus on comparative distinctions, contrasting opposing concepts, edge cases, and subtle distinctions.',
      'Sample and synthesize concepts from the middle and concluding sections of the material, exploring advanced implications.',
      'Focus on real-world case scenarios, practical problem solving, and system architectures.'
    ];
    final randomLens = lenses[Random().nextInt(lenses.length)];

    final avoidSection = previousStems.isNotEmpty
        ? '''
CRITICAL NON-REPETITION CONSTRAINT:
The user has previously generated and taken quizzes on this study material. You MUST NOT generate duplicate or closely rephrased questions on the same specific facts as these previous questions:
${previousStems.take(25).map((s) => '- $s').join('\n')}
You MUST generate completely fresh, new questions exploring unasked aspects, alternative definitions, formulas, or mechanisms from the study material!
'''
        : '';

    final multiFileInstruction = cleanedDoc.contains('=== SOURCE FILE')
        ? '''
MULTI-FILE BALANCED DISTRIBUTION REQUIREMENT:
The study material combines multiple source files (demarcated by === SOURCE FILE N: ... ===).
You MUST randomly sample questions evenly across ALL provided source files rather than focusing only on the first file!
'''
        : '';

    final randomVariation =
        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999999)}';

    final isHardDifficulty = difficulty == QuizDifficulty.hard;
    final prompt = isHardDifficulty
        ? '''
You are an expert university professor and senior exam writer.
Generate $questionCount completely distinct, rigorous exam questions grounded in the provided study material.
Target Difficulty: HARD.
Randomization Variation Seed: $randomVariation
Pedagogical Lens: $randomLens

$avoidSection
$multiFileInstruction

CRITICAL HARD DIFFICULTY REQUIREMENTS:
1. MIX OF QUESTION TYPES: Generate a balanced mix of:
   - Multiple Choice Questions (MCQ): Set "type": "multiple_choice". Exactly 4 options.
   - Fill-in-the-Blank Questions: Set "type": "fill_in_the_blank". The question stem MUST represent the missing concept or term with "______" (six underscores). Example: "In distributed computing, the ______ theorem states that it is impossible for a distributed data store to simultaneously provide more than two out of Consistency, Availability, and Partition tolerance."
2. DEEPER UNDERSTANDING: Questions MUST require deeper conceptual understanding, critical analysis, and synthesis of principles. Under NO circumstances should questions simply copy-paste verbatim sentences from the uploaded files.
3. FOCUS FOR FILL-IN-THE-BLANK: Fill-in-the-blank questions must focus on important terms, concepts, definitions, formulas, and key technical information found in the source material.
4. For Fill-in-the-blank questions:
   - "correctAnswer": Exact core term or formula.
   - "acceptableAnswers": Array of acceptable synonyms, common abbreviations, or alternate spellings (e.g. ["CAP", "CAP theorem"]).
   - "options": 4 plausible related terms (can be used for hints).
5. NEVER cite or mention the source ("According to the text", "As stated in the PPT", etc.).
6. Provide an educational explanation for every question explaining why the answer is valid.
7. Randomly position the correct choice among options.

Return a STRICT JSON object matching this schema:
{
  "questions": [
    {
      "type": "multiple_choice" or "fill_in_the_blank",
      "question": "Question stem ending with a question mark, or containing ______ for fill-in-the-blank?",
      "options": [
        "First plausible option",
        "Second plausible option",
        "Third plausible option",
        "Fourth plausible option"
      ],
      "correctAnswer": "Exact matching text of the correct choice or term",
      "acceptableAnswers": ["Alternative accepted spelling/alias if fill_in_the_blank"],
      "explanation": "Concise academic explanation stating the conceptual foundation.",
      "hint": "A subtle educational clue or guiding hint."
    }
  ]
}

STUDY MATERIAL:
$truncated
'''
        : '''
You are an expert university professor and professional exam writer.
Generate $questionCount completely distinct, non-repeated multiple-choice questions (MCQs) grounded in the provided study material.
Target Difficulty: ${difficulty.name.toUpperCase()}.
Randomization Variation Seed: $randomVariation
Pedagogical Lens: $randomLens

$avoidSection
$multiFileInstruction

CRITICAL REQUIREMENTS:
1. NEVER cite or mention the source ("According to the text", "As stated in the PPT", etc.). The student must feel like they are in a real academic examination.
2. STRICT DIVERSITY & ZERO REPETITION: Every question must test a completely distinct concept, mechanism, or principle from the document. Under NO circumstances should questions test the same concept or repeat question phrasing.
3. FULL-DOCUMENT RANDOM SAMPLING: Sample questions randomly and evenly from the beginning, middle, and end of the document. Do not cluster questions around the first section.
4. DIVERSE MCQ QUESTION STYLES: Vary question types across conceptual definitions, cause-and-effect scenarios, operational mechanisms, comparative distinctions, and practical troubleshooting.
5. CONCISE OPTIONS & SINGLE-WORD ANSWERS:
   - Do NOT always use long, wordy sentences for options!
   - For questions testing terminology, definitions, concepts, components, acronyms, formulas, classification, or identification: options SHOULD BE CONCISE: single words (e.g. "Mitochondria", "Polymorphism", "Encapsulation", "TCP", "Ribosome", "Photosynthesis", "Scalar") or short 2-4 word terms.
   - For questions testing complex scenarios, case analyses, or multi-step reasoning: options may be short phrases or sentences.
   - Across the generated quiz, include a strong proportion of single-word or short-term option questions!
6. Do NOT include bullet points, dashes, or numbering inside the question stem or options (no "•", "*", "1.", "A)").
7. Ensure all 4 options are completely distinct and mutually exclusive.
8. Provide a clear, educational explanation stating why the correct answer is valid.
9. FILTER OUT HEADERS, FOOTERS & METADATA: Ignore page numbers, course headers, slide dates (e.g., 'October 16 - 21, 2025'), syllabus information, slide titles, and administrative footers. Do NOT copy-paste raw document headers or fragmented slide titles into question stems, answer options, or explanations.
10. CONTEXTUAL QUESTION GENERATION: Extract only core academic concepts, definitions, and technical logic from the document body.
11. PARALLEL OPTION STRUCTURE: Ensure all 4 options for any given question share parallel grammatical structure and roughly equal length (e.g. if the answer is a single word like "Entropy", all 4 options must be single words like "Entropy", "Enthalpy", "Temperature", "Pressure").
12. RANDOMIZED CORRECT ANSWER DISTRIBUTION: Randomly distribute the correct answer across positions A, B, C, and D. NEVER default solely or repeatedly to option A.
13. STRICT JSON ESCAPING: Ensure all string values are strictly valid JSON. Always escape any inner quotes with \\" and never put raw unescaped newlines inside string values.

STRUCTURED QUESTION EXAMPLES:
Example 1 (Concise single-word options):
Which cellular organelle is primarily responsible for ATP synthesis through cellular respiration?
A. Mitochondria
B. Ribosome
C. Golgi apparatus
D. Lysosome

Example 2 (Short phrase options):
What is the primary role of the Transport Layer in the OSI network model?
A. Routing packets across disparate networks
B. Providing end-to-end communication and reliability
C. Physical bit transmission over cables
D. Data representation and syntax formatting

Return a STRICT JSON object matching this schema:
{
  "questions": [
    {
      "type": "multiple_choice",
      "question": "Clear, balanced multiple-choice question stem ending with a question mark?",
      "options": [
        "First plausible, complete option choice",
        "Second plausible, complete option choice",
        "Third plausible, complete option choice",
        "Fourth plausible, complete option choice"
      ],
      "correctAnswer": "Exact matching text of the correct choice (randomly positioned among the 4 options)",
      "explanation": "Concise academic explanation stating the conceptual foundation.",
      "hint": "A subtle educational clue or guiding hint to help solve the question without directly revealing the correct answer choice."
    }
  ]
}

STUDY MATERIAL:
$truncated
''';

    final provider = await getActiveProvider();
    if (provider != AiProvider.gemini) {
      try {
        debugPrint(
            '[AiService] Calling ${provider.displayName} (${provider.modelName})...');
        final jsonText = await _executeLlmCall(
          provider: provider,
          apiKey: key,
          prompt: prompt,
          systemPrompt:
              'You are an expert exam writer. You must respond strictly with a valid JSON object matching the requested schema.',
          temperature: 0.7,
        );
        if (jsonText != null && jsonText.trim().isNotEmpty) {
          final cleanJson = _extractAndRepairJson(jsonText);
          final quiz = await _buildQuizFromCleanJson(
            cleanJson: cleanJson,
            rawText: jsonText,
            sourceFileName: sourceFileName,
            difficulty: difficulty,
            questionCount: questionCount,
            historyService: historyService,
          );
          if (quiz != null && quiz.questions.isNotEmpty) {
            return quiz;
          }
        }
      } catch (e) {
        debugPrint(
            '[AiService] ${provider.displayName} quiz generation failed: $e');
      }

      if (documentText.trim().length >= 10) {
        debugPrint(
            '[AiService] ${provider.displayName} failed. Falling back to local document synthesis...');
        return _buildLocalQuizFallback(
          documentText: documentText,
          sourceFileName: sourceFileName,
          questionCount: questionCount,
          difficulty: difficulty,
        );
      }
      throw GeminiGenerationException(
          'Failed to generate quiz with ${provider.displayName}');
    }

    final modelsToTry = [
      _modelName,
      ..._fallbackModels.where((m) => m != _modelName),
    ];

    Object? lastError;

    for (var i = 0; i < modelsToTry.length; i++) {
      final candidateModel = modelsToTry[i];
      try {
        debugPrint(
            '[GeminiService] Calling Google AI Studio with model: $candidateModel');
        final currentModel = GenerativeModel(
          model: candidateModel,
          apiKey: key,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.7,
            topP: 0.9,
            maxOutputTokens: 8192,
          ),
        );
        final response =
            await currentModel.generateContent([Content.text(prompt)]);
        final text = response.text;
        if (text == null || text.trim().isEmpty) {
          debugPrint(
              '[GeminiService] Model $candidateModel returned empty text. Trying next model...');
          continue;
        }

        final cleanJson = _extractAndRepairJson(text);
        final quiz = await _buildQuizFromCleanJson(
          cleanJson: cleanJson,
          rawText: text,
          sourceFileName: sourceFileName,
          difficulty: difficulty,
          questionCount: questionCount,
          historyService: historyService,
        );

        if (quiz != null && quiz.questions.isNotEmpty) {
          debugPrint(
              '[GeminiService] Successfully generated ${quiz.questions.length} questions with $candidateModel');
          return quiz;
        } else {
          debugPrint(
              '[GeminiService] Model $candidateModel produced 0 valid questions. Trying next model...');
        }
      } catch (e) {
        lastError = e;
        final errorStr = e.toString();
        debugPrint('[GeminiService] Model $candidateModel failed: $e');

        final match =
            RegExp(r'models/([a-zA-Z0-9\.\-_]+)').firstMatch(errorStr);
        if (match != null) {
          final suggested = match.group(1);
          if (suggested != null && !modelsToTry.contains(suggested)) {
            debugPrint(
                '[GeminiService] Dynamically queued suggested model from API: $suggested');
            modelsToTry.add(suggested);
          }
        }

        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    if (documentText.trim().length >= 10) {
      debugPrint(
          '[GeminiService] All Gemini models exhausted or malformed output ($lastError). Falling back to intelligent local document synthesis...');
      return _buildLocalQuizFallback(
        documentText: documentText,
        sourceFileName: sourceFileName,
        questionCount: questionCount,
        difficulty: difficulty,
      );
    }

    throw GeminiGenerationException(
      _formatErrorMessage(lastError ??
          'All supported Gemini models failed to generate content.'),
    );
  }

  Future<QuizModel?> _buildQuizFromCleanJson({
    required String cleanJson,
    String? rawText,
    required String sourceFileName,
    required QuizDifficulty difficulty,
    required int questionCount,
    required QuestionHistoryService historyService,
  }) async {
    List<dynamic> rawQuestions = [];
    try {
      final decoded = jsonDecode(cleanJson);
      if (decoded is Map<String, dynamic>) {
        rawQuestions = decoded['questions'] as List? ?? const [];
      } else if (decoded is List) {
        rawQuestions = decoded;
      }
    } catch (e) {
      debugPrint(
          '[AiService] Direct jsonDecode failed after repair: $e. Attempting question extraction...');
    }

    if (rawQuestions.isEmpty) {
      final extracted = _extractQuestionObjects(cleanJson);
      if (extracted.isNotEmpty) {
        rawQuestions = extracted;
      } else if (rawText != null && rawText != cleanJson) {
        final extractedFromRaw = _extractQuestionObjects(rawText);
        if (extractedFromRaw.isNotEmpty) {
          rawQuestions = extractedFromRaw;
        }
      }
    }

    if (rawQuestions.isEmpty) {
      debugPrint('[AiService] No question objects found in response.');
      return null;
    }

    final questions = <QuestionModel>[];
    final seenStems = <String>{};

    for (final q in rawQuestions) {
      if (q is Map<String, dynamic>) {
        try {
          final parsed = QuestionModel.fromJson(q).randomizeAnswers();
          final stemKey = QuestionHistoryService.normalizeStem(parsed.question);
          if (stemKey.isNotEmpty && !seenStems.contains(stemKey)) {
            seenStems.add(stemKey);
            questions.add(parsed);
          }
        } catch (e) {
          debugPrint('[AiService] Skipped malformed question: $e');
        }
      }
    }

    if (questions.isEmpty) {
      debugPrint(
          '[AiService] No valid questions could be formed from raw questions.');
      return null;
    }

    final freshQuestions = <QuestionModel>[];
    for (final q in questions) {
      if (!historyService.isDuplicate(sourceFileName, q.question)) {
        freshQuestions.add(q);
      }
    }
    final finalQuestions = freshQuestions.length >= (questionCount / 2).ceil()
        ? freshQuestions
        : questions;

    finalQuestions.shuffle(Random());

    await historyService.recordGeneratedQuestions(
      sourceFileName,
      finalQuestions.map((q) => q.question).toList(),
    );

    return QuizModel(
      sourceFileName: sourceFileName,
      difficulty: difficulty,
      questions: finalQuestions,
      createdAt: DateTime.now(),
    );
  }

  Future<QuestionModel> regenerateSingleQuestion({
    required String documentText,
    required QuestionModel oldQuestion,
    required QuizDifficulty difficulty,
    List<String> existingQuestionStems = const [],
  }) async {
    final key = await getEffectiveApiKey();
    if (key == null || key.isEmpty) {
      throw const GeminiApiKeyMissingException();
    }

    final cleanedDoc = TextSanitizer.cleanMetadataArtifacts(documentText);
    final truncated =
        cleanedDoc.length > 25000 ? cleanedDoc.substring(0, 25000) : cleanedDoc;

    final existingList =
        existingQuestionStems.take(15).map((s) => '- $s').join('\n');
    final randomVariation =
        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';

    final prompt = '''
You are an expert university professor and exam reviewer.
Generate EXACTLY 1 new, fresh multiple-choice question (MCQ) grounded in the study material.
Target Difficulty: ${difficulty.name.toUpperCase()}.
Randomization Seed: $randomVariation

PREVIOUS QUESTION TO REPLACE:
"${oldQuestion.question}"

EXISTING QUESTIONS ALREADY IN THE QUIZ (DO NOT REPEAT OR COVER THE SAME TOPIC AS THESE):
$existingList

CRITICAL REQUIREMENTS:
1. Never cite or mention the source ("According to the text", etc.).
2. Generate a completely fresh concept different from the question being replaced and all existing questions.
3. Exactly 4 options (A, B, C, D) with parallel word lengths (6-16 words).
4. No bullet points or numbering in the stem or options.
5. Randomize the correct answer position among the 4 choices.

Return a STRICT JSON object matching this schema:
{
  "questions": [
    {
      "question": "Clear, balanced multiple-choice question stem ending with a question mark?",
      "options": [
        "First plausible option",
        "Second plausible option",
        "Third plausible option",
        "Fourth plausible option"
      ],
      "correctAnswer": "Exact text of the correct choice",
      "explanation": "Concise academic explanation.",
      "hint": "Subtle educational hint."
    }
  ]
}

STUDY MATERIAL:
$truncated
''';

    final modelsToTry = [
      _modelName,
      ..._fallbackModels.where((m) => m != _modelName),
    ];

    for (final candidate in modelsToTry) {
      try {
        final currentModel = GenerativeModel(
          model: candidate,
          apiKey: key,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.9,
          ),
        );
        final resp = await currentModel.generateContent([Content.text(prompt)]);
        if (resp.text != null && resp.text!.trim().isNotEmpty) {
          final cleanJson = _extractJson(resp.text!);
          final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;
          final rawQuestions = decoded['questions'] as List? ?? const [];
          if (rawQuestions.isNotEmpty &&
              rawQuestions.first is Map<String, dynamic>) {
            return QuestionModel.fromJson(
                    rawQuestions.first as Map<String, dynamic>)
                .randomizeAnswers();
          }
        }
      } catch (e) {
        debugPrint(
            '[GeminiService] Single question regeneration attempt failed on $candidate: $e');
      }
    }

    throw const GeminiGenerationException(
        'Failed to regenerate single question with Google AI Studio.');
  }

  String _formatErrorMessage(Object error) {
    final msg = error.toString();
    if (msg.contains('Your project has been denied access') ||
        msg.contains('PERMISSION_DENIED') ||
        msg.contains('API_KEY_SERVICE_BLOCKED') ||
        msg.contains('403')) {
      return 'Google AI Studio Access Error (403): Your project was denied access or lacks Gemini permissions. Please ensure the Gemini API is enabled in your Google AI Studio project, or create a fresh API key at https://aistudio.google.com/.';
    }
    if (msg.contains('Quota exceeded') ||
        msg.contains('quota') ||
        msg.contains('Quota') ||
        msg.contains('rate-limits') ||
        msg.contains('rate limit') ||
        msg.contains('RESOURCE_EXHAUSTED') ||
        msg.contains('429')) {
      final retryMatch = RegExp(r'retry in ([0-9\.]+)s').firstMatch(msg);
      final waitSec = retryMatch != null
          ? ' Please retry in ${double.tryParse(retryMatch.group(1) ?? '')?.ceil() ?? 45} seconds.'
          : ' Please wait a moment before retrying.';
      return 'Google AI Studio Quota Exceeded (429): Free tier limit of 20 requests was reached.$waitSec You can tap "Set Key" or the key icon 🔑 above to enter a new API key, or use offline quiz generation.';
    }
    if (msg.contains('503') ||
        msg.contains('high demand') ||
        msg.contains('UNAVAILABLE')) {
      return 'Google AI Studio Server Busy (503): The AI model is currently experiencing temporary high demand. Please try generating again in a few moments.';
    }
    if (msg.contains('no longer available') ||
        msg.contains('not found') ||
        msg.contains('404')) {
      return 'Google AI Studio Model Error: The requested model is no longer available. QuickQuiz automatically upgrades to gemini-2.5-flash.';
    }
    if (msg.contains('API_KEY_INVALID') || msg.contains('400')) {
      return 'Invalid Google AI Studio API key (400). Please verify your key at https://aistudio.google.com/.';
    }
    if (msg.contains('RESOURCE_EXHAUSTED') || msg.contains('429')) {
      return 'Google AI Studio rate limit exceeded (429). Please wait a moment before generating again.';
    }
    return 'Google AI Studio error: $error';
  }

  String _extractJson(String raw) => _extractAndRepairJson(raw);

  String _extractAndRepairJson(String raw) {
    var text = raw.trim();

    final codeBlockRegex =
        RegExp(r'```(?:json)?\s*([\s\S]*?)(?:```|$)', caseSensitive: false);
    final match = codeBlockRegex.firstMatch(text);
    if (match != null &&
        match.group(1) != null &&
        match.group(1)!.trim().isNotEmpty) {
      text = match.group(1)!.trim();
    }

    final firstCurly = text.indexOf('{');
    final firstSquare = text.indexOf('[');
    int startIdx = -1;
    if (firstCurly != -1 && firstSquare != -1) {
      startIdx = firstCurly < firstSquare ? firstCurly : firstSquare;
    } else if (firstCurly != -1) {
      startIdx = firstCurly;
    } else if (firstSquare != -1) {
      startIdx = firstSquare;
    }

    if (startIdx > 0) {
      text = text.substring(startIdx);
    }

    try {
      jsonDecode(text);
      return text;
    } catch (_) {}

    final buffer = StringBuffer();
    bool inString = false;
    bool escaped = false;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];

      if (escaped) {
        buffer.write(char);
        escaped = false;
        continue;
      }

      if (char == '\\') {
        buffer.write(char);
        escaped = true;
        continue;
      }

      if (char == '"') {
        inString = !inString;
        buffer.write(char);
        continue;
      }

      if (inString) {
        if (char == '\n') {
          buffer.write(r'\n');
        } else if (char == '\r') {
        } else if (char == '\t') {
          buffer.write(r'\t');
        } else {
          buffer.write(char);
        }
      } else {
        buffer.write(char);
      }
    }

    var sanitized = buffer.toString();

    sanitized =
        sanitized.replaceAllMapped(RegExp(r',\s*([\]}])'), (m) => m.group(1)!);

    try {
      jsonDecode(sanitized);
      return sanitized;
    } catch (_) {}

    final openStack = <String>[];
    bool inStr = false;
    bool isEsc = false;

    for (int i = 0; i < sanitized.length; i++) {
      final c = sanitized[i];
      if (isEsc) {
        isEsc = false;
        continue;
      }
      if (c == '\\') {
        isEsc = true;
        continue;
      }
      if (c == '"') {
        inStr = !inStr;
        continue;
      }
      if (!inStr) {
        if (c == '{') {
          openStack.add('}');
        } else if (c == '[') {
          openStack.add(']');
        } else if (c == '}' || c == ']') {
          if (openStack.isNotEmpty && openStack.last == c) {
            openStack.removeLast();
          }
        }
      }
    }

    final repairBuffer = StringBuffer(sanitized);
    if (inStr) {
      repairBuffer.write('"');
    }

    var repaired = repairBuffer.toString().replaceAll(RegExp(r',\s*$'), '');

    while (openStack.isNotEmpty) {
      final closer = openStack.removeLast();
      repaired = repaired.replaceAll(RegExp(r',\s*$'), '') + closer;
    }

    try {
      jsonDecode(repaired);
      return repaired;
    } catch (_) {}

    return sanitized;
  }

  List<Map<String, dynamic>> _extractQuestionObjects(String raw) {
    final results = <Map<String, dynamic>>[];

    final arrayStartMatch = RegExp(r'"questions"\s*:\s*\[').firstMatch(raw);
    final int searchStart = arrayStartMatch != null ? arrayStartMatch.end : 0;
    final String arrayContent = raw.substring(searchStart);

    int i = 0;
    while (i < arrayContent.length) {
      if (arrayContent[i] == '{') {
        int braceDepth = 1;
        int j = i + 1;
        bool inString = false;
        bool escaped = false;

        while (j < arrayContent.length && braceDepth > 0) {
          final c = arrayContent[j];
          if (escaped) {
            escaped = false;
            j++;
            continue;
          }
          if (c == '\\') {
            escaped = true;
            j++;
            continue;
          }
          if (c == '"') {
            inString = !inString;
          } else if (!inString) {
            if (c == '{') braceDepth++;
            if (c == '}') braceDepth--;
          }
          j++;
        }

        if (braceDepth == 0) {
          final candidate = arrayContent.substring(i, j);
          try {
            final obj = jsonDecode(candidate);
            if (obj is Map<String, dynamic> && obj.containsKey('question')) {
              results.add(obj);
            }
          } catch (_) {
            try {
              final fixed = _extractAndRepairJson(candidate);
              final obj = jsonDecode(fixed);
              if (obj is Map<String, dynamic> && obj.containsKey('question')) {
                results.add(obj);
              }
            } catch (_) {}
          }
          i = j;
          continue;
        }
      }
      i++;
    }

    return results;
  }

  DocumentAnalysisResult _buildLocalAnalysisFallback(String text) {
    final words = text.split(RegExp(r'\s+'));
    final wordCount = words.length;

    final titleCaseRegExp = RegExp(r'\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2}\b');
    final terms = <String>{};
    for (final m in titleCaseRegExp.allMatches(text)) {
      final t = m.group(0)?.trim();
      if (t != null && t.length > 3 && t.length < 30) {
        terms.add(TextSanitizer.stripLeadingArtifacts(t));
      }
      if (terms.length >= 4) break;
    }

    final topics = terms.isNotEmpty
        ? terms.toList()
        : ['Foundational Concepts', 'System Architecture', 'Core Principles'];

    return DocumentAnalysisResult(
      summary:
          'Analyzed study material containing $wordCount words across primary key subject domains.',
      keyTopics: topics,
      detectedSubject: topics.first,
      recommendedDifficulty: 'medium',
    );
  }

  QuizModel _buildLocalQuizFallback({
    required String documentText,
    required String sourceFileName,
    required int questionCount,
    required QuizDifficulty difficulty,
  }) {
    final cleaned = TextSanitizer.cleanMetadataArtifacts(documentText);
    final paragraphs = cleaned
        .split(RegExp(r'\n{2,}|\r\n{2,}'))
        .map((p) => p.trim())
        .where((p) => p.length > 25)
        .toList();

    final titleCaseRegExp = RegExp(r'\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2}\b');
    final termsSet = <String>{};
    for (final m in titleCaseRegExp.allMatches(cleaned)) {
      final t = m.group(0)?.trim();
      if (t != null && t.length > 3 && t.length < 35) {
        final clean = TextSanitizer.stripLeadingArtifacts(t);
        if (clean.isNotEmpty) termsSet.add(clean);
      }
    }
    final terms = termsSet.toList();

    final sentences = <String>[];
    for (final p in paragraphs) {
      for (final s in p.split(RegExp(r'(?<=[.!?])\s+'))) {
        final trimmed = s.trim();
        if (trimmed.length > 30 &&
            trimmed.length < 180 &&
            !trimmed.contains('\n')) {
          sentences.add(trimmed);
        }
      }
    }

    final questions = <QuestionModel>[];
    final random = Random();

    for (int i = 0; i < questionCount; i++) {
      final term =
          terms.isNotEmpty ? terms[i % terms.length] : 'Core Concept ${i + 1}';

      if (sentences.isNotEmpty && i % 2 == 0) {
        final sentence = sentences[i % sentences.length];
        final otherSentences = sentences.where((s) => s != sentence).toList()
          ..shuffle(random);
        final distractor1 = otherSentences.isNotEmpty
            ? otherSentences[0]
            : 'It operates independently without system interaction.';
        final distractor2 = otherSentences.length > 1
            ? otherSentences[1]
            : 'It directly contradicts the fundamental model.';
        final distractor3 = otherSentences.length > 2
            ? otherSentences[2]
            : 'It is exclusively applied in obsolete legacy contexts.';

        final options = [sentence, distractor1, distractor2, distractor3];
        options.shuffle(random);
        final correctIdx = options.indexOf(sentence);

        questions.add(
          QuestionModel(
            id: 'local_q_${i + 1}',
            question:
                'According to $sourceFileName, which statement accurately reflects the principles of "$term"?',
            options: options,
            correctAnswerIndex: correctIdx,
            explanation: 'Grounded in the study material: "$sentence"',
            category: term,
            difficulty: difficulty,
            hint:
                'Recall the specific operational description from the source file.',
          ),
        );
      } else {
        final otherTerms = terms.where((t) => t != term).toList()
          ..shuffle(random);
        final distractor1 =
            otherTerms.isNotEmpty ? otherTerms[0] : 'Heuristic Calibration';
        final distractor2 =
            otherTerms.length > 1 ? otherTerms[1] : 'Dynamic Allocation';
        final distractor3 =
            otherTerms.length > 2 ? otherTerms[2] : 'Sequential Validation';

        final options = [term, distractor1, distractor2, distractor3];
        options.shuffle(random);
        final correctIdx = options.indexOf(term);

        questions.add(
          QuestionModel(
            id: 'local_q_${i + 1}',
            question:
                'Which fundamental concept from the study guide is primarily highlighted in relation to "$term"?',
            options: options,
            correctAnswerIndex: correctIdx,
            explanation:
                '"$term" is identified throughout the material as a primary conceptual driver.',
            category: term,
            difficulty: difficulty,
            hint: 'Focus on core definitions and high-yield vocabulary.',
          ),
        );
      }
    }

    return QuizModel(
      sourceFileName: sourceFileName,
      difficulty: difficulty,
      questions: questions,
      timeLimitSeconds: QuizSettingsModel.calculateTimeLimitInSeconds(
          questionCount, difficulty),
      createdAt: DateTime.now(),
    );
  }

  QuizModel buildLocalQuizFallback({
    required String documentText,
    required String sourceFileName,
    required int questionCount,
    required QuizDifficulty difficulty,
  }) =>
      _buildLocalQuizFallback(
        documentText: documentText,
        sourceFileName: sourceFileName,
        questionCount: questionCount,
        difficulty: difficulty,
      );

  Future<StudyNotesModel> generateStudyNotes({
    required String documentText,
    required String title,
    List<String> sourceFileNames = const [],
  }) async {
    final key = await getEffectiveApiKey();
    if (key == null || key.isEmpty) {
      return _buildLocalNotesFallback(documentText, title, sourceFileNames);
    }

    final cleanedDoc = TextSanitizer.cleanMetadataArtifacts(documentText);
    final truncated =
        cleanedDoc.length > 30000 ? cleanedDoc.substring(0, 30000) : cleanedDoc;

    final prompt = '''
You are an expert university professor, curriculum designer, and master educator.
Read the provided study material and generate comprehensive, easy-to-digest study notes strictly following a clean modular structure designed for scholars to study easily.

CORE NOTE FORMAT SPECIFICATION:
1. Term / Topic: The important word or concept.
2. Simple Definition: Explain it using easy, accessible words grounded strictly in the material (no generic filler).
3. Purpose / Function: What is it used for? Why is it important in this subject?
4. Key Points: Short, punchy bullet points containing only high-yield facts, avoiding long dense paragraphs.
5. Example: Give a simple, practical or technical example grounded in or relevant to the material.
6. Difference / Comparison: When applicable, highlight contrast with an alternative or opposing concept.
7. Key Takeaway: A single, punchy, high-impact sentence containing the absolute most important takeaway to memorize for the exam (do NOT prefix with [B] or B:).
8. Possible Exam Question: Formulated as "Q: What is ...?\nA: Simple, direct answer."

Return a STRICT JSON object matching this schema:
{
  "title": "Clear, engaging academic title for these study notes",
  "overview": "Comprehensive 2-4 sentence executive overview summarizing the entire material",
  "sections": [
    {
      "heading": "Term / Topic Name",
      "definition": "Simple, direct explanation in plain language grounded in the text",
      "purpose": "What is it used for? Why is it important?",
      "keyPoints": [
        "First short bullet point with only high-yield info",
        "Second short bullet point avoiding long paragraphs"
      ],
      "example": "Simple real-life or technical practical example",
      "comparison": "Optional concise comparison with a related concept",
      "bottomLine": "Single punchy sentence of the absolute most important exam takeaway to memorize",
      "rememberThis": "Core mnemonic or takeaway",
      "examQuestion": "Q: Direct exam question?\\nA: Simple, direct answer."
    }
  ],
  "glossary": [
    {
      "term": "Key Term or Formula Name",
      "definition": "Clear, direct definition and operational significance grounded in the document."
    }
  ],
  "examTakeaways": [
    "High-yield exam review point 1",
    "High-yield exam review point 2"
  ]
}

STUDY MATERIAL:
$truncated
''';

    final provider = await getActiveProvider();
    if (provider != AiProvider.gemini) {
      try {
        debugPrint(
            '[AiService] Calling ${provider.displayName} (${provider.modelName}) for Easy-to-Study notes...');
        final jsonText = await _executeLlmCall(
          provider: provider,
          apiKey: key,
          prompt: prompt,
          systemPrompt:
              'You are an expert curriculum designer and educator. Respond strictly with a JSON object containing "title", "overview", "sections", "glossary", and "examTakeaways" following the Easy-to-Study format.',
          temperature: 0.7,
        );
        if (jsonText != null && jsonText.trim().isNotEmpty) {
          final cleanJson = _extractJson(jsonText);
          final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;
          return StudyNotesModel.fromJson({
            ...decoded,
            'sourceFileNames': sourceFileNames,
          });
        }
      } catch (e) {
        debugPrint(
            '[AiService] ${provider.displayName} notes generation failed: $e');
      }
      return _buildLocalNotesFallback(documentText, title, sourceFileNames);
    }

    final modelsToTry = [
      _modelName,
      ..._fallbackModels.where((m) => m != _modelName),
    ];

    for (final candidate in modelsToTry) {
      try {
        final model = GenerativeModel(
          model: candidate,
          apiKey: key,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.7,
          ),
        );
        final response = await model.generateContent([Content.text(prompt)]);
        final text = response.text;
        if (text != null && text.trim().isNotEmpty) {
          final cleanJson = _extractJson(text);
          final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;
          return StudyNotesModel.fromJson({
            ...decoded,
            'sourceFileNames': sourceFileNames,
          });
        }
      } catch (e) {
        debugPrint(
            '[GeminiService] Notes generation failed with $candidate: $e');
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    return _buildLocalNotesFallback(documentText, title, sourceFileNames);
  }

  StudyNotesModel _buildLocalNotesFallback(
    String text,
    String title,
    List<String> sourceFileNames,
  ) {
    final words =
        text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final wordCount = words.length;

    final allSentences = text
        .split(RegExp(r'(?<=[.!?])\s+|\r?\n+'))
        .map((s) => s.trim())
        .where((s) => s.length > 20 && s.length < 350)
        .toList();

    final titleCaseRegExp = RegExp(r'\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2}\b');
    final terms = <String>{};
    for (final m in titleCaseRegExp.allMatches(text)) {
      final t = m.group(0)?.trim();
      if (t != null && t.length > 3 && t.length < 30) {
        final stripped = TextSanitizer.stripLeadingArtifacts(t);
        if (stripped.isNotEmpty && !terms.contains(stripped)) {
          terms.add(stripped);
        }
      }
      if (terms.length >= 8) break;
    }

    final termList = terms.toList();
    final glossary = <StudyNoteTerm>[];
    for (final t in termList) {
      final matchingSentence = allSentences.firstWhere(
        (s) => s.toLowerCase().contains(t.toLowerCase()),
        orElse: () => allSentences.isNotEmpty ? allSentences.first : '',
      );
      if (matchingSentence.isNotEmpty) {
        glossary.add(StudyNoteTerm(term: t, definition: matchingSentence));
      }
    }

    final rawParagraphs = text
        .split(RegExp(r'\n{2,}'))
        .map((p) => p.trim())
        .where((p) => p.length > 20)
        .toList();

    final paragraphs = rawParagraphs
        .map((p) {
          return p
              .split(RegExp(r'\r?\n'))
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .join(' ')
              .replaceAll(RegExp(r'\s{2,}'), ' ')
              .trim();
        })
        .where((p) => p.length > 30)
        .take(5)
        .toList();

    final sections = <StudyNoteSection>[];
    final takeaways = <String>[];

    if (paragraphs.isNotEmpty) {
      for (int i = 0; i < paragraphs.length; i++) {
        final pText = paragraphs[i];
        final pSentences = pText
            .split(RegExp(r'(?<=[.!?])\s+'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        final heading = (termList.length > i)
            ? termList[i]
            : (pSentences.isNotEmpty && pSentences.first.length < 35
                ? pSentences.first
                : 'Core Concept ${i + 1}');

        final def = pSentences.isNotEmpty ? pSentences.first : pText;
        final purposeText = pSentences.length > 1 ? pSentences[1] : null;

        final bulletPoints = pSentences.skip(1).take(3).toList();
        if (bulletPoints.isEmpty) {
          bulletPoints.add(def);
        }

        final bottomLineText = pSentences.isNotEmpty ? pSentences.last : def;

        takeaways.add('$heading: $bottomLineText');

        sections.add(
          StudyNoteSection(
            heading: heading,
            content: def,
            definition: def,
            purpose: purposeText,
            keyPoints: bulletPoints,
            example: pSentences.length > 2 ? pSentences[2] : null,
            bottomLine: bottomLineText,
            rememberThis: bottomLineText,
            examQuestion:
                'Q: What is the primary concept regarding $heading in this material?\nA: $def',
          ),
        );
      }
    } else {
      final summarySentence = allSentences.isNotEmpty
          ? allSentences.first
          : 'Analyzed study material containing $wordCount words.';

      sections.add(
        StudyNoteSection(
          heading: 'Core Subject Foundations',
          content: summarySentence,
          definition: summarySentence,
          purpose:
              'Provides foundational concepts required for mastery and exam review.',
          keyPoints: allSentences.take(3).toList(),
          bottomLine: summarySentence,
          rememberThis: summarySentence,
          examQuestion:
              'Q: What is the core topic of this material?\nA: $summarySentence',
        ),
      );
      takeaways.add('Core Foundation: $summarySentence');
    }

    return StudyNotesModel(
      title: title.isNotEmpty ? title : 'Synthesized Study Notes',
      overview: allSentences.take(2).join(' '),
      sections: sections,
      glossary: glossary,
      examTakeaways: takeaways.isNotEmpty
          ? takeaways.take(4).toList()
          : [
              'Master core operational definitions grounded in the material.',
              'Contrast interrelated principles before starting the exam.',
            ],
      sourceFileNames: sourceFileNames,
    );
  }

  Future<FlashcardDeckModel> generateFlashcards({
    required String documentText,
    required String sourceFileName,
    int cardCount = 12,
    QuizDifficulty difficulty = QuizDifficulty.medium,
  }) async {
    final key = await getEffectiveApiKey();
    if (key == null || key.isEmpty) {
      return _buildLocalFlashcardsFallback(
          documentText, sourceFileName, cardCount);
    }

    final cleanedDoc = TextSanitizer.cleanMetadataArtifacts(documentText);
    final truncated =
        cleanedDoc.length > 30000 ? cleanedDoc.substring(0, 30000) : cleanedDoc;

    final randomSeed =
        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999999)}';

    final prompt = '''
You are an expert university educator, flashcard author, and learning science specialist.
Generate $cardCount high-yield, conceptually rigorous study flashcards grounded entirely in the provided study material.
Target Academic Level: ${difficulty.name.toUpperCase()}.
Randomization Seed: $randomSeed

FLASHCARD DESIGN REQUIREMENTS:
1. FRONT OF CARD ("front"):
   - Clear, concise question, prompt, formula name, or core technical term.
   - Formulate prompts that demand recall and conceptual comprehension (e.g. "What is the primary function of...?", "State the formula for... and identify each variable", "Define the principle of...").
   - Under NO circumstances copy-paste raw, disconnected sentences.
2. BACK OF CARD ("back"):
   - Rigorous, comprehensive, and accurate answer, definition, formula derivation, or conceptual explanation.
   - Explain WHY the concept matters and summarize operational details clearly.
3. HINT ("hint"):
   - A subtle educational memory clue, mnemonic, or guiding hint without directly revealing the entire answer.
4. CATEGORY ("category"):
   - Concise topical category for this flashcard (e.g., "Axiom", "Formula", "Architecture", "Definition", "Mechanism").
5. NO CITATIONS: Do not mention "According to the slide", "In the document", etc.
6. NO ADMINISTRATIVE JUNK: Exclude page numbers, course headers, slide dates, and footers.
7. CRITICAL INFORMATION: Focus on the most important terms, concepts, definitions, formulas, and principles necessary to master this material.

Return a STRICT JSON object matching this schema:
{
  "deckTitle": "Engaging, academic title for this flashcard deck",
  "flashcards": [
    {
      "front": "Question, Term, or Formula Prompt",
      "back": "Accurate, clear explanation",
      "hint": "Educational memory clue",
      "category": "Topic Category"
    }
  ]
}

STUDY MATERIAL:
$truncated
''';

    final provider = await getActiveProvider();
    if (provider != AiProvider.gemini) {
      try {
        debugPrint(
            '[AiService] Calling ${provider.displayName} (${provider.modelName}) for flashcards...');
        final jsonText = await _executeLlmCall(
          provider: provider,
          apiKey: key,
          prompt: prompt,
          systemPrompt:
              'You are an expert educator and flashcard designer. Respond strictly with a JSON object containing "deckTitle" and "flashcards".',
          temperature: 0.8,
        );
        if (jsonText != null && jsonText.trim().isNotEmpty) {
          final cleanJson = _extractJson(jsonText);
          final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;
          final deck = FlashcardDeckModel.fromJson({
            ...decoded,
            'sourceFileName': sourceFileName,
          });
          if (deck.cards.isNotEmpty) {
            return deck;
          }
        }
      } catch (e) {
        debugPrint(
            '[AiService] ${provider.displayName} flashcards generation failed: $e');
      }
      return _buildLocalFlashcardsFallback(
          documentText, sourceFileName, cardCount);
    }

    final modelsToTry = [
      _modelName,
      ..._fallbackModels.where((m) => m != _modelName),
    ];

    for (final candidate in modelsToTry) {
      try {
        final model = GenerativeModel(
          model: candidate,
          apiKey: key,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.85,
            topP: 0.95,
            topK: 40,
          ),
        );
        final response = await model.generateContent([Content.text(prompt)]);
        final text = response.text;
        if (text != null && text.trim().isNotEmpty) {
          final cleanJson = _extractJson(text);
          final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;
          final deck = FlashcardDeckModel.fromJson({
            ...decoded,
            'sourceFileName': sourceFileName,
          });
          if (deck.cards.isNotEmpty) {
            return deck;
          }
        }
      } catch (e) {
        debugPrint(
            '[GeminiService] Flashcards generation failed with $candidate: $e');
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    return _buildLocalFlashcardsFallback(
        documentText, sourceFileName, cardCount);
  }

  FlashcardDeckModel _buildLocalFlashcardsFallback(
    String text,
    String sourceFileName,
    int cardCount,
  ) {
    final allSentences = text
        .split(RegExp(r'(?<=[.!?])\s+|\r?\n+'))
        .map((s) => s.trim())
        .where((s) => s.length > 25 && s.length < 300)
        .toList();

    final titleCaseRegExp = RegExp(r'\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2}\b');
    final terms = <String>{};
    for (final m in titleCaseRegExp.allMatches(text)) {
      final t = m.group(0)?.trim();
      if (t != null && t.length > 3 && t.length < 30) {
        final stripped = TextSanitizer.stripLeadingArtifacts(t);
        if (stripped.isNotEmpty && !terms.contains(stripped)) {
          terms.add(stripped);
        }
      }
      if (terms.length >= cardCount) break;
    }

    final cards = <FlashcardModel>[];
    int idx = 1;
    for (final t in terms) {
      final matchingSentence = allSentences.firstWhere(
        (s) => s.toLowerCase().contains(t.toLowerCase()),
        orElse: () => '',
      );

      final backAnswer = matchingSentence.isNotEmpty
          ? matchingSentence
          : (allSentences.isNotEmpty
              ? allSentences[idx % allSentences.length]
              : t);

      final hintWords = backAnswer.split(RegExp(r'\s+')).take(4).join(' ');

      cards.add(
        FlashcardModel(
          id: 'card_$idx',
          front:
              'What key concept or principle in this material describes "$t"?',
          back: backAnswer,
          hint: hintWords.isNotEmpty ? 'Begins: "$hintWords..."' : null,
          category: 'Key Concept',
        ),
      );
      idx++;
      if (cards.length >= cardCount) break;
    }

    if (cards.isEmpty && allSentences.isNotEmpty) {
      for (int i = 0; i < min(cardCount, allSentences.length); i++) {
        final sentence = allSentences[i];
        final words = sentence.split(RegExp(r'\s+'));
        final candidateTopic = words.take(3).join(' ');
        cards.add(
          FlashcardModel(
            id: 'card_${i + 1}',
            front:
                'What fact does the study guide state regarding "$candidateTopic"?',
            back: sentence,
            hint: 'Review: ${words.take(2).join(" ")}...',
            category: 'Study Fact',
          ),
        );
      }
    }

    if (cards.isEmpty) {
      cards.add(
        const FlashcardModel(
          id: 'card_1',
          front: 'What is the core takeaway of this study material?',
          back:
              'Review the foundational principles and key terminology outlined across the document.',
          hint: 'Focus on primary concepts.',
          category: 'Overview',
        ),
      );
    }

    return FlashcardDeckModel(
      title: '$sourceFileName Study Deck',
      sourceFileName: sourceFileName,
      cards: cards,
    );
  }
}
