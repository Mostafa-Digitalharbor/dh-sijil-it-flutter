import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_dimens.dart';

/// The two movements the product uses between screens, and nothing else.
///
/// ## Why not the platform default
///
/// `GoRoute.builder` hands every destination the same Material zoom. That is a
/// reasonable default and it says nothing: a detail pushed onto a list, a form
/// raised over the whole app, and a tab swap all arrive identically, so the
/// animation carries no information about where the user went or how to get
/// back. Two movements with distinct meanings do carry it:
///
/// * [forward] — the trailing-edge slide. "You went one level deeper, and back
///   is the way you came." Detail screens, sub-lists.
/// * [modal] — the rise from the bottom. "This is a task on top of what you
///   were doing, and it ends by being dismissed." Forms, assign, return,
///   handover.
///
/// Tab switches deliberately have neither. They are an `IndexedStack` swap
/// between peers, and sliding between them implies an order the bottom bar
/// does not have.
///
/// ## Direction
///
/// [forward] reads the ambient [Directionality] rather than hardcoding a sign.
/// In Arabic the app runs right-to-left, and a detail that slides in from the
/// left is sliding in from *behind the back button* — the animation and the
/// gesture that reverses it would be pointing opposite ways.
///
/// ## Motion sensitivity
///
/// Both collapse to a plain fade when the platform reports "reduce motion".
/// The transition is decoration; the navigation is not, so what gets dropped
/// is the travel and never the arrival.
abstract final class AppTransitions {
  /// How far a page travels before it settles, as a fraction of the screen.
  ///
  /// A fraction rather than a distance so a tablet does not get a longer slide
  /// than a phone at the same duration, which reads as sluggish. Short on
  /// purpose: the page is already mostly in place when it starts fading in, so
  /// the movement reads as a hand-off rather than as a journey.
  static const double _slideExtent = 0.06;

  /// The modal rise. Longer than [_slideExtent] because it starts from off the
  /// bottom edge rather than from almost-in-place.
  static const double _modalExtent = 0.10;

  /// A screen one level deeper than the one it was opened from.
  static CustomTransitionPage<void> forward({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: key,
      transitionDuration: AppDurations.normal,
      reverseTransitionDuration: AppDurations.fast,
      child: child,
      transitionsBuilder: (context, animation, secondary, child) {
        if (_prefersReducedMotion(context)) {
          return FadeTransition(opacity: animation, child: child);
        }

        // Trailing edge in the current writing direction: the right in
        // English, the left in Arabic.
        final sign = Directionality.of(context) == TextDirection.rtl
            ? -1.0
            : 1.0;

        return FadeTransition(
          opacity: _fade.animate(animation),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(_slideExtent * sign, 0),
              end: Offset.zero,
            ).animate(_ease.animate(animation)),
            child: child,
          ),
        );
      },
    );
  }

  /// A task raised over whatever the user was doing.
  static CustomTransitionPage<void> modal({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: key,
      transitionDuration: AppDurations.normal,
      reverseTransitionDuration: AppDurations.fast,
      child: child,
      transitionsBuilder: (context, animation, secondary, child) {
        if (_prefersReducedMotion(context)) {
          return FadeTransition(opacity: animation, child: child);
        }

        return FadeTransition(
          opacity: _fade.animate(animation),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, _modalExtent),
              end: Offset.zero,
            ).animate(_ease.animate(animation)),
            child: child,
          ),
        );
      },
    );
  }

  /// Decelerating: fast at the start, settling at the end. A page that eases
  /// in at both ends reads as hesitant.
  static final CurveTween _ease = CurveTween(curve: Curves.easeOutCubic);

  /// The opacity ramp finishes early, so the page is opaque before it stops
  /// moving. Fading all the way to the end makes the last few pixels of travel
  /// look like a rendering glitch.
  static final CurveTween _fade = CurveTween(
    curve: const Interval(0, 0.7, curve: Curves.easeOut),
  );

  static bool _prefersReducedMotion(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
