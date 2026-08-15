import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/practice_record_celebration.dart';
import '../../../data/models/game_models.dart';
import '../../home/widgets/banner_ad_widget.dart' show BannerPosition;
import '../../../core/utils/banner_position_route.dart';
import '../providers/practice_provider.dart';
import '../widgets/practice_session_widgets.dart';

class PracticeNeighboursScreen extends ConsumerStatefulWidget {
  const PracticeNeighboursScreen({super.key});

  @override
  ConsumerState<PracticeNeighboursScreen> createState() => _PracticeNeighboursScreenState();
}

class _PracticeNeighboursScreenState extends ConsumerState<PracticeNeighboursScreen>
    with SingleTickerProviderStateMixin, BannerPositionRoute<PracticeNeighboursScreen> {
  @override
  BannerPosition get bannerPosition => BannerPosition.top;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _guessScrollController = ScrollController();
  late AnimationController _shakeController;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    Future.microtask(_startSession);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _guessScrollController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _startSession() {
    if (!mounted) return;
    final region = ref.read(practiceRegionProvider);
    final first = ref.read(practiceNeighboursSessionProvider.notifier).startSession(region);
    if (first != null) {
      ref.read(practiceNeighboursProvider.notifier).nextPuzzle(forcedEntry: first);
    }
  }

  Future<void> _advanceSession() async {
    final gameState = ref.read(practiceNeighboursProvider);
    final won = gameState?.status == GameStatus.won;
    final next = await ref.read(practiceNeighboursSessionProvider.notifier).recordResultAndAdvance(won);
    if (!mounted) return;
    _controller.clear();
    setState(() => _showResult = false);
    if (next != null) {
      ref.read(practiceNeighboursProvider.notifier).nextPuzzle(forcedEntry: next);
      _focusNode.requestFocus();
      return;
    }
    final session = ref.read(practiceNeighboursSessionProvider);
    if (session.isNewRecord) {
      showPracticeRecordCelebration(
        context,
        correct: session.correct,
        total: session.total,
        modeLabel: GameMode.guessNeighbours.label,
        modeEmoji: GameMode.guessNeighbours.emoji,
        region: session.region,
      );
    }
  }

  void _playAgain() {
    setState(() => _showResult = false);
    Future.microtask(_startSession);
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
    final gameState = ref.read(practiceNeighboursProvider);
    if (gameState == null || gameState.isOver) return;

    ref.read(practiceNeighboursProvider.notifier).submitGuess(text);
    _controller.clear();
    _focusNode.requestFocus();
    _scrollToLatestGuess();

    final updated = ref.read(practiceNeighboursProvider);
    if (updated != null && updated.guesses.isNotEmpty && !updated.guesses.last.isCorrect) {
      HapticFeedback.mediumImpact();
      _shakeController.forward(from: 0);
    } else if (updated?.guesses.last.isCorrect == true) {
      HapticFeedback.heavyImpact();
    }
    if (updated?.isOver == true) setState(() => _showResult = true);
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(practiceNeighboursProvider);
    final session = ref.watch(practiceNeighboursSessionProvider);
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
                mode: GameMode.guessNeighbours,
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
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final surface2 = isDark ? AppColors.surface2 : AppColors.surface2Light;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final correct = gameState.puzzle.entry.neighbours;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // Banner moves above the content on this screen rather than
          // sitting as bottomNavigationBar — the number-entry keyboard
          // covers the bottom of the screen, which would hide a bottom
          // banner entirely.
          const SafeArea(top: true, bottom: false, child: SizedBox(height: 50)),
          Expanded(
            child: SafeArea(
        top: false,
        child: Column(
          children: [
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
                  child: const Text('🎯 Practice · Neighbours',
                      style: TextStyle(fontSize: 11, color: AppColors.blue, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                Row(children: List.generate(GameState.maxGuesses, (i) {
                  final realGuesses = gameState.guesses.where((g) => !g.isClue).toList();
                  Color pipColor = i < realGuesses.length
                      ? (realGuesses[i].isCorrect ? AppColors.teal : AppColors.red)
                      : (isDark ? AppColors.borderTealDark : AppColors.borderTealLight);
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

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                decoration: BoxDecoration(
                  color: surface,
                  border: Border.all(color: AppColors.blue.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(children: [
                  const Text('COUNTRY', style: TextStyle(
                    fontSize: 10, letterSpacing: 3, color: AppColors.blue, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Text(gameState.puzzle.entry.flagEmoji, style: const TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text(gameState.puzzle.entry.country, style: TextStyle(
                    fontFamily: 'Outfit', fontSize: 32, fontWeight: FontWeight.w800,
                    color: textColor, letterSpacing: -1, height: 1,
                  ), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text('How many land borders does this country have?',
                      style: TextStyle(fontSize: 13, color: textMuted), textAlign: TextAlign.center),
                ]),
              ),
            ),

            const SizedBox(height: 16),

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
                  if (!guess.isCorrect && guessNum != null) {
                    final diff = guessNum - correct;
                    hint = diff > 0 ? '↓ Too high' : '↑ Too low';
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: guess.isCorrect ? AppColors.teal.withOpacity(0.05) : AppColors.red.withOpacity(0.04),
                      border: Border.all(color: guess.isCorrect ? AppColors.teal.withOpacity(0.4) : AppColors.red.withOpacity(0.25)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: guess.isCorrect ? AppColors.teal.withOpacity(0.15) : AppColors.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(child: Icon(guess.isCorrect ? Icons.check_rounded : Icons.close_rounded,
                            size: 16, color: guess.isCorrect ? AppColors.teal : AppColors.red)),
                      ),
                      const SizedBox(width: 10),
                      Text(guess.input, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                          color: guess.isCorrect ? AppColors.teal : textColor)),
                      const SizedBox(width: 10),
                      if (hint.isNotEmpty) Text(hint, style: const TextStyle(fontSize: 13, color: AppColors.red)),
                      const Spacer(),
                      if (guess.isCorrect)
                        const Text('Correct!', style: TextStyle(fontSize: 13, color: AppColors.teal, fontWeight: FontWeight.w600)),
                    ]),
                  );
                },
              ),
            ),

            if (_showResult)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: surface,
                  border: Border.all(color: gameState.status == GameStatus.won
                      ? AppColors.teal.withOpacity(0.4) : AppColors.red.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Text(gameState.status == GameStatus.won ? '🎉' : '💭', style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(gameState.status == GameStatus.won ? 'Got it!' : 'The answer was...',
                            style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700,
                                color: gameState.status == GameStatus.won ? AppColors.teal : AppColors.red)),
                        Text('$correct neighbours', style: TextStyle(fontFamily: 'Outfit', fontSize: 17,
                            fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.3)),
                      ],
                    )),
                  ]),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _advanceSession,
                    child: Container(
                      width: double.infinity, height: 46,
                      decoration: BoxDecoration(gradient: AppColors.gradientTealBlue, borderRadius: BorderRadius.circular(13)),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('Next Puzzle', style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 17),
                      ]),
                    ),
                  ),
                ]),
              )
            else
              AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) {
                  final shake = _shakeController.value;
                  final offset = shake < 0.5 ? Offset(-8 * (shake * 2), 0) : Offset(8 * ((shake - 0.5) * 2), 0);
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
                          style: TextStyle(fontSize: 20, color: textColor, fontWeight: FontWeight.w700),
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
                            boxShadow: [BoxShadow(color: AppColors.teal.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
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
