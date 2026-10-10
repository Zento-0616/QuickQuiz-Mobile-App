import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../models/document_model.dart';
import '../../models/question_model.dart';
import '../../models/quiz_model.dart';
import '../../models/quiz_settings_model.dart';
import '../../repositories/document_repository.dart';
import '../../repositories/quiz_repository.dart';
import '../../services/firestore_service.dart';
import '../../services/gemini_service.dart';
import '../../utils/toast_helper.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/gemini_api_key_dialog.dart';

class AiQuizStudioModal extends StatefulWidget {
  final VoidCallback onPublished;

  const AiQuizStudioModal({super.key, required this.onPublished});

  static Future<void> show(BuildContext context, {required VoidCallback onPublished}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AiQuizStudioModal(onPublished: onPublished),
    );
  }

  @override
  State<AiQuizStudioModal> createState() => _AiQuizStudioModalState();
}

class _AiQuizStudioModalState extends State<AiQuizStudioModal> {
  final DocumentRepository _docRepo = DocumentRepository();
  final QuizRepository _quizRepo = QuizRepository();
  final FirestoreService _firestoreService = FirestoreService();

  int _step = 0;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  DocumentModel? _uploadedDoc;
  bool _isExtractingText = false;
  bool _isGeneratingQuiz = false;
  bool _isPublishing = false;

  String _category = 'Science';
  final List<String> _categories = [
    'Science',
    'Technology',
    'History',
    'Literature',
    'Mathematics',
    'Medicine',
    'Business',
    'General',
  ];

  QuizDifficulty _difficulty = QuizDifficulty.medium;
  int _minLevel = 1;
  int _expReward = 100;
  int _questionCount = 5;
  bool _isGlobal = true;
  bool _isUnlimitedPlay = false;
  bool _allowRepeatExp = false;
  int _expirationDays = 7;
  String _quizScheduleType = 'standard';

