import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/ad_service.dart';
import '../../../core/utils/meta_banner_ad.dart';

enum _BannerState { loading, loaded, failed }

/// Banner ad, normally shown at the bottom of a screen (as
/// bottomNavigationBar). Uses Meta Audience Network via a native
/// platform channel (see meta_banner_ad.dart). If the real ad fails to
/// load — or Meta never responds at all within a reasonable window
/// (covers "no return", not just an explicit failure callback) — falls
/// back to a self-provided house banner instead of leaving a blank
/// strip.
///
/// Set [atTop] on screens with a text field the on-screen keyboard can
/// cover the bottom of the screen with (the games) — the banner moves
/// above the content instead of getting hidden behind the keyboard.
/// This only flips which edge the widget pads for safe-area insets
/// (status bar vs. home indicator); callers are responsible for actually
/// positioning it at the top of their layout instead of passing it as
/// bottomNavigationBar.
class BannerAdWidget extends StatefulWidget {
  final bool atTop;
  const BannerAdWidget({super.key, this.atTop = false});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  _BannerState _state = _BannerState.loading;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    // If Meta never calls back at all (success or failure) within
    // this window, treat it the same as an explicit failure.
    _timeoutTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && _state == _BannerState.loading) {
        setState(() => _state = _BannerState.failed);
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!adService.isMetaInitialized) return const SizedBox.shrink();

    return SafeArea(
      top: widget.atTop,
      bottom: !widget.atTop,
      child: SizedBox(
        width: double.infinity,
        height: 50, // standard banner height
        child: Stack(
          children: [
            // Real ad — kept mounted even after falling back, so if it
            // loads late (e.g. Meta recovers, or a retry succeeds) it
            // can still swap back in automatically.
            Offstage(
              offstage: _state == _BannerState.failed,
              child: MetaBannerAd(
                placementId: adService.metaBannerPlacementId,
                onLoad: () {
                  _timeoutTimer?.cancel();
                  if (mounted) setState(() => _state = _BannerState.loaded);
                },
                onFailed: (errorCode, errorMessage) {
                  debugPrint('BannerAd failed to load: $errorCode $errorMessage');
                  _timeoutTimer?.cancel();
                  if (mounted) setState(() => _state = _BannerState.failed);
                },
              ),
            ),
            if (_state == _BannerState.failed) const _HouseBanner(),
          ],
        ),
      ),
    );
  }
}

// ── House banner ─────────────────────────────────────────────────────
// Cross-promotion for Mark's other pre-launch apps, shown whenever the
// real ad can't fill. Alternates between the two on a fixed timer
// rather than picking one and sticking with it, so neither app's plug
// gets starved of impressions just because it happened to lose a coin
// flip on mount.

class _HouseBanner extends StatefulWidget {
  const _HouseBanner();

  @override
  State<_HouseBanner> createState() => _HouseBannerState();
}

class _HouseBannerState extends State<_HouseBanner> {
  static const _brandDuration = Duration(seconds: 18);

  int _brandIndex = 0;
  Timer? _alternateTimer;

  @override
  void initState() {
    super.initState();
    _scheduleNext();
  }

  void _scheduleNext() {
    _alternateTimer = Timer(_brandDuration, () {
      if (!mounted) return;
      setState(() => _brandIndex = 1 - _brandIndex);
      _scheduleNext();
    });
  }

  @override
  void dispose() {
    _alternateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      // Each brand widget carries its own key so AnimatedSwitcher treats
      // a re-entry as a fresh instance — Higgins re-types its intro from
      // scratch, Aluna re-breathes from scratch, every time it cycles
      // back around, rather than trying to resume mid-animation.
      child: _brandIndex == 0
          ? const _HigginsBanner(key: ValueKey('higgins'))
          : const _AlunaBanner(key: ValueKey('aluna')),
    );
  }
}

// ── Higgins ──────────────────────────────────────────────────────────
// Dark navy background, bold serif type, cream text with a gold accent
// on the final punctuation mark, typewriter reveal that's LEFT-ANCHORED
// (text stays pinned to its starting x position and grows rightward —
// never re-centers or shifts as characters are added).

const _navyBg = Color(0xFF0D1830);
const _cream = Color(0xFFF4F1EA);
const _gold = Color(0xFFD4AF5A);

// Cross-promotion ad for Higgins (Mark's other app) — exact copy,
// not adapted. Tapping this banner opens Higgins' Play Store listing.
const List<String> _houseMessages = [
  "Hi, I'm Higgins.",
  "I'm your new coach.",
];

