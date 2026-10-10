import 'dart:ui';
import 'package:flutter/material.dart';
import '../app/theme.dart';

enum AdminTab { home, quizzes, scholars, messages, feedback, expControls, settings }

class AdminBottomNavBar extends StatelessWidget {
  final AdminTab currentTab;
  final ValueChanged<AdminTab> onTabSelected;

  const AdminBottomNavBar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottomInset > 0 ? bottomInset + 8 : 16,
        top: 6,
      ),
      child: Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, minHeight: 62),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.5)
                      : AppTheme.primaryColor.withValues(alpha: 0.16),
                  blurRadius: 28,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B).withValues(alpha: 0.92)
                        : Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.14)
                          : Colors.white.withValues(alpha: 0.85),
                      width: 1.2,
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: constraints.maxWidth),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _AdminNavIconItem(
                                icon: Icons.dashboard_rounded,
                                tooltip: 'Home',
                                isSelected: currentTab == AdminTab.home,
                                onTap: () => onTabSelected(AdminTab.home),
                              ),
                              _AdminNavIconItem(
                                icon: Icons.auto_stories_rounded,
                                tooltip: 'Created Quizzes',
                                isSelected: currentTab == AdminTab.quizzes,
                                onTap: () => onTabSelected(AdminTab.quizzes),
                              ),
                              _AdminNavIconItem(
                                icon: Icons.school_rounded,
                                tooltip: 'Scholars',
                                isSelected: currentTab == AdminTab.scholars,
                                onTap: () => onTabSelected(AdminTab.scholars),
                              ),
                              _AdminNavIconItem(
                                icon: Icons.chat_bubble_rounded,
                                tooltip: 'Messages',
                                isSelected: currentTab == AdminTab.messages,
                                onTap: () => onTabSelected(AdminTab.messages),
                              ),
                              _AdminNavIconItem(
                                icon: Icons.rate_review_rounded,
                                tooltip: 'Feedback Hub',
                                isSelected: currentTab == AdminTab.feedback,
                                onTap: () => onTabSelected(AdminTab.feedback),
                              ),
                              _AdminNavIconItem(
                                icon: Icons.tune_rounded,
                                tooltip: 'Daily Scholar EXP Cap',
                                isSelected: currentTab == AdminTab.expControls,
                                onTap: () => onTabSelected(AdminTab.expControls),
                              ),
                              _AdminNavIconItem(
                                icon: Icons.settings_rounded,
                                tooltip: 'Settings',
                                isSelected: currentTab == AdminTab.settings,
                                onTap: () => onTabSelected(AdminTab.settings),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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

class _AdminNavIconItem extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onTap;

  const _AdminNavIconItem({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final unselectedColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : theme.colorScheme.onSurface.withValues(alpha: 0.5);

    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.accentColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.circular(24),
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
            child: Icon(
              icon,
              size: 22,
              color: isSelected ? Colors.white : unselectedColor,
            ),
          ),
        ),
      ),
    );
  }
}