  List<QuestionModel> _reviewQuestions = [];
  int? _regeneratingIndex;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }


  Future<void> _handleFilePick() async {
    try {
      final picked = await _docRepo.pickFile();

      final ext = picked.extension.toLowerCase();
      if (ext != 'pdf' && ext != 'pptx' && ext != 'txt' && ext != 'docx') {
        if (mounted) {
          showErrorToast(context, 'Invalid format (.$ext). Please upload a PDF, PPTX, or TXT file.');
        }
        return;
      }

      setState(() {
        _isExtractingText = true;
        _uploadedDoc = picked;
      });

      final parsed = await _docRepo.extractText(picked);

      if (mounted) {
        String detectedCat = 'General';
        if (parsed.detectedSubject != null && parsed.detectedSubject!.trim().isNotEmpty) {
          detectedCat = parsed.detectedSubject!.trim();
        } else if (parsed.keyTopics != null && parsed.keyTopics!.isNotEmpty) {
          detectedCat = parsed.keyTopics!.first.trim();
        } else {
          final content = '${picked.fileName} ${parsed.extractedText ?? ''}'.toLowerCase();
          if (content.contains('crypt') || content.contains('secur') || content.contains('code') ||
              content.contains('network') || content.contains('software') || content.contains('comput') ||
              content.contains('tech') || content.contains('algorithm')) {
            detectedCat = 'Technology';
          } else if (content.contains('cell') || content.contains('bio') || content.contains('chem') ||
              content.contains('physic') || content.contains('dna') || content.contains('organism')) {
            detectedCat = 'Science';
          } else if (content.contains('war') || content.contains('centur') || content.contains('empire') ||
              content.contains('revolution') || content.contains('history') || content.contains('ancient')) {
            detectedCat = 'History';
          } else if (content.contains('poem') || content.contains('novel') || content.contains('author') ||
              content.contains('drama') || content.contains('literature')) {
            detectedCat = 'Literature';
          } else if (content.contains('matrix') || content.contains('calculus') || content.contains('algebra') ||
              content.contains('equation') || content.contains('math') || content.contains('theorem')) {
            detectedCat = 'Mathematics';
          } else if (content.contains('clinic') || content.contains('patient') || content.contains('disease') ||
              content.contains('medical') || content.contains('medicine') || content.contains('anatomy')) {
            detectedCat = 'Medicine';
          } else if (content.contains('market') || content.contains('econom') || content.contains('financ') ||
              content.contains('business') || content.contains('revenue')) {
            detectedCat = 'Business';
          }
        }

        if (detectedCat.isNotEmpty) {
          detectedCat = detectedCat[0].toUpperCase() + detectedCat.substring(1);
          if (!_categories.contains(detectedCat)) {
            _categories.insert(0, detectedCat);
          }
          _category = detectedCat;
        }

        setState(() {
          _uploadedDoc = parsed;
          _isExtractingText = false;
          if (_titleCtrl.text.isEmpty) {
            _titleCtrl.text = picked.title;
          }
          if (_descCtrl.text.isEmpty && parsed.summary != null) {
            _descCtrl.text = parsed.summary!;
          }
        });
        showSuccessToast(context, 'Document parsed! Detected topic: "$_category"');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExtractingText = false);
        showErrorToast(context, 'Failed to read file: $e');
      }
    }
  }


  Future<void> _handleGenerateQuestions() async {
    if (_titleCtrl.text.trim().isEmpty) {
      showErrorToast(context, 'Please enter a quiz title.');
      return;
    }

    final geminiService = GeminiService();
    final hasKey = await geminiService.isConfiguredAsync;
    if (!hasKey) {
      if (!mounted) return;
      final keyProvided = await showGeminiApiKeyDialog(context);
      if (keyProvided != true && !(await geminiService.isConfiguredAsync)) {
        if (mounted) {
          showWarningToast(context, 'Google AI Studio API key required to generate questions from files.');
        }
        return;
      }
    }

    setState(() => _isGeneratingQuiz = true);

    try {
      final docText = _uploadedDoc?.extractedText ?? _descCtrl.text.trim();
      final quiz = await _quizRepo.generateQuiz(
        documentText: docText.isNotEmpty ? docText : '${_titleCtrl.text}. ${_descCtrl.text}',
        sourceFileName: _uploadedDoc?.name ?? _titleCtrl.text.trim(),
        questionCount: _questionCount,
        difficulty: _difficulty,
        category: _category,
      );

      if (mounted) {
        setState(() {
          _reviewQuestions = quiz.questions.map((q) => q.randomizeAnswers()).toList();
          _isGeneratingQuiz = false;
          _step = 1;
        });
        showSuccessToast(context, 'Generated ${_reviewQuestions.length} randomized MCQs from document.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingQuiz = false);
        if (e is GeminiApiKeyMissingException) {
          await showGeminiApiKeyDialog(context);
        } else {
          showErrorToast(context, 'AI generation failed: $e');
        }
      }
    }
  }


  Future<void> _regenerateQuestion(int index) async {
    if (_regeneratingIndex != null) return;
    setState(() => _regeneratingIndex = index);

    try {
      final docText = _uploadedDoc?.extractedText ?? _descCtrl.text.trim();
      final old = _reviewQuestions[index];
      final existingStems = _reviewQuestions
          .asMap()
          .entries
          .where((e) => e.key != index)
          .map((e) => e.value.question)
          .toList();

      final newQ = await _quizRepo.regenerateQuestion(
        documentText: docText.isNotEmpty ? docText : '${_titleCtrl.text}. ${_descCtrl.text}',
        oldQuestion: old,
        difficulty: _difficulty,
        existingQuestionStems: existingStems,
      );

      if (mounted) {
        setState(() {
          _reviewQuestions[index] = newQ.randomizeAnswers();
          _regeneratingIndex = null;
        });
        showSuccessToast(context, 'Regenerated question #${index + 1} with AI Studio.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _regeneratingIndex = null);
        if (e is GeminiApiKeyMissingException) {
          await showGeminiApiKeyDialog(context);
        } else {
          showErrorToast(context, 'Regeneration failed: $e');
        }
      }
    }
  }

  void _addBlankQuestion() {
    final randIdx = Random().nextInt(4);
    setState(() {
      _reviewQuestions.add(
        QuestionModel(
          question: 'New Question ${_reviewQuestions.length + 1}',
          options: ['Option A', 'Option B', 'Option C', 'Option D'],
          correctAnswerIndex: randIdx,
          explanation: 'Add explanation here.',
        ),
      );
    });
  }

  void _removeQuestion(int index) {
    if (_reviewQuestions.length <= 1) {
      showErrorToast(context, 'A quiz must contain at least 1 question.');
      return;
    }
    setState(() {
      _reviewQuestions.removeAt(index);
    });
  }

  Future<void> _publishQuiz() async {
    final auth = context.read<AuthViewModel>();
    final user = auth.currentUser;

    if (user == null || !user.isAdmin) {
      showErrorToast(context, 'Administrator permissions required to publish.');
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final title = _titleCtrl.text.trim();
      final quiz = QuizModel(
        title: title,
        sourceFileName: _uploadedDoc?.name ?? title,
        description: _descCtrl.text.trim(),
        difficulty: _difficulty,
        category: _category,
        minLevel: _minLevel,
        expReward: _expReward,
        expMultiplier: (_expReward / 100.0).clamp(1.0, 10.0),
        isGlobal: _isGlobal,
        isUnlimitedPlay: _isUnlimitedPlay,
        allowRepeatExp: _allowRepeatExp,
        quizScheduleType: _quizScheduleType,
        expiresAt: DateTime.now().add(Duration(days: _expirationDays)),
        topicTags: [
          _category,
          _difficulty.name.toUpperCase(),
          if (_quizScheduleType != 'standard') _quizScheduleType.toUpperCase(),
        ],
        isPublished: true,
        status: 'Active',
        authorId: user.uid,
        authorName: user.effectiveNickname,
        questions: _reviewQuestions,
      );

      await _firestoreService.savePublishedQuiz(quiz, user: user);

      if (mounted) {
        setState(() => _isPublishing = false);
        Navigator.of(context).pop();
        widget.onPublished();
        showSuccessToast(context, '🎉 Quiz "$title" published to Arena!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPublishing = false);
        showErrorToast(context, 'Failed to publish: $e');
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Container(
      constraints: BoxConstraints(maxHeight: size.height * 0.92),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/icons/quickquiz_logo.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _step == 0 ? 'AI Quiz Generator Studio' : 'Admin Review & Refinement',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        _step == 0
                            ? 'Upload document and configure AI generator'
                            : 'Preview, edit, or regenerate questions before publishing',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _step == 0 ? _buildConfigStep(context) : _buildReviewStep(context),
          ),
        ],
      ),
    );
  }


  Widget _buildConfigStep(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. Document Drop Zone',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Upload a PDF, PPTX, or TXT file for AI analysis and automatic MCQ extraction.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),

          _buildDropZone(context),
          const SizedBox(height: 24),

          const Text(
            '2. Quiz Configuration & Gating',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: 'Quiz Title *',
              hintText: 'e.g., Cellular Respiration & ATP Synthesis',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.title_rounded),
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _descCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Description / Concepts Tested',
              hintText: 'What key concepts does this quiz evaluate?',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.description_rounded),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: _category,
                  decoration: InputDecoration(
                    labelText: 'Topic Category',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  items: _categories.map((c) {
                    return DropdownMenuItem(value: c, child: Text(c));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _category = val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  value: _questionCount,
                  decoration: InputDecoration(
                    labelText: 'Questions',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5 MCQs')),
                    DropdownMenuItem(value: 10, child: Text('10 MCQs')),
                    DropdownMenuItem(value: 30, child: Text('30 MCQs')),
                    DropdownMenuItem(value: 50, child: Text('50 MCQs')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _questionCount = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const Text('Difficulty Tier:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          SegmentedButton<QuizDifficulty>(
            segments: const [
              ButtonSegment(value: QuizDifficulty.easy, label: Text('Easy')),
              ButtonSegment(value: QuizDifficulty.medium, label: Text('Medium')),
              ButtonSegment(value: QuizDifficulty.hard, label: Text('Hard')),
            ],
            selected: {_difficulty},
            onSelectionChanged: (val) => setState(() => _difficulty = val.first),
          ),
          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Level Requirement Gate:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Minimum Level $_minLevel',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.accentColor, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Scholars must reach this level before they can unlock and play this quiz in the Arena.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [1, 5, 10, 15, 20].map((lvl) {
                final isSel = _minLevel == lvl;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('Lvl $lvl+'),
                    selected: isSel,
                    onSelected: (val) {
                      if (val) setState(() => _minLevel = lvl);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('EXP Reward (1 - 1000):', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('+$_expReward EXP', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFD97706), fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Slider(
            value: _expReward.toDouble().clamp(1.0, 1000.0),
            min: 1,
            max: 1000,
            divisions: 100,
            label: '$_expReward EXP',
            onChanged: (v) => setState(() => _expReward = v.round()),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [50, 100, 250, 500, 1000].map((preset) {
              final isSel = _expReward == preset;
              return ChoiceChip(
                label: Text('$preset EXP'),
                selected: isSel,
                onSelected: (val) {
                  if (val) setState(() => _expReward = preset);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.event_available_rounded, color: Color(0xFFF59E0B), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quiz Mode & Recurrence',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            Text(
                              'Tag as a standard deck, daily challenge, or weekly tournament',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        avatar: const Icon(Icons.bolt_rounded, size: 16),
                        label: const Text('Standard Deck'),
                        selected: _quizScheduleType == 'standard',
                        onSelected: (val) {
                          if (val) setState(() => _quizScheduleType = 'standard');
                        },
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.today_rounded, size: 16),
                        label: const Text('Daily Quiz'),
                        selected: _quizScheduleType == 'daily',
                        onSelected: (val) {
                          if (val) setState(() => _quizScheduleType = 'daily');
                        },
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.emoji_events_rounded, size: 16),
                        label: const Text('Weekly Tournament'),
                        selected: _quizScheduleType == 'weekly',
                        onSelected: (val) {
                          if (val) setState(() => _quizScheduleType = 'weekly');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 18, color: Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      Text(
                        'Quiz Duration / Auto-Close ($_expirationDays Days):',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('1 Day'),
                        selected: _expirationDays == 1,
                        onSelected: (val) {
                          if (val) setState(() => _expirationDays = 1);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('3 Days'),
                        selected: _expirationDays == 3,
                        onSelected: (val) {
                          if (val) setState(() => _expirationDays = 3);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('7 Days (1 Wk)'),
                        selected: _expirationDays == 7,
                        onSelected: (val) {
                          if (val) setState(() => _expirationDays = 7);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('14 Days (2 Wks)'),
                        selected: _expirationDays == 14,
                        onSelected: (val) {
                          if (val) setState(() => _expirationDays = 14);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('30 Days (1 Mo)'),
                        selected: _expirationDays == 30,
                        onSelected: (val) {
                          if (val) setState(() => _expirationDays = 30);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.public_rounded, color: AppTheme.primaryColor),
                  ),
                  title: const Text(
                    'Global Quiz Arena',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Publish to the global arena & universal leaderboard with premium badge',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _isGlobal,
                  onChanged: (val) => setState(() => _isGlobal = val),
                ),
                Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.all_inclusive_rounded, color: Colors.teal),
                  ),
                  title: const Text(
                    'Unlimited Quiz Plays',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Allow scholars to replay repeatedly without lockouts',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _isUnlimitedPlay,
                  onChanged: (val) => setState(() => _isUnlimitedPlay = val),
                ),
                Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.replay_rounded, color: Color(0xFF10B981)),
                  ),
                  title: const Text(
                    'Repeat Quiz EXP Gain',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Allow scholars to earn EXP on replay (unlimited EXP gain for this specific quiz)',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _allowRepeatExp,
                  onChanged: (val) => setState(() => _allowRepeatExp = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _isGeneratingQuiz
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded, color: Colors.white),
              label: Text(
                _isGeneratingQuiz ? 'Analyzing & Extracting MCQs...' : 'Generate MCQ Questions with AI',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
              ),
              onPressed: _isGeneratingQuiz ? null : _handleGenerateQuestions,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropZone(BuildContext context) {
    final theme = Theme.of(context);
    final doc = _uploadedDoc;

    if (_isExtractingText) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
        ),
        child: const Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Extracting and analyzing document content...', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Powering insights with AI...', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    if (doc != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.name, style: const TextStyle(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${doc.formattedSize} • ${doc.wordCount} words extracted', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('Change'),
              onPressed: _handleFilePick,
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _handleFilePick,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3), style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Icon(Icons.cloud_upload_outlined, size: 44, color: AppTheme.primaryColor.withValues(alpha: 0.8)),
            const SizedBox(height: 10),
            const Text(
              'Drag & drop document or tap to browse',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Supported formats: PDF, PPTX, TXT (up to 20MB)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildReviewStep(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.7)
                : AppTheme.primaryColor.withValues(alpha: 0.05),
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 14, color: Color(0xFF10B981)),
                      SizedBox(width: 5),
                      Text(
                        'AI Answer Keys Locked',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_reviewQuestions.length} Review MCQs',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ...List.generate(_reviewQuestions.length, (idx) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Text(
                        'Q${idx + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _reviewQuestions.length + 1,
            itemBuilder: (context, index) {
              if (index == _reviewQuestions.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Custom Question', style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: _addBlankQuestion,
                  ),
                );
              }

              final q = _reviewQuestions[index];
              return _buildQuestionCard(index, q);
            },
          ),
        ),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Flexible(
                  flex: 2,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => setState(() => _step = 0),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Back to Setup', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: _isPublishing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.publish_rounded, color: Colors.white),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _isPublishing
                              ? 'Publishing...'
                              : 'Publish to Arena (${_reviewQuestions.length} MCQs)',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                      ),
                      onPressed: _isPublishing ? null : _publishQuiz,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(int index, QuestionModel question) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isDark ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'QUESTION ${index + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_rounded, size: 12, color: Color(0xFF10B981)),
                            SizedBox(width: 4),
                            Text(
                              'KEY LOCKED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: _regeneratingIndex == index
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, size: 20),
                      tooltip: 'Regenerate Question with AI Studio',
                      onPressed: _regeneratingIndex != null ? null : () => _regenerateQuestion(index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                      tooltip: 'Delete Question',
                      onPressed: () => _removeQuestion(index),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              initialValue: question.question,
              decoration: InputDecoration(
                labelText: 'Question Stem (MCQ)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              maxLines: 2,
              onChanged: (val) {
                _reviewQuestions[index] = question.copyWith(question: val);
              },
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF10B981)),
                const SizedBox(width: 6),
                Text(
                  'Options (AI Correct Key is Locked):',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ...List.generate(question.options.length, (optIdx) {
              final isCorrect = question.correctAnswerIndex == optIdx;
              final optionLetter = String.fromCharCode(65 + optIdx);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCorrect ? const Color(0xFF10B981) : Colors.grey.withValues(alpha: 0.2),
                      ),
                      child: Center(
                        child: Text(
                          optionLetter,
                          style: TextStyle(
                            color: isCorrect ? Colors.white : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    Radio<int>(
                      value: optIdx,
                      groupValue: question.correctAnswerIndex,
                      activeColor: const Color(0xFF10B981),
                      onChanged: null,
                    ),

                    Expanded(
                      child: TextFormField(
                        initialValue: question.options[optIdx],
                        readOnly: isCorrect,
                        decoration: InputDecoration(
                          hintText: 'Option $optionLetter',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          suffixIcon: isCorrect
                              ? const Tooltip(
                                  message: 'Correct answer key locked by AI generator',
                                  child: Icon(Icons.lock_rounded, size: 16, color: Color(0xFF10B981)),
                                )
                              : null,
                          filled: true,
                          fillColor: isCorrect
                              ? const Color(0xFF10B981).withValues(alpha: 0.08)
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isCorrect ? const Color(0xFF10B981) : Colors.grey.shade300,
                              width: isCorrect ? 1.5 : 1.0,
                            ),
                          ),
                        ),
                        onChanged: isCorrect
                            ? null
                            : (val) {
                                final updatedOptions = List<String>.from(question.options);
                                updatedOptions[optIdx] = val;
                                _reviewQuestions[index] = question.copyWith(options: updatedOptions);
                              },
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),

            TextFormField(
              initialValue: question.explanation,
              decoration: InputDecoration(
                labelText: 'Explanation (Grounding context)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                isDense: true,
              ),
              maxLines: 2,
              onChanged: (val) {
                _reviewQuestions[index] = question.copyWith(explanation: val);
              },
            ),
          ],
        ),
      ),
    );
  }
}
