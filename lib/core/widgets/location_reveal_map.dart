import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../../features/home/widgets/banner_ad_widget.dart' show BannerPosition;
import '../utils/banner_position_route.dart';

/// Shows a full-screen animated wireframe globe: starts oriented on the
/// user's approximate location (via IP-based geolocation — no device
/// location permission needed), spins to the puzzle's country, and
/// pulses on arrival. Ported from a Claude-Design-built HTML/canvas
/// prototype — same projection math, same rendering layers, same spin
/// physics, rebuilt natively as a Flutter CustomPainter (no WebView,
/// no 3D library — this is all 2D canvas drawing plus basic spherical
/// projection trig, which Flutter's Canvas API handles just as well as
/// HTML5 canvas did).
Future<void> showLocationReveal(
  BuildContext context, {
  required double targetLat,
  required double targetLng,
  required String countryName,
  required String countryEmoji,
}) async {
  await Navigator.of(context).push(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim, secondaryAnim) => FadeTransition(
        opacity: anim,
        child: _GlobeRevealScreen(
          targetLat: targetLat,
          targetLng: targetLng,
          countryName: countryName,
          countryEmoji: countryEmoji,
        ),
      ),
    ),
  );
}

// ── Bundled country border data ─────────────────────────────────────────
// Loaded once and cached — simplified ring data (~185 countries, ~130KB),
// derived from Natural Earth's 110m resolution dataset. Bundled as a
// local asset rather than fetched at runtime: no network dependency for
// the globe's core visual, works offline, faster to show.

class _GlobeData {
  static Map<String, List<List<Offset>>>? _cache; // country name -> rings (lon,lat as Offset.dx/dy)

  static Future<Map<String, List<List<Offset>>>> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/globe_countries.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final countries = data['countries'] as Map<String, dynamic>;
    final result = <String, List<List<Offset>>>{};
    countries.forEach((name, rings) {
      result[name] = (rings as List).map((ring) {
        return (ring as List).map((pt) => Offset((pt[0] as num).toDouble(), (pt[1] as num).toDouble())).toList();
      }).toList();
    });
    _cache = result;
    return result;
  }
}

// ── Spherical projection math (ported directly from the source) ───────

class _Vec3 {
  final double x, y, z;
  const _Vec3(this.x, this.y, this.z);
}

_Vec3 _sphereFromLonLat(double lonDeg, double latDeg) {
  final a = latDeg * pi / 180, b = lonDeg * pi / 180;
  return _Vec3(cos(a) * sin(b), sin(a), cos(a) * cos(b));
}

class _Projected {
  final double x, y, z;
  const _Projected(this.x, this.y, this.z);
}

/// Two-axis rotation: spin (around the vertical axis, by the current
/// animated angle) then tilt (around the horizontal axis, fixed per
/// destination so its latitude sits reasonably centred). Then simple
/// orthographic projection — x,y become screen offsets scaled by
/// radius, z is kept for front/back-face culling.
_Projected _project(_Vec3 p, double ca, double sa, double tiltCos, double tiltSin) {
  final sx = p.x * ca + p.z * sa;
  final sz = -p.x * sa + p.z * ca;
  final sy = p.y;
  final ty = sy * tiltCos - sz * tiltSin;
  final tz = sy * tiltSin + sz * tiltCos;
  return _Projected(sx, ty, tz);
}

/// Computes the spin angle needed to bring a given longitude to face
/// the viewer, always choosing a forward (never backward) spin from
/// the current angle — same wrap-forward logic as the source, so the
/// globe always visibly spins rather than potentially snapping back.
double _targetAngleFor(double fromAngle, double lonDeg) {
  final offset = -lonDeg * pi / 180;
  final base = fromAngle + 2 * 2 * pi;
  return base + (((offset - base) % (2 * pi)) + 2 * pi) % (2 * pi);
}

class _GlobeRevealScreen extends ConsumerStatefulWidget {
  final double targetLat;
  final double targetLng;
  final String countryName;
  final String countryEmoji;
  const _GlobeRevealScreen({
    required this.targetLat,
    required this.targetLng,
    required this.countryName,
    required this.countryEmoji,
  });

  @override
  ConsumerState<_GlobeRevealScreen> createState() => _GlobeRevealScreenState();
}

