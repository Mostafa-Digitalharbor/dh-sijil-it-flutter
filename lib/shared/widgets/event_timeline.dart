import 'package:flutter/material.dart';

import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_palette.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// One dot on an [EventTimeline].
@immutable
class TimelineEvent {
  const TimelineEvent({
    required this.icon,
    required this.tone,
    required this.title,
    this.subtitle,
    this.meta,
    this.onTap,
  });

  final IconData icon;

  /// The status hue this kind of event belongs to. The reader learns the
  /// mapping once on the asset list and it holds everywhere — a handover is
  /// blue on both screens.
  final Color tone;

  final String title;
  final String? subtitle;

  /// The date line. Callers pass an already-formatted string because the
  /// timeline has no opinion on calendars.
  final String? meta;
  final VoidCallback? onTap;
}

/// A vertical history of what happened to a record.
///
/// The rail is drawn as a per-row segment rather than one line behind the
/// column, because rows have different heights: a single positioned line has
/// to guess the total, and gets it wrong the moment a subtitle wraps. Each
/// row owning its own segment also means the last row simply omits it, which
/// is what makes the timeline visibly *end* at the record's creation instead
/// of trailing off.
class EventTimeline extends StatelessWidget {
  const EventTimeline({required this.events, this.padding, super.key});

  final List<TimelineEvent> events;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < events.length; i++)
            _Row(event: events[i], isLast: i == events.length - 1),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.event, required this.isLast});

  final TimelineEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final tone = context.ink(event.tone);

    final body = Padding(
      padding: EdgeInsetsDirectional.only(bottom: isLast ? 0 : AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(event.title, style: text.titleSmall),
          if (event.subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                event.subtitle!,
                style: text.bodySmall?.copyWith(color: palette.dim),
              ),
            ),
          if (event.meta != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                event.meta!,
                style: text.bodySmall?.copyWith(
                  fontSize: AppTextSize.meta,
                  color: palette.faint,
                ),
              ),
            ),
        ],
      ),
    );

    final row = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: AppDimens.timelineRail,
            child: Column(
              children: <Widget>[
                Container(
                  width: AppDimens.timelineRail,
                  height: AppDimens.timelineRail,
                  decoration: BoxDecoration(
                    color: context.tint(event.tone),
                    borderRadius: BorderRadius.circular(AppRadii.sm + 1),
                  ),
                  child: Icon(event.icon, size: AppDimens.iconSm, color: tone),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: AppDimens.timelineRail,
                      color: palette.lineSoft,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: body),
        ],
      ),
    );

    if (event.onTap == null) return row;
    return InkWell(
      onTap: event.onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: row,
    );
  }
}
