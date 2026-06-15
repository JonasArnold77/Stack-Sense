import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

// ---------------------------------------------------------------------------
// Provider — wird gefeuert wenn XP vergeben wird
// ---------------------------------------------------------------------------

/// Jedes Mal wenn dieser Wert sich ändert, startet die Reward-Animation.
/// [amount] = wie viele XP vergeben wurden.
class XpRewardEvent {
  final int amount;
  final int id; // Eindeutige ID damit jedes Event genau einmal animiert wird
  const XpRewardEvent({required this.amount, required this.id});
}

final xpRewardProvider = StateProvider<XpRewardEvent?>((ref) => null);

// ---------------------------------------------------------------------------
// Sound-Service (Singleton)
// ---------------------------------------------------------------------------

class _XpSoundPlayer {
  static final _XpSoundPlayer instance = _XpSoundPlayer._();
  _XpSoundPlayer._();

  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;

  Future<void> play() async {
    try {
      if (!_initialized) {
        await _player.setVolume(0.7);
        _initialized = true;
      }
      await _player.stop();
      await _player.play(AssetSource('sounds/xp_chime.wav'));
    } catch (_) {
      // Lautlos wenn Audio nicht verfügbar
    }
  }
}

// ---------------------------------------------------------------------------
// Overlay-Widget — umschließt die gesamte App
// ---------------------------------------------------------------------------

/// Wickle dieses Widget um [MaterialApp] um XP-Animationen app-weit zu zeigen.
class XpRewardOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const XpRewardOverlay({super.key, required this.child});

  @override
  ConsumerState<XpRewardOverlay> createState() => _XpRewardOverlayState();
}

class _XpRewardOverlayState extends ConsumerState<XpRewardOverlay> {
  final List<_ActiveReward> _active = [];
  int? _lastEventId;

  @override
  Widget build(BuildContext context) {
    // Neues Event erkennen
    final event = ref.watch(xpRewardProvider);
    if (event != null && event.id != _lastEventId) {
      _lastEventId = event.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _trigger(event.amount);
      });
    }

    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        // Alle aktiven Animationen übereinander
        ..._active.map((r) => _XpRewardAnimation(
              key: r.key,
              amount: r.amount,
              onDone: () => setState(() => _active.remove(r)),
            )),
      ],
    );
  }

  void _trigger(int amount) {
    _XpSoundPlayer.instance.play();
    setState(() {
      _active.add(_ActiveReward(
        key: UniqueKey(),
        amount: amount,
      ));
    });
  }
}

class _ActiveReward {
  final Key key;
  final int amount;
  _ActiveReward({required this.key, required this.amount});
}

// ---------------------------------------------------------------------------
// Animations-Widget — Sterne + XP-Badge
// ---------------------------------------------------------------------------

class _XpRewardAnimation extends StatefulWidget {
  final int amount;
  final VoidCallback onDone;
  const _XpRewardAnimation({super.key, required this.amount, required this.onDone});

  @override
  State<_XpRewardAnimation> createState() => _XpRewardAnimationState();
}

