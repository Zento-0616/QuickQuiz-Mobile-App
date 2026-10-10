import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/document_model.dart';
import '../../models/flashcard_model.dart';
import '../../models/study_notes_model.dart';
import '../../services/gemini_service.dart';
import '../../services/local_storage_service.dart';
import '../../utils/constants.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/ai_provider_logo.dart';
import '../../widgets/gemini_api_key_dialog.dart';

/// Screen displayed immediately after document analysis, allowing the user
/// to choose between generating an Exam Quiz, Structured Study Notes, or Interactive Flashcards.
class GenerationMethodView extends StatefulWidget {
  final DocumentModel? document;

  const GenerationMethodView({super.key, this.document});

  static void updateDeckCache(FlashcardDeckModel updatedDeck) {
    _GenerationMethodViewState.updateDeckCache(updatedDeck);
  }

  @override
  State<GenerationMethodView> createState() => _GenerationMethodViewState();
}

class _GenerationMethodViewState extends State<GenerationMethodView> {
  // In-memory cache for previously generated study notes and flashcard decks
  // ensuring switching methods or returning to this screen consumes ZERO additional tokens!
  static final Map<String, StudyNotesModel> _notesCache = {};
  static final Map<String, FlashcardDeckModel> _deckCache = {};

  static void updateDeckCache(FlashcardDeckModel updatedDeck) {
    for (final entry in _deckCache.entries) {
      if (entry.value.id == updatedDeck.id) {
        _deckCache[entry.key] = updatedDeck;
        return;
      }
    }
  }

  bool _isGeneratingNotes = false;
  bool _isGeneratingFlashcards = false;
  String? _errorMessage;

  AiProvider _activeProvider = AiProvider.gemini;
  bool _hasApiKey = false;

  @override
  void initState() {
    super.initState();
    _loadAiStatus();
  }

  Future<void> _loadAiStatus() async {
    final storage = LocalStorageService();
    final provider = await storage.getActiveAiProvider();
    final key = await storage.getApiKeyForProvider(provider);
    if (mounted) {
      setState(() {
        _activeProvider = provider;
        _hasApiKey = key != null && key.isNotEmpty;
      });
    }
  }

  Future<void> _openApiKeyDialog() async {
    final changed = await showGeminiApiKeyDialog(context);
    if (changed == true || mounted) {
      await _loadAiStatus();
    }
  }

  DocumentModel? get _doc => widget.document;

  String _getDocKey(DocumentModel doc) {
    return '${doc.fileName}_${doc.extractedText?.hashCode ?? 0}';
  }

  Future<void> _handleGenerateNotes() async {
    final doc = _doc;
    if (doc == null || doc.extractedText == null || doc.extractedText!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No analyzed document text found. Please upload again.')),
      );
      context.go(AppRoutes.upload);
      return;
    }

    final docKey = _getDocKey(doc);
    if (_notesCache.containsKey(docKey)) {
      // Re-use cached notes immediately without calling Gemini or burning tokens!
      context.go(
        AppRoutes.studyNotes,
        extra: (notes: _notesCache[docKey]!, document: doc),
      );
      return;
    }

    // Prompt for key if not configured
    if (!_hasApiKey) {
      final keyProvided = await showGeminiApiKeyDialog(context);
      if (keyProvided == true) {
        await _loadAiStatus();
      }
    }

    setState(() {
      _isGeneratingNotes = true;
      _errorMessage = null;
    });

