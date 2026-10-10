import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../services/unread_notification_service.dart';
import '../viewmodels/auth_viewmodel.dart';

enum MainTab { home, history, games, messages }

class MainBottomNav extends StatelessWidget {
  final MainTab current;
  const MainBottomNav({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final auth = context.watch<AuthViewModel?>();
    final user = auth?.currentUser;
    final unreadService = UnreadNotificationService();

    if (user != null && !user.isGuest) {
      unreadService.startMonitoring(user.uid);
      if (current == MainTab.messages) {
        unreadService.markMessagesTabSeen();
      }
    }

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: bottomInset > 0 ? bottomInset + 8 : 16,
        top: 6,
      ),
      child: Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.38)
                      : AppTheme.primaryColor.withValues(alpha: 0.12),
                  blurRadius: 24,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: (isDark ? const Color(0xFF6366F1) : AppTheme.primaryColor)
                      .withValues(alpha: isDark ? 0.18 : 0.08),
                  blurRadius: 16,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              const Color(0xFF1E293B).withValues(alpha: 0.52),
                              const Color(0xFF0F172A).withValues(alpha: 0.38),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.65),
                              Colors.white.withValues(alpha: 0.42),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.22)
                          : Colors.white.withValues(alpha: 0.75),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _FloatingNavIconItem(
                        icon: Icons.home_rounded,
                        tooltip: 'Home',
                        isSelected: current == MainTab.home,
                        onTap: () {
                          if (current != MainTab.home) {
                            context.go(AppRoutes.home);
                          }
                        },
                      ),
                      _FloatingNavIconItem(
                        icon: Icons.history_rounded,
                        tooltip: 'History',
                        isSelected: current == MainTab.history,
                        onTap: () {
                          if (current != MainTab.history) {
                            context.go(AppRoutes.history);
                          }
                        },
                      ),
                      _FloatingNavIconItem(
                        icon: Icons.sports_esports_rounded,
                        tooltip: 'Games',
                        isSelected: current == MainTab.games,
                        onTap: () {
                          if (current != MainTab.games) {
                            context.go(AppRoutes.games);
                          }
                        },
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: unreadService.hasUnreadMessages,
                        builder: (context, hasUnread, _) {
                          final showDot = hasUnread && current != MainTab.messages;
                          return _FloatingNavIconItem(
                            icon: Icons.chat_bubble_rounded,
                            tooltip: 'Messages',
                            isSelected: current == MainTab.messages,
                            hasBadge: showDot,
                            onTap: () {
                              unreadService.markMessagesTabSeen();
                              if (current != MainTab.messages) {
                                context.go(AppRoutes.messages);
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingNavIconItem extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final bool hasBadge;
  final VoidCallback onTap;

  const _FloatingNavIconItem({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    this.hasBadge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 22 : 16,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: isSelected ? AppTheme.primaryGradient : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected
                    ? Colors.white
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.55)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.55)),
              ),
              if (hasBadge)
                Positioned(
                  top: -2,
                  right: -3,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF6366F1)
                            : (isDark ? const Color(0xFF0F172A) : Colors.white),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.8),
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
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
