import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../utils/toast_helper.dart';
import '../viewmodels/auth_viewmodel.dart';

Future<bool?> showSignInRequiredDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => const _SignInRequiredDialog(),
  );
}

class _SignInRequiredDialog extends StatelessWidget {
  const _SignInRequiredDialog();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, auth, _) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/icons/quickquiz_logo.png',
                    width: 68,
                    height: 68,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.primaryColor,
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Unlock Unlimited Quizzes',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'You\'ve used your free quiz trial! Sign in with Google to create unlimited AI quizzes and track your progress.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              if (auth.hasError) ...[
                const SizedBox(height: 12),
                Text(
                  auth.errorMessage ?? '',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: auth.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.login_rounded, size: 20),
                  label: const Text(
                    'Sign in with Google',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onPressed: auth.isLoading
                      ? null
                      : () async {
                          final success = await auth.signInWithGoogle();
                        if (context.mounted && success) {
                          showSuccessToast(context, 'Signed in successfully! Unlimited quizzes unlocked.');
                          Navigator.of(context).pop(success);
                        } else if (context.mounted) {
                          Navigator.of(context).pop(false);
                        }
                        },
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: auth.isLoading
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Maybe Later'),
              ),
            ],
          ),
        );
      },
    );
  }
}

