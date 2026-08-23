import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/ad_service.dart';
import '../../../core/utils/meta_banner_ad.dart';
import '../../../core/utils/aluna_availability_service.dart';

// Real ad networks tried in order for the banner slot, before falling
// back to the house banner — Unity first (it's the one with actual
// gaming-category demand for a small new publisher right now), Meta
// second (currently near-zero fill of its own, see the fill-rate
// investigation, but a real independent demand source that costs
// nothing to keep trying). A third provider (e.g. Vungle/Liftoff) slots
// in here later the same way, once it's actually integrated — nothing
// else about this waterfall needs to change to add one.
enum _AdProvider { unity, meta }

const _adProviders = [_AdProvider.unity, _AdProvider.meta];

enum _BannerState { loading, loaded, failed }

/// Where the single persistent banner ad should currently sit — driven by
/// whichever screen is the active route (see BannerPositionRoute) or by
/// MainScaffold for the tab screens. `hidden` covers splash/onboarding and
/// any tab (League, Settings) that has never shown a banner.
///
/// `bottom` is used by pushed routes with no bottom nav bar of their own
/// (the ad sits flush against the screen's bottom safe area). `bottomAboveNav`
/// is used by MainScaffold's own tabs (Home, Stats) — it sits directly above
/// MainScaffold's bottom nav bar instead of underneath/behind it, since both
/// would otherwise anchor to the same screen edge and the ad (painted on top
/// via MaterialApp.builder) would visually cover the nav bar entirely.
enum BannerPosition { top, bottom, bottomAboveNav, hidden }

final bannerPositionProvider = StateProvider<BannerPosition>((ref) => BannerPosition.hidden);

/// Height of MainScaffold's bottom nav bar content (excludes safe-area
/// inset, which it adds separately via its own SafeArea). Shared here so
/// PersistentBannerAd can reserve exactly this much space above the nav bar
/// for `bottomAboveNav` without guessing at a magic number.
const double kMainNavBarHeight = 60;

/// The ONE instance of [BannerAdWidget] for the whole app, injected above
/// the Navigator via MaterialApp.builder (see main.dart) so it's never
/// unmounted by screen navigation — that's the entire point of this
/// widget. Screens never create their own banner; they just set
/// [bannerPositionProvider] to say where they'd like it.
///
/// The underlying BannerAdWidget stays mounted at all times (via
/// Visibility(maintainState: true)) even when "hidden" — removing it from
/// the tree would destroy the native AdView, exactly what this whole
/// change is meant to stop happening. Only its position/visibility changes.
class PersistentBannerAd extends ConsumerWidget {
  const PersistentBannerAd({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(bannerPositionProvider);
    final atTop = position == BannerPosition.top;
    final aboveNav = position == BannerPosition.bottomAboveNav;
    final hidden = position == BannerPosition.hidden;

    // MainScaffold's nav bar renders at kMainNavBarHeight *plus* the
    // device's own bottom safe-area inset (it adds that via its own
    // SafeArea) — reserve exactly that much here, or the ad ends up a few
    // pixels too low and clips into the nav bar's own bottom padding.
    final navBarTotalHeight = kMainNavBarHeight + MediaQuery.of(context).padding.bottom;

    return IgnorePointer(
      ignoring: hidden,
      child: Padding(
        padding: EdgeInsets.only(bottom: aboveNav ? navBarTotalHeight : 0),
        child: Align(
          alignment: atTop ? Alignment.topCenter : Alignment.bottomCenter,
          child: Visibility(
            visible: !hidden,
            maintainState: true,
            maintainAnimation: true,
            maintainSize: false,
            // MainScaffold's nav bar already applies its own bottom
            // safe-area inset below where this ad now sits, so skip a
            // second one here — otherwise the gap doubles up.
            child: BannerAdWidget(atTop: atTop, applyBottomSafeArea: !aboveNav),
          ),
        ),
      ),
    );
  }
}

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
  final bool applyBottomSafeArea;
  const BannerAdWidget({super.key, this.atTop = false, this.applyBottomSafeArea = true});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  // Once every real provider in the waterfall has failed, wait this long
  // before trying the whole thing again from the top. Ad auctions
  // refresh, so a request that fails now can easily succeed a bit later
  // — but ad networks generally advise against refreshing much faster
  // than this: it doesn't meaningfully improve fill odds (inventory
  // doesn't turn over that quickly either) and can start to look like
  // abusive traffic.
  static const _retryInterval = Duration(seconds: 20);
  static const _providerTimeout = Duration(seconds: 8);

