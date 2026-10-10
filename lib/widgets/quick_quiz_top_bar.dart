import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../utils/constants.dart';
import '../viewmodels/auth_viewmodel.dart';

import '../services/local_storage_service.dart';
import '../widgets/ai_provider_logo.dart';
import '../widgets/gemini_api_key_dialog.dart';
import '../widgets/scholar_feedback_dialog.dart';

/// Top Navigation Bar adhering to QuickQuiz UI guidelines:
/// - Official QuickQuiz icon placed directly beside the "QuickQuiz" title text.
/// - AI Key connection button showing active provider logo and key status.
/// - Feedback button allowing scholars to submit suggestions or issue reports.
/// - Clickable User Profile avatar button positioned in the top-right corner.
class QuickQuizTopBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget>? extraActions;
  final bool showBackButton;
  final bool showFeedbackButton;
  final bool showAiKeyButton;
  final VoidCallback? onBack;

  const QuickQuizTopBar({
    super.key,
    this.extraActions,
    this.showBackButton = false,
    this.showFeedbackButton = true,
    this.showAiKeyButton = true,
    this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final user = auth.currentUser;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: showBackButton ? 2.0 : 12.0,
      leadingWidth: showBackButton ? 46.0 : null,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : null,
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Official QuickQuiz logo directly beside title text
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset(
                'assets/icons/quickquiz_logo.png',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              AppConstants.appName,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 21,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (extraActions != null) ...extraActions!,
        if (showAiKeyButton) const _AiKeyTopBarButton(),
        if (showFeedbackButton)
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            icon: const Icon(Icons.rate_review_outlined, size: 21),
            tooltip: 'Scholar Feedback',
            onPressed: () => ScholarFeedbackDialog.show(context),
          ),
        // Clickable user profile avatar button in top-right corner
        Padding(
          padding: const EdgeInsets.only(right: 10, left: 2),
          child: InkWell(
            onTap: () => context.go(AppRoutes.profile),
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.heroGradient,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: user.photoUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (_, __, ___) => _DefaultAvatar(initials: _getInitials(user.name)),
                          )
                        : _DefaultAvatar(initials: _getInitials(user?.name ?? 'Q')),
                  ),
                ),
                // Level badge chip
                if (auth.isAuthenticated && user != null)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: Text(
                        '${user.level}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
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

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'Q';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}

class _DefaultAvatar extends StatelessWidget {
  final String initials;
  const _DefaultAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primaryColor,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _AiKeyTopBarButton extends StatefulWidget {
  const _AiKeyTopBarButton();

  @override
  State<_AiKeyTopBarButton> createState() => _AiKeyTopBarButtonState();
}

class _AiKeyTopBarButtonState extends State<_AiKeyTopBarButton> {
  final _storage = LocalStorageService();
  AiProvider _provider = AiProvider.gemini;
  bool _hasKey = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final provider = await _storage.getActiveAiProvider();
    final key = await _storage.getApiKeyForProvider(provider);
    if (mounted) {
      setState(() {
        _provider = provider;
        _hasKey = key != null && key.isNotEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      tooltip: _hasKey
          ? '${_provider.displayName} Connected (Tap to change)'
          : 'Connect AI Key (${_provider.displayName})',
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: _hasKey ? const Color(0xFF10B981).withValues(alpha: 0.5) : Colors.transparent,
                width: 1,
              ),
            ),
            child: AiProviderLogo(provider: _provider, size: 17),
          ),
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _hasKey ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
            ),
          ),
        ],
      ),
      onPressed: () async {
        final changed = await showGeminiApiKeyDialog(context);
        if (changed == true || mounted) {
          _refresh();
        }
      },
    );
  }
}
