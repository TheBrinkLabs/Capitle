import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_effects.dart';
import '../../../data/models/capital_entry.dart';
import '../../../data/models/game_models.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../../../data/models/outline_assets.dart';
import '../../home/widgets/banner_ad_widget.dart' show BannerPosition;
import '../../../core/utils/banner_position_route.dart';
import '../../../core/widgets/clue_rewarded_ad.dart';
import '../../../core/widgets/location_reveal_map.dart';
import '../../../core/widgets/practice_record_celebration.dart';
import '../../../core/utils/providers.dart';
import '../providers/practice_provider.dart';
import '../widgets/practice_session_widgets.dart';
import 'practice_neighbours_screen.dart';
import 'practice_population_screen.dart';

// ── Practice Menu ──────────────────────────────────────────────────────────

class PracticeMenuScreen extends ConsumerStatefulWidget {
  const PracticeMenuScreen({super.key});

  @override
  ConsumerState<PracticeMenuScreen> createState() => _PracticeMenuScreenState();
}

class _PracticeMenuScreenState extends ConsumerState<PracticeMenuScreen>
    with BannerPositionRoute<PracticeMenuScreen> {
  @override
  BannerPosition get bannerPosition => BannerPosition.bottom;

  int _poolSizeFor(GameMode mode, String? region) {
    final base = mode == GameMode.guessOutline
        ? kCapitals.where((e) => kOutlineAssetPath.containsKey(e.country))
        : kCapitals;
    return region == null ? base.length : base.where((e) => e.continent == region).length;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bg : AppColors.bgLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final surface2 = isDark ? AppColors.surface2 : AppColors.surface2Light;
    final region = ref.watch(practiceRegionProvider);
    ref.watch(practiceBestScoresVersionProvider);
    final repo = ref.read(gameRepositoryProvider);

    String? bestFooter(GameMode mode) {
      final total = _poolSizeFor(mode, region);
      if (total == 0) return null;
      final best = repo.loadPracticeBest(mode, region);
      return best > 0 ? '🏆 Best: $best/$total' : null;
    }

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar:
          const SafeArea(top: false, bottom: true, child: SizedBox(height: 50)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: surface2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 16,
                        color: isDark ? AppColors.textDimDark : AppColors.textDimLight),
                  ),
                ),
                const SizedBox(width: 14),
                Text('Practice Mode', style: TextStyle(
                  fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.w800,
                  color: textColor, letterSpacing: -0.5,
                )),
              ]),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 50),
                child: Text('No limits, no stats — just geography.',
                    style: TextStyle(fontSize: 13, color: textMuted)),
              ),
              const SizedBox(height: 28),

              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withOpacity(0.1),
                    border: Border.all(color: AppColors.blue.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('🎯', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text("Results don't count toward stats or streaks",
                        style: TextStyle(fontSize: 12, color: AppColors.blue, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),

              const SizedBox(height: 28),

              Text('REGION', style: TextStyle(
                fontSize: 10, letterSpacing: 2.5, fontWeight: FontWeight.w700, color: textMuted)),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kPracticeRegions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final r = kPracticeRegions[i];
                    final selected = r == region;
                    return GestureDetector(
                      onTap: () => ref.read(practiceRegionProvider.notifier).state = r,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.teal.withOpacity(0.15) : surface2,
                          border: Border.all(
                            color: selected ? AppColors.teal
                                : (isDark ? AppColors.borderDark : AppColors.borderLight),
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(child: Text(practiceRegionLabel(r), style: TextStyle(
                          fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? AppColors.teal
                              : (isDark ? AppColors.textDimDark : AppColors.textDimLight),
                        ))),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              _PracticeModeCard(
                emoji: '🌍',
                title: 'Guess the Country',
                subtitle: 'Capital shown — name the country',
                footer: bestFooter(GameMode.guessCountry),
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D4AA), Color(0xFF0099FF)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PracticeGameScreen(mode: GameMode.guessCountry))),
              ),
              const SizedBox(height: 12),
              _PracticeModeCard(
                emoji: '🗺️',
                title: 'Guess the Capital',
                subtitle: 'Country shown — name the capital',
                footer: bestFooter(GameMode.guessCapital),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0099FF), Color(0xFF7B61FF)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PracticeGameScreen(mode: GameMode.guessCapital))),
              ),
              const SizedBox(height: 12),
              _PracticeModeCard(
                emoji: '🚩',
                title: 'Guess the Flag',
                subtitle: 'Flag shown — name the country',
                footer: bestFooter(GameMode.guessFlag),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PracticeGameScreen(mode: GameMode.guessFlag))),
              ),
              const SizedBox(height: 12),
              _PracticeModeCard(
                emoji: '🤝',
                title: 'Neighbours',
                subtitle: 'Guess how many land borders',
                footer: bestFooter(GameMode.guessNeighbours),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFC845), Color(0xFFFF8E53)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PracticeNeighboursScreen())),
              ),
              const SizedBox(height: 12),
              _PracticeModeCard(
                emoji: '📊',
                title: 'Population',
                subtitle: 'Which capital city is bigger?',
                footer: 'Uses all countries · unlimited',
                gradient: const LinearGradient(
                  colors: [Color(0xFF7B61FF), Color(0xFF0099FF)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                footerColor: textMuted,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PracticePopulationScreen())),
              ),
              const SizedBox(height: 12),
              _PracticeModeCard(
                emoji: '🧩',
                title: 'Outline',
                subtitle: 'Shape shown — name the country',
                footer: bestFooter(GameMode.guessOutline),
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D4AA), Color(0xFF7B61FF)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PracticeGameScreen(mode: GameMode.guessOutline))),
              ),

              const SizedBox(height: 20),
              Center(child: Text('Each country appears once per round',
                  style: TextStyle(fontSize: 12, color: textMuted))),
            ],
          ),
        ),
      ),
    );
  }
}

