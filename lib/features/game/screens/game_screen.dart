import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/game_models.dart';
import '../../../data/models/outline_assets.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../../../core/widgets/app_effects.dart';
import '../../../core/widgets/app_transitions.dart';
import '../providers/game_provider.dart';
import 'result_screen.dart';
import '../../home/widgets/banner_ad_widget.dart';
import '../../../core/widgets/clue_ad_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  final GameMode mode;
  const GameScreen({super.key, required this.mode});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<String> _suggestions = [];
  late AnimationController _shakeController;
  late AnimationController _entryController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  NotifierProvider<GameNotifier, GameState?> get _provider =>
      gameProviderForMode(widget.mode);

  void _onInputChanged(String value) {
    final notifier = ref.read(_provider.notifier);
    setState(() {
      _suggestions = notifier.getSuggestions(value);
    });
  }

  void _selectSuggestion(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: value.length),
    );
    setState(() => _suggestions = []);
    _focusNode.requestFocus();
  }

  void _submitGuess(String input) {
    final text = input.trim();
    if (text.isEmpty) return;
    final notifier = ref.read(_provider.notifier);
    final gameState = ref.read(_provider);
    if (gameState == null || gameState.isOver) return;

    notifier.submitGuess(text);
    _controller.clear();
    setState(() => _suggestions = []);
    _focusNode.requestFocus();

    final updatedState = ref.read(_provider);
    if (updatedState != null &&
        updatedState.guesses.isNotEmpty &&
        !updatedState.guesses.last.isCorrect &&
        !updatedState.guesses.last.isClue) {
      HapticFeedback.mediumImpact();
      _shakeController.forward(from: 0);
    } else if (updatedState?.guesses.last.isCorrect == true) {
      HapticFeedback.heavyImpact();
    }

    if (updatedState?.isOver == true) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ResultScreen(mode: widget.mode),
            ),
          );
        }
      });
    }
  }

  void _useClue() {
    final gameState = ref.read(_provider);
    if (gameState == null || gameState.isOver || gameState.clueUsed || gameState.freeClueUsed) return;

    final canSpendGuess = gameState.guessesRemaining > 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    void afterReveal() {
      final updated = ref.read(_provider);
      if (updated?.isOver == true) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => ResultScreen(mode: widget.mode)));
          }
        });
      }
    }

    Future<void> watchAdForClue() async {
      await showClueAdScreen(context);
      if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(_provider);
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (gameState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (gameState.isOver && gameState.guesses.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ResultScreen(mode: widget.mode)),
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bg = isDark ? AppColors.bg : AppColors.bgLight;
    final surface2 = isDark ? AppColors.surface2 : AppColors.surface2Light;
    final borderTeal = isDark ? AppColors.borderTealDark : AppColors.borderTealLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    final isFlag = widget.mode == GameMode.guessFlag;
    // Button opens if EITHER path is available — the ad option doesn't
    // require guesses in reserve, only the "spend a guess" option does
    // (that's gated separately inside the dialog itself).
    final canUseClue = !gameState.clueUsed &&
        !gameState.freeClueUsed &&
        !gameState.isOver;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // Banner moves above the content on this screen rather than
          // sitting as bottomNavigationBar — the text field's keyboard
          // covers the bottom of the screen while guessing, which would
          // hide a bottom banner entirely.
          const BannerAdWidget(atTop: true),
          Expanded(
            child: GlowMesh(
        isDark: isDark,
        child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          reverse: true,
          child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: surface2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16,
                          color: isDark
                              ? AppColors.textDimDark
                              : AppColors.textDimLight),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withOpacity(0.1),
                      border: Border.all(color: borderTeal),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${widget.mode.emoji} ${widget.mode.label}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.teal,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Guess pips
                  Row(
                    children: List.generate(GameState.maxGuesses, (i) {
                      final realGuesses =
                          gameState.guesses.where((g) => !g.isClue).toList();
                      Color pipColor;
                      if (i < realGuesses.length) {
                        pipColor = realGuesses[i].isCorrect
                            ? AppColors.teal
                            : AppColors.red;
                      } else {
                        pipColor = borderTeal;
                      }
                      return Container(
                        width: 8, height: 8,
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: i < realGuesses.length
                              ? pipColor
                              : Colors.transparent,
                          border: Border.all(color: pipColor, width: 1.5),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Hero card ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _HeroCard(
                puzzle: gameState.puzzle,
                showContinent: settings.showContinentHint,
                clueText: gameState.clueText,
                isDark: isDark,
              ),
            ),

            const SizedBox(height: 16),

            // ── Guess list ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (int i = 0; i < gameState.guesses.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _GuessRow(
                      guess: gameState.guesses[i],
                      settings: settings,
                      isDark: isDark,
                      isLatest: i == gameState.guesses.length - 1,
                    ),
                  ],
                ],
              ),
            ),

            // ── Input zone ─────────────────────────────────────────
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_suggestions.isNotEmpty) ...[
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 7),
                          itemBuilder: (context, i) {
                            final s = _suggestions[i];
                            final isFirst = i == 0;
                            return GestureDetector(
                              onTap: () => _selectSuggestion(s),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isFirst
                                      ? AppColors.teal.withOpacity(0.1)
                                      : (isDark
                                          ? surface2
                                          : AppColors.surface2Light),
                                  border: Border.all(
                                    color: isFirst
                                        ? borderTeal
                                        : (isDark
                                            ? AppColors.borderDark
                                            : AppColors.borderLight),
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(s,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isFirst
                                          ? AppColors.teal
                                          : (isDark
                                              ? AppColors.textDimDark
                                              : AppColors.textDimLight),
                                      fontWeight: FontWeight.w500,
                                    )),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    Row(
                      children: [
                        GestureDetector(
                          onTap: canUseClue ? _useClue : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: canUseClue
                                  ? AppColors.yellow.withOpacity(0.12)
                                  : (isDark
                                      ? surface2
                                      : AppColors.surface2Light),
                              border: Border.all(
                                color: canUseClue
                                    ? AppColors.yellow.withOpacity(0.5)
                                    : (isDark
                                        ? AppColors.borderDark
                                        : AppColors.borderLight),
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text('💡',
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: canUseClue
                                        ? AppColors.yellow
                                        : textMuted,
                                  )),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            autofocus: true,
                            textCapitalization: TextCapitalization.words,
                            style: TextStyle(
                              fontSize: 15,
                              color: textColor,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: switch (widget.mode) {
                                GameMode.guessCountry => 'Type a country…',
                                GameMode.guessCapital => 'Type a capital city…',
                                GameMode.guessFlag => 'Type a country…',
                                GameMode.guessNeighbours => 'Type a number…',
                                GameMode.guessPopulation => 'Type a capital…',
                                GameMode.guessOutline => 'Type a country…',
                              },
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
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.teal.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.arrow_forward_rounded,
                                color: Colors.black, size: 22),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${gameState.guessesRemaining} guess${gameState.guessesRemaining != 1 ? 'es' : ''} remaining',
                          style: TextStyle(
                              fontSize: 11,
                              color: textMuted,
                              letterSpacing: 0.5),
                        ),
                        if (gameState.clueUsed) ...[
                          const SizedBox(width: 8),
                          Text('· clue used',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.yellow.withOpacity(0.7),
                                  letterSpacing: 0.5)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
      ),
          ),
        ],
      ),
    );
  }
}

