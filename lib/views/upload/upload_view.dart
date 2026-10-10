import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/document_model.dart';
import '../../viewmodels/upload_viewmodel.dart';

/// Modern Upload screen: select study material, preview document, and proceed to settings.
class UploadView extends StatelessWidget {
  const UploadView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UploadViewModel(),
      child: const _UploadBody(),
    );
  }
}

class _UploadBody extends StatelessWidget {
  const _UploadBody();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UploadViewModel>();
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go(AppRoutes.home);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Upload Document'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go(AppRoutes.home),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Select Study Material',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Upload 1 to 3 lecture slides, notes, or reading materials to automatically generate a quiz or study notes.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // File count and limit indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Selected Files',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: viewModel.fileCount == UploadViewModel.maxFiles
                                ? Colors.amber.withValues(alpha: 0.15)
                                : AppTheme.primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: viewModel.fileCount == UploadViewModel.maxFiles
                                  ? Colors.amber.withValues(alpha: 0.5)
                                  : AppTheme.primaryColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '${viewModel.fileCount} / ${UploadViewModel.maxFiles} MAX',
                            style: TextStyle(
                              color: viewModel.fileCount == UploadViewModel.maxFiles
                                  ? Colors.amber.shade300
                                  : AppTheme.primaryColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (viewModel.hasFile && !viewModel.isLoading)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: Colors.redAccent,
                        ),
                        icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                        label: const Text('Clear All', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        onPressed: viewModel.removeFile,
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (viewModel.hasFile) ...[
                  ...List.generate(viewModel.documents.length, (index) {
                    final doc = viewModel.documents[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FileCard(
                        document: doc,
                        onRemove: viewModel.isLoading ? null : () => viewModel.removeFileAt(index),
                      ),
                    );
                  }),
                  if (viewModel.canAddMoreFiles) ...[
                    _AddMoreFilesButton(
                      viewModel: viewModel,
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '3 files limit reached. Remove a file if you wish to swap materials.',
                              style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else
                  _EmptyPicker(viewModel: viewModel),

                const SizedBox(height: 20),

                // Supported formats badge list
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _FormatBadge(label: 'PDF'),
                    SizedBox(width: 8),
                    _FormatBadge(label: 'DOCX'),
                    SizedBox(width: 8),
                    _FormatBadge(label: 'PPTX'),
                    SizedBox(width: 8),
                    _FormatBadge(label: 'TXT'),
                  ],
                ),

                if (viewModel.isLoading) ...[
                  const SizedBox(height: 20),
                  _DocumentAnalysisLoadingAnimation(
                    message: viewModel.loadingMessage,
                  ),
                ],

                if (viewModel.hasError) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded,
                            color: theme.colorScheme.onErrorContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            viewModel.errorMessage ?? '',
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              onPressed: viewModel.isLoading
                  ? null
                  : (viewModel.isReadyToProceed
                      ? () => context.go(AppRoutes.generationMethod, extra: viewModel.document)
                      : (viewModel.hasFile
                          ? () async {
                              final success = await viewModel.extractText();
                              if (success && context.mounted) {
                                context.go(AppRoutes.generationMethod, extra: viewModel.document);
                              }
                            }
                          : null)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (viewModel.isLoading) ...[
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      viewModel.fileCount > 1
                          ? 'Analyzing ${viewModel.fileCount} Files...'
                          : 'Analyzing Material...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ] else ...[
                    Text(
                      viewModel.isReadyToProceed
                          ? 'Choose Generation Method'
                          : (viewModel.fileCount > 1
                              ? 'Analyze ${viewModel.fileCount} Files'
                              : 'Analyze Material'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddMoreFilesButton extends StatelessWidget {
  final UploadViewModel viewModel;
  const _AddMoreFilesButton({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    const primary = AppTheme.primaryColor;

    return InkWell(
      onTap: viewModel.isLoading ? null : () => viewModel.pickFile(),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primary.withValues(alpha: 0.3),
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, color: primary, size: 20),
            SizedBox(width: 8),
            Text(
              '+ Add Another File (Up to 3)',
              style: TextStyle(
                color: primary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatBadge extends StatelessWidget {
  final String label;
  const _FormatBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _EmptyPicker extends StatelessWidget {
  final UploadViewModel viewModel;
  const _EmptyPicker({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    const primary = AppTheme.primaryColor;

    return InkWell(
      onTap: viewModel.isLoading ? null : () => viewModel.pickFile(),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.04),
          border: Border.all(
            color: primary.withValues(alpha: 0.3),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_upload_rounded,
                size: 44,
                color: primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tap to select study documents',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Upload 1 to 3 files (PDF, DOCX, PPTX, TXT up to 20 MB each)',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback? onRemove;
  const _FileCard({required this.document, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_iconFor(document.type),
                  color: AppTheme.primaryColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.fileName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '${document.type.label} · ${document.fileSizeMb.toStringAsFixed(1)} MB',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      if (document.hasExtractedText) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle_rounded,
                            color: AppTheme.successColor, size: 14),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 22),
              tooltip: 'Remove file',
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return Icons.picture_as_pdf_rounded;
      case DocumentType.pptx:
        return Icons.slideshow_rounded;
      case DocumentType.docx:
        return Icons.description_rounded;
      case DocumentType.txt:
        return Icons.article_rounded;
      case DocumentType.unsupported:
        return Icons.insert_drive_file_rounded;
    }
  }
}

/// Visual animated loading indicator card displayed while analyzing document text.
class _DocumentAnalysisLoadingAnimation extends StatefulWidget {
  final String? message;
  const _DocumentAnalysisLoadingAnimation({this.message});

  @override
  State<_DocumentAnalysisLoadingAnimation> createState() =>
      _DocumentAnalysisLoadingAnimationState();
}

class _DocumentAnalysisLoadingAnimationState
    extends State<_DocumentAnalysisLoadingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primary = AppTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: primary.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.message ?? 'Analyzing Study Material...',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Parsing document syntax, identifying topics & reading concepts...',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                backgroundColor: Colors.black12,
                valueColor: AlwaysStoppedAnimation<Color>(primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

