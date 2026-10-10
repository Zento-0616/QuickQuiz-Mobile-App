import 'dart:async';
import 'package:flutter/material.dart';
import '../app/theme.dart';

/// Full-screen simulated interstitial ad dialog used when native Google Mobile Ads
/// are not yet loaded, unsupported (e.g. desktop/Windows or web development), or in test mode.
/// Automatically dismisses after [autoDismissDuration] (default 3s) and guarantees
/// [onDismissed] is called exactly once.
class InterstitialAdDialog extends StatefulWidget {
  final VoidCallback onDismissed;
  final Duration autoDismissDuration;

  const InterstitialAdDialog({
    super.key,
    required this.onDismissed,
    this.autoDismissDuration = const Duration(seconds: 3),
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onDismissed,
    Duration autoDismissDuration = const Duration(seconds: 3),
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      routeSettings: const RouteSettings(name: '/interstitial-ad-overlay'),
      builder: (ctx) => InterstitialAdDialog(
        onDismissed: onDismissed,
        autoDismissDuration: autoDismissDuration,
      ),
    );
  }

  @override
  State<InterstitialAdDialog> createState() => _InterstitialAdDialogState();
}

class _InterstitialAdDialogState extends State<InterstitialAdDialog> {
  late int _secondsRemaining;
  Timer? _countdownTimer;
  bool _hasDismissed = false;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.autoDismissDuration.inSeconds;
    if (_secondsRemaining <= 0) _secondsRemaining = 3;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 1) {
          _secondsRemaining--;
        } else {
          _countdownTimer?.cancel();
          _dismiss();
        }
      });
    });
  }

  void _dismiss() {
    if (_hasDismissed) return;
    _hasDismissed = true;
    _countdownTimer?.cancel();
    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    widget.onDismissed();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar with Ad Tag, Countdown, and Close Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'ADVERTISEMENT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${_secondsRemaining}s',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Close Ad',
                    onPressed: _dismiss,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Main Promotional Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.heroGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'QuickQuiz Pro Sponsor',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Turn any lecture note or study guide into exam-ready questions instantly with AI precision.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                      fontSize: 14,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _dismiss,
                      child: const Text(
                        'Learn More & Continue',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
