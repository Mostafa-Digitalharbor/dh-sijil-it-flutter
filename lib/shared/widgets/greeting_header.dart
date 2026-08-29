import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_palette.dart';
import '../../app/theme/app_spacing.dart';
import '../../l10n/generated/app_localizations.dart';

/// The signed-in person, at the top of the dashboard.
///
/// ## What this replaced
///
/// The old header carried the server host and "synced 2 min ago". Both are
/// real information and neither belongs in the first line somebody reads every
/// morning — they are answers to "is this data trustworthy", asked once during
/// setup and almost never after. They moved to the More screen, where the
/// connection lives.
///
/// What took their place addresses the person: their photo, the time of day,
/// and their name.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({
    required this.name,
    this.photo,
    this.trailing,
    this.now,
    super.key,
  });

  final String name;

  /// `res.users.image_128`, decoded. Falls back to initials when unset, which
  /// is the common case on a fresh instance.
  final Uint8List? photo;

  final Widget? trailing;

  /// Injectable clock, so the greeting is testable without waiting for noon.
  final DateTime? now;

  /// The greeting for [at].
  ///
  /// English splits the day three ways; Arabic has one word covering both
  /// afternoon and evening, and both ARB entries resolve to `مساء الخير`.
  /// That is a translation decision, not a bug — which is why the split lives
  /// here and not in a `switch` the translator cannot reach.
  static String greetingFor(AppL10n l10n, DateTime at) {
    if (at.hour < 12) return l10n.greetingMorning;
    if (at.hour < 18) return l10n.greetingAfternoon;
    return l10n.greetingEvening;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return Row(
      children: <Widget>[
        UserAvatar(name: name, photo: photo),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                greetingFor(l10n, now ?? DateTime.now()),
                style: text.headlineSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                name,
                style: text.bodySmall?.copyWith(
                  color: palette.dim,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// A round portrait with an accent ring, falling back to initials.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    required this.name,
    this.photo,
    this.size = AppDimens.avatarMd,
    super.key,
  });

  final String name;
  final Uint8List? photo;
  final double size;

  /// First letters of the first two words. Works for "Mostafa Bader" and for
  /// "مصطفى بدر" without a script branch, because it never inspects the
  /// characters — only where the spaces are.
  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w.characters.first).join();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final photo = this.photo;

    // Decorative, like [AppAvatar]: the initials are a drawing of the name,
    // and the name itself is the line beside this. Left in the tree the
    // dashboard header opens with "M B" spelled out before the greeting.
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.raised,
          border: Border.all(color: palette.mint, width: AppDimens.avatarRing),
        ),
        clipBehavior: Clip.antiAlias,
        child: photo == null
            ? Center(
                child: Text(
                  initialsOf(name),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: palette.mint),
                ),
              )
            : Image.memory(
                photo,
                fit: BoxFit.cover,
                // An instance that has been through a bad migration can hold a
                // non-image in image_128. Initials beat an exception in the
                // frame callback.
                errorBuilder: (context, _, _) => Center(
                  child: Text(
                    initialsOf(name),
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: palette.mint),
                  ),
                ),
              ),
      ),
    );
  }
}
