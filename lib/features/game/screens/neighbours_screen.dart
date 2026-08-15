import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/game_models.dart';
import '../providers/game_provider.dart';
import 'result_screen.dart';
import '../../../core/utils/banner_position_route.dart';
import '../../home/widgets/banner_ad_widget.dart' show BannerPosition;

class NeighboursScreen extends ConsumerStatefulWidget {
  const NeighboursScreen({super.key});

  @override
  ConsumerState<NeighboursScreen> createState() => _NeighboursScreenState();
}

class _NeighboursScreenState extends ConsumerState<NeighboursScreen>
    with SingleTickerProviderStateMixin, BannerPositionRoute<NeighboursScreen> {
  @override
  BannerPosition get bannerPosition => BannerPosition.top;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _guessScrollController = ScrollController();
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _guessScrollController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // The guess list only gets the leftover space above the on-screen
  // keyboard (it's an Expanded ListView, not a reverse-scrolling column
  // like the other game screens), so a new guess can land below the
  // visible area once the keyboard has shrunk that space. Scroll it into
  // view explicitly rather than leaving the latest guess hidden.
  void _scrollToLatestGuess() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_guessScrollController.hasClients) return;
      _guessScrollController.animateTo(
        _guessScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _submitGuess() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final gameState = ref.read(guessNeighboursGameProvider);
    if (gameState == null || gameState.isOver) return;

    ref.read(guessNeighboursGameProvider.notifier).submitGuess(text);
    _controller.clear();
    _focusNode.requestFocus();
    _scrollToLatestGuess();

    final updated = ref.read(guessNeighboursGameProvider);
    if (updated != null && updated.guesses.isNotEmpty && !updated.guesses.last.isCorrect) {
      HapticFeedback.mediumImpact();
      _shakeController.forward(from: 0);
    } else if (updated?.guesses.last.isCorrect == true) {
      HapticFeedback.heavyImpact();
    }

    if (updated?.isOver == true) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ResultScreen(mode: GameMode.guessNeighbours)));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(guessNeighboursGameProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (gameState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (gameState.isOver && gameState.guesses.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ResultScreen(mode: GameMode.guessNeighbours)));
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bg = isDark ? AppColors.bg : AppColors.bgLight;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final surface2 = isDark ? AppColors.surface2 : AppColors.surface2Light;
    final borderTeal = isDark ? AppColors.borderTealDark : AppColors.borderTealLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final correct = gameState.puzzle.entry.neighbours;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // Reserves space for the persistent banner ad (see
          // PersistentBannerAd) — kept at the top since the number-entry
          // keyboard covers the bottom of the screen.
          const SafeArea(top: true, bottom: false, child: SizedBox(height: 50)),
          Expanded(
            child: SafeArea(
        top: false,
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
                    color: AppColors.teal.withOpacity(0.1),
                    border: Border.all(color: borderTeal),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('🤝 Neighbours',
                      style: TextStyle(fontSize: 11, color: AppColors.teal, fontWeight: FontWeight.w600)),
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

            const SizedBox(height: 20),

            // Hero card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                decoration: BoxDecoration(
                  color: surface,
                  border: Border.all(color: borderTeal),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(children: [
                  const Text('COUNTRY', style: TextStyle(
                    fontSize: 10, letterSpacing: 3, color: AppColors.teal, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Text(gameState.puzzle.entry.flagEmoji, style: const TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text(gameState.puzzle.entry.country, style: TextStyle(
                    fontFamily: 'Outfit', fontSize: 32, fontWeight: FontWeight.w800,
                    color: textColor, letterSpacing: -1, height: 1,
                  ), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text('How many land borders does this country have?',
                      style: TextStyle(fontSize: 13, color: textMuted),
                      textAlign: TextAlign.center),
                ]),
              ),
            ),

            const SizedBox(height: 16),

            // Guess list with hot/cold hints
            Expanded(
              child: ListView.separated(
                controller: _guessScrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: gameState.guesses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final guess = gameState.guesses[i];
                  final guessNum = int.tryParse(guess.input);
                  String hint = '';
                  Color hintColor = AppColors.red;
                  if (!guess.isCorrect && guessNum != null) {
                    final diff = guessNum - correct;
                    hint = diff > 0 ? '↓ Too high' : '↑ Too low';
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: guess.isCorrect
                          ? AppColors.teal.withOpacity(0.05)
                          : AppColors.red.withOpacity(0.04),
                      border: Border.all(
                        color: guess.isCorrect
                            ? AppColors.teal.withOpacity(0.4)
                            : AppColors.red.withOpacity(0.25),
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: guess.isCorrect
                              ? AppColors.teal.withOpacity(0.15)
                              : AppColors.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(child: Icon(
                          guess.isCorrect ? Icons.check_rounded : Icons.close_rounded,
                          size: 16,
                          color: guess.isCorrect ? AppColors.teal : AppColors.red,
                        )),
                      ),
                      const SizedBox(width: 10),
                      Text(guess.input, style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: guess.isCorrect ? AppColors.teal : textColor,
                      )),
                      const SizedBox(width: 10),
                      if (hint.isNotEmpty)
                        Text(hint, style: TextStyle(fontSize: 13, color: hintColor)),
                      const Spacer(),
                      if (guess.isCorrect)
                        const Text('Correct!', style: TextStyle(
                          fontSize: 13, color: AppColors.teal, fontWeight: FontWeight.w600)),
                    ]),
                  );
                },
              ),
            ),

            // Number input
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
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          fontSize: 20, color: textColor, fontWeight: FontWeight.w700),
                        decoration: const InputDecoration(hintText: 'Enter a number…'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _submitGuess,
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
                        child: const Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 22),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text('${gameState.guessesRemaining} guess${gameState.guessesRemaining != 1 ? 'es' : ''} remaining',
                      style: TextStyle(fontSize: 11, color: textMuted, letterSpacing: 0.5)),
                ]),
              ),
            ),
          ],
        ),
      ),
          ),
        ],
      ),
    );
  }
}
