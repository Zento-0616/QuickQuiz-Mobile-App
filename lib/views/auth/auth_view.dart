import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../services/profanity_filter_service.dart';
import '../../utils/toast_helper.dart';
import '../../viewmodels/auth_viewmodel.dart';

/// Comprehensive Authentication view supporting:
/// - Native Email/Password Registration (Real Name, Age, Email, Password, Nickname)
/// - Native Email/Password Login
/// - Google Sign-In
/// - Password Reset & Email Verification flow
/// - Guest mode fallback
class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Sign In controllers
  final _signInEmailCtrl = TextEditingController();
  final _signInPassCtrl = TextEditingController();
  bool _obscureSignInPass = true;

  // Register controllers
  final _regNameCtrl = TextEditingController();
  final _regAgeCtrl = TextEditingController(text: '18');
  final _regNicknameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  final _regConfirmPassCtrl = TextEditingController();
  bool _obscureRegPass = true;
  bool _obscureRegConfirmPass = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signInEmailCtrl.dispose();
    _signInPassCtrl.dispose();
    _regNameCtrl.dispose();
    _regAgeCtrl.dispose();
    _regNicknameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPassCtrl.dispose();
    _regConfirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleEmailSignIn(BuildContext context) async {
    final email = _signInEmailCtrl.text.trim();
    final pass = _signInPassCtrl.text;

    if (email.isEmpty || !email.contains('@')) {
      showWarningToast(context, 'Please enter a valid email address.');
      return;
    }
    if (pass.isEmpty) {
      showWarningToast(context, 'Please enter your password.');
      return;
    }

    final auth = context.read<AuthViewModel>();
    final success =
        await auth.signInWithEmailPassword(email: email, password: pass);
    if (success && context.mounted) {
      showSuccessToast(context, 'Signed in successfully! Welcome back.');
      context.go(AppRoutes.home);
    }
  }

  Future<void> _handleRegistration(BuildContext context) async {
    final realName = _regNameCtrl.text.trim();
    final ageStr = _regAgeCtrl.text.trim();
    final nickname = _regNicknameCtrl.text.trim();
    final email = _regEmailCtrl.text.trim();
    final pass = _regPassCtrl.text;
    final confirmPass = _regConfirmPassCtrl.text;

    if (realName.isEmpty) {
      showWarningToast(context, 'Please enter your real name.');
      return;
    }
    final age = int.tryParse(ageStr);
    if (age == null || age < 5 || age > 120) {
      showWarningToast(context, 'Please enter a valid age between 5 and 120.');
      return;
    }

    final nickErr = ProfanityFilterService.validateNickname(nickname);
    if (nickErr != null) {
      showWarningToast(context, nickErr);
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      showWarningToast(context, 'Please enter a valid email address.');
      return;
    }
    if (pass.length < 6) {
      showWarningToast(context, 'Password must be at least 6 characters.');
      return;
    }
    if (pass != confirmPass) {
      showWarningToast(context, 'Passwords do not match.');
      return;
    }

    final auth = context.read<AuthViewModel>();
    final success = await auth.registerWithEmailPassword(
      email: email,
      password: pass,
      realName: realName,
      age: age,
      nickname: nickname,
    );

    if (success && context.mounted) {
      showSuccessToast(
          context, 'Account created! Verification link sent to $email.');
      context.go(AppRoutes.home);
    }
  }

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    final auth = context.read<AuthViewModel>();
    final success = await auth.signInWithGoogle();
    if (success && context.mounted) {
      showSuccessToast(context, 'Signed in with Google! Welcome.');
      context.go(AppRoutes.home);
    }
  }

  void _showPasswordResetDialog(BuildContext context) {
    final resetEmailCtrl =
        TextEditingController(text: _signInEmailCtrl.text.trim());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Reset Password',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your registered email address and we will send a password reset link.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final email = resetEmailCtrl.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                showWarningToast(context, 'Please enter a valid email.');
                return;
              }
              Navigator.pop(ctx);
              final auth = context.read<AuthViewModel>();
              final success = await auth.sendPasswordResetEmail(email);
              if (success && context.mounted) {
                showSuccessToast(
                    context, 'Password reset link sent to $email!');
              }
            },
            child: const Text('Send Reset Link',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1E1B4B),
                  Color(0xFF312E81),
                  Color(0xFF4C1D95)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // Official Logo beside App Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/icons/quickquiz_logo.png',
                          width: 44,
                          height: 44,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.auto_awesome_rounded,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'QuickQuiz',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AI-Powered Exam Preparation & Quiz Arena',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Auth Tabs: Sign In vs Create Account
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      labelColor: const Color(0xFF0F172A),
                      unselectedLabelColor:
                          Colors.white.withValues(alpha: 0.85),
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 14.5),
                      unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                      tabs: const [
                        Tab(text: 'Sign In'),
                        Tab(text: 'Create Account'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Error Banner
                  if (auth.hasError) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Colors.redAccent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              auth.errorMessage ?? '',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Tab Views Content Container (Enhanced Glassmorphism)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) {
                        return _tabController.index == 0
                            ? _buildSignInTab(context, auth)
                            : _buildRegisterTab(context, auth);
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Google Sign-In Button with Authentic Logo & Elevated Surface
                  Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1F2937),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: auth.isLoading
                          ? null
                          : () => _handleGoogleSignIn(context),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _GoogleLogo(),
                          SizedBox(width: 12),
                          Text(
                            'Continue with Google',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Guest Mode Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                      ),
                      onPressed: auth.isLoading
                          ? null
                          : () => context.go(AppRoutes.home),
                      child: Text(
                        'Continue as Guest (1 free quiz)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // Tab 1: Sign In
  // -------------------------------------------------------------------

  Widget _buildSignInTab(BuildContext context, AuthViewModel auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Email Address',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: _signInEmailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: _authFieldDecoration(
              hint: 'you@quickquiz.com', icon: Icons.email_outlined),
        ),
        const SizedBox(height: 14),
        const Text('Password',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: _signInPassCtrl,
          obscureText: _obscureSignInPass,
          style: const TextStyle(color: Colors.white),
          decoration: _authFieldDecoration(
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            suffix: IconButton(
              icon: Icon(
                _obscureSignInPass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.white70,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscureSignInPass = !_obscureSignInPass),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _showPasswordResetDialog(context),
            child: const Text('Forgot Password?',
                style: TextStyle(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA855F7)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed:
                auth.isLoading ? null : () => _handleEmailSignIn(context),
            child: auth.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: Colors.white))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.login_rounded, size: 20, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Sign In',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16.5,
                          letterSpacing: 0.3,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // Tab 2: Create Account
  // -------------------------------------------------------------------

  Widget _buildRegisterTab(BuildContext context, AuthViewModel auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Real Name & Age Row
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Real Name',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _regNameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _authFieldDecoration(
                        hint: 'Reynaldo Seroje', icon: Icons.badge_outlined),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Age',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _regAgeCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _authFieldDecoration(
                        hint: '18', icon: Icons.cake_outlined),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Initial Nickname (Profanity filtered)
        const Text('Nickname (Display Name)',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: _regNicknameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: _authFieldDecoration(
              hint: 'Naldz01', icon: Icons.alternate_email_rounded),
        ),
        const SizedBox(height: 12),

        // Email
        const Text('Email Address',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: _regEmailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: _authFieldDecoration(
              hint: 'you@quickquiz.com', icon: Icons.email_outlined),
        ),
        const SizedBox(height: 12),

        // Password
        const Text('Password (min 6 characters)',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: _regPassCtrl,
          obscureText: _obscureRegPass,
          style: const TextStyle(color: Colors.white),
          decoration: _authFieldDecoration(
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            suffix: IconButton(
              icon: Icon(
                  _obscureRegPass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white70,
                  size: 18),
              onPressed: () =>
                  setState(() => _obscureRegPass = !_obscureRegPass),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Confirm Password
        const Text('Confirm Password',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: _regConfirmPassCtrl,
          obscureText: _obscureRegConfirmPass,
          style: const TextStyle(color: Colors.white),
          decoration: _authFieldDecoration(
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            suffix: IconButton(
              icon: Icon(
                  _obscureRegConfirmPass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white70,
                  size: 18),
              onPressed: () => setState(
                  () => _obscureRegConfirmPass = !_obscureRegConfirmPass),
            ),
          ),
        ),

        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA855F7)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed:
                auth.isLoading ? null : () => _handleRegistration(context),
            child: auth.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: Colors.white))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add_alt_1_rounded,
                          size: 20, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Create Account',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16.5,
                          letterSpacing: 0.3,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  InputDecoration _authFieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.white70, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.25),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.amberAccent, width: 1.5),
      ),
    );
  }
}

/// Official Multi-Color Google "G" Vector Logo
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  static const String _svgData = '''
<svg viewBox="0 0 24 24" width="24" height="24" xmlns="http://www.w3.org/2000/svg">
  <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
  <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
  <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z" fill="#FBBC05"/>
  <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z" fill="#EA4335"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _svgData,
      width: 20,
      height: 20,
    );
  }
}