// TODO: once Higgins ships, swap this tap behaviour to open its real
// Play Store listing via url_launcher instead of showing this message.

class _HigginsBanner extends StatefulWidget {
  const _HigginsBanner({super.key});

  @override
  State<_HigginsBanner> createState() => _HigginsBannerState();
}

class _HigginsBannerState extends State<_HigginsBanner> with TickerProviderStateMixin {
  int _messageIndex = 0;
  int _charCount = 0;
  bool _showingComingSoon = false; // terminal state — replaces the typing entirely
  Timer? _typeTimer;
  Timer? _cycleTimer;
  late final AnimationController _cursorController;

  static const _msPerChar = 45;
  static const _pauseAfterTyped = Duration(seconds: 3);
  static const _waitBeforeComingSoon = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
    _startTyping();
  }

  void _startTyping() {
    _charCount = 0;
    final message = _houseMessages[_messageIndex];
    _typeTimer?.cancel();
    _typeTimer = Timer.periodic(const Duration(milliseconds: _msPerChar), (timer) {
      if (!mounted) return;
      setState(() => _charCount++);
      if (_charCount >= message.length) {
        timer.cancel();
        final isLastMessage = _messageIndex == _houseMessages.length - 1;
        if (isLastMessage) {
          // After the last message sits fully typed for a few seconds,
          // switch permanently to the "coming soon" state — not another
          // loop back to message 1.
          _cycleTimer = Timer(_waitBeforeComingSoon, () {
            if (!mounted) return;
            setState(() => _showingComingSoon = true);
          });
          return;
        }
        _cycleTimer = Timer(_pauseAfterTyped, () {
          if (!mounted) return;
          setState(() => _messageIndex = (_messageIndex + 1) % _houseMessages.length);
          _startTyping();
        });
      }
    });
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _cycleTimer?.cancel();
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🐾 Coach Higgins — coming soon!'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        height: 50,
        color: _navyBg,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: _showingComingSoon ? _buildComingSoon() : _buildTyping(),
        ),
      ),
    );
  }

  Widget _buildTyping() {
    final message = _houseMessages[_messageIndex];
    final visible = message.substring(0, _charCount.clamp(0, message.length));
    // Split off the final character (typically punctuation) to render
    // it in the gold accent colour, matching the reference design.
    final hasFullText = visible.isNotEmpty;
    final bodyText = hasFullText && visible.length > 1 ? visible.substring(0, visible.length - 1) : '';
    final lastChar = hasFullText ? visible.substring(visible.length - 1) : '';
    final isFullyTyped = _charCount >= message.length;

    return RichText(
      textAlign: TextAlign.left,
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'serif',
          fontWeight: FontWeight.w700,
          fontSize: 16,
          height: 1.0,
        ),
        children: [
          TextSpan(text: bodyText, style: const TextStyle(color: _cream)),
          TextSpan(text: lastChar, style: const TextStyle(color: _gold)),
          // Blinking cursor while still typing.
          if (!isFullyTyped)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: FadeTransition(
                opacity: _cursorController,
                child: const Text('|', style: TextStyle(color: _gold, fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComingSoon() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Higgins logo — 3 ascending gold bars, matching the real
        // in-app wordmark icon (seen next to "Higgins." in the app itself).
        const _HigginsLogoBars(),
        const SizedBox(width: 10),
        RichText(
          text: TextSpan(
            style: const TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w700, fontSize: 16, height: 1.0),
            children: [
              TextSpan(text: 'Higgins', style: TextStyle(color: _cream)),
              TextSpan(text: '... ', style: TextStyle(color: _gold)),
              TextSpan(text: 'coming soon', style: TextStyle(color: _cream.withOpacity(0.75))),
            ],
          ),
        ),
      ],
    );
  }
}

/// Higgins' logo mark — 3 vertical bars of ascending height, gold,
/// rounded tops. Matches the icon shown next to "Higgins." in the
/// actual app's own header.
class _HigginsLogoBars extends StatelessWidget {
  const _HigginsLogoBars();

  @override
  Widget build(BuildContext context) {
    Widget bar(double height) => Container(
          width: 5,
          height: height,
          margin: const EdgeInsets.only(right: 3),
          decoration: const BoxDecoration(
            color: _gold,
            borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
          ),
        );

    return SizedBox(
      width: 24,
      height: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [bar(10), bar(16), bar(22)],
      ),
    );
  }
}