class _XpRewardAnimationState extends State<_XpRewardAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  // Badge: Scale-Bounce
  late Animation<double> _badgeScale;
  // Alles: Float nach oben
  late Animation<double> _floatUp;
  // Fade out
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Badge ploppt rein: 0-25% = Scale 0→1.15, 25-38% = 1.15→1.0
    _badgeScale = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.18, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 13,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 62,
      ),
    ]).animate(_ctrl);

    // Schwebt 70px nach oben
    _floatUp = Tween(begin: 0.0, end: -70.0)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_ctrl);

    // Fade: voll sichtbar bis 60%, dann ausblenden
    _opacity = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
    ]).animate(_ctrl);

    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Animation-Mittelpunkt: unteres Drittel, horizontal zentriert
    final centerX = size.width / 2;
    final centerY = size.height * 0.66;

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            // Badge-Position: zentriert, schwebt nach oben
            final badgeTop = centerY - 24 + _floatUp.value;

            return Stack(
              textDirection: TextDirection.ltr,
              clipBehavior: Clip.none,
              children: [
                // Sterne-Partikel
                Positioned.fill(
                  child: _StarParticles(
                    center: Offset(centerX, centerY),
                    progress: _ctrl.value,
                    opacity: _opacity.value,
                  ),
                ),

                // +XP Badge — horizontal zentriert
                Positioned(
                  left: 0,
                  right: 0,
                  top: badgeTop,
                  child: Center(
                    child: Opacity(
                      opacity: _opacity.value.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: _badgeScale.value,
                        child: _XpBadge(amount: widget.amount),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// XP-Badge — die "+15 XP ⭐" Pille
// ---------------------------------------------------------------------------

class _XpBadge extends StatelessWidget {
  final int amount;
  const _XpBadge({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFAA00)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.55),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⭐', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 5),
          Text(
            '+$amount XP',
            style: AppTextStyles.labelLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              shadows: [
                const Shadow(
                  color: Color(0x66000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sterne-Partikel — CustomPainter
// ---------------------------------------------------------------------------

class _StarParticles extends StatelessWidget {
  final Offset center;
  final double progress;
  final double opacity;

  const _StarParticles({
    required this.center,
    required this.progress,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StarPainter(
        center: center,
        progress: progress,
        opacity: opacity,
      ),
      size: Size.infinite,
    );
  }
}

class _StarPainter extends CustomPainter {
  final Offset center;
  final double progress;
  final double opacity;

  // Fest definierte Partikel: Winkel (Grad), Distanz, Größe, Farbe
  static const _particles = [
    _Particle(angle: -90, dist: 95, size: 14, colorIdx: 0), // oben mitte
    _Particle(angle: -50, dist: 80, size: 10, colorIdx: 1),
    _Particle(angle: -130, dist: 80, size: 10, colorIdx: 1),
    _Particle(angle: -20, dist: 70, size: 8, colorIdx: 2),
    _Particle(angle: -160, dist: 70, size: 8, colorIdx: 2),
    _Particle(angle: 15, dist: 55, size: 7, colorIdx: 0),
    _Particle(angle: -195, dist: 55, size: 7, colorIdx: 0),
    _Particle(angle: -75, dist: 115, size: 6, colorIdx: 3),
    _Particle(angle: -105, dist: 115, size: 6, colorIdx: 3),
  ];

  static const _colors = [
    Color(0xFFFFD700), // Gold
    Color(0xFFFFAA00), // Orange-Gold
    Color(0xFFFFE066), // Hellgelb
    Color(0xFFFFFFAA), // Weißgold
  ];

  _StarPainter({
    required this.center,
    required this.progress,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || progress <= 0) return;

    // Partikel fliegen in den ersten 45% der Animation raus
    final flyProgress = (progress / 0.45).clamp(0.0, 1.0);
    final eased = Curves.easeOut.transform(flyProgress);

    for (final p in _particles) {
      final rad = p.angle * math.pi / 180;
      final dist = p.dist * eased;
      final pos = Offset(
        center.dx + math.cos(rad) * dist,
        center.dy + math.sin(rad) * dist,
      );

      // Partikel-Opacity: erscheint schnell, verblasst mit Gesamt-Opacity
      final pOpacity = (flyProgress > 0.05 ? 1.0 : flyProgress / 0.05) * opacity;

      _drawStar(canvas, pos, p.size * (0.7 + 0.3 * eased), _colors[p.colorIdx], pOpacity);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Color color, double opacity) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    final path = Path();
    const points = 5;
    const outerR = 1.0;
    const innerR = 0.42;

    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? outerR : innerR;
      final angle = (i * math.pi / points) - math.pi / 2;
      final x = center.dx + math.cos(angle) * size * r;
      final y = center.dy + math.sin(angle) * size * r;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);

    // Kleiner Glow
    canvas.drawCircle(
      center,
      size * 0.5,
      Paint()
        ..color = color.withOpacity(opacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.progress != progress || old.opacity != opacity;
}

class _Particle {
  final double angle; // Grad
  final double dist;  // Max-Distanz in px
  final double size;  // Stern-Größe
  final int colorIdx;

  const _Particle({
    required this.angle,
    required this.dist,
    required this.size,
    required this.colorIdx,
  });
}