// ── Hero Card ──────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final DailyPuzzle puzzle;
  final bool showContinent;
  final String? clueText;
  final bool isDark;

  const _HeroCard({
    required this.puzzle,
    required this.showContinent,
    required this.isDark,
    this.clueText,
  });

  @override
  Widget build(BuildContext context) {
    final isFlag = puzzle.mode == GameMode.guessFlag;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF18202C), const Color(0xFF131820), const Color(0xFF11161E)]
              : [Colors.white, const Color(0xFFF7F9FC), const Color(0xFFEFF3F8)],
        ),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.9),
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.lifted(isDark),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -20, left: 0, right: 0,
            child: Center(
              child: Container(
                width: 200, height: 100,
                decoration: BoxDecoration(
                  gradient: RadialGradient(colors: [
                    AppColors.teal.withOpacity(0.08),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ),
          Column(
            children: [
              Text(
                puzzle.mode.heroLabel.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 3,
                  color: AppColors.teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),

              // Flag mode: show huge flag emoji
              if (isFlag)
                Text(
                  puzzle.heroText, // flagEmoji
                  style: const TextStyle(fontSize: 80, height: 1),
                  textAlign: TextAlign.center,
                )
              else if (puzzle.mode == GameMode.guessOutline)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  // Larger when the keyboard is closed (most of the time
                  // spent looking at the shape); shrinks to keep everything
                  // on screen once the keyboard opens for typing.
                  height: MediaQuery.of(context).viewInsets.bottom > 0 ? 108 : 220,
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
                Text(
                  puzzle.heroText,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                    letterSpacing: -1.5,
                    height: 1,
                  ),
                  textAlign: TextAlign.center,
                ),

              if (showContinent) ...[
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    border:
                        Border.all(color: Colors.white.withOpacity(0.08)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5, height: 5,
                        decoration: const BoxDecoration(
                          color: AppColors.teal,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        puzzle.entry.continent,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textDimDark
                              : AppColors.textDimLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (clueText != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.yellow.withOpacity(0.1),
                    border: Border.all(
                        color: AppColors.yellow.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(
                        clueText!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.yellow,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Guess Row ──────────────────────────────────────────────────────────────

class _GuessRow extends StatefulWidget {
  final GuessResult guess;
  final dynamic settings;
  final bool isDark;
  final bool isLatest;

  const _GuessRow({
    required this.guess,
    required this.settings,
    required this.isDark,
    required this.isLatest,
  });

  @override
  State<_GuessRow> createState() => _GuessRowState();
}

class _GuessRowState extends State<_GuessRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    widget.isLatest ? _anim.forward() : _anim.value = 1;
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.guess;
    final isDark = widget.isDark;

    if (g.isClue) {
      return FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.yellow.withOpacity(0.06),
              border:
                  Border.all(color: AppColors.yellow.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Text(g.input,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.yellow,
                        fontWeight: FontWeight.w500)),
                const Spacer(),
                Text(g.isFreeClue ? 'Free · Ad' : '−1 guess',
                    style: TextStyle(
                        fontSize: 11,
                        color: g.isFreeClue ? AppColors.teal : AppColors.yellow)),
              ],
            ),
          ),
        ),
      );
    }

    final borderColor = g.isCorrect
        ? AppColors.teal.withOpacity(0.4)
        : AppColors.red.withOpacity(0.25);
    final bgColor = g.isCorrect
        ? AppColors.teal.withOpacity(0.05)
        : AppColors.red.withOpacity(0.04);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: g.isCorrect
                          ? AppColors.teal.withOpacity(0.15)
                          : AppColors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        g.isCorrect
                            ? Icons.check_rounded
                            : Icons.close_rounded,
                        size: 16,
                        color:
                            g.isCorrect ? AppColors.teal : AppColors.red,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(g.matchedEntry?.flagEmoji ?? '',
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(g.input,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textDimDark
                              : AppColors.textDimLight,
                        )),
                  ),
                  if (!g.isCorrect && g.distanceMiles != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.settings.formatDistance(g.distanceMiles!),
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.red,
                              fontWeight: FontWeight.w600),
                        ),
                        if (g.directionArrow.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Text(g.directionArrow,
                              style: const TextStyle(
                                  fontSize: 16, color: AppColors.red)),
                        ],
                      ],
                    ),
                  if (g.isCorrect)
                    const Text('Correct!',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.teal,
                            fontWeight: FontWeight.w600)),
                ],
              ),
              if (!g.isCorrect && g.distanceMiles != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: g.closeness,
                    backgroundColor: Colors.white.withOpacity(0.04),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.teal.withOpacity(0.5)),
                    minHeight: 3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
