import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/theme.dart';
import '../utils/toast_helper.dart';

class PhoneNotificationService {
  static final PhoneNotificationService _instance = PhoneNotificationService._internal();
  factory PhoneNotificationService() => _instance;
  PhoneNotificationService._internal();

  static const String _promptedKey = 'has_requested_device_notifications';

  Future<bool> isPermissionGranted() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.notification.status;
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermission({BuildContext? context}) async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.notification.request();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_promptedKey, true);

      if (context != null && context.mounted) {
        if (status.isGranted) {
          showSuccessToast(context, 'Notification permission allowed on your device!');
        } else if (status.isPermanentlyDenied) {
          _showSettingsDialog(context);
        } else if (status.isDenied) {
          showWarningToast(context, 'Notifications are disabled for QuickQuiz.');
        }
      }
      return status.isGranted;
    } catch (e) {
      debugPrint('[PhoneNotificationService] Permission request error: $e');
      return false;
    }
  }

  Future<void> checkAndPromptInitial(BuildContext context) async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyPrompted = prefs.getBool(_promptedKey) ?? false;
      if (alreadyPrompted) return;

      final isGranted = await Permission.notification.isGranted;
      if (!isGranted && context.mounted) {
        _showPermissionRationaleModal(context);
      }
    } catch (_) {}
  }

  void _showPermissionRationaleModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  size: 36,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Allow Phone Notifications',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Get instant alerts for quiz challenges, incoming friend requests, and study reminders directly on your phone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool(_promptedKey, true);
                      },
                      child: const Text('Not Now'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await requestPermission(context: context);
                      },
                      child: const Text('Allow Notifications'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.notifications_off_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Notifications Disabled', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Notification permission was previously denied. You can enable it in your phone settings to receive quiz invites and study alerts.',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
