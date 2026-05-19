import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/haptics.dart';
import '../../core/theme/app_theme.dart';
import '../../models/profile.dart';
import '../../providers/theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Profile? _profile;
  // ignore: unused_field
  bool _loading = true;
  int _itemCount = 0;
  bool _autoSaveShares = false;
  bool _haptics = true;

  @override
  void initState() {
    super.initState();
    _load();
    SettingsService.getAutoSaveShares()
        .then((v) => mounted ? setState(() => _autoSaveShares = v) : null);
    SettingsService.getHaptics()
        .then((v) => mounted ? setState(() => _haptics = v) : null);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Image cache cleared'),
          duration: Duration(seconds: 2)),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getProfile(),
        SupabaseService.getItemCount(),
      ]);
      if (mounted) {
        setState(() {
          _profile = results[0] as Profile?;
          _itemCount = results[1] as int;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        title: Text('Sign Out',
            style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.textPrimary)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(
                    color: isDark ? Colors.white : AppTheme.textPrimary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : AppTheme.black,
              foregroundColor: isDark ? AppTheme.black : Colors.white,
              elevation: 0,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await SupabaseService.signOut();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();
    final user = SupabaseService.currentUser;
    final firstName = (_profile?.fullName ??
            user?.userMetadata?['full_name'] ?? 'User')
        .split(' ')
        .first as String;
    final fullName =
        _profile?.fullName ?? user?.userMetadata?['full_name'] ?? 'User';
    final email = _profile?.email ?? user?.email ?? '';

    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2A2A2A) : AppTheme.cardBorder;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: isDark ? Colors.white : AppTheme.black,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              Row(
                children: [
                  Text(
                    'Profile',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 24),

              // ── Avatar + info ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? const Color(0xFF2A2A2A)
                            : AppTheme.grey100,
                        border: Border.all(color: borderColor),
                      ),
                      child: Center(
                        child: Text(
                          firstName.isNotEmpty
                              ? firstName[0].toUpperCase()
                              : 'U',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(email,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13)),
                          if (_profile?.isPro == true)
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.black,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'PRO',
                                style: TextStyle(
                                  color: isDark
                                      ? AppTheme.black
                                      : Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 12),

              // ── Stats ────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatBox(
                      value: _itemCount.toString(),
                      label: 'Items',
                      icon: Icons.inventory_2_outlined,
                      isDark: isDark,
                    ),
                    Container(
                        width: 1,
                        height: 36,
                        color: borderColor),
                    _StatBox(
                      value: (_profile?.foldersCount ?? 0).toString(),
                      label: 'Folders',
                      icon: Icons.folder_outlined,
                      isDark: isDark,
                    ),
                    Container(
                        width: 1,
                        height: 36,
                        color: borderColor),
                    _StatBox(
                      value: '${_profile?.streakDays ?? 0}d',
                      label: 'Streak',
                      icon: Icons.local_fire_department_outlined,
                      isDark: isDark,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 24),

              // ── Preferences ──────────────────────────────────────────
              _SectionTitle('Preferences', isDark),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                title: 'Dark Mode',
                isDark: isDark,
                trailing: Switch(
                  value: themeProvider.isDark,
                  onChanged: (_) => themeProvider.toggle(),
                  activeColor: isDark ? Colors.white : AppTheme.black,
                  activeTrackColor:
                      isDark ? AppTheme.grey700 : AppTheme.grey300,
                  inactiveThumbColor: AppTheme.grey300,
                  inactiveTrackColor: AppTheme.grey100,
                ),
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.bolt_outlined,
                title: 'Auto-save shared links',
                subtitle: 'Skip the Save button — save instantly on share',
                isDark: isDark,
                trailing: Switch(
                  value: _autoSaveShares,
                  onChanged: (v) async {
                    setState(() => _autoSaveShares = v);
                    await SettingsService.setAutoSaveShares(v);
                  },
                  activeColor: isDark ? Colors.white : AppTheme.black,
                  activeTrackColor:
                      isDark ? AppTheme.grey700 : AppTheme.grey300,
                  inactiveThumbColor: AppTheme.grey300,
                  inactiveTrackColor: AppTheme.grey100,
                ),
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.vibration,
                title: 'Haptic feedback',
                subtitle: 'Subtle vibrations on taps & actions',
                isDark: isDark,
                trailing: Switch(
                  value: _haptics,
                  onChanged: (v) async {
                    setState(() => _haptics = v);
                    Haptics.enabled = v;
                    await SettingsService.setHaptics(v);
                    if (v) Haptics.tap();
                  },
                  activeColor: isDark ? Colors.white : AppTheme.black,
                  activeTrackColor:
                      isDark ? AppTheme.grey700 : AppTheme.grey300,
                  inactiveThumbColor: AppTheme.grey300,
                  inactiveTrackColor: AppTheme.grey100,
                ),
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Push, email & weekly digest',
                isDark: isDark,
                trailing: Icon(Icons.chevron_right,
                    color: AppTheme.textSecondary),
                onTap: () {},
              ),
              const SizedBox(height: 24),

              // ── Account ──────────────────────────────────────────────
              _SectionTitle('Account', isDark),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.person_outline,
                title: 'Edit Profile',
                isDark: isDark,
                trailing: Icon(Icons.chevron_right,
                    color: AppTheme.textSecondary),
                onTap: () {},
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.lock_outline,
                title: 'Change Password',
                isDark: isDark,
                trailing: Icon(Icons.chevron_right,
                    color: AppTheme.textSecondary),
                onTap: () {},
              ),

              const SizedBox(height: 24),

              // ── Storage ──────────────────────────────────────────────
              _SectionTitle('Storage', isDark),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.cleaning_services_outlined,
                title: 'Clear image cache',
                subtitle: 'Free up space used by thumbnails',
                isDark: isDark,
                trailing: Icon(Icons.chevron_right,
                    color: AppTheme.textSecondary),
                onTap: _clearImageCache,
              ),
              const SizedBox(height: 24),

              // ── Support ──────────────────────────────────────────────
              _SectionTitle('Support', isDark),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.help_outline,
                title: 'Help & FAQ',
                isDark: isDark,
                trailing: Icon(Icons.chevron_right,
                    color: AppTheme.textSecondary),
                onTap: () => _openUrl('https://github.com/naodt1/stashh_app'),
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.feedback_outlined,
                title: 'Send feedback',
                subtitle: 'Report a bug or request a feature',
                isDark: isDark,
                trailing: Icon(Icons.chevron_right,
                    color: AppTheme.textSecondary),
                onTap: () => _openUrl(
                    'mailto:feedback@stashh.app?subject=Stashh%20feedback'),
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                isDark: isDark,
                trailing: Icon(Icons.chevron_right,
                    color: AppTheme.textSecondary),
                onTap: () => _openUrl('https://stashh.app/privacy'),
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'About Stashh',
                subtitle: 'Version 1.0.0',
                isDark: isDark,
                trailing: Icon(Icons.chevron_right,
                    color: AppTheme.textSecondary),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Stashh',
                  applicationVersion: '1.0.0',
                  applicationLegalese:
                      'Your AI second brain for saved videos & links.',
                ),
              ),
              const SizedBox(height: 24),

              // ── Sign out ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text(
                    'Sign Out',
                    style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        isDark ? Colors.white : AppTheme.textPrimary,
                    side: BorderSide(color: borderColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Stashh v1.0.0',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool isDark;

  const _StatBox({
    required this.value,
    required this.label,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon,
            color: isDark ? AppTheme.grey300 : AppTheme.grey700, size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionTitle(this.title, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.spaceGrotesk(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppTheme.textSecondary,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final bool isDark;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.trailing,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark
                  ? const Color(0xFF2A2A2A)
                  : AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: isDark ? AppTheme.grey300 : AppTheme.grey700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}
