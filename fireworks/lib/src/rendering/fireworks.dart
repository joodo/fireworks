import 'dart:math';
import 'dart:typed_data';

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

  // Reuse buffers to avoid per-frame memory allocation
  Float32List _rectBuffer = Float32List(0);
  Float32List _transformBuffer = Float32List(0);
  Int32List _colorBuffer = Int32List(0);

  void _drawFireworks(Canvas canvas) {
    final sprite = controller.particleSprite;
    if (sprite == null) return;

    // Render Rockets (kept simple for now as they are few)
    final rocketPaint = Paint()..style = PaintingStyle.stroke;
    for (final rocket in controller.rockets) {
      rocketPaint
        ..color = rocket.baseColor
        ..strokeWidth = rocket.size;
      canvas.drawLine(
        Offset(rocket.oldestTrailPoint.x, rocket.oldestTrailPoint.y),
        Offset(rocket.position.x, rocket.position.y),
        rocketPaint,
      );
    }

    // Render Particles using drawRawAtlas
    final int count = controller.particles.length;
    if (count == 0) return;

    _prepareBuffers(count);

    final double sw = sprite.width.toDouble();
    final double sh = sprite.height.toDouble();

    for (int i = 0; i < count; i++) {
      final p = controller.particles[i];
      final int offset = i * 4;

      // Source rect in the sprite image
      _rectBuffer[offset + 0] = 0;
      _rectBuffer[offset + 1] = 0;
      _rectBuffer[offset + 2] = sw;
      _rectBuffer[offset + 3] = sh;

      // Transformation: [scos, ssin, tx, ty]
      // We center the sprite on the particle position
      _transformBuffer[offset + 0] = 1.0; // scale
      _transformBuffer[offset + 1] = 0.0; // rotation
      _transformBuffer[offset + 2] = p.position.x - sw / 2;
      _transformBuffer[offset + 3] = p.position.y - sh / 2;

      // Color and opacity
      _colorBuffer[i] = p.baseColor
          .withAlpha((p.alpha * 255).clamp(0, 255).toInt())
          .toARGB32();
    }

    // The single most efficient way to draw thousands of particles
    canvas.drawRawAtlas(
      sprite,
      _transformBuffer.buffer.asFloat32List(0, count * 4),
      _rectBuffer.buffer.asFloat32List(0, count * 4),
      _colorBuffer.buffer.asInt32List(0, count),
      BlendMode.modulate,
      null,
      Paint(),
    );
  }

  /// Grows buffers only when needed to minimize re-allocation.
  void _prepareBuffers(int count) {
    if (_colorBuffer.length < count) {
      _rectBuffer = Float32List(count * 4);
      _transformBuffer = Float32List(count * 4);
      _colorBuffer = Int32List(count);
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
