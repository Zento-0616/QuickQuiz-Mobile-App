import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../models/feedback_model.dart';
import '../services/firestore_service.dart';
import '../utils/toast_helper.dart';
import '../viewmodels/auth_viewmodel.dart';

/// Modal dialog allowing Scholars to submit platform suggestions or issue reports.
class ScholarFeedbackDialog extends StatefulWidget {
  const ScholarFeedbackDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const ScholarFeedbackDialog(),
    );
  }

  @override
  State<ScholarFeedbackDialog> createState() => _ScholarFeedbackDialogState();
}

class _ScholarFeedbackDialogState extends State<ScholarFeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _firestoreService = FirestoreService();

  String _type = 'suggestion'; // 'suggestion' | 'issue_report'
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthViewModel>();
    final user = auth.currentUser;

    setState(() => _isSubmitting = true);

    try {
      final feedback = FeedbackModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user?.uid ?? 'guest_${DateTime.now().millisecondsSinceEpoch}',
        userName: user?.effectiveNickname ?? 'Scholar Guest',
        userEmail: user?.email ?? 'anonymous@scholar.quickquiz',
        type: _type,
        title: _titleCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
        createdAt: DateTime.now(),
        status: 'pending',
      );

      await _firestoreService.submitFeedback(feedback);

      if (mounted) {
        Navigator.of(context).pop();
        showSuccessToast(
          context,
          _type == 'suggestion'
              ? 'Thank you! Your suggestion has been sent to the admin team.'
              : 'Issue report submitted. Our team will investigate shortly.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        showWarningToast(context, 'Failed to submit feedback: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: theme.colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.rate_review_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scholar Feedback',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Share your suggestions or report issues',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
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
                const SizedBox(height: 18),

                // Feedback Type Segmented Selector
                Row(
                  children: [
                    Expanded(
                      child: _buildTypeOption(
                        typeKey: 'suggestion',
                        label: 'Suggestion',
                        icon: Icons.lightbulb_outline_rounded,
                        color: const Color(0xFF10B981),
                        isSelected: _type == 'suggestion',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTypeOption(
                        typeKey: 'issue_report',
                        label: 'Issue Report',
                        icon: Icons.bug_report_outlined,
                        color: const Color(0xFFEF4444),
                        isSelected: _type == 'issue_report',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Title field
                TextFormField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Subject / Title',
                    hintText: _type == 'suggestion'
                        ? 'e.g., Add timed speed rounds'
                        : 'e.g., MCQ Option cut off on tablet',
                    prefixIcon: const Icon(Icons.title_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please provide a brief subject';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Details field
                TextFormField(
                  controller: _messageCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Details / Description',
                    hintText: _type == 'suggestion'
                        ? 'Describe how this feature would enhance your study sessions...'
                        : 'Describe the bug, steps to reproduce, or quiz deck affected...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please describe your feedback';
                    }
                    if (val.trim().length < 10) {
                      return 'Please provide at least 10 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Action buttons wrapped to prevent horizontal overflow on narrow displays
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                      label: Text(
                        _isSubmitting ? 'Submitting...' : 'Submit Feedback',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildTypeOption({
    required String typeKey,
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _type = typeKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.25),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? color : null,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
