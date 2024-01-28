import 'dart:math';

import 'package:fireworks/src/foundation/controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

class RenderFireworks extends RenderBox {
  RenderFireworks({
    required FireworkController controller,
  }) : _controller = controller;

  /// The controller that manages the fireworks and tells the render box what
  /// and when to paint.
  FireworkController get controller => _controller;
  FireworkController _controller;

  set controller(FireworkController value) {
    if (controller == value) return;

    // Detach old controller.
    _controller.removeListener(_handleControllerUpdate);
    _controller = value;

    // Attach new controller.
    controller.addListener(_handleControllerUpdate);
  }

  @override
  void attach(covariant PipelineOwner owner) {
    super.attach(owner);

    controller.addListener(_handleControllerUpdate);
  }

  @override
  void detach() {
    controller.removeListener(_handleControllerUpdate);

    super.detach();
  }

  void _handleControllerUpdate() {
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  void performResize() {
    super.performResize();

    controller.windowSize = size;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.biggest;
  }

  @override
  bool hitTestSelf(Offset position) {
    return size.contains(position);
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    assert(debugHandleEvent(event, entry));

    if (event is PointerHoverEvent) {
      controller.spawnRocket(Point(
        event.localPosition.dx,
        event.localPosition.dy,
      ));
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas
      ..save()
      ..clipRect(offset & size)
      ..translate(offset.dx, offset.dy);

    if (_controller.withSky) _drawBackground(canvas);
    _drawFireworks(canvas);
    if (_controller.withStars) _drawStars(canvas);

    canvas.restore();
  }

  void _drawBackground(Canvas canvas) {
    canvas.drawPaint(
        Paint()..color = _controller.skyColor ?? const Color(0xff000000));
  }

  void _drawFireworks(Canvas canvas) {
    for (final rocket in controller.rockets) {
      final paint = Paint()
        ..color =
            HSVColor.fromAHSV(1, rocket.hue, 1, rocket.brightness).toColor()
        ..strokeWidth = rocket.size
        ..style = PaintingStyle.stroke;

      canvas.drawPath(
        Path()
          ..moveTo(
            rocket.trailPoints.last.x,
            rocket.trailPoints.last.y,
          )
          ..lineTo(
            rocket.position.x,
            rocket.position.y,
          ),
        paint,
      );
    }

    for (final particle in controller.particles) {
      canvas.drawPath(
        Path()
          ..moveTo(
            particle.trailPoints.last.x,
            particle.trailPoints.last.y,
          )
          ..lineTo(
            particle.position.x,
            particle.position.y,
          ),
        Paint()
          ..color = HSVColor.fromAHSV(
                  particle.alpha, particle.hue % 360, 1, particle.brightness)
              .toColor()
          ..blendMode = BlendMode.screen
          ..strokeWidth = particle.size
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawStars(Canvas canvas) {
    final random = Random(42);
    for (var i = 0; i < 199; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        size.shortestSide / 4e2 * pow(random.nextDouble().clamp(1 / 5, 1), 2),
        Paint()..color = _controller.starColor ?? Color(0xffffffff),
      );
    }
  }
}
