import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_spacing.dart';
import 'app_button.dart';

/// The one text field in the product.
///
/// Owns the label row, the icon, the error line and the obscure toggle, so a
/// form is a list of these rather than fifteen lines of `InputDecoration`
/// each time. The error is rendered under the field rather than inside it, so
/// a long sentence (Arabic runs longer) never truncates.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.errorText,
    this.action,
    this.keyboardType,
    this.textInputAction,
    this.obscure = false,
    this.onToggleObscure,
    this.enabled = true,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.textDirection,
    this.focusNode,
    this.maxLines = 1,
    this.showLabel = true,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? icon;

  /// Non-null renders the field in its error state with the message below.
  final String? errorText;

  /// A small action at the end of the label row, e.g. "Detect".
  final Widget? action;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscure;

  /// Non-null shows the eye toggle.
  final VoidCallback? onToggleObscure;

  final bool enabled;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;

  /// Forces LTR for URLs, emails and keys even inside an Arabic layout.
  final TextDirection? textDirection;

  final FocusNode? focusNode;

  /// Hides the printed label while keeping it for screen readers.
  ///
  /// For forms where a heading already names the field — the numbered steps on
  /// the assign screen, the section labels on the return screen — printing it
  /// again puts the same words on screen twice.
  final bool showLabel;

  /// Rows the field grows to. Above one it becomes a notes box: the height
  /// constraint the theme puts on a single-line field would otherwise clip
  /// the second line rather than expand.
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = errorText != null && errorText!.isNotEmpty;
    final isMultiline = maxLines > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel || action != null) ...[
          Row(
            children: [
              Expanded(
                child: showLabel
                    ? Text(
                        label.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: hasError
                              ? AppColors.danger
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : const SizedBox.shrink(),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Semantics(
          label: showLabel ? null : label,
          textField: true,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            obscureText: obscure,
            maxLines: obscure ? 1 : maxLines,
            minLines: isMultiline ? maxLines : null,
            keyboardType: isMultiline ? TextInputType.multiline : keyboardType,
            textInputAction: textInputAction,
            textAlignVertical: isMultiline ? TextAlignVertical.top : null,
            autofillHints: autofillHints,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            inputFormatters: inputFormatters,
            textDirection: textDirection,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              // The theme centres a 50-px single-line field; a notes box needs
              // real top padding instead, or the first line sits against the
              // border.
              contentPadding: isMultiline
                  ? const EdgeInsetsDirectional.all(AppSpacing.md)
                  : null,
              alignLabelWithHint: isMultiline,
              prefixIcon: icon == null
                  ? null
                  : Icon(icon, size: AppDimens.iconLg),
              prefixIconConstraints: const BoxConstraints(
                minWidth: AppDimens.minTapTarget,
              ),
              suffixIcon: onToggleObscure == null
                  ? null
                  : IconButton(
                      onPressed: onToggleObscure,
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: AppDimens.iconLg,
                      ),
                    ),
              // Errors render below, so the field itself only changes colour.
              errorText: null,
              enabledBorder: hasError ? _errorBorder(theme) : null,
              focusedBorder: hasError
                  ? _errorBorder(theme, focused: true)
                  : null,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: AppDimens.iconSm,
                color: AppColors.danger,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  errorText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  OutlineInputBorder _errorBorder(ThemeData theme, {bool focused = false}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(
          color: AppColors.danger,
          width: focused ? AppDimens.focusedBorder : AppDimens.hairline,
        ),
      );
}

/// A read-only field that opens a picker — dates, and any value chosen rather
/// than typed.
class AppPickerField extends StatelessWidget {
  const AppPickerField({
    required this.label,
    required this.value,
    required this.onTap,
    this.icon,
    this.trailingLabel,
    this.enabled = true,
    this.showLabel = true,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData? icon;

  /// A hint at the end of the field, e.g. "Today".
  final String? trailingLabel;

  final bool enabled;

  /// Hides the printed label while keeping it for screen readers, for forms
  /// where a heading already names the field.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel) ...[
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: Container(
              height: AppDimens.fieldHeight,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: AppDimens.iconLg,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: Text(
                      value,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trailingLabel != null)
                    AppTextAction(label: trailingLabel!, onPressed: onTap),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The search field used on the asset and employee lists.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.trailing,
    this.onClear,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  /// An extra affordance inside the field, e.g. the scan button.
  final Widget? trailing;

  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.isNotEmpty;

        return TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsetsDirectional.symmetric(
              vertical: AppSpacing.lg,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: AppDimens.iconXl,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasText && onClear != null)
                  IconButton(
                    onPressed: onClear,
                    icon: const Icon(
                      Icons.close_rounded,
                      size: AppDimens.iconLg,
                    ),
                  ),
                if (trailing != null) trailing!,
                const SizedBox(width: AppSpacing.xs),
              ],
            ),
          ),
        );
      },
    );
  }
}
