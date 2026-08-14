import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/worldcup_provider.dart';
import '../../../data/models/capital_entry.dart';
import '../../home/widgets/banner_ad_widget.dart';

// ── Entry Menu ─────────────────────────────────────────────────────────────

class WorldCupMenuScreen extends ConsumerWidget {
  const WorldCupMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wcAsync = ref.watch(wcProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bg : AppColors.bgLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final surface2 = isDark ? AppColors.surface2 : AppColors.surface2Light;

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: const BannerAdWidget(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back + title
              Row(
                children: [
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('World Cup 2026', style: TextStyle(
                        fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.w800,
                        color: textColor, letterSpacing: -0.5,
                      )),
                      Text('Capital City Challenge', style: TextStyle(fontSize: 12, color: textMuted)),
                    ],
                  ),
                  const Spacer(),
                  const Text('⚽', style: TextStyle(fontSize: 28)),
                ],
              ),

              const SizedBox(height: 24),

              // Info badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.1),
                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Name the capital of every World Cup nation. 1 attempt each. Share your score!',
                        style: TextStyle(fontSize: 12, color: textMuted, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text('SELECT ROUND', style: TextStyle(
                  fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.w600, color: textMuted)),
              const SizedBox(height: 12),

              // Round cards
              Expanded(
                child: wcAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.teal)),
                  error: (_, __) => _RoundList(wcState: WCState(allTeams: kWC2026Teams), isDark: isDark),
                  data: (wcState) => _RoundList(wcState: wcState, isDark: isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundList extends StatelessWidget {
  final WCState wcState;
  final bool isDark;
  const _RoundList({required this.wcState, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: WCRound.values.map((round) {
        final available = wcState.roundAvailable(round);
        final teamCount = round == WCRound.all48
            ? wcState.allTeams.length
            : (wcState.roundTeams[round]?.length ?? 0);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _RoundCard(
            round: round,
            available: available,
            teamCount: teamCount,
            isDark: isDark,
            onTap: available
                ? () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => WorldCupGameScreen(
                        round: round,
                        teams: wcState.teamsForRound(round),
                      ),
                    ))
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _RoundCard extends StatelessWidget {
  final WCRound round;
  final bool available;
  final int teamCount;
  final bool isDark;
  final VoidCallback? onTap;

  const _RoundCard({
    required this.round,
    required this.available,
    required this.teamCount,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: available ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: available
                ? const Color(0xFFFFD700).withOpacity(0.07)
                : surface,
            border: Border.all(
              color: available
                  ? const Color(0xFFFFD700).withOpacity(0.35)
                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: available
                      ? const Color(0xFFFFD700).withOpacity(0.15)
                      : (isDark ? AppColors.surface2 : AppColors.surface2Light),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(child: Text(round.emoji, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(round.label, style: TextStyle(
                      fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700,
                      color: textColor, letterSpacing: -0.3,
                    )),
                    const SizedBox(height: 2),
                    Text(
                      available
                          ? '$teamCount teams · guess their capitals'
                          : 'Not yet decided',
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ],
                ),
              ),
              if (available)
                Icon(Icons.arrow_forward_ios_rounded, color: textMuted, size: 16)
              else
                Icon(Icons.lock_outline_rounded, color: textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Game Screen ────────────────────────────────────────────────────────────

class WorldCupGameScreen extends StatefulWidget {
  final WCRound round;
  final List<WCTeam> teams;

  const WorldCupGameScreen({super.key, required this.round, required this.teams});

  @override
  State<WorldCupGameScreen> createState() => _WorldCupGameScreenState();
}

class _WorldCupGameScreenState extends State<WorldCupGameScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late List<WCTeam> _shuffled;
  int _current = 0;
  int _correct = 0;
  bool _answered = false;
  bool _wasCorrect = false;
  bool _finished = false;
  final List<bool> _results = [];
  late AnimationController _shakeController;
  List<String> _suggestions = [];

  // Same guess pool as a normal Capital round — every world capital plus
  // decoy cities — not just the teams in this round. Restricting to round
  // teams made it too easy (too few possible matches to type against).
  List<String> _getSuggestions(String query) {
    if (query.isEmpty) return [];
    final lower = query.toLowerCase();
    final capitals = kCapitals.map((e) => e.capital).toList();
    final decoys = kCapitals.expand((e) => e.decoyCities.map((d) => d.name)).toList();
    final candidates = {...capitals, ...decoys}.toList();
    candidates.sort();
    return candidates.where((c) => c.toLowerCase().contains(lower)).toList();
  }

  @override
  void initState() {
    super.initState();
    _shuffled = [...widget.teams]..shuffle();
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_answered) return;
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    final team = _shuffled[_current];
    final correct = input.toLowerCase() == team.capital.toLowerCase();

    setState(() {
      _answered = true;
      _wasCorrect = correct;
      if (correct) _correct++;
      _results.add(correct);
    });

    if (correct) HapticFeedback.heavyImpact();
    else {
      HapticFeedback.mediumImpact();
      _shakeController.forward(from: 0);
    }
  }

  void _next() {
    if (_current >= _shuffled.length - 1) {
      setState(() => _finished = true);
    } else {
      setState(() {
        _current++;
        _answered = false;
        _wasCorrect = false;
        _suggestions = [];
        _controller.clear();
      });
      _focusNode.requestFocus();
    }
  }

  void _skip() {
    if (_answered) return;
    setState(() {
      _answered = true;
      _wasCorrect = false;
      _results.add(false);
    });
    HapticFeedback.lightImpact();
  }

  void _share() {
    final total = _shuffled.length;
    final grid = _results.map((r) => r ? '🟩' : '🟥').join('');
    final text = 'I got $_correct/$total in the World Cup 2026 Capital Quiz on Capitle! ⚽🌍\n${widget.round.label}\n$grid\n\nInstall Capitle now on:\nhttps://play.google.com/store/apps/details?id=com.brinklabs.capitle';
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bg : AppColors.bgLight;

    if (_finished) return _buildResult(isDark);

    final team = _shuffled[_current];
    final progress = _current / _shuffled.length;

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: const BannerAdWidget(),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surface2 : AppColors.surface2Light,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 16,
                          color: isDark ? AppColors.textDimDark : AppColors.textDimLight),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${widget.round.emoji} ${widget.round.label}',
                            style: const TextStyle(
                              fontFamily: 'Outfit', fontSize: 14,
                              fontWeight: FontWeight.w700, color: AppColors.teal,
                            )),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: isDark ? AppColors.surface2 : AppColors.surface2Light,
                            valueColor: const AlwaysStoppedAnimation(AppColors.teal),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${_current + 1}/${_shuffled.length}',
                      style: TextStyle(
                        fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textDimDark : AppColors.textDimLight,
                      )),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Score
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withOpacity(0.1),
                      border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$_correct correct',
                        style: const TextStyle(
                          fontFamily: 'Outfit', fontSize: 14,
                          fontWeight: FontWeight.w700, color: AppColors.teal,
                        )),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Flag + country card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surface : AppColors.surfaceLight,
                  border: Border.all(
                    color: _answered
                        ? (_wasCorrect
                            ? AppColors.teal.withOpacity(0.5)
                            : AppColors.red.withOpacity(0.5))
                        : const Color(0xFFFFD700).withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Text(team.flagEmoji, style: const TextStyle(fontSize: 64)),
                    const SizedBox(height: 12),
                    Text('What is the capital of', style: TextStyle(
                      fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    )),
                    const SizedBox(height: 4),
                    Text(team.name, style: TextStyle(
                      fontFamily: 'Outfit', fontSize: 32, fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.textDark : AppColors.textLight,
                      letterSpacing: -1,
                    )),
                    if (_answered) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: _wasCorrect
                              ? AppColors.teal.withOpacity(0.1)
                              : AppColors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_wasCorrect ? '✓' : '✗',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _wasCorrect ? AppColors.teal : AppColors.red,
                                )),
                            const SizedBox(width: 8),
                            Text(
                              _wasCorrect
                                  ? 'Correct! ${team.capital}'
                                  : 'It\'s ${team.capital}',
                              style: TextStyle(
                                fontFamily: 'Outfit', fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _wasCorrect ? AppColors.teal : AppColors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Input or Next button
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: _answered
                    ? GestureDetector(
                        onTap: _next,
                        child: Container(
                          width: double.infinity, height: 54,
                          decoration: BoxDecoration(
                            gradient: AppColors.gradientTealBlue,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(
                              color: AppColors.teal.withOpacity(0.3),
                              blurRadius: 16, offset: const Offset(0, 4),
                            )],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _current >= _shuffled.length - 1
                                    ? 'See Results'
                                    : 'Next Country',
                                style: const TextStyle(
                                  fontFamily: 'Outfit', fontSize: 16,
                                  fontWeight: FontWeight.w700, color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded,
                                  color: Colors.black, size: 20),
                            ],
                          ),
                        ),
                      )
                    : Column(
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
                                    onTap: () {
                                      _controller.text = s;
                                      _controller.selection = TextSelection.fromPosition(
                                        TextPosition(offset: s.length));
                                      setState(() => _suggestions = []);
                                      _focusNode.requestFocus();
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isFirst
                                            ? AppColors.teal.withOpacity(0.1)
                                            : (isDark ? AppColors.surface2 : AppColors.surface2Light),
                                        border: Border.all(
                                          color: isFirst
                                              ? (isDark ? AppColors.borderTealDark : AppColors.borderTealLight)
                                              : (isDark ? AppColors.borderDark : AppColors.borderLight),
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(s, style: TextStyle(
                                        fontSize: 13,
                                        color: isFirst
                                            ? AppColors.teal
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: _skip,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.surface2 : AppColors.surface2Light,
                                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text('Skip',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                        fontWeight: FontWeight.w500,
                                      )),
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
                                color: isDark ? AppColors.textDark : AppColors.textLight,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Type the capital city…',
                              ),
                              onChanged: (v) => setState(() {
                              _suggestions = _getSuggestions(v);
                            }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _submit,
                            child: Container(
                              width: 52, height: 52,
                              decoration: BoxDecoration(
                                gradient: _controller.text.trim().isNotEmpty
                                    ? AppColors.gradientTealBlue
                                    : null,
                                color: _controller.text.trim().isEmpty
                                    ? (isDark ? AppColors.surface2 : AppColors.surface2Light)
                                    : null,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.arrow_forward_rounded,
                                  color: _controller.text.trim().isNotEmpty
                                      ? Colors.black
                                      : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                                  size: 22),
                            ),
                          ),
                        ],
                      ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(bool isDark) {
    final total = _shuffled.length;
    final pct = (_correct / total * 100).round();
    final bg = isDark ? AppColors.bg : AppColors.bgLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    String medal;
    if (pct >= 90) medal = '🥇';
    else if (pct >= 70) medal = '🥈';
    else if (pct >= 50) medal = '🥉';
    else medal = '⚽';

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: const BannerAdWidget(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            children: [
              // Score hero
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: AppColors.gradientTealBlueSubtle,
                  border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Text(medal, style: const TextStyle(fontSize: 56)),
                    const SizedBox(height: 12),
                    Text('$_correct / $total', style: TextStyle(
                      fontFamily: 'Outfit', fontSize: 48, fontWeight: FontWeight.w800,
                      color: textColor, letterSpacing: -2, height: 1,
                    )),
                    const SizedBox(height: 4),
                    Text('${widget.round.emoji} ${widget.round.label}',
                        style: const TextStyle(fontSize: 14, color: AppColors.teal, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(_scoreMessage(pct),
                        style: TextStyle(fontSize: 13, color: textMuted),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Result grid
              Wrap(
                spacing: 4, runSpacing: 4,
                children: _results.map((r) => Text(
                  r ? '🟩' : '🟥',
                  style: const TextStyle(fontSize: 20),
                )).toList(),
              ),

              const SizedBox(height: 24),

              // Share button
              GestureDetector(
                onTap: _share,
                child: Container(
                  width: double.infinity, height: 54,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientTealBlue,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(
                      color: AppColors.teal.withOpacity(0.3),
                      blurRadius: 16, offset: const Offset(0, 4),
                    )],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.ios_share_rounded, color: Colors.black, size: 18),
                      SizedBox(width: 8),
                      Text('Share Score', style: TextStyle(
                        fontFamily: 'Outfit', fontSize: 16,
                        fontWeight: FontWeight.w700, color: Colors.black,
                      )),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Play again / back
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _shuffled.shuffle();
                          _current = 0;
                          _correct = 0;
                          _answered = false;
                          _wasCorrect = false;
                          _finished = false;
                          _results.clear();
                          _controller.clear();
                        });
                      },
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.teal.withOpacity(0.1),
                          border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(child: Text('Play Again',
                            style: TextStyle(fontFamily: 'Outfit', fontSize: 14,
                                fontWeight: FontWeight.w700, color: AppColors.teal))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surface2 : AppColors.surface2Light,
                          border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(child: Text('Home',
                            style: TextStyle(fontSize: 14, color: textMuted, fontWeight: FontWeight.w500))),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _scoreMessage(int pct) {
    final round = widget.round.label;
    if (pct == 100) return 'Perfect! You knew every capital in the $round! 🌍';
    if (pct >= 90) return 'Outstanding! Almost flawless in the $round.';
    if (pct >= 70) return 'Solid effort in the $round — you know your capitals!';
    if (pct >= 50) return 'Not bad! A few $round capitals surprised you though…';
    if (pct >= 30) return 'The $round gave you some trouble 😅';
    return 'Time to study up before the next round!';
  }
}
