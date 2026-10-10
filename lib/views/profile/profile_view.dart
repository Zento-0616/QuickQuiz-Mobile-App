import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../providers/theme_provider.dart';
import '../../services/phone_notification_service.dart';
import '../../services/profanity_filter_service.dart';
import '../../utils/toast_helper.dart';
import '../../viewmodels/auth_viewmodel.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go(AppRoutes.home);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile & Settings', style: TextStyle(fontWeight: FontWeight.w800)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go(AppRoutes.home),
          ),
          actions: [
            if (auth.isAuthenticated && (auth.currentUser?.isAdmin ?? false))
              IconButton(
                icon: const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.accentColor),
                tooltip: 'Admin Dashboard',
                onPressed: () => context.push(AppRoutes.admin),
              ),
          ],
        ),
        body: SafeArea(
          child: auth.isAuthenticated
              ? _AuthenticatedProfile(auth: auth)
              : _GuestProfile(auth: auth),
        ),
      ),
    );
  }
}

class _AuthenticatedProfile extends StatefulWidget {
  final AuthViewModel auth;
  const _AuthenticatedProfile({required this.auth});

  @override
  State<_AuthenticatedProfile> createState() => _AuthenticatedProfileState();
}

class _AuthenticatedProfileState extends State<_AuthenticatedProfile> {
  late TextEditingController _nameCtrl;
  late TextEditingController _nicknameCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _bioCtrl;
  late String _selectedRegion;
  String? _nicknameError;
  bool _isEditingProfile = false;

  static const _regionOptions = [
    {'code': 'US', 'name': 'United States', 'flag': '🇺🇸'},
    {'code': 'PH', 'name': 'Philippines', 'flag': '🇵🇭'},
    {'code': 'GB', 'name': 'United Kingdom', 'flag': '🇬🇧'},
    {'code': 'CA', 'name': 'Canada', 'flag': '🇨🇦'},
    {'code': 'AU', 'name': 'Australia', 'flag': '🇦🇺'},
    {'code': 'DE', 'name': 'Germany', 'flag': '🇩🇪'},
    {'code': 'JP', 'name': 'Japan', 'flag': '🇯🇵'},
    {'code': 'SG', 'name': 'Singapore', 'flag': '🇸🇬'},
    {'code': 'IN', 'name': 'India', 'flag': '🇮🇳'},
    {'code': 'BR', 'name': 'Brazil', 'flag': '🇧🇷'},
  ];