    try {
      final gemini = GeminiService();
      final sourceFiles = doc.sourceDocuments != null && doc.sourceDocuments!.isNotEmpty
          ? doc.sourceDocuments!.map((d) => d.fileName).toList()
          : [doc.fileName];

      final notes = await gemini.generateStudyNotes(
        documentText: doc.extractedText!,
        title: doc.detectedSubject != null && doc.detectedSubject!.isNotEmpty
            ? '${doc.detectedSubject} Study Notes'
            : doc.title,
        sourceFileNames: sourceFiles,
      );

      _notesCache[docKey] = notes;

      // Auto-save to local storage history
      if (mounted) {
        final auth = context.read<AuthViewModel>();
        final userId = auth.isAuthenticated ? auth.currentUser!.uid : '';
        await LocalStorageService().saveStudyNotesLocally(notes, userId: userId);
      }

      if (!mounted) return;
      setState(() => _isGeneratingNotes = false);

      context.go(
        AppRoutes.studyNotes,
        extra: (notes: notes, document: doc),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGeneratingNotes = false;
        _errorMessage = "Failed to generate notes: ${e.toString().replaceAll('Exception: ', '')}";
      });
    }
  }

  Future<void> _handleGenerateFlashcards() async {
    final doc = _doc;
    if (doc == null || doc.extractedText == null || doc.extractedText!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No analyzed document text found. Please upload again.')),
      );
      context.go(AppRoutes.upload);
      return;
    }

    final docKey = _getDocKey(doc);
    if (_deckCache.containsKey(docKey)) {
      // Re-use cached deck immediately without calling Gemini or burning tokens!
      context.go(
        AppRoutes.flashcards,
        extra: (deck: _deckCache[docKey]!, document: doc),
      );
      return;
    }

    // Prompt for key if not configured
    if (!_hasApiKey) {
      final keyProvided = await showGeminiApiKeyDialog(context);
      if (keyProvided == true) {
        await _loadAiStatus();
      }
    }

    setState(() {
      _isGeneratingFlashcards = true;
      _errorMessage = null;
    });

    try {
      final gemini = GeminiService();
      final sourceFiles = doc.sourceDocuments != null && doc.sourceDocuments!.isNotEmpty
          ? doc.sourceDocuments!.map((d) => d.fileName).join(', ')
          : doc.fileName;

      final deck = await gemini.generateFlashcards(
        documentText: doc.extractedText!,
        sourceFileName: sourceFiles,
        cardCount: 12,
      );

      _deckCache[docKey] = deck;

      // Auto-save to local storage history
      if (mounted) {
        final auth = context.read<AuthViewModel>();
        final userId = auth.isAuthenticated ? auth.currentUser!.uid : '';
        await LocalStorageService().saveFlashcardDeckLocally(deck, userId: userId);
      }

      if (!mounted) return;
      setState(() => _isGeneratingFlashcards = false);

      context.go(
        AppRoutes.flashcards,
        extra: (deck: deck, document: doc),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGeneratingFlashcards = false;
        _errorMessage = "Failed to generate flashcards: ${e.toString().replaceAll('Exception: ', '')}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doc = _doc;

    if (doc == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Generation Method')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No analyzed material found.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.upload),
                child: const Text('Return to Upload'),
              ),
            ],
          ),
        ),
      );
    }

    final fileCount = doc.fileCount;
    final fileNames = doc.sourceDocuments != null && doc.sourceDocuments!.isNotEmpty
        ? doc.sourceDocuments!.map((d) => d.fileName).join(', ')
        : doc.fileName;

    final docKey = _getDocKey(doc);
    final hasGeneratedNotes = _notesCache.containsKey(docKey);
    final hasGeneratedDeck = _deckCache.containsKey(docKey);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go(AppRoutes.upload);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Choose Method'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go(AppRoutes.upload),
          ),
          actions: [
            IconButton(
              tooltip: _hasApiKey
                  ? '${_activeProvider.displayName} Connected'
                  : 'Connect AI Key (${_activeProvider.displayName})',
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _hasApiKey
                            ? const Color(0xFF10B981).withValues(alpha: 0.5)
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: AiProviderLogo(provider: _activeProvider, size: 18),
                  ),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _hasApiKey ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              onPressed: _openApiKeyDialog,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                children: [
                  // AI Engine & API Key Status Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _hasApiKey
                            ? const Color(0xFF10B981).withValues(alpha: 0.3)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        AiProviderLogo(provider: _activeProvider, size: 22, showBackground: true),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _activeProvider.displayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: _hasApiKey
                                          ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                          : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _hasApiKey ? 'Key Active' : 'No Key',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: _hasApiKey
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFF59E0B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _hasApiKey
                                    ? 'Powered by ${_activeProvider.modelName}'
                                    : 'Tap to connect Gemini, OpenAI, or DeepSeek',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: _openApiKeyDialog,
                          child: Text(
                            _hasApiKey ? 'Change' : 'Connect',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Text(
                    'Choose What You Want to Generate',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your material is analyzed. Select how you want to learn today:',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Material Summary Overview Card (Compact)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.verified_rounded,
                                color: AppTheme.primaryColor,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$fileCount Analyzed ${fileCount > 1 ? "Files" : "File"}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  Text(
                                    fileNames,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      fontSize: 11.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (doc.keyTopics != null && doc.keyTopics!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            children: doc.keyTopics!.take(4).map((topic) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: theme.dividerColor.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  topic,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: theme.colorScheme.onErrorContainer, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Method Card 1: Quiz (MCQ)
                  _MethodCard(
                    title: 'Quiz (MCQ & Practice)',
                    badge: 'POPULAR',
                    badgeColor: const Color(0xFF8B5CF6),
                    icon: Icons.quiz_rounded,
                    gradientColors: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    description:
                        'Generate exam-grade questions with customizable timers. Hard mode supports both MCQs and Fill-in-the-Blank.',
                    actionLabel: 'Quiz Settings',
                    onTap: (_isGeneratingNotes || _isGeneratingFlashcards)
                        ? null
                        : () => context.go(AppRoutes.quizSettings, extra: doc),
                  ),

                  const SizedBox(height: 10),

                  // Method Card 2: Notes
                  _MethodCard(
                    title: 'Organized Study Notes',
                    badge: hasGeneratedNotes ? 'READY • 0 TOKENS' : 'AI SYNTHESIS',
                    badgeColor: const Color(0xFF10B981),
                    icon: Icons.menu_book_rounded,
                    gradientColors: const [Color(0xFF059669), Color(0xFF10B981)],
                    description: hasGeneratedNotes
                        ? 'Your structured study notes for this document are already synthesized and ready to review immediately with 0 token cost.'
                        : 'Generate structured study notes with conceptual breakdowns, key terminology & formulas, and takeaways.',
                    actionLabel: hasGeneratedNotes ? 'View Notes' : 'Study Notes',
                    onTap: (_isGeneratingNotes || _isGeneratingFlashcards)
                        ? null
                        : _handleGenerateNotes,
                  ),

                  const SizedBox(height: 10),

                  // Method Card 3: Flashcards
                  _MethodCard(
                    title: 'Flashcards',
                    badge: hasGeneratedDeck ? 'READY • 0 TOKENS' : 'ACTIVE RECALL',
                    badgeColor: const Color(0xFFF59E0B),
                    icon: Icons.style_rounded,
                    gradientColors: const [Color(0xFFD97706), Color(0xFFF59E0B)],
                    description: hasGeneratedDeck
                        ? 'Your 3D interactive flashcards for this material are already compiled and ready for active recall review with 0 token cost.'
                        : 'Generate interactive double-sided flashcards with key terms, formulas, and definitions with 3D flip animation.',
                    actionLabel: hasGeneratedDeck ? 'View Cards' : 'Flashcards',
                    onTap: (_isGeneratingNotes || _isGeneratingFlashcards)
                        ? null
                        : _handleGenerateFlashcards,
                  ),

                  const SizedBox(height: 16),
                ],
              ),

              // Loading overlay when synthesizing notes or flashcards
              if (_isGeneratingNotes || _isGeneratingFlashcards)
                Container(
                  color: Colors.black.withValues(alpha: 0.65),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color ?? const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 44,
                            height: 44,
                            child: CircularProgressIndicator(
                              strokeWidth: 3.5,
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _isGeneratingFlashcards
                                ? 'Generating Flashcards...'
                                : 'Synthesizing Study Notes...',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isGeneratingFlashcards
                                ? 'Extracting core terms, definitions, formulas, and key concepts into study cards...'
                                : 'Extracting core concepts, compiling glossary & definitions, and highlighting key takeaways...',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final String title;
  final String badge;
  final Color badgeColor;
  final IconData icon;
  final List<Color> gradientColors;
  final String description;
  final String actionLabel;
  final VoidCallback? onTap;

  const _MethodCard({
    required this.title,
    required this.badge,
    required this.badgeColor,
    required this.icon,
    required this.gradientColors,
    required this.description,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: gradientColors.first.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  actionLabel,
                  style: TextStyle(
                    color: gradientColors.first,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: gradientColors.first,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
