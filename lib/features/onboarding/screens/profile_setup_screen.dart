import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_effects.dart';
import '../../../core/utils/nickname_generator.dart';
import '../../../data/models/country_flag_data.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/league_repository.dart';
import '../../../data/models/game_models.dart';
import '../../../features/game/screens/game_screen.dart';
import '../../../features/profile/providers/player_profile_provider.dart';
import '../../../main_scaffold.dart';

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

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);

    final notifier = ref.read(playerProfileProvider.notifier);
    final nickname = _nicknameController.text.trim();
    if (nickname.isNotEmpty) await notifier.setNickname(nickname);
    await notifier.setCountryCode(_countryCode);
    await notifier.markSetupComplete();

    final finalProfile = ref.read(playerProfileProvider);
    final uid = ref.read(uidProvider);
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
            const SizedBox(height: 28),

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
                      : const Text('Continue', style: TextStyle(
                          fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: GestureDetector(
                onTap: _saving ? null : () {
                  _nicknameController.text = '';
                  _finish();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text('Skip for now', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500, color: textMuted)),
                ),
              ),
            ),
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
