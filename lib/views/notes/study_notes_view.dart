import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/document_model.dart';
import '../../models/study_notes_model.dart';
import '../../services/local_storage_service.dart';
import '../../utils/toast_helper.dart';
import '../../viewmodels/auth_viewmodel.dart';

class StudyNotesView extends StatefulWidget {
  final StudyNotesModel? notes;
  final DocumentModel? document;

  const StudyNotesView({
    super.key,
    this.notes,
    this.document,
  });

  @override
  State<StudyNotesView> createState() => _StudyNotesViewState();
}

class _StudyNotesViewState extends State<StudyNotesView> {
  @override
  void initState() {
    super.initState();
    _autoSaveToHistory();
  }

  void _autoSaveToHistory() {
    final studyNotes = widget.notes;
    if (studyNotes != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final auth = context.read<AuthViewModel>();
          final userId = auth.isAuthenticated ? auth.currentUser!.uid : '';
          await LocalStorageService().saveStudyNotesLocally(studyNotes, userId: userId);
        } catch (_) {}
      });
    }
  }

  void _handleBack() {
    if (widget.document != null) {
      context.go(AppRoutes.generationMethod, extra: widget.document);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  static String _sanitizeNoteContent(String raw) {
    if (raw.isEmpty) return raw;

    final lines = raw.split(RegExp(r'\r?\n'));
    final cleanedLines = <String>[];
    final charBuffer = StringBuffer();

    void flushCharBuffer() {
      if (charBuffer.isNotEmpty) {
        final word = charBuffer.toString().trim();
        final formatted = word.replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (m) => '${m.group(1)} ${m.group(2)}',
        );
        cleanedLines.add(formatted);
        charBuffer.clear();
      }
    }

    for (final l in lines) {
      final trimmed = l.trim();
      if (trimmed.isEmpty) {
        flushCharBuffer();
        cleanedLines.add('');
        continue;
      }

      if (trimmed.length == 1 && RegExp(r'[a-zA-Z0-9]').hasMatch(trimmed)) {
        charBuffer.write(trimmed);
      } else {
        flushCharBuffer();
        cleanedLines.add(trimmed);
      }
    }
    flushCharBuffer();

    final buffer = StringBuffer();
    for (int i = 0; i < cleanedLines.length; i++) {
      final line = cleanedLines[i].trim();
      if (line.isEmpty) {
        if (!buffer.toString().endsWith('\n\n')) {
          buffer.write('\n\n');
        }
        continue;
      }

      if (buffer.isNotEmpty &&
          !buffer.toString().endsWith('\n\n') &&
          !buffer.toString().endsWith('\n')) {
        buffer.write(' ');
      }
      buffer.write(line);
    }

    final result = buffer
        .toString()
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return result
        .replaceFirst(RegExp(r'^\[(B|M)\]\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^(B|M)\s*•\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^(Bottom Line|Bottom Summary|Main Note):\s*', caseSensitive: false), '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studyNotes = widget.notes;

    if (studyNotes == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Study Notes')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No study notes data found.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.upload),
                child: const Text('Go to Upload'),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Organized Study Notes'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: widget.document != null ? 'Back to Method Options' : 'Back',
            onPressed: _handleBack,
          ),
          actions: [
            if (widget.document != null)
              IconButton(
                icon: const Icon(Icons.alt_route_rounded),
                tooltip: 'Change Learning Method',
                onPressed: () => context.go(AppRoutes.generationMethod, extra: widget.document),
              ),
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'Copy Notes to Clipboard',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: studyNotes.toMarkdown()));
                showSuccessToast(context, '📋 Study notes copied to clipboard!');
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF065F46), Color(0xFF047857), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF059669).withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_stories_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 6),
                              Text(
                                'STUDY GUIDE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10.5,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${studyNotes.sections.length} Chapters • ${studyNotes.glossary.length} Terms',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      studyNotes.title,
                      softWrap: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.3,
                      ),
                    ),
                    if (studyNotes.sourceFileNames.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Sources: ${studyNotes.sourceFileNames.join(", ")}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              if (studyNotes.overview.isNotEmpty) ...[
                _buildSectionHeader(
                  context,
                  title: 'Executive Overview',
                  icon: Icons.lightbulb_rounded,
                  color: const Color(0xFFF59E0B),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _sanitizeNoteContent(studyNotes.overview),
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              if (studyNotes.sections.isNotEmpty) ...[
                _buildSectionHeader(
                  context,
                  title: 'Core Conceptual Pillars',
                  icon: Icons.account_tree_rounded,
                  color: const Color(0xFF38BDF8),
                ),
                const SizedBox(height: 12),
                ...studyNotes.sections.asMap().entries.map((entry) {
                  final sectionIndex = entry.key;
                  final section = entry.value;
                  final hasStructuredFormat = section.definition != null || section.purpose != null || section.rememberThis != null;
                  final effectiveBottomLine = (section.bottomLine != null && section.bottomLine!.isNotEmpty)
                      ? section.bottomLine!
                      : (section.rememberThis != null && section.rememberThis!.isNotEmpty ? section.rememberThis! : null);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  'Topic ${sectionIndex + 1}',
                                  style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _sanitizeNoteContent(section.heading),
                                  softWrap: true,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (section.definition != null && section.definition!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Definition:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF38BDF8),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _sanitizeNoteContent(section.definition!),
                                    softWrap: true,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      height: 1.5,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (!hasStructuredFormat && section.content.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: Text(
                                _sanitizeNoteContent(section.content),
                                softWrap: true,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.5,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ],

                          if (section.purpose != null && section.purpose!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('👉 ', style: TextStyle(fontSize: 14)),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 1.45,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.88),
                                        ),
                                        children: [
                                          const TextSpan(
                                            text: 'Purpose: ',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                          ),
                                          TextSpan(text: _sanitizeNoteContent(section.purpose!)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (section.keyPoints.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      'Key Points:',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF38BDF8),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  ...section.keyPoints.map((point) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 5),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '• ',
                                            style: TextStyle(
                                              color: Color(0xFF38BDF8),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              _sanitizeNoteContent(point),
                                              softWrap: true,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                height: 1.4,
                                                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],

                          if (section.example != null && section.example!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF10B981), size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          height: 1.4,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                                        ),
                                        children: [
                                          const TextSpan(
                                            text: 'Example: ',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                          ),
                                          TextSpan(text: _sanitizeNoteContent(section.example!)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (section.comparison != null && section.comparison!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.compare_arrows_rounded, color: Color(0xFFF59E0B), size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          height: 1.4,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                                        ),
                                        children: [
                                          const TextSpan(
                                            text: 'Comparison: ',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                                          ),
                                          TextSpan(text: _sanitizeNoteContent(section.comparison!)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (effectiveBottomLine != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                    const Color(0xFFF59E0B).withValues(alpha: 0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.45), width: 1.2),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'KEY TAKEAWAY',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _sanitizeNoteContent(effectiveBottomLine),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.95),
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (section.examQuestion != null && section.examQuestion!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.help_outline_rounded, color: Color(0xFF6366F1), size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Possible Exam Question:',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF6366F1),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _sanitizeNoteContent(section.examQuestion!),
                                          softWrap: true,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            height: 1.4,
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 16),
              ],

              if (studyNotes.glossary.isNotEmpty) ...[
                _buildSectionHeader(
                  context,
                  title: 'Key Definitions & Formulas',
                  icon: Icons.menu_book_rounded,
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < studyNotes.glossary.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            color: theme.dividerColor.withValues(alpha: 0.1),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _sanitizeNoteContent(studyNotes.glossary[i].term),
                                    softWrap: true,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: Text(
                                  _sanitizeNoteContent(studyNotes.glossary[i].definition),
                                  softWrap: true,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.45,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              if (studyNotes.examTakeaways.isNotEmpty) ...[
                _buildSectionHeader(
                  context,
                  title: 'High-Yield Exam Takeaways',
                  icon: Icons.checklist_rounded,
                  color: const Color(0xFF8B5CF6),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: studyNotes.examTakeaways.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final text = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 11,
                              backgroundColor: const Color(0xFF8B5CF6),
                              child: Text(
                                '$idx',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _sanitizeNoteContent(text),
                                softWrap: true,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              if (widget.document != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Ready for Another Learning Mode?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Use this same analyzed material to generate an exam quiz or interactive flashcards without uploading again.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.quiz_rounded, size: 20),
                        label: const Text(
                          'Create Quiz from this Material',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                        ),
                        onPressed: () => context.go(AppRoutes.quizSettings, extra: widget.document),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                          foregroundColor: const Color(0xFFF59E0B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.style_rounded, size: 20),
                        label: const Text(
                          'Generate Flashcards',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                        ),
                        onPressed: () => context.go(AppRoutes.generationMethod, extra: widget.document),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        icon: const Icon(Icons.alt_route_rounded, size: 18),
                        label: const Text(
                          'Back to Method Selection',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onPressed: () => context.go(AppRoutes.generationMethod, extra: widget.document),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            softWrap: true,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}
