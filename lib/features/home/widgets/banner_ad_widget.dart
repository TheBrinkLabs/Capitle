import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import '../../../core/utils/ad_service.dart';
import '../../../core/utils/meta_banner_ad.dart';
import '../../../core/utils/vungle_banner_ad.dart';
import '../../../core/widgets/aluna_house_ad.dart';

// Real ad networks tried in order for the banner slot, before falling
// back to the house banner — Unity first (it's the one with actual
// gaming-category demand for a small new publisher right now), Meta
// second (currently near-zero fill of its own, see the fill-rate
// investigation, but a real independent demand source that costs
// nothing to keep trying), Vungle third (freshly integrated — its own
// fill rate here isn't established yet).
enum _AdProvider { unity, meta, vungle }

const _adProviders = [_AdProvider.unity, _AdProvider.meta, _AdProvider.vungle];

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
      case _AdProvider.vungle:
        return VungleBannerAd(
          key: ValueKey('vungle_$_loadAttempt'),
          placementId: adService.vungleBannerPlacementId,
          onLoad: () => _onProviderLoaded(),
          onFailed: (errorCode, errorMessage) {
            debugPrint('Vungle banner failed to load: $errorCode $errorMessage');
            _onProviderFailed();
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!adService.isUnityInitialized && !adService.isMetaInitialized && !adService.isVungleInitialized) {
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
          : const AlunaBanner(key: ValueKey('aluna')),
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
