import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/constants/app_constants.dart';
import '../../core/error/failure_presenter.dart';
import '../../core/error/failures.dart';
import '../../core/responsive/responsive.dart';
import '../../l10n/generated/app_localizations.dart';

/// Transient messages, in one place.
///
/// Every screen needs to say "that worked" and "that didn't". Centralising it
/// means a failure is *always* rendered through [FailurePresenter] — a screen
/// cannot accidentally show a user `Exception: XmlRpcFault(3)` because someone
/// reached for `SnackBar(content: Text('$error'))` in a hurry (spec §22).
abstract final class AppSnack {
  /// Confirms something the user just did.
  static void success(BuildContext context, String message) => _show(
    context,
    message,
    icon: Icons.check_circle_rounded,
    tone: AppColors.success,
  );

  /// Confirms a write, saying plainly whether Odoo has it yet.
  ///
  /// ## Why this is not [success]
  ///
  /// A write made with no signal is parked in the outbox and the repository
  /// returns the record as it *will* read once the queue drains — which is the
  /// right answer for the screen and the wrong one for the sentence under it.
  /// Every one of these actions used to end in a green tick and "Assigned to
  /// Ahmed", whether Odoo had accepted the handover or whether it was sitting
  /// on a phone in a basement.
  ///
  /// That is the one lie worth going out of the way to prevent: a technician
  /// who has been told the handover is recorded has no reason to keep the app
  /// open, and the queue is the only copy. So a queued write gets the upload
  /// icon and the sentence that says where it actually is, rather than a tick
  /// that means something it does not.
  static void written(
    BuildContext context,
    String message, {
    required bool queued,
  }) {
    if (!queued) return success(context, message);

    final l10n = AppL10n.of(context);
    _show(
      context,
      '$message\n${l10n.syncQueuedNotice}',
      icon: Icons.cloud_upload_outlined,
      tone: AppColors.warning,
      // Two sentences rather than one, and the second is the one that matters.
      // At the text ceiling in Arabic the pair runs past the usual three lines,
      // and the line that would have been dropped is "not in Odoo yet".
      maxLines: _queuedMaxLines,
    );
  }

  /// Reports a failure that does not take over the screen.
  ///
  /// Uses the failure's short form: a snackbar has room for what happened, not
  /// for the fix. Blocking problems get [FailureView] instead, which has room
  /// for all three parts.
  static void failure(BuildContext context, Failure failure) {
    final l10n = AppL10n.of(context);
    _show(
      context,
      FailurePresenter.shortMessage(l10n, failure),
      icon: FailurePresenter.iconFor(failure.kind),
      tone: AppColors.danger,
    );
  }

  static void info(BuildContext context, String message) => _show(
    context,
    message,
    icon: Icons.info_outline_rounded,
    tone: AppColors.info,
  );

  /// Lines a one-sentence confirmation gets.
  static const int _defaultMaxLines = 3;

  /// Lines the queued form gets. See [written].
  static const int _queuedMaxLines = 5;

  static void _show(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color tone,
    int maxLines = _defaultMaxLines,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final theme = Theme.of(context);

    messenger
      // One message at a time: queued snackbars from a rapid sequence of
      // actions arrive long after the action they describe, which reads as
      // the app reporting something that just happened when it did not.
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: AppDurations.snackBar,
          behavior: SnackBarBehavior.floating,
          backgroundColor: theme.colorScheme.inverseSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          margin: const EdgeInsetsDirectional.all(AppSpacing.lg),
          content: Row(
            children: <Widget>[
              Icon(icon, size: AppDimens.iconLg, color: tone),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onInverseSurface,
                  ),
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
  }
}

/// A yes/no question the user must answer before something irreversible.
abstract final class AppConfirmDialog {
  /// Returns true only on an explicit confirmation — a dismissed dialog is a
  /// "no", never a silent yes.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String? cancelLabel,
    bool isDestructive = false,
  }) async {
    final l10n = AppL10n.of(context);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);

        return AlertDialog(
          // Every message this dialog is given today is one or two short
          // sentences, and none of them clips. This is here for the next one.
          //
          // `AlertDialog` hands its content a bounded box and clips the
          // remainder rather than scrolling it, so the margin is whatever is
          // left after the title, the buttons and the user's text scale — and
          // on the one screen where somebody is agreeing to something
          // irreversible, "it fits at the moment" is not the property worth
          // relying on. Scrolling costs nothing when the content already fits.
          scrollable: true,
          title: Text(title, style: theme.textTheme.titleLarge),
          content: Text(message, style: theme.textTheme.bodyMedium),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          actionsPadding: const EdgeInsetsDirectional.only(
            start: AppSpacing.md,
            end: AppSpacing.md,
            bottom: AppSpacing.md,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(cancelLabel ?? l10n.actionCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: isDestructive ? AppColors.danger : null,
              ),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}

/// The one date picker in the product.
///
/// Wraps Material's so the range, the locale and the theming are decided once.
/// Assets have dates in both directions — a warranty runs forward, a handover
/// being recorded late runs back — so the window is deliberately wide rather
/// than clamped to the future.
abstract final class AppDatePicker {
  static Future<DateTime?> show(
    BuildContext context, {
    DateTime? initial,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    final now = DateTime.now();
    final start = initial ?? now;

    return showDatePicker(
      context: context,
      initialDate: start,
      firstDate:
          firstDate ?? DateTime(now.year - AppConstants.datePickerYearsBack),
      lastDate:
          lastDate ??
          DateTime(
            now.year + AppConstants.datePickerYearsForward,
            AppConstants.decemberMonth,
            AppConstants.decemberLastDay,
          ),
    );
  }
}

/// A titled bottom sheet with a list of choices.
///
/// The shape behind the status picker and any other "pick one of these"
/// interaction, so they cannot drift apart visually.
class AppOptionSheet<T> extends StatelessWidget {
  const AppOptionSheet({
    required this.title,
    required this.options,
    this.subtitle,
    this.selected,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<AppSheetOption<T>> options;
  final T? selected;

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required List<AppSheetOption<T>> options,
    String? subtitle,
    T? selected,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => AppOptionSheet<T>(
        title: title,
        subtitle: subtitle,
        options: options,
        selected: selected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = context.screen;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: screen.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleLarge),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsetsDirectional.only(
                start: screen.gutter,
                end: screen.gutter,
                bottom: AppSpacing.lg,
              ),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                return _OptionRow<T>(
                  option: option,
                  isSelected: option.value == selected,
                  onTap: () => Navigator.of(context).pop(option.value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One choice inside an [AppOptionSheet].
class AppSheetOption<T> {
  const AppSheetOption({
    required this.value,
    required this.label,
    this.description,
    this.icon,
    this.tone,
  });

  final T value;
  final String label;
  final String? description;
  final IconData? icon;
  final Color? tone;
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final AppSheetOption<T> option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = option.tone ?? theme.colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppDimens.minTapTarget),
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              if (option.icon != null) ...<Widget>[
                Icon(option.icon, size: AppDimens.iconXl, color: tone),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(option.label, style: theme.textTheme.titleSmall),
                    if (option.description != null)
                      Text(
                        option.description!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_rounded,
                  size: AppDimens.iconXl,
                  color: theme.colorScheme.secondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dialog that asks for one short piece of text.
///
/// The smallest thing that can stand in for a whole form — opening a
/// maintenance request needs a sentence and nothing else, and sending the user
/// to a full screen for one field is friction with no payoff.
class AppPromptDialog extends StatefulWidget {
  const AppPromptDialog({
    required this.title,
    required this.confirmLabel,
    this.hint,
    this.message,
    super.key,
  });

  final String title;
  final String? message;
  final String? hint;
  final String confirmLabel;

  /// Resolves to the trimmed text, or null if dismissed or left blank.
  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    String? message,
    String? hint,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => AppPromptDialog(
        title: title,
        message: message,
        hint: hint,
        confirmLabel: confirmLabel,
      ),
    );
  }

  @override
  State<AppPromptDialog> createState() => _AppPromptDialogState();
}

class _AppPromptDialogState extends State<AppPromptDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.title, style: theme.textTheme.titleLarge),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (widget.message != null) ...<Widget>[
            Text(widget.message!, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
          ],
          // Rebuilt on every keystroke so the confirm action enables the
          // moment the field stops being empty.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, _, __) => TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(hintText: widget.hint),
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsetsDirectional.only(
        start: AppSpacing.md,
        end: AppSpacing.md,
        bottom: AppSpacing.md,
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, __) => TextButton(
            onPressed: value.text.trim().isEmpty ? null : _submit,
            child: Text(widget.confirmLabel),
          ),
        ),
      ],
    );
  }
}