class _GlobeRevealScreenState extends ConsumerState<_GlobeRevealScreen>
    with TickerProviderStateMixin, BannerPositionRoute<_GlobeRevealScreen> {
  @override
  BannerPosition get bannerPosition => BannerPosition.bottom;

  Map<String, List<List<Offset>>>? _countries;
  late final List<_Star> _stars;
  late final Ticker _clockTicker;
  Duration _elapsed = Duration.zero;

  late final AnimationController _spinController;
  late Animation<double> _spinAnim;

  double _startAngle = 0;
  double _targetAngle = 0;
  double _tiltCos = 1;
  double _tiltSin = 0;
  bool _arrived = false;
  double? _arrivedAtSeconds;
  bool _showLabel = false;
  bool _ready = false;

  static const _spinDuration = Duration(milliseconds: 4000);

  @override
  void initState() {
    super.initState();
    _stars = List.generate(90, (_) => _Star(
      x: Random().nextDouble(),
      y: Random().nextDouble(),
      r: 0.6 + Random().nextDouble() * 1.4,
      phase: Random().nextDouble() * 2 * pi,
    ));
    _clockTicker = createTicker((elapsed) {
      setState(() => _elapsed = elapsed);
    })..start();

    _spinController = AnimationController(vsync: this, duration: _spinDuration);
    _spinAnim = CurvedAnimation(parent: _spinController, curve: Curves.easeOutCubic);

    _setup();
  }

  Future<void> _setup() async {
    // IP-based geolocation — approximates the user's country/region
    // from their network connection, entirely server-side. No device
    // location permission needed at all.
    double startLat = 20, startLng = 0;
    try {
      final response = await http.get(Uri.parse('https://ipwho.is/')).timeout(const Duration(seconds: 4));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] != false) {
        startLat = (data['latitude'] as num).toDouble();
        startLng = (data['longitude'] as num).toDouble();
      }
    } catch (_) {
      // Falls back to the default start position above — still gives a
      // full spinning-globe effect, just without personalisation.
    }

    final countries = await _GlobeData.load();
    if (!mounted) return;

    // Tilt centres the destination's latitude reasonably in view: after
    // the spin aligns its longitude to face the viewer, a tilt equal to
    // the latitude itself brings that point to the vertical middle
    // (derived directly from the rotation math, not just eyeballed).
    final tilt = widget.targetLat * pi / 180;

    setState(() {
      _countries = countries;
      _startAngle = _targetAngleFor(0, startLng);
      _targetAngle = _targetAngleFor(_startAngle, widget.targetLng);
      _tiltCos = cos(tilt);
      _tiltSin = sin(tilt);
      _ready = true;
    });

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    await _spinController.forward();
    if (!mounted) return;

    HapticFeedback.heavyImpact();
    setState(() {
      _arrived = true;
      _arrivedAtSeconds = _elapsed.inMilliseconds / 1000.0;
      _showLabel = true;
    });
  }

  @override
  void dispose() {
    _clockTicker.dispose();
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final angle = _ready ? _startAngle + (_targetAngle - _startAngle) * _spinAnim.value : 0.0;
    final nowSeconds = _elapsed.inMilliseconds / 1000.0;

    return Scaffold(
      backgroundColor: Colors.black,
      bottomNavigationBar:
          const SafeArea(top: false, bottom: true, child: SizedBox(height: 50)),
      body: Stack(
        children: [
          Positioned.fill(
            child: _ready
                ? CustomPaint(
                    painter: _GlobePainter(
                      countries: _countries!,
                      angle: angle,
                      tiltCos: _tiltCos,
                      tiltSin: _tiltSin,
                      nowSeconds: nowSeconds,
                      stars: _stars,
                      targetLat: widget.targetLat,
                      targetLng: widget.targetLng,
                      targetCountry: widget.countryName,
                      arrived: _arrived,
                      arrivedAtSeconds: _arrivedAtSeconds,
                    ),
                  )
                : const Center(child: CircularProgressIndicator(color: AppColors.teal)),
          ),

          // Top label
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AnimatedOpacity(
                opacity: _showLabel ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.teal.withOpacity(0.4)),
                    ),
                    child: Text(
                      '${widget.countryEmoji}  ${widget.countryName}',
                      style: const TextStyle(
                        fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Continue button
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: AnimatedOpacity(
                  opacity: _arrived ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: GestureDetector(
                    onTap: _arrived ? () => Navigator.of(context).pop() : null,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppColors.gradientTealBlue,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: AppColors.teal.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 5)),
                        ],
                      ),
                      child: const Center(
                        child: Text('Continue',
                            style: TextStyle(
                              fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700,
                              color: Colors.black,
                            )),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Skip button
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Skip', style: TextStyle(color: Colors.white70, fontSize: 13)),
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

class _Star {
  final double x, y, r, phase;
  const _Star({required this.x, required this.y, required this.r, required this.phase});
}

class _GlobePainter extends CustomPainter {
  final Map<String, List<List<Offset>>> countries;
  final double angle;
  final double tiltCos, tiltSin;
  final double nowSeconds;
  final List<_Star> stars;
  final double targetLat, targetLng;
  final String targetCountry;
  final bool arrived;
  final double? arrivedAtSeconds;

  _GlobePainter({
    required this.countries,
    required this.angle,
    required this.tiltCos,
    required this.tiltSin,
    required this.nowSeconds,
    required this.stars,
    required this.targetLat,
    required this.targetLng,
    required this.targetCountry,
    required this.arrived,
    required this.arrivedAtSeconds,
  });

  Path _buildRingPath(List<Offset> ring, double ca, double sa, Offset centre, double radius, {double zCutoff = 0.02}) {
    final path = Path();
    bool pen = false;
    for (final pt in ring) {
      final v = _sphereFromLonLat(pt.dx, pt.dy);
      final q = _project(v, ca, sa, tiltCos, tiltSin);
      if (q.z > zCutoff) {
        final x = centre.dx + q.x * radius, y = centre.dy - q.y * radius;
        if (pen) {
          path.lineTo(x, y);
        } else {
          path.moveTo(x, y);
          pen = true;
        }
      } else {
        pen = false;
      }
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final centre = Offset(w * 0.5, h * 0.4);
    final radius = min(w, h) * 0.34;
    final ca = cos(angle), sa = sin(angle);

    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);

    // Stars — pulsing, additive-ish glow
    for (final s in stars) {
      final alpha = 0.35 + 0.5 * (0.5 + 0.5 * sin(nowSeconds * 1.667 + s.phase));
      canvas.drawCircle(
        Offset(s.x * w, s.y * h),
        s.r,
        Paint()..color = const Color(0xFF96FFC8).withOpacity(alpha.clamp(0.0, 1.0)),
      );
    }

    // Sphere body
    final bodyRect = Rect.fromCircle(center: centre, radius: radius);
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.35),
        colors: const [Color(0xFF0A3023), Color(0xFF072018), Color(0xFF04140E)],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(bodyRect);
    canvas.drawCircle(centre, radius, bodyPaint);

    // Halo
    final haloRect = Rect.fromCircle(center: centre, radius: radius * 1.32);
    final haloPaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF3CF096).withOpacity(0),
          const Color(0xFF3CF096).withOpacity(0.08),
          const Color(0xFF3CF096).withOpacity(0),
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(haloRect);
    canvas.drawCircle(centre, radius * 1.32, haloPaint);

    // Graticule (faint lat/lon grid)
    final gratPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x1A46DC96);
    for (var lon = -180; lon < 180; lon += 30) {
      final seg = <Offset>[];
      for (var lat = -80; lat <= 80; lat += 4) {
        seg.add(Offset(lon.toDouble(), lat.toDouble()));
      }
      canvas.drawPath(_buildRingPath(seg, ca, sa, centre, radius), gratPaint);
    }
    for (var lat = -60; lat <= 60; lat += 30) {
      final seg = <Offset>[];
      for (var lon = -180; lon <= 180; lon += 5) {
        seg.add(Offset(lon.toDouble(), lat.toDouble()));
      }
      canvas.drawPath(_buildRingPath(seg, ca, sa, centre, radius), gratPaint);
    }

    // Country borders — double stroke: soft thick glow pass + thin bright pass
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..color = const Color(0x1F28BE73);
    final brightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..color = const Color(0xB27DFFBC);

    for (final rings in countries.values) {
      for (final ring in rings) {
        final path = _buildRingPath(ring, ca, sa, centre, radius);
        canvas.drawPath(path, glowPaint);
        canvas.drawPath(path, brightPaint);
      }
    }

    // Destination highlight + marker — only once arrived
    if (arrivedAtSeconds != null) {
      final revealT = nowSeconds - arrivedAtSeconds!;
      final k = min(1.0, revealT / 0.6);
      final pulse = 0.5 + 0.5 * sin(revealT * 4);

      final destRings = countries[targetCountry];
      if (destRings != null) {
        final fillPaint = Paint()
          ..blendMode = BlendMode.plus
          ..color = const Color(0xFF46F096).withOpacity((0.3 + 0.12 * pulse) * k);
        final strokePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFBEFFD7).withOpacity(0.9 * k);
        for (final ring in destRings) {
          final path = _buildRingPath(ring, ca, sa, centre, radius, zCutoff: 0)..close();
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, strokePaint);
        }
      }

      // Pulsing marker at the exact destination point
      final markerVec = _sphereFromLonLat(targetLng, targetLat);
      final m = _project(markerVec, ca, sa, tiltCos, tiltSin);
      if (m.z > -0.1) {
        final markerPos = Offset(centre.dx + m.x * radius, centre.dy - m.y * radius);
        final glowRadius = 26.0;
        final markerGlow = Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFD2FFE1).withOpacity(0.85 * k),
            const Color(0xFF5AFFAF).withOpacity(0.4 * k),
            const Color(0xFF5AFFAF).withOpacity(0),
          ]).createShader(Rect.fromCircle(center: markerPos, radius: glowRadius));
        canvas.drawCircle(markerPos, glowRadius, markerGlow);

        final ringOuter = 20 + 60 * (pulse * 0.5 + 0.25);
        canvas.drawCircle(
          markerPos, ringOuter / 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppColors.yellow.withOpacity((1 - pulse * 0.5).clamp(0.0, 1.0) * k),
        );
        canvas.drawCircle(markerPos, 9, Paint()..color = AppColors.yellow.withOpacity(k));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GlobePainter oldDelegate) => true;
}