  @override
  void initState() {
    super.initState();
    final u = widget.auth.currentUser!;
    _nameCtrl = TextEditingController(text: u.name);
    _nicknameCtrl = TextEditingController(text: u.effectiveNickname);
    _ageCtrl = TextEditingController(text: '${u.age}');
    _bioCtrl = TextEditingController(text: u.bio ?? '');
    _selectedRegion = u.region.isNotEmpty ? u.region : 'US';

    if (u.photoUrl == null || u.photoUrl!.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.auth.syncGoogleAccountProfile();
        }
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nicknameCtrl.dispose();
    _ageCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfileChanges() async {
    final name = _nameCtrl.text.trim();
    final nickname = _nicknameCtrl.text.trim();
    final age = int.tryParse(_ageCtrl.text.trim()) ?? widget.auth.currentUser!.age;
    final bio = _bioCtrl.text.trim();

    final validationError = ProfanityFilterService.validateNickname(nickname);
    if (validationError != null) {
      setState(() => _nicknameError = validationError);
      showWarningToast(context, validationError);
      return;
    }

    setState(() => _nicknameError = null);
    await widget.auth.updateProfile(
      name: name,
      nickname: nickname,
      age: age,
      bio: bio,
      region: _selectedRegion,
    );

    setState(() => _isEditingProfile = false);
    if (mounted) {
      showSuccessToast(context, 'Profile updated successfully!');
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text('Change Password', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verify your current password before setting a new one.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: currentPassCtrl,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPassCtrl,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.vpn_key_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPassCtrl,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final current = currentPassCtrl.text;
                final newPass = newPassCtrl.text;
                final confirm = confirmPassCtrl.text;

                if (current.isEmpty) {
                  showWarningToast(context, 'Please enter your current password.');
                  return;
                }
                if (newPass.length < 6) {
                  showWarningToast(context, 'New password must be at least 6 characters.');
                  return;
                }
                if (newPass != confirm) {
                  showWarningToast(context, 'New passwords do not match.');
                  return;
                }

                Navigator.pop(ctx);
                final success = await widget.auth.changePassword(
                  currentPassword: current,
                  newPassword: newPass,
                );

                if (context.mounted) {
                  if (success) {
                    showSuccessToast(context, 'Password updated successfully!');
                  } else {
                    showWarningToast(context, widget.auth.errorMessage ?? 'Password verification failed.');
                  }
                }
              },
              child: const Text('Save Password', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  void _openAvatarPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_circle_rounded, color: AppTheme.primaryColor, size: 24),
                const SizedBox(width: 8),
                const Text('Profile Picture & Avatar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  Navigator.pop(ctx);
                  final success = await widget.auth.syncGoogleAccountProfile();
                  if (context.mounted) {
                    if (success) {
                      showSuccessToast(context, 'Synced Google account profile picture & details!');
                    } else {
                      showInfoToast(context, 'Google profile picture is already up-to-date.');
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.12),
                        const Color(0xFF6366F1).withValues(alpha: 0.06),
                      ],
                    ),
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.sync_rounded, size: 22, color: Color(0xFF4285F4)),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sync with Google Account',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Fetch and sync your Google profile photo & info',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),
            const Text('Choose Avatar Preset', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _avatarOption('🎓', 'Scholar', 'https://api.dicebear.com/7.x/bottts/png?seed=Scholar'),
                _avatarOption('⚡', 'Speedster', 'https://api.dicebear.com/7.x/bottts/png?seed=Speedster'),
                _avatarOption('🚀', 'Explorer', 'https://api.dicebear.com/7.x/bottts/png?seed=Explorer'),
                _avatarOption('🧠', 'Genius', 'https://api.dicebear.com/7.x/bottts/png?seed=Genius'),
                _avatarOption('🏆', 'Champion', 'https://api.dicebear.com/7.x/bottts/png?seed=Champion'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarOption(String emoji, String label, String avatarUrl) {
    return InkWell(
      onTap: () async {
        Navigator.pop(context);
        await widget.auth.updateProfile(photoUrl: avatarUrl);
        if (mounted) {
          showSuccessToast(context, 'Avatar updated to $label!');
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.currentUser!;
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        children: [
          Center(
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.heroGradient,
                  ),
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: theme.scaffoldBackgroundColor,
                    child: user.photoUrl != null && user.photoUrl!.isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: user.photoUrl!,
                              fit: BoxFit.cover,
                              width: 92,
                              height: 92,
                              errorWidget: (_, __, ___) => _InitialText(name: user.name),
                            ),
                          )
                        : _InitialText(name: user.name),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: () => _openAvatarPicker(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppTheme.accentColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (user.regionFlag.isNotEmpty) ...[
                Text(
                  user.regionFlag,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                user.effectiveNickname,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              if (user.isAdmin) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ADMIN',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.badge_outlined, size: 15, color: Colors.grey),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  user.name.isNotEmpty ? user.name : 'Scholar',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '• ${user.age} yrs',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    user.email,
                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          if (user.bio != null && user.bio!.isNotEmpty && !_isEditingProfile)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '“${user.bio}”',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  fontSize: 13,
                ),
              ),
            ),

          const SizedBox(height: 12),

          if (!_isEditingProfile)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Edit Profile & Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              onPressed: () => setState(() => _isEditingProfile = true),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Full Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Enter your full name',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nickname (Checked by Bad-Word Filter)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nicknameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Enter new nickname',
                      errorText: _nicknameError,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Age', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Enter your age',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Country / Region', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _regionOptions.any((r) => r['code'] == _selectedRegion) ? _selectedRegion : 'US',
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: _regionOptions.map((r) {
                      return DropdownMenuItem<String>(
                        value: r['code'],
                        child: Text('${r['flag']} ${r['name']} (${r['code']})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedRegion = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Personal Bio', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _bioCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Share a bit about yourself...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.sync_rounded, size: 16, color: Color(0xFF4285F4)),
                        label: const Text('Sync Google', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        onPressed: () async {
                          final success = await widget.auth.syncGoogleAccountProfile();
                          if (!context.mounted) return;
                          final current = widget.auth.currentUser;
                          if (current != null) {
                            _nameCtrl.text = current.name;
                            _nicknameCtrl.text = current.effectiveNickname;
                            _ageCtrl.text = '${current.age}';
                            _bioCtrl.text = current.bio ?? '';
                          }
                          if (success) {
                            showSuccessToast(context, 'Synced Google account details & picture!');
                          } else {
                            showInfoToast(context, 'Google account is already up-to-date.');
                          }
                        },
                      ),
                      const Spacer(),
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () => setState(() => _isEditingProfile = false),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saveProfileChanges,
                        child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Account Information', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 12),
                  _AccountDetailRow(
                    label: 'Full Name',
                    value: user.name.isNotEmpty ? user.name : 'Scholar',
                    icon: Icons.person_outline_rounded,
                  ),
                  const Divider(height: 16),
                  _AccountDetailRow(
                    label: 'Nickname',
                    value: user.effectiveNickname,
                    icon: Icons.alternate_email_rounded,
                  ),
                  const Divider(height: 16),
                  _AccountDetailRow(
                    label: 'Age',
                    value: '${user.age} years old',
                    icon: Icons.cake_outlined,
                  ),
                  const Divider(height: 16),
                  _AccountDetailRow(
                    label: 'Email Address',
                    value: user.email,
                    icon: Icons.email_outlined,
                  ),
                  const Divider(height: 16),
                  _AccountDetailRow(
                    label: 'Country / Region',
                    value: '${user.regionFlag} ${user.region}',
                    icon: Icons.public_rounded,
                  ),
                  const Divider(height: 16),
                  _AccountDetailRow(
                    label: 'Personal Bio',
                    value: user.bio != null && user.bio!.isNotEmpty ? user.bio! : 'No bio provided.',
                    icon: Icons.notes_rounded,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: _GamifiedStatCard(
                  label: 'Level',
                  value: '${user.level}',
                  icon: Icons.military_tech_rounded,
                  color: AppTheme.accentColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GamifiedStatCard(
                  label: 'Total EXP',
                  value: '${user.exp}',
                  icon: Icons.bolt_rounded,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GamifiedStatCard(
                  label: 'Streak',
                  value: '${user.dailyStreak}d',
                  icon: Icons.local_fire_department_rounded,
                  color: Colors.deepOrange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GamifiedStatCard(
                  label: 'Win Rate',
                  value: '${user.winRate}%',
                  icon: Icons.emoji_events_rounded,
                  color: AppTheme.successColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          if (user.isAdmin) ...[
            Card(
              color: AppTheme.accentColor.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppTheme.accentColor.withValues(alpha: 0.4)),
              ),
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.accentColor, size: 28),
                title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Manage Quiz Decks, Registered Users & Analytics'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () => context.push(AppRoutes.admin),
              ),
            ),
            const SizedBox(height: 16),
          ],

          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('App Settings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  SwitchListTile(
                    title: const Text('Dark Theme'),
                    secondary: const Icon(Icons.dark_mode_rounded),
                    value: themeProvider.isDarkMode,
                    onChanged: (val) => themeProvider.toggleTheme(val),
                  ),
                  SwitchListTile(
                    title: const Text('Haptic Feedback'),
                    secondary: const Icon(Icons.vibration_rounded),
                    value: user.hapticsEnabled,
                    onChanged: (val) => widget.auth.updateProfile(hapticsEnabled: val),
                  ),
                  SwitchListTile(
                    title: const Text('Sound Effects'),
                    secondary: const Icon(Icons.volume_up_rounded),
                    value: user.soundEnabled,
                    onChanged: (val) => widget.auth.updateProfile(soundEnabled: val),
                  ),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_android_rounded, color: AppTheme.primaryColor, size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cellphone System Notifications',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Allow QuickQuiz alerts on this phone',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => PhoneNotificationService().requestPermission(context: context),
                          child: const Text('Allow / Check', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    dense: true,
                    title: const Text('New Quiz Drops'),
                    value: user.notifyQuizDrops,
                    onChanged: (val) async {
                      if (val) {
                        await PhoneNotificationService().requestPermission(context: context);
                      }
                      widget.auth.updateProfile(notifyQuizDrops: val);
                    },
                  ),
                  SwitchListTile(
                    dense: true,
                    title: const Text('Friend Requests'),
                    value: user.notifyFriendRequests,
                    onChanged: (val) async {
                      if (val) {
                        await PhoneNotificationService().requestPermission(context: context);
                      }
                      widget.auth.updateProfile(notifyFriendRequests: val);
                    },
                  ),
                  SwitchListTile(
                    dense: true,
                    title: const Text('Chat Messages'),
                    value: user.notifyChatMessages,
                    onChanged: (val) async {
                      if (val) {
                        await PhoneNotificationService().requestPermission(context: context);
                      }
                      widget.auth.updateProfile(notifyChatMessages: val);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text('Security & Credentials', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                ListTile(
                  leading: const Icon(Icons.lock_reset_rounded, color: AppTheme.primaryColor),
                  title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Verify current password to set new password'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () => _showChangePasswordDialog(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w800)),
              onPressed: () => _handleSignOut(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of QuickQuiz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await widget.auth.signOut();
      if (context.mounted) {
        GoRouter.of(context).go(AppRoutes.home);
      }
    }
  }
}

class _GuestProfile extends StatelessWidget {
  final AuthViewModel auth;
  const _GuestProfile({required this.auth});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded, size: 56, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 20),
            const Text(
              'Guest Account',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a QuickQuiz account or sign in to save progression, level up, and connect with friends.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.login_rounded),
                label: const Text('Sign In / Register', style: TextStyle(fontWeight: FontWeight.w800)),
                onPressed: () => context.go(AppRoutes.auth),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InitialText extends StatelessWidget {
  final String name;
  const _InitialText({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'Q';
    return Text(
      initials,
      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.primaryColor),
    );
  }
}

class _GamifiedStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _GamifiedStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _AccountDetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}