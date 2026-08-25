import 'package:flutter/material.dart';

import '../../app/theme/app_palette.dart';
import '../../app/theme/app_typography.dart';

/// An **identifier**: an asset tag, serial, ISO date, host, version or MAC.
///
/// ## Why this is a widget and not a `TextStyle`
///
/// Setting the monospace face is the easy half. The half that actually bit us
/// is direction. Under an Arabic locale a bare `Text('SJL-0042 · 2026-08-24')`
/// sits in an RTL paragraph, the `·` between two Latin runs is a *neutral*,
/// and the bidi algorithm resolves it to the paragraph direction — so the two
/// halves render swapped. The same rule turns `في الخدمة · ١٢ شهر` into
/// something that reads `١٢٠`, and `٣١ / ٤٣` into `٤٣ / ٣١`.
///
/// Wrapping the run in [Directionality] with [TextDirection.ltr] isolates it,
/// which is correct for identifiers specifically: a tag is the same six
/// characters in every locale because that is what is printed on the sticker.
/// Counts are the opposite case and must **not** use this — they follow the
/// language, and `NumberFormat` already handles them.
class MonoText extends StatelessWidget {
  const MonoText(
    this.value, {
    this.size = 11,
    this.weight = AppTypography.medium,
    this.color,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    super.key,
  });

  /// The tag-sized variant used on list rows and detail headers.
  const MonoText.tag(this.value, {this.color, super.key})
    : size = 11,
      weight = AppTypography.medium,
      maxLines = 1,
      overflow = TextOverflow.ellipsis;

  /// The small caption under a chart axis or a proof line.
  const MonoText.caption(this.value, {this.color, super.key})
    : size = 9.5,
      weight = AppTypography.medium,
      maxLines = 1,
      overflow = TextOverflow.ellipsis;

  final String value;
  final double size;
  final FontWeight weight;
  final Color? color;
  final int maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        value,
        maxLines: maxLines,
        overflow: overflow,
        style: AppTypography.mono(
          size: size,
          weight: weight,
          color: color ?? context.palette.faint,
        ),
      ),
    );
  }
}

/// The two-part second line of an asset row: `SJL-0042 · Sara Fouad`.
///
/// The tag is an identifier and the note is prose, and they need opposite
/// treatment — one Latin-isolated and monospaced, the other following the
/// locale. Rendering both in a single [MonoText] is what made Arabic rows
/// read back to front, so this composes them as separate runs with the
/// separator owned by the layout rather than by either string.
class IdentifierLine extends StatelessWidget {
  const IdentifierLine({required this.tag, this.note, this.color, super.key});

  final String tag;
  final String? note;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? context.palette.faint;
    final note = this.note;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(child: MonoText.tag(tag, color: tone)),
        if (note != null && note.isNotEmpty) ...<Widget>[
          Text(
            ' · ',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tone, fontSize: AppTextSize.label),
          ),
          Flexible(
            flex: 2,
            child: Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tone, fontSize: AppTextSize.label),
            ),
          ),
        ],
      ],
    );
  }
}
