import 'package:flutter/material.dart';

/// Slide up page transition for modal-style screens.
class SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideUpPageRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.05);
          const end = Offset.zero;
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return SlideTransition(
            position: Tween(begin: begin, end: end).animate(curve),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 250),
      );
}

/// Fade scale transition for push navigation.
class FadeScalePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadeScalePageRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(curve),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      );
}

/// Shared axis transition (horizontal).
class SharedAxisPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final bool forward;

  SharedAxisPageRoute({required this.page, this.forward = true})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          final begin = Offset(forward ? 0.1 : -0.1, 0.0);
          const end = Offset.zero;

          return SlideTransition(
            position: Tween(begin: begin, end: end).animate(curve),
            child: FadeTransition(opacity: curve, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 250),
      );
}

/// Helper extension to use transitions easily.
extension NavigationExtensions on NavigatorState {
  Future<T?> pushSlideUp<T extends Object?>(Widget page) {
    return push(SlideUpPageRoute<T>(page: page));
  }

  Future<T?> pushFadeScale<T extends Object?>(Widget page) {
    return push(FadeScalePageRoute<T>(page: page));
  }

  Future<T?> pushSharedAxis<T extends Object?>(
    Widget page, {
    bool forward = true,
  }) {
    return push(SharedAxisPageRoute<T>(page: page, forward: forward));
  }
}
