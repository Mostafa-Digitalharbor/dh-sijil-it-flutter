import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/observability/crash_reporter.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/utils/logger.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/utils/app_date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_media_row.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_sheets.dart';
import '../../../../shared/widgets/state_views.dart';

/// Recent technical failures, credentials redacted (spec §22).
///
/// Reads [DiagnosticsLog] directly rather than through a Cubit: there is no
/// asynchronous work, no failure mode of its own, and no state beyond "what is
/// in the buffer right now". A ViewModel here would be ceremony.
class DebugLogPage extends StatefulWidget {
  const DebugLogPage({super.key});

  @override
  State<DebugLogPage> createState() => _DebugLogPageState();
}

class _DebugLogPageState extends State<DebugLogPage> {
  late List<DiagnosticEntry> _entries = DiagnosticsLog.entries;

  void _refresh() => setState(() => _entries = DiagnosticsLog.entries);

  Future<void> _copy() async {
    final l10n = AppL10n.of(context);
    await Clipboard.setData(ClipboardData(text: DiagnosticsLog.asText()));
    if (mounted) AppSnack.success(context, l10n.diagnosticsCopied);
  }

  void _clear() {
    DiagnosticsLog.clear();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      title: l10n.settingsDiagnostics,
      compactTitle: true,
      subtitle: l10n.settingsDiagnosticsDetail,
      showBack: true,
      onBack: () => context.go(AppRoutes.settingsPath),
      actions: <Widget>[
        if (_entries.isNotEmpty) ...<Widget>[
          AppIconButton(
            icon: Icons.copy_rounded,
            tooltip: l10n.diagnosticsCopy,
            bordered: false,
            onPressed: _copy,
          ),
          AppIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: l10n.actionClear,
            bordered: false,
            onPressed: _clear,
          ),
        ],
      ],
      // The crash-reporting card is pinned above whichever body follows, not
      // listed inside it: `EmptyStateView` centres itself against the height it
      // is given and must not be nested in a second scroll view, so the empty
      // case gets `Expanded` rather than a row in a ListView.
      body: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: context.screen.gutter,
              end: context.screen.gutter,
              top: AppSpacing.xs,
            ),
            child: const _CrashReportingCard(),
          ),
          Expanded(
            child: _entries.isEmpty
                ? EmptyStateView(
                    icon: Icons.verified_outlined,
                    title: l10n.diagnosticsEmpty,
                    message: l10n.diagnosticsEmptyBody,
                  )
                : AppPageBody(
                    gap: AppSpacing.sm,
                    onRefresh: () async => _refresh(),
                    children: <Widget>[
                      for (final entry in _entries) _EntryCard(entry: entry),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Whether this build sends crash reports anywhere.
///
/// Stated in the app rather than only in the handover document, because the
/// person who needs the answer — an IT manager deciding whether to roll the
/// app out, or an auditor asked what leaves the device — is holding a phone,
/// not reading `docs/`. A build with no DSN compiled in says so plainly here,
/// which is the difference between "we believe it is off" and "it is off".
class _CrashReportingCard extends StatelessWidget {
  const _CrashReportingCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final isOn = CrashReporter.isEnabled;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            isOn ? Icons.cloud_upload_outlined : Icons.cloud_off_rounded,
            size: AppDimens.iconLg,
            color: isOn
                ? AppColors.statusAssigned
                : theme.textTheme.bodySmall?.color,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.diagnosticsCrashReporting,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isOn ? l10n.diagnosticsCrashOn : l10n.diagnosticsCrashOff,
                  style: theme.textTheme.bodySmall,
                ),
                if (isOn) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.diagnosticsCrashDetail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final DiagnosticEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isError = entry.level == DiagnosticSeverity.error;
    final tone = isError ? AppColors.danger : AppColors.warning;

    return AppCard(
      child: AppMediaRow(
        alignment: CrossAxisAlignment.start,
        leading: Icon(
          isError ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
          size: AppDimens.iconLg,
          color: tone,
        ),
        children: <Widget>[
          Text(
            context.dates.dateAndTime(entry.at),
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          // Technical text, so it keeps LTR reading order even in an
          // Arabic UI — a reversed model name is not a diagnostic.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(entry.message, style: theme.textTheme.bodyMedium),
                if (entry.detail != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(entry.detail!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
