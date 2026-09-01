import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_effects.dart';
import '../../../core/utils/nickname_generator.dart';
import '../../../data/models/country_flag_data.dart';
import '../../../data/repositories/league_repository.dart';
import '../../../data/models/game_models.dart';
import '../../../features/game/screens/game_screen.dart';
import '../../../features/profile/providers/player_profile_provider.dart';
import '../../../main_scaffold.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/device_id_service.dart';

/// How this screen was reached, which decides what happens once setup
/// finishes (whether Skip/Continue was chosen either way — this never
/// hard-blocks play).
enum ProfileSetupMode {
  firstLaunch, // end of the first-launch onboarding carousel
  existingUserAnnouncement, // shown once to existing users after this update
  standalone, // opened directly from the League tab or Settings
}

class ProfileSetupScreen extends ConsumerStatefulWidget {
  final ProfileSetupMode mode;
  const ProfileSetupScreen({super.key, required this.mode});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  late final TextEditingController _nicknameController;
  late String _countryCode;
  bool _saving = false;
  bool _linkingGoogle = false;
  bool _linkedGoogle = authService.isLinkedToGoogle;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(playerProfileProvider);
    _nicknameController = TextEditingController(
        text: profile.nickname ?? generateFallbackNickname());
    _countryCode = profile.countryCode;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickCountry() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountryPickerSheet(currentCode: _countryCode),
    );
    if (selected != null) setState(() => _countryCode = selected);
  }

  /// The one entry point for both "back up a new profile" and "restore an
  /// existing one" — [AuthService.linkGoogle] already figures out which of
  /// those happened (see its doc comment), so this just reacts to the
  /// result rather than needing two separate buttons for what is the same
  /// underlying action from the player's point of view.
  Future<void> _signInWithGoogle() async {
    if (_linkingGoogle || _saving) return;
    setState(() => _linkingGoogle = true);

    try {
      final result = await authService.linkGoogle();
      // authService.uid reads FirebaseAuth's currentUser directly — unlike
      // ref.read(uidProvider), which derives from authStateChanges() and
      // can still reflect the pre-switch uid for a moment here, since that
      // stream's update arrives over a separate native->Dart channel than
      // this call's own result.
      final uid = authService.uid;
      if (uid != null) {
        await ref.read(leagueRepositoryProvider).markLinkedGoogle(uid);
      }

      if (result.restoredExistingAccount && uid != null) {
        // Pull the restored account's real nickname/country in before
        // finishing, so "welcome back" actually shows their old profile
        // rather than whatever fallback this fresh install generated.
        try {
          final doc = await ref.read(leagueRepositoryProvider).getPlayer(uid);
          final data = doc.data();
          final nickname = data?['nickname'] as String?;
          final countryCode = data?['countryCode'] as String?;
          if (nickname != null && nickname.isNotEmpty) _nicknameController.text = nickname;
          if (countryCode != null && countryCode.isNotEmpty) _countryCode = countryCode;
        } catch (_) {
          // Non-fatal — they still keep whichever nickname/country was
          // already showing; _finish below still restores the right uid.
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome back — restoring your previous profile…')),
        );
        await _finish();
        return;
      }

      if (!mounted) return;
      setState(() {
        _linkingGoogle = false;
        _linkedGoogle = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed in with Google — your progress will be backed up.')),
      );
    } catch (e, st) {
      debugPrint('Google sign-in from profile setup failed: $e\n$st');
      if (!mounted) return;
      setState(() => _linkingGoogle = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't sign in — try again in a bit.")),
      );
    }
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);

    final notifier = ref.read(playerProfileProvider.notifier);
    final nickname = _nicknameController.text.trim();
    if (nickname.isNotEmpty) await notifier.setNickname(nickname);
    await notifier.setCountryCode(_countryCode);
    await notifier.markSetupComplete();

    final finalProfile = ref.read(playerProfileProvider);
    // authService.uid, not ref.read(uidProvider) — see _signInWithGoogle's
    // comment; _finish can run immediately after a Google link/restore,
    // where the stream-backed provider may still lag the real current user.
    final uid = authService.uid;
    if (uid != null) {
      final repo = ref.read(leagueRepositoryProvider);
      final resolvedNickname = finalProfile.nickname ?? generateFallbackNickname();
      try {
        // Creates the doc on first-ever setup; no-ops if it already
        // exists. ensurePlayerDocument alone is NOT enough for an edit
        // (standalone mode, reached from Settings/League) — it silently
        // does nothing once the doc exists, which is why a nickname
        // change here used to never actually reach Firestore. syncProfile
        // is what actually applies the edit to an existing profile.
        await repo.ensurePlayerDocument(
          uid: uid,
          nickname: resolvedNickname,
          countryCode: finalProfile.countryCode,
          deviceId: await deviceIdService.getDeviceId(),
        );
        await repo.syncProfile(
          uid: uid,
          nickname: resolvedNickname,
          countryCode: finalProfile.countryCode,
        );
      } catch (_) {
        // Non-fatal — the player doc gets created/synced lazily the next
        // time this succeeds (e.g. next app open with connectivity).
      }
    }

    if (!mounted) return;

    switch (widget.mode) {
      case ProfileSetupMode.firstLaunch:
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainScaffold()));
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GameScreen(mode: GameMode.guessFlag)));
      case ProfileSetupMode.existingUserAnnouncement:
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainScaffold()));
      case ProfileSetupMode.standalone:
        Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final country = findCountryByCode(_countryCode);

    return Scaffold(
      backgroundColor: isDark ? AppColors.bg : AppColors.bgLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🏆', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 16),
            Text('Set up your league profile', style: TextStyle(
                fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.w800,
                color: textColor, letterSpacing: -0.5)),
            const SizedBox(height: 6),
            Text("This is what other players see on the leaderboard.",
                style: TextStyle(fontSize: 13, color: textMuted)),
            const SizedBox(height: 20),

            Text('NICKNAME', style: TextStyle(
                fontSize: 10, letterSpacing: 2.5, fontWeight: FontWeight.w700, color: textMuted)),
            const SizedBox(height: 8),
            TextField(
              controller: _nicknameController,
              maxLength: 20,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
              decoration: const InputDecoration(hintText: 'Enter a nickname…'),
            ),

            const SizedBox(height: 12),
            Text('COUNTRY', style: TextStyle(
                fontSize: 10, letterSpacing: 2.5, fontWeight: FontWeight.w700, color: textMuted)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickCountry,
              child: MatteCard(
                isDark: isDark,
                borderRadius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Text(country?.flagEmoji ?? '🏳️', style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(country?.name ?? 'Select a country',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor))),
                  Icon(Icons.expand_more_rounded, color: textMuted),
                ]),
              ),
            ),

            const Spacer(),

            if (_linkedGoogle) ...[
              Row(children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.teal, size: 18),
                const SizedBox(width: 8),
                Text('Signed in with Google — your progress is backed up.',
                    style: TextStyle(fontSize: 12, color: textMuted)),
              ]),
              const SizedBox(height: 14),
            ],

            GestureDetector(
              onTap: _saving ? null : _finish,
              child: Container(
                width: double.infinity, height: 52,
                decoration: BoxDecoration(
                  gradient: AppColors.gradientTealBlue,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: _saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Text(_linkedGoogle ? 'Continue' : 'Continue without signing in', style: const TextStyle(
                          fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
                ),
              ),
            ),

            if (!_linkedGoogle) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _linkingGoogle ? null : _signInWithGoogle,
                child: Container(
                  width: double.infinity, height: 52,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surface2 : AppColors.surface2Light,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: _linkingGoogle
                        ? SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: textMuted))
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            const Text('🔗', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text('Continue with Google', style: TextStyle(
                                fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
                          ]),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: GestureDetector(
                  onTap: _linkingGoogle ? null : _signInWithGoogle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('Played before? Sign in to restore your progress',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textMuted)),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  final String currentCode;
  const _CountryPickerSheet({required this.currentCode});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.surface : AppColors.surfaceLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final results = _query.isEmpty
        ? kCountries
        : kCountries.where((c) => c.name.toLowerCase().contains(_query.toLowerCase())).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: false,
              style: TextStyle(color: textColor),
              decoration: const InputDecoration(hintText: 'Search countries…', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: results.length,
              itemBuilder: (context, i) {
                final c = results[i];
                final selected = c.isoCode == widget.currentCode;
                return ListTile(
                  leading: Text(c.flagEmoji, style: const TextStyle(fontSize: 22)),
                  title: Text(c.name, style: TextStyle(color: textColor, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                  trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.teal) : null,
                  onTap: () => Navigator.of(context).pop(c.isoCode),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