// ── Aluna ────────────────────────────────────────────────────────────
// Dark green background with a glowing mint ring icon that slowly
// "breathes" (scales up and down), matching Aluna's own brand look.
// Text cycles by fading in/out — deliberately NOT the Higgins typewriter
// style, these are two visually distinct brands — landing permanently
// on the wordmark + tagline once the cycle finishes.

const _alunaBg = Color(0xFF0B1F16);
const _alunaBgDeep = Color(0xFF0F241A);
const _alunaMint = Color(0xFF6EE7B7);
const _alunaWhite = Color(0xFFF4FFF9);
const _alunaMuted = Color(0xFFAFC2B8);

const List<String> _alunaMessages = [
  'relax',
  'take deep breaths',
];

// TODO: once Aluna ships, swap this tap behaviour to open its real Play
// Store listing via url_launcher instead of showing this message.

class _AlunaBanner extends StatefulWidget {
  const _AlunaBanner({super.key});

  @override
  State<_AlunaBanner> createState() => _AlunaBannerState();
}

class _AlunaBannerState extends State<_AlunaBanner> with TickerProviderStateMixin {
  late final AnimationController _breatheController;
  int _messageIndex = 0;
  bool _wordVisible = false;
  bool _showingComingSoon = false;
  Timer? _sequenceTimer;

  // Slow and unhurried on purpose — this is meant to feel calming, not
  // like a typical ad's snappy attention-grab.
  static const _wordFadeIn = Duration(milliseconds: 1400);
  static const _holdWord = Duration(milliseconds: 3000);
  static const _iconSettleDelay = Duration(milliseconds: 900); // before "relax" starts fading in
  static const _breatheStartDelay = Duration(seconds: 3);
  static const _breatheCycle = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(vsync: this, duration: _breatheCycle);
    // Icon sits still for a few seconds before it starts breathing,
    // rather than animating immediately on mount.
    Future.delayed(_breatheStartDelay, () {
      if (mounted) _breatheController.repeat(reverse: true);
    });
    // The icon appears first, on its own, before any text starts fading
    // in — not simultaneously.
    _sequenceTimer = Timer(_iconSettleDelay, () {
      if (!mounted) return;
      setState(() => _wordVisible = true);
      _runWordCycle();
    });
  }

  void _runWordCycle() {
    // Current word is already fading in (_wordVisible was just set true);
    // hold it, fade out, then either advance to the next word or — after
    // the last one — settle permanently on the wordmark + tagline.
    _sequenceTimer = Timer(_wordFadeIn + _holdWord, () {
      if (!mounted) return;
      setState(() => _wordVisible = false);
      _sequenceTimer = Timer(_wordFadeIn, () {
        if (!mounted) return;
        final isLastMessage = _messageIndex == _alunaMessages.length - 1;
        if (isLastMessage) {
          setState(() {
            _showingComingSoon = true;
            _wordVisible = true;
          });
          return;
        }
        setState(() {
          _messageIndex++;
          _wordVisible = true;
        });
        _runWordCycle();
      });
    });
  }

  @override
  void dispose() {
    _sequenceTimer?.cancel();
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🧘 Aluna — coming soon!'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        height: 50,
        color: _alunaBg,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _breatheController,
              builder: (context, child) {
                final scale = 1.0 + (_breatheController.value * 0.45);
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _alunaBgDeep,
                  border: Border.all(color: _alunaMint, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: _alunaMint.withOpacity(0.55), blurRadius: 9, spreadRadius: 1),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            AnimatedOpacity(
              opacity: _wordVisible ? 1.0 : 0.0,
              duration: _wordFadeIn,
              child: _showingComingSoon ? _buildComingSoon() : _buildWord(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWord() {
    return Text(
      _alunaMessages[_messageIndex],
      style: GoogleFonts.quicksand(
        fontSize: 16, fontWeight: FontWeight.w600, color: _alunaWhite, height: 1.0,
      ),
    );
  }

  Widget _buildComingSoon() {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.w700, height: 1.0),
        children: [
          const TextSpan(text: 'a', style: TextStyle(color: _alunaMint)),
          const TextSpan(text: 'lun', style: TextStyle(color: _alunaWhite)),
          const TextSpan(text: 'a', style: TextStyle(color: _alunaMint)),
          const TextSpan(text: '  ·  ', style: TextStyle(color: _alunaMuted)),
          TextSpan(
            text: 'no ads, no subscription, coming soon',
            style: GoogleFonts.quicksand(fontSize: 12, fontWeight: FontWeight.w500, color: _alunaMuted, height: 1.0),
          ),
        ],
      ),
    );
  }
}
