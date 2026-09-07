import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'go_ui.dart';
import 'l10n/go_localizations.dart';

/// Bundled artwork only: launch never waits for a timer or external assets.
class GoLaunchArt extends StatelessWidget {
  const GoLaunchArt({super.key});

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: GoPalette.ink,
      body: Stack(
        children: [
          const Positioned.fill(
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: CustomPaint(painter: _LaunchBackdrop()),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, bounds) => Stack(
                children: [
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 48,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: reduced ? 1 : 0, end: 1),
                          duration: reduced
                              ? Duration.zero
                              : const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) => Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, (1 - value) * 8),
                              child: child,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const GoLaunchEmblem(),
                              const SizedBox(height: 12),
                              const Text(
                                'GOwallet',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFFEDF5F1),
                                  fontSize: 36,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -1.3,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                goTr(context, '小型 PoW 资产，自主持有'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFA6BBB1),
                                  fontSize: 13,
                                  height: 1.6,
                                  letterSpacing: .2,
                                ),
                              ),
                              const SizedBox(height: 38),
                              Semantics(
                                label: goTr(context, '正在加载钱包'),
                                child: SizedBox(
                                  width: 64,
                                  height: 2,
                                  child: LinearProgressIndicator(
                                    value: reduced ? .5 : null,
                                    color: GoPalette.mint,
                                    backgroundColor: GoPalette.mint.withValues(
                                      alpha: .12,
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 13),
                              Text(
                                goTr(context, '正在加载钱包'),
                                style: TextStyle(
                                  color: const Color(
                                    0xFFA6BBB1,
                                  ).withValues(alpha: .65),
                                  fontSize: 11,
                                  letterSpacing: .3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (bounds.maxHeight >= 640 &&
                      MediaQuery.textScalerOf(context).scale(14) <= 21)
                    Positioned(
                      bottom: 28,
                      left: 24,
                      right: 24,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.key_outlined,
                            size: 14,
                            color: GoPalette.mint.withValues(alpha: .55),
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              goTr(context, '密钥留在你的设备'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: const Color(
                                  0xFFA6BBB1,
                                ).withValues(alpha: .65),
                                fontSize: 11,
                                letterSpacing: .5,
                              ),
                            ),
                          ),
                        ],
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

class GoLaunchEmblem extends StatelessWidget {
  const GoLaunchEmblem({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 208,
    height: 208,
    child: Stack(
      alignment: Alignment.center,
      children: [
        const Positioned.fill(
          child: ExcludeSemantics(child: CustomPaint(painter: _EmblemRings())),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .22),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: GoPalette.mint.withValues(alpha: .10),
                blurRadius: 46,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const GoMark(size: 104),
        ),
      ],
    ),
  );
}

class _EmblemRings extends CustomPainter {
  const _EmblemRings();
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7;
    canvas.drawCircle(
      center,
      80,
      paint..color = GoPalette.mint.withValues(alpha: .13),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 99),
      math.pi * .08,
      math.pi * .85,
      false,
      paint..color = GoPalette.mint.withValues(alpha: .11),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 99),
      math.pi * 1.08,
      math.pi * .65,
      false,
      paint..color = GoPalette.mint.withValues(alpha: .11),
    );
    final node = center + Offset(math.cos(-.62), math.sin(-.62)) * 80;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: node, width: 4, height: 4),
        const Radius.circular(1),
      ),
      Paint()..color = GoPalette.mint.withValues(alpha: .5),
    );
  }

  @override
  bool shouldRepaint(_EmblemRings oldDelegate) => false;
}

class _LaunchBackdrop extends CustomPainter {
  const _LaunchBackdrop();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -.22),
          radius: .8,
          colors: [Color(0xFF1B3930), GoPalette.ink, Color(0xFF0D1C19)],
          stops: [0, .62, 1],
        ).createShader(rect),
    );
    final paint = Paint()
      ..color = GoPalette.mint.withValues(alpha: .035)
      ..strokeWidth = .6;
    for (final ratio in [.16, .84]) {
      final x = size.width * ratio;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      for (final y in [size.height * .14, size.height * .86]) {
        final cross = Paint()
          ..color = GoPalette.mint.withValues(alpha: .16)
          ..strokeWidth = .8;
        canvas.drawLine(Offset(x - 3, y), Offset(x + 3, y), cross);
        canvas.drawLine(Offset(x, y - 3), Offset(x, y + 3), cross);
      }
    }
  }

  @override
  bool shouldRepaint(_LaunchBackdrop oldDelegate) => false;
}
