import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../providers/theme_provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'routes.dart';
import 'theme.dart';
import '../widgets/game_invitation_overlay.dart';

/// Root widget. ViewModels/services are provided here (via MultiProvider)
/// so any screen can access them without prop-drilling.
class QuickQuizApp extends StatefulWidget {
  final List<SingleChildWidget> providers;
  final String? initialRoute;

  const QuickQuizApp({
    super.key,
    this.providers = const [],
    this.initialRoute,
  });

  @override
  State<QuickQuizApp> createState() => _QuickQuizAppState();
}

class _QuickQuizAppState extends State<QuickQuizApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(
      initialLocation: widget.initialRoute ?? AppRoutes.home,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ...widget.providers,
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return AdminInactivityWatcher(
            router: _router,
            child: MaterialApp.router(
              title: 'QuickQuiz',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeProvider.themeMode,
              routerConfig: _router,
              builder: (context, child) => GameInvitationOverlay(
                router: _router,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Observes user interaction and app lifecycle to enforce the 5-minute inactivity
/// auto-logout strictly for Administrator accounts. Regular scholars are never logged out.
class AdminInactivityWatcher extends StatefulWidget {
  final Widget child;
  final GoRouter router;

  const AdminInactivityWatcher({
    super.key,
    required this.child,
    required this.router,
  });

  @override
  State<AdminInactivityWatcher> createState() => _AdminInactivityWatcherState();
}

class _AdminInactivityWatcherState extends State<AdminInactivityWatcher>
    with WidgetsBindingObserver {
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Periodically check inactivity every 15 seconds
    _inactivityTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _checkInactivity());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkInactivity();
    }
  }

  Future<void> _checkInactivity() async {
    if (!mounted) return;
    final auth = Provider.of<AuthViewModel?>(context, listen: false);
    if (auth != null && (auth.currentUser?.isAdmin ?? false)) {
      final timedOut = await auth.checkAdminInactivityTimeout();
      if (timedOut && mounted) {
        widget.router.go(AppRoutes.auth);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        final auth = Provider.of<AuthViewModel?>(context, listen: false);
        auth?.touchAdminActivity();
      },
      onPointerMove: (_) {
        final auth = Provider.of<AuthViewModel?>(context, listen: false);
        auth?.touchAdminActivity();
      },
      child: widget.child,
    );
  }
}