class _PracticeModeCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final VoidCallback onTap;
  final String? footer;
  final Color? footerColor;

  const _PracticeModeCard({
    required this.emoji, required this.title,
    required this.subtitle, required this.gradient, required this.onTap,
    this.footer, this.footerColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient.colors.map((c) => (c as Color).withOpacity(0.12)).toList(),
            begin: gradient.begin, end: gradient.end,
          ),
          border: Border.all(color: (gradient.colors.first as Color).withOpacity(0.35)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [BoxShadow(
                color: (gradient.colors.first as Color).withOpacity(0.3),
                blurRadius: 10, offset: const Offset(0, 3),
              )],
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(
                fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textDark : AppColors.textLight,
                letterSpacing: -0.3)),
              const SizedBox(height: 3),
              Text(subtitle, style: TextStyle(fontSize: 12, color: textMuted)),
              if (footer != null) ...[
                const SizedBox(height: 3),
                Text(footer!, style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: footerColor ?? AppColors.yellow)),
              ],
            ],
          )),
          Icon(Icons.arrow_forward_ios_rounded, size: 15, color: textMuted),
        ]),
      ),
    );
  }
}

// ── Practice Game Screen ───────────────────────────────────────────────────

class PracticeGameScreen extends ConsumerStatefulWidget {
  final GameMode mode;
  const PracticeGameScreen({super.key, required this.mode});

  @override
  ConsumerState<PracticeGameScreen> createState() => _PracticeGameScreenState();
}