  _BannerState _state = _BannerState.loading;
  int _providerIndex = 0;
  Timer? _timeoutTimer;
  Timer? _retryTimer;
  // Bumped on every attempt so the provider widget gets a new Key —
  // that's what actually forces its underlying native platform view to
  // be torn down and recreated, which is what triggers a fresh load
  // attempt (each widget only ever loads once per Key, on creation).
  int _loadAttempt = 0;

  _AdProvider get _currentProvider => _adProviders[_providerIndex];

  @override
  void initState() {
    super.initState();
    _startProviderTimeout();
  }

  void _startProviderTimeout() {
    _timeoutTimer?.cancel();
    // If a provider never calls back at all (success or failure) within
    // this window, treat it the same as an explicit failure.
    _timeoutTimer = Timer(_providerTimeout, () {
      if (mounted && _state == _BannerState.loading) _onProviderFailed();
    });
  }

  void _onProviderLoaded() {
    _timeoutTimer?.cancel();
    _retryTimer?.cancel();
    if (mounted) setState(() => _state = _BannerState.loaded);
  }

  void _onProviderFailed() {
    if (!mounted) return;
    if (_providerIndex < _adProviders.length - 1) {
      // Next provider in the waterfall, immediately — no reason to wait
      // once we already know this one has nothing.
      setState(() {
        _providerIndex++;
        _loadAttempt++;
        _state = _BannerState.loading;
      });
      _startProviderTimeout();
      return;
    }
    // Every provider struck out — fall back to the house banner, and
    // retry the whole waterfall from the top after a cooldown.
    setState(() => _state = _BannerState.failed);
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryInterval, () {
      if (!mounted) return;
      setState(() {
        _providerIndex = 0;
        _loadAttempt++;
        _state = _BannerState.loading;
      });
      _startProviderTimeout();
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  Widget _buildProviderAd() {
    switch (_currentProvider) {
      case _AdProvider.unity:
        return UnityBannerAd(
          key: ValueKey('unity_$_loadAttempt'),
          placementId: adService.unityBannerPlacementId,
          onLoad: (placementId) => _onProviderLoaded(),
          onFailed: (placementId, error, message) {
            debugPrint('Unity banner failed to load: $error $message');
            _onProviderFailed();
          },
        );
      case _AdProvider.meta:
        return MetaBannerAd(
          key: ValueKey('meta_$_loadAttempt'),
          placementId: adService.metaBannerPlacementId,
          onLoad: () => _onProviderLoaded(),
          onFailed: (errorCode, errorMessage) {
            debugPrint('Meta banner failed to load: $errorCode $errorMessage');
            _onProviderFailed();
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!adService.isUnityInitialized && !adService.isMetaInitialized) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: widget.atTop,
      bottom: !widget.atTop && widget.applyBottomSafeArea,
      child: SizedBox(
        width: double.infinity,
        height: 50, // standard banner height
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Real ad — kept mounted even after falling back (just
            // offstage, and periodically retried via the key bump above),
            // so a later successful load — whether from a retry here or
            // the provider's own auto-refresh — can still swap back in
            // automatically without losing the house banner's own state.
            Offstage(
              offstage: _state == _BannerState.failed,
              child: _buildProviderAd(),
            ),
            // Also kept permanently mounted rather than built/torn down
            // conditionally — providers can flicker between loaded and
            // failed (e.g. a brief fill followed by a refresh miss), and
            // conditionally removing this from the tree would destroy its
            // State every time, restarting the whole Higgins/Aluna cycle
            // from scratch instead of just resuming where it left off.
            Offstage(
              offstage: _state != _BannerState.failed,
              child: const _HouseBanner(),
            ),
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
  // Aluna's own intro + live-view sequence needs ~19.5s to play out in
  // full (see _AlunaBannerState) — keep this comfortably above that so
  // its Play Store view actually gets a turn before swapping to Higgins.
  static const _brandDuration = Duration(seconds: 21);

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
          decoration: TextDecoration.none,
        ),
        children: [
          TextSpan(text: bodyText, style: const TextStyle(color: _cream, decoration: TextDecoration.none)),
          TextSpan(text: lastChar, style: const TextStyle(color: _gold, decoration: TextDecoration.none)),
          // Blinking cursor while still typing.
          if (!isFullyTyped)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: FadeTransition(
                opacity: _cursorController,
                child: const Text('|', style: TextStyle(color: _gold, fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
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
            style: const TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w700, fontSize: 16, height: 1.0, decoration: TextDecoration.none),
            children: [
              const TextSpan(text: 'Higgins', style: TextStyle(color: _cream, decoration: TextDecoration.none)),
              const TextSpan(text: '... ', style: TextStyle(color: _gold, decoration: TextDecoration.none)),
              TextSpan(text: 'coming soon', style: TextStyle(color: _cream.withOpacity(0.75), decoration: TextDecoration.none)),
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
// style, these are two visually distinct brands. Once the intro word
// cycle finishes, it settles into a permanent live state that itself
// alternates between a tagline and a "get it on Google Play" call to
// action — the whole banner is tappable and opens Aluna's real Play
// Store listing.

const _alunaBg = Color(0xFF0B1F16);
const _alunaBgDeep = Color(0xFF0F241A);
const _alunaMint = Color(0xFF6EE7B7);
const _alunaWhite = Color(0xFFF4FFF9);
const _alunaMuted = Color(0xFFAFC2B8);

const List<String> _alunaMessages = [
  'relax',
  'take deep breaths',
];

const _alunaPlayStoreUrl = 'https://play.google.com/store/apps/details?id=com.brinklabs.aluna';

class _AlunaBanner extends StatefulWidget {
  const _AlunaBanner({super.key});

  @override
  State<_AlunaBanner> createState() => _AlunaBannerState();
}

enum _AlunaLiveView { tagline, playStore }

class _AlunaBannerState extends State<_AlunaBanner> with TickerProviderStateMixin {
  late final AnimationController _breatheController;
  int _messageIndex = 0;
  bool _wordVisible = false;
  bool _isLive = false;
  _AlunaLiveView _liveView = _AlunaLiveView.tagline;
  Timer? _sequenceTimer;
  Timer? _liveViewTimer;

  // Slow and unhurried on purpose — this is meant to feel calming, not
  // like a typical ad's snappy attention-grab.
  static const _wordFadeIn = Duration(milliseconds: 1400);
  static const _holdWord = Duration(milliseconds: 3000);
  static const _iconSettleDelay = Duration(milliseconds: 900); // before "relax" starts fading in
  static const _breatheStartDelay = Duration(seconds: 3);
  static const _breatheCycle = Duration(seconds: 4);
  // How long the penultimate (tagline) screen holds before switching to
  // the Play Store screen — a one-shot transition, not a loop, so it
  // doesn't flash back to the tagline before the outer Higgins/Aluna
  // swap. The Play Store screen just sits until Aluna itself is swapped
  // out (comfortably longer than 2-3s given the remaining time budget).
  static const _taglineDuration = Duration(seconds: 4, milliseconds: 500);

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
    // the last one — settle permanently into the live-view alternation.
    _sequenceTimer = Timer(_wordFadeIn + _holdWord, () {
      if (!mounted) return;
      setState(() => _wordVisible = false);
      _sequenceTimer = Timer(_wordFadeIn, () {
        if (!mounted) return;
        final isLastMessage = _messageIndex == _alunaMessages.length - 1;
        if (isLastMessage) {
          setState(() {
            _isLive = true;
            _wordVisible = true;
          });
          _scheduleNextLiveView();
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

  void _scheduleNextLiveView() {
    // One-shot: tagline holds, then switches permanently to the Play
    // Store screen for the rest of Aluna's mounted lifetime.
    _liveViewTimer = Timer(_taglineDuration, () {
      if (!mounted) return;
      setState(() => _liveView = _AlunaLiveView.playStore);
    });
  }

  Future<void> _openPlayStore() async {
    if (!alunaAvailabilityService.isLive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🌿 Aluna — coming soon!'), duration: Duration(seconds: 2)),
      );
      return;
    }
    final uri = Uri.parse(_alunaPlayStoreUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _sequenceTimer?.cancel();
    _liveViewTimer?.cancel();
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openPlayStore,
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
            Expanded(
              child: AnimatedOpacity(
                opacity: _wordVisible ? 1.0 : 0.0,
                duration: _wordFadeIn,
                child: _isLive ? _buildLiveContent() : _buildWord(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWord() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        _alunaMessages[_messageIndex],
        style: GoogleFonts.quicksand(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _alunaWhite,
          height: 1.0,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _buildLiveContent() {
    return AnimatedSwitcher(
      // Slower than the default cross-fade — Aluna's brand is calm and
      // unhurried, so the Play Store view should visibly fade in rather
      // than snap on.
      duration: const Duration(milliseconds: 800),
      child: _liveView == _AlunaLiveView.tagline
          ? _buildTagline(key: const ValueKey('tagline'))
          : _buildPlayStoreRow(key: const ValueKey('playstore')),
    );
  }

  Widget _buildWordmark({double fontSize = 16}) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.quicksand(fontSize: fontSize, fontWeight: FontWeight.w700, height: 1.0, decoration: TextDecoration.none),
        children: const [
          TextSpan(text: 'a', style: TextStyle(color: _alunaMint, decoration: TextDecoration.none)),
          TextSpan(text: 'lun', style: TextStyle(color: _alunaWhite, decoration: TextDecoration.none)),
          TextSpan(text: 'a', style: TextStyle(color: _alunaMint, decoration: TextDecoration.none)),
        ],
      ),
    );
  }

  Widget _buildTagline({Key? key}) {
    return Align(
      key: key,
      alignment: Alignment.centerLeft,
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.w700, height: 1.0, decoration: TextDecoration.none),
          children: [
            const TextSpan(text: 'a', style: TextStyle(color: _alunaMint, decoration: TextDecoration.none)),
            const TextSpan(text: 'lun', style: TextStyle(color: _alunaWhite, decoration: TextDecoration.none)),
            const TextSpan(text: 'a', style: TextStyle(color: _alunaMint, decoration: TextDecoration.none)),
            const TextSpan(text: '  ·  ', style: TextStyle(color: _alunaMuted, decoration: TextDecoration.none)),
            TextSpan(
              text: 'no ads, no subscription, on Play Store now',
              style: GoogleFonts.quicksand(fontSize: 12, fontWeight: FontWeight.w500, color: _alunaMuted, height: 1.0, decoration: TextDecoration.none),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayStoreRow({Key? key}) {
    return Row(
      key: key,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildWordmark(),
        const _GooglePlayBadge(),
      ],
    );
  }
}

/// Small "available on Google Play" badge — the Play triangle (rendered
/// with the store's own 4-colour gradient via ShaderMask rather than a
/// bundled image, matching this file's convention of hand-drawing brand
/// marks like [_HigginsLogoBars]) plus "Google Play" in a Google-ish
/// sans-serif. Not the official pixel-exact Play badge asset — a tasteful
/// approximation sized for a 50px cross-promo strip.
class _GooglePlayBadge extends StatelessWidget {
  const _GooglePlayBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF00D2FF), // blue
              Color(0xFF00F076), // green
              Color(0xFFFFCF00), // yellow
              Color(0xFFFF3A44), // red
            ],
            stops: [0.0, 0.4, 0.65, 1.0],
          ).createShader(bounds),
          child: const Icon(Icons.play_arrow_rounded, size: 22, color: Colors.white),
        ),
        const SizedBox(width: 6),
        Text(
          'Google Play',
          style: GoogleFonts.roboto(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _alunaWhite,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
