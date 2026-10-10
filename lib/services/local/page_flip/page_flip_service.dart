import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter-flip-animation/misc/half_clipper.dart';

/// Service encapsulating the "newspaper page flip" effect (3D page flip
///
/// The service does NOT own the controller: the page creates it (via
/// [PageFlipService.createController]) and handles its disposal.
///
/// The controller value represents the "current page" as a continuous value:
/// 0.0 = first page, 1.0 = second page, 0.5 = halfway through the flip.
class PageFlipService {
  PageFlipService({
    required this.controller,
    this.velocityThreshold = 500,
    this.flipDuration = const Duration(milliseconds: 300),
    this.flipCurve = Curves.easeOut,
    this.perspective = 0.001,
    this.shadowOpacity = 0.4,
  });

  final AnimationController controller;

  /// Velocity (px/s) above which swipe forces a page change.
  final double velocityThreshold;

  /// Default duration and curve for the flip animation.
  final Duration flipDuration;
  final Curve flipCurve;

  /// Perspective value (entry 3,2 of the Matrix4).
  final double perspective;

  /// Maximum opacity of the black shadow applied during flip.
  final double shadowOpacity;

  /// Creates a controller suited for the flip effect (continuous value, no
  /// upper bound: clamping is handled by the service based on page count).
  static AnimationController createController({
    required TickerProvider vsync,
    int initialPage = 0,
  }) =>
      AnimationController(
        vsync: vsync,
        value: initialPage.toDouble(),
        lowerBound: 0.0,
        upperBound: double.infinity,
      );

  /// Page currently closest to the controller value.
  int get currentPage => controller.value.round();

  // ---------------------------------------------------------------------------
  // GESTURES
  // ---------------------------------------------------------------------------

  /// To be called inside `onHorizontalDragUpdate`.
  void onDragUpdate(DragUpdateDetails details, {
    required double screenWidth,
    required int pageCount,
  }) {
    final delta = details.primaryDelta ?? 0;
    final newValue = controller.value - (delta / screenWidth);
    controller.value = newValue.clamp(0.0, _maxPage(pageCount));
  }

  /// Calculates the target page at drag end, based on position and velocity.
  int resolveTargetPage(DragEndDetails details, {required int pageCount}) {
    final velocity = details.primaryVelocity ?? 0;
    final value = controller.value;
    int target = value.round();

    if (velocity < -velocityThreshold) {
      target = value.floor() + 1;
    } else if (velocity > velocityThreshold) {
      target = value.ceil() - 1;
    }

    return target.clamp(0, pageCount - 1);
  }

  /// To be called inside `onHorizontalDragEnd`. Animates to the target page and
  /// returns the reached index (useful for tracking / tutorials).
  Future<int> onDragEnd(DragEndDetails details, {
    required int pageCount,
  }) async {
    final target = resolveTargetPage(details, pageCount: pageCount);
    await controller.animateTo(
      target.toDouble(),
      duration: flipDuration,
      curve: flipCurve,
    );
    return target;
  }

  // ---------------------------------------------------------------------------
  // PROGRAMMATIC NAVIGATION
  // ---------------------------------------------------------------------------

  /// Animates towards a specific page. Returns the reached index, or
  /// `null` if already on that page (no animation needed).
  Future<int?> animateToPage(double targetPage, {
    required int pageCount,
    Duration? duration,
    Curve? curve,
  }) async {
    final target = targetPage.clamp(0.0, _maxPage(pageCount));
    if (controller.value.round() == target.round()) return null;

    await controller.animateTo(
      target,
      duration: duration ?? flipDuration,
      curve: curve ?? flipCurve,
    );
    return target.round();
  }

  /// Immediate jump without animation.
  void jumpToPage(int page, {required int pageCount}) {
    controller.value = page.toDouble().clamp(0.0, _maxPage(pageCount));
  }

  // ---------------------------------------------------------------------------
  // RENDERING
  // ---------------------------------------------------------------------------

  /// Builds the widget that renders the [pages] with the flip effect,
  /// based on the current controller value.
  Widget buildFlip({required List<Widget> pages}) =>
      AnimatedBuilder(
        animation: controller,
        builder: (context, _) => _buildFrame(pages),
      );

  Widget _buildFrame(List<Widget> pages) {
    if (pages.isEmpty) return const SizedBox.shrink();

    final maxPage = _maxPage(pages.length);
    final globalProgress = controller.value.clamp(0.0, maxPage);

    final currentIndex = globalProgress.floor().clamp(0, pages.length - 1);
    final nextIndex = globalProgress.ceil().clamp(0, pages.length - 1);

    if (currentIndex == nextIndex) return pages[currentIndex];

    final localProgress = globalProgress - currentIndex;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Underneath page (the one being revealed)
        pages[nextIndex],
        // Left half of current page (remains static)
        ClipRect(
          clipper: HalfClipper(rightHalf: false),
          child: pages[currentIndex],
        ),
        // Rotating half around center axis
        Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, perspective)
            ..rotateY(math.pi * localProgress),
          alignment: Alignment.center,
          child: localProgress <= 0.5
              ? _frontFace(pages[currentIndex], localProgress)
              : _backFace(pages[nextIndex], localProgress),
        ),
      ],
    );
  }

  /// Front face: right half of current page darkening.
  Widget _frontFace(Widget page, double localProgress) =>
      ClipRect(
        clipper: HalfClipper(rightHalf: true),
        child: Stack(
          fit: StackFit.expand,
          children: [
            page,
            Container(
              color: Colors.black.withOpacity(
                  shadowOpacity * localProgress * 2),
            ),
          ],
        ),
      );

  /// Back face: left half of next page, mirrored.
  Widget _backFace(Widget page, double localProgress) =>
      Transform(
        transform: Matrix4.identity()
          ..rotateY(math.pi),
        alignment: Alignment.center,
        child: ClipRect(
          clipper: HalfClipper(rightHalf: false),
          child: Stack(
            fit: StackFit.expand,
            children: [
              page,
              Container(
                color: Colors.black
                    .withOpacity(shadowOpacity * (1 - localProgress) * 2),
              ),
            ],
          ),
        ),
      );

  double _maxPage(int pageCount) => math.max(0, pageCount - 1).toDouble();
}