class _PracticeGameScreenState extends ConsumerState<PracticeGameScreen>
    with TickerProviderStateMixin, BannerPositionRoute<PracticeGameScreen> {
  @override
  BannerPosition get bannerPosition => BannerPosition.top;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<String> _suggestions = [];
  late AnimationController _shakeController;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    Future.microtask(_startSession);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  NotifierProvider<PracticeNotifier, GameState?> get _provider =>
      practiceProviderForMode(widget.mode);

  NotifierProvider<PracticeSessionNotifier, PracticeSessionState> get _sessionProvider =>
      practiceSessionProviderForMode(widget.mode);

  void _startSession() {
    if (!mounted) return;
    final region = ref.read(practiceRegionProvider);
    final first = ref.read(_sessionProvider.notifier).startSession(region);
    if (first != null) {
      ref.read(_provider.notifier).nextPuzzle(forcedEntry: first);
    }
  }

  Future<void> _advanceSession() async {
    final gameState = ref.read(_provider);
    final won = gameState?.status == GameStatus.won;
    final next = await ref.read(_sessionProvider.notifier).recordResultAndAdvance(won);
    if (!mounted) return;
    _controller.clear();
    setState(() { _suggestions = []; _showResult = false; });
    if (next != null) {
      ref.read(_provider.notifier).nextPuzzle(forcedEntry: next);
      _focusNode.requestFocus();
      return;
    }
    final session = ref.read(_sessionProvider);
    if (session.isNewRecord) {
      showPracticeRecordCelebration(
        context,
        correct: session.correct,
        total: session.total,
        modeLabel: widget.mode.label,
        modeEmoji: widget.mode.emoji,
        region: session.region,
      );
    }
  }

  void _onInputChanged(String value) {
    setState(() {
      _suggestions = ref.read(_provider.notifier).getSuggestions(value);
    });
  }

  void _selectSuggestion(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: value.length));
    setState(() => _suggestions = []);
    _focusNode.requestFocus();
  }

  void _submitGuess(String input) {
    final text = input.trim();
    if (text.isEmpty) return;
    final gameState = ref.read(_provider);
    if (gameState == null || gameState.isOver) return;

    ref.read(_provider.notifier).submitGuess(text);
    _controller.clear();
    setState(() => _suggestions = []);
    _focusNode.requestFocus();

    final updated = ref.read(_provider);
    if (updated != null && updated.guesses.isNotEmpty) {
      if (!updated.guesses.last.isCorrect && !updated.guesses.last.isClue) {
        HapticFeedback.mediumImpact();
        _shakeController.forward(from: 0);
      } else if (updated.guesses.last.isCorrect) {
        HapticFeedback.heavyImpact();
      }
    }
    if (updated?.isOver == true) setState(() => _showResult = true);
  }

  void _useClue() {
    final gameState = ref.read(_provider);
    if (gameState == null || gameState.isOver || gameState.clueUsed || gameState.freeClueUsed) return;

    final canSpendGuess = gameState.guessesRemaining > 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    void afterReveal() {
      final updated = ref.read(_provider);
      if (updated?.isOver == true) setState(() => _showResult = true);
    }

    Future<void> watchAdForClue() async {
      final earned = await showClueRewardedAd(context);
      if (!mounted || !earned) return;
      ref.read(_provider.notifier).useClueViaAd();
      afterReveal();
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: MatteCard(
          isDark: isDark,
          borderRadius: 24,
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💡', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text('Reveal a Clue?',
                  style: TextStyle(
                    fontFamily: 'Outfit', fontSize: 19, fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                  )),
              const SizedBox(height: 6),
              Text(
                'Reveals the first letter of the answer.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textDimDark : AppColors.textDimLight,
                ),
              ),
              const SizedBox(height: 22),

              // Watch ad — free
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  watchAdForClue();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.red, Color(0xFFFF8A65)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: AppColors.red.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Watch a quick ad — free',
                          style: TextStyle(
                            fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w700,
                            color: Colors.white,
                          )),
                    ],
                  ),
                ),
              ),

              if (canSpendGuess) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(_provider.notifier).useClue();
                    afterReveal();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientTealBlue,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: AppColors.teal.withOpacity(0.28), blurRadius: 14, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_circle_up_rounded, color: Colors.black, size: 20),
                        SizedBox(width: 8),
                        Text('Use a guess instead',
                            style: TextStyle(
                              fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w700,
                              color: Colors.black,
                            )),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text('Cancel',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _playAgain() {
    setState(() => _showResult = false);
    Future.microtask(_startSession);
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(_provider);
    final session = ref.watch(_sessionProvider);
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (session.complete) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.bg : AppColors.bgLight,
        body: Column(children: [
          const SafeArea(top: true, bottom: false, child: SizedBox(height: 50)),
          Expanded(
            child: SafeArea(
              top: false,
              child: PracticeSessionCompletePanel(
                mode: widget.mode,
                session: session,
                isDark: isDark,
                onPlayAgain: _playAgain,
                onBackToMenu: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ]),
      );
    }

    if (gameState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bg = isDark ? AppColors.bg : AppColors.bgLight;
    final surface2 = isDark ? AppColors.surface2 : AppColors.surface2Light;
    final borderTeal = isDark ? AppColors.borderTealDark : AppColors.borderTealLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final isFlag = widget.mode == GameMode.guessFlag;
    // Button opens if EITHER path is available — the ad option doesn't
    // require guesses in reserve, only "spend a guess" does (gated
    // separately inside the dialog).
    final canUseClue = !gameState.clueUsed &&
        !gameState.freeClueUsed &&
        !gameState.isOver;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // Reserves space for the persistent banner ad — kept at the
          // top since the text field's keyboard covers the bottom of
          // the screen while guessing.
          const SafeArea(top: true, bottom: false, child: SizedBox(height: 50)),
          Expanded(
            child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          reverse: true,
          child: Column(
            children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: surface2, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 16,
                        color: isDark ? AppColors.textDimDark : AppColors.textDimLight),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withOpacity(0.1),
                    border: Border.all(color: AppColors.blue.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('🎯 Practice · ${widget.mode.label}',
                      style: const TextStyle(fontSize: 11, color: AppColors.blue, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                Row(children: List.generate(GameState.maxGuesses, (i) {
                  final realGuesses = gameState.guesses.where((g) => !g.isClue).toList();
                  Color pipColor;
                  if (i < realGuesses.length) {
                    pipColor = realGuesses[i].isCorrect ? AppColors.teal : AppColors.red;
                  } else { pipColor = borderTeal; }
                  return Container(
                    width: 8, height: 8, margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: i < realGuesses.length ? pipColor : Colors.transparent,
                      border: Border.all(color: pipColor, width: 1.5),
                      shape: BoxShape.circle,
                    ),
                  );
                })),
              ]),
            ),

            PracticeProgressBar(session: session, isDark: isDark),

            const SizedBox(height: 20),

            // Hero card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _PracticeHeroCard(
                puzzle: gameState.puzzle,
                showContinent: settings.showContinentHint,
                clueText: gameState.clueText,
                isDark: isDark,
              ),
            ),

            const SizedBox(height: 16),

            // Guess list — plain Column (max 3 items) so the whole screen
            // can live inside one scroll view without nested-scrollable issues
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (int i = 0; i < gameState.guesses.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _PracticeGuessRow(
                      guess: gameState.guesses[i],
                      settings: settings,
                      isDark: isDark,
                      isLatest: i == gameState.guesses.length - 1,
                    ),
                  ],
                ],
              ),
            ),

            // Result panel or input
            if (_showResult)
              _PracticeResultPanel(gameState: gameState, isDark: isDark, onNext: _advanceSession, locationRevealEnabled: settings.locationRevealEnabled)
            else
              AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) {
                  final shake = _shakeController.value;
                  final offset = shake < 0.5
                      ? Offset(-8 * (shake * 2), 0)
                      : Offset(8 * ((shake - 0.5) * 2), 0);
                  return Transform.translate(offset: offset, child: child);
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_suggestions.isNotEmpty) ...[
                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _suggestions.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 7),
                            itemBuilder: (context, i) {
                              final s = _suggestions[i];
                              final isFirst = i == 0;
                              return GestureDetector(
                                onTap: () => _selectSuggestion(s),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isFirst ? AppColors.teal.withOpacity(0.1)
                                        : (isDark ? surface2 : AppColors.surface2Light),
                                    border: Border.all(
                                      color: isFirst ? borderTeal
                                          : (isDark ? AppColors.borderDark : AppColors.borderLight),
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(s, style: TextStyle(
                                    fontSize: 13,
                                    color: isFirst ? AppColors.teal
                                        : (isDark ? AppColors.textDimDark : AppColors.textDimLight),
                                    fontWeight: FontWeight.w500,
                                  )),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      Row(children: [
                        GestureDetector(
                          onTap: canUseClue ? _useClue : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: canUseClue ? AppColors.yellow.withOpacity(0.12)
                                  : (isDark ? surface2 : AppColors.surface2Light),
                              border: Border.all(
                                color: canUseClue ? AppColors.yellow.withOpacity(0.5)
                                    : (isDark ? AppColors.borderDark : AppColors.borderLight),
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(child: Text('💡',
                                style: TextStyle(fontSize: 20,
                                    color: canUseClue ? AppColors.yellow : textMuted))),
                          ),
                        ),
                        const SizedBox(width: 8),

                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            autofocus: true,
                            textCapitalization: TextCapitalization.words,
                            style: TextStyle(fontSize: 15, color: textColor, fontWeight: FontWeight.w500),
                            decoration: InputDecoration(
                              hintText: isFlag ? 'Type a country…' : widget.mode == GameMode.guessCapital
                                  ? 'Type a capital city…' : 'Type a country…',
                            ),
                            onChanged: _onInputChanged,
                          ),
                        ),
                        const SizedBox(width: 8),

                        GestureDetector(
                          onTap: () {
                            final text = _controller.text.trim();
                            if (text.isNotEmpty) _submitGuess(text);
                          },
                          child: Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              gradient: AppColors.gradientTealBlue,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(
                                color: AppColors.teal.withOpacity(0.3),
                                blurRadius: 12, offset: const Offset(0, 4),
                              )],
                            ),
                            child: const Icon(Icons.arrow_forward_rounded,
                                color: Colors.black, size: 22),
                          ),
                        ),
                      ]),

                      const SizedBox(height: 8),
                      Row(children: [
                        Text('${gameState.guessesRemaining} guess${gameState.guessesRemaining != 1 ? 'es' : ''} remaining',
                            style: TextStyle(fontSize: 11, color: textMuted, letterSpacing: 0.5)),
                        if (gameState.clueUsed) ...[
                          const SizedBox(width: 8),
                          Text('· clue used',
                              style: TextStyle(fontSize: 11,
                                  color: AppColors.yellow.withOpacity(0.7), letterSpacing: 0.5)),
                        ],
                      ]),
                    ],
                  ),
                ),
              ),
          ],
            ),
          ),
        ),
          ),
        ],
      ),
      );
  }
}

// ── Practice Result Panel ──────────────────────────────────────────────────

class _PracticeResultPanel extends StatelessWidget {
  final GameState gameState;
  final bool isDark;
  final VoidCallback onNext;
  final bool locationRevealEnabled;

  const _PracticeResultPanel({
    required this.gameState,
    required this.isDark,
    required this.onNext,
    required this.locationRevealEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final won = gameState.status == GameStatus.won;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final entry = gameState.puzzle.entry;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(
          color: won ? AppColors.teal.withOpacity(0.4) : AppColors.red.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text(won ? '🎉' : '💭', style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(won ? 'Got it!' : 'The answer was...',
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: won ? AppColors.teal : AppColors.red)),
              Row(children: [
                Text(gameState.puzzle.entry.flagEmoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(gameState.puzzle.correctAnswer, style: TextStyle(
                  fontFamily: 'Outfit', fontSize: 17, fontWeight: FontWeight.w800,
                  color: textColor, letterSpacing: -0.3)),
              ]),
            ],
          )),
          // "(?)" — tap to see the fly-to-country map reveal, on demand
          // rather than automatically. Only shown if the feature is on
          // in Settings at all.
          if (locationRevealEnabled)
            GestureDetector(
              onTap: () => showLocationReveal(
                context,
                targetLat: entry.lat,
                targetLng: entry.lng,
                countryName: entry.country,
                countryEmoji: entry.flagEmoji,
              ),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.teal.withOpacity(0.12),
                  border: Border.all(color: AppColors.teal.withOpacity(0.4)),
                ),
                child: const Center(
                  child: Text('?', style: TextStyle(
                      fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w800,
                      color: AppColors.teal)),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onNext,
          child: Container(
            width: double.infinity, height: 46,
            decoration: BoxDecoration(
              gradient: AppColors.gradientTealBlue,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Next Puzzle', style: TextStyle(
                  fontFamily: 'Outfit', fontSize: 15,
                  fontWeight: FontWeight.w700, color: Colors.black)),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 17),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Practice Hero Card ─────────────────────────────────────────────────────

class _PracticeHeroCard extends StatelessWidget {
  final DailyPuzzle puzzle;
  final bool showContinent;
  final String? clueText;
  final bool isDark;

  const _PracticeHeroCard({
    required this.puzzle, required this.showContinent,
    required this.isDark, this.clueText,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final isFlag = puzzle.mode == GameMode.guessFlag;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: AppColors.blue.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(children: [
        Text(puzzle.mode.heroLabel.toUpperCase(),
            style: TextStyle(fontSize: 10, letterSpacing: 3,
                color: AppColors.blue.withOpacity(0.8), fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        if (isFlag)
          Text(puzzle.heroText, style: const TextStyle(fontSize: 80, height: 1))
        else if (puzzle.mode == GameMode.guessOutline)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            height: MediaQuery.of(context).viewInsets.bottom > 0 ? 104 : 210,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                isDark ? AppColors.textDark : AppColors.textLight,
                BlendMode.srcIn,
              ),
              child: Image.asset(
                kOutlineAssetPath[puzzle.entry.country]!,
                fit: BoxFit.contain,
              ),
            ),
          )
        else
          Text(puzzle.heroText, style: TextStyle(
            fontFamily: 'Outfit', fontSize: 38, fontWeight: FontWeight.w800,
            color: isDark ? AppColors.textDark : AppColors.textLight,
            letterSpacing: -1.5, height: 1,
          ), textAlign: TextAlign.center),
        if (showContinent && !isFlag && puzzle.mode != GameMode.guessOutline) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 5, height: 5, decoration: BoxDecoration(
                color: AppColors.blue.withOpacity(0.7), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(puzzle.entry.continent, style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textDimDark : AppColors.textDimLight)),
            ]),
          ),
        ],
        if (clueText != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.yellow.withOpacity(0.1),
              border: Border.all(color: AppColors.yellow.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('💡', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text(clueText!, style: const TextStyle(
                  fontSize: 13, color: AppColors.yellow, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ── Practice Guess Row ─────────────────────────────────────────────────────

class _PracticeGuessRow extends StatefulWidget {
  final GuessResult guess;
  final dynamic settings;
  final bool isDark;
  final bool isLatest;

  const _PracticeGuessRow({
    required this.guess, required this.settings,
    required this.isDark, required this.isLatest,
  });

  @override
  State<_PracticeGuessRow> createState() => _PracticeGuessRowState();
}

class _PracticeGuessRowState extends State<_PracticeGuessRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    widget.isLatest ? _anim.forward() : _anim.value = 1;
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final g = widget.guess;
    final isDark = widget.isDark;

    if (g.isClue) {
      return FadeTransition(opacity: _fade, child: SlideTransition(position: _slide,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.yellow.withOpacity(0.06),
            border: Border.all(color: AppColors.yellow.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Text('💡', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Text(g.input, style: const TextStyle(fontSize: 13, color: AppColors.yellow, fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(g.isFreeClue ? 'Free · Ad' : '−1 guess',
                style: TextStyle(fontSize: 11, color: g.isFreeClue ? AppColors.teal : AppColors.yellow)),
          ]),
        ),
      ));
    }

    final borderColor = g.isCorrect ? AppColors.teal.withOpacity(0.4) : AppColors.red.withOpacity(0.25);
    final bgColor = g.isCorrect ? AppColors.teal.withOpacity(0.05) : AppColors.red.withOpacity(0.04);

    return FadeTransition(opacity: _fade, child: SlideTransition(position: _slide,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: bgColor, border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: g.isCorrect ? AppColors.teal.withOpacity(0.15) : AppColors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Icon(g.isCorrect ? Icons.check_rounded : Icons.close_rounded,
                  size: 16, color: g.isCorrect ? AppColors.teal : AppColors.red)),
            ),
            const SizedBox(width: 10),
            Text(g.matchedEntry?.flagEmoji ?? '', style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Expanded(child: Text(g.input, style: TextStyle(fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textDimDark : AppColors.textDimLight))),
            if (!g.isCorrect && g.distanceMiles != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(widget.settings.formatDistance(g.distanceMiles!),
                    style: const TextStyle(fontSize: 13, color: AppColors.red, fontWeight: FontWeight.w600)),
                if (g.directionArrow.isNotEmpty) ...[
                  const SizedBox(width: 5),
                  Text(g.directionArrow, style: const TextStyle(fontSize: 16, color: AppColors.red)),
                ],
              ]),
            if (g.isCorrect)
              const Text('Correct!', style: TextStyle(fontSize: 13, color: AppColors.teal, fontWeight: FontWeight.w600)),
          ]),
          if (!g.isCorrect && g.distanceMiles != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: g.closeness,
                backgroundColor: Colors.white.withOpacity(0.04),
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.teal.withOpacity(0.5)),
                minHeight: 3,
              ),
            ),
          ],
        ]),
      ),
    ));
  }
}
