import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injector.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/error/failure_presenter.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/utils/l10n_lookup.dart';
import '../../../../shared/widgets/app_brand_header.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_media_row.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../domain/entities/connection_probe.dart';
import '../cubit/connection_form_cubit.dart';

/// First of the two first-run screens: *which Odoo* (spec §3).
///
/// ## Why the server and the credential are separate screens
///
/// They are separate decisions with separate lifetimes. The server URL and
/// database are chosen once, by whoever sets the device up, and then never
/// again; the username and password are typed by whoever is holding the phone,
/// every time the session lapses. Asking for all four at once made the second
/// group look as permanent as the first — and put a password field on the very
/// first screen a user ever sees, before anything had established which server
/// was about to receive it.
///
/// Splitting them also gives "Test connection" something honest to mean. On
/// one combined screen it sat beside a credential it did not use, so a green
/// result read as "your details are right" when it only ever meant "something
/// is answering at this address".
class ConnectionPage extends StatelessWidget {
  const ConnectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ConnectionFormCubit>(
      create: (_) => ConnectionFormCubit(
        sl<AuthRepository>(),
        initial: context.read<AuthCubit>().state.connection,
      ),
      child: const _ConnectionView(),
    );
  }
}

class _ConnectionView extends StatefulWidget {
  const _ConnectionView();

  @override
  State<_ConnectionView> createState() => _ConnectionViewState();
}

class _ConnectionViewState extends State<_ConnectionView> {
  late final TextEditingController _url;
  late final TextEditingController _database;

  @override
  void initState() {
    super.initState();
    final form = context.read<ConnectionFormCubit>().state;
    _url = TextEditingController(text: form.serverUrl);
    _database = TextEditingController(text: form.database);
  }

  @override
  void dispose() {
    _url.dispose();
    _database.dispose();
    super.dispose();
  }

  /// Carries the two fields to the sign-in screen.
  ///
  /// Nothing is written to storage and no request is made: this is a step in a
  /// form, not a commitment. `AuthCubit` moves to `signedOut`, and the router
  /// — the app's single auth gate — is what actually navigates.
  void _continue() {
    final connection = context
        .read<ConnectionFormCubit>()
        .validateForContinue();
    if (connection == null) return;

    FocusScope.of(context).unfocus();
    context.read<AuthCubit>().useConnection(connection);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final screen = context.screen;

    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<ConnectionFormCubit, ConnectionFormState>(
          // Opening the sheet is a side effect, so it belongs in a listener.
          // A builder runs on every rebuild and would re-open it endlessly.
          listenWhen: (previous, current) =>
              previous.detectOutcome != current.detectOutcome &&
              current.detectOutcome == DetectOutcome.found,
          listener: (context, form) => _pickDatabase(form),
          builder: (context, form) {
            final cubit = context.read<ConnectionFormCubit>();

            return ListView(
              padding: EdgeInsetsDirectional.only(
                start: screen.gutter + AppSpacing.sm,
                end: screen.gutter + AppSpacing.sm,
                top: AppSpacing.md,
                bottom: AppSpacing.xxl,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppDimens.dialogMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Brand mark centred, with the language and theme
                        // controls beside it — both reachable before the user
                        // has an account to configure them from.
                        const AppBrandHeader(),
                        const SizedBox(height: AppSpacing.xxl),

                        Text(
                          l10n.connectTitle,
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.connectSubtitle,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.xxl),

                        AppTextField(
                          label: l10n.fieldServerUrl,
                          hint: l10n.fieldServerUrlHint,
                          icon: Icons.dns_outlined,
                          controller: _url,
                          onChanged: cubit.setServerUrl,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.next,
                          textDirection: TextDirection.ltr,
                          autofillHints: const [AutofillHints.url],
                          errorText: l10n.lookup(
                            form.errorFor(ConnectionField.serverUrl),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Detection sits above the field it fills in, so the
                        // order on screen matches the order of the task.
                        AppButton.outlined(
                          label: l10n.actionDetectDatabases,
                          icon: Icons.travel_explore_rounded,
                          isCompact: true,
                          isBusy: form.isDetecting,
                          onPressed: form.serverUrl.trim().isEmpty
                              ? null
                              : cubit.detectDatabases,
                        ),
                        if (form.detectOutcome == DetectOutcome.unsupported)
                          const _DetectUnsupportedNotice(),
                        const SizedBox(height: AppSpacing.md),

                        AppTextField(
                          label: l10n.fieldDatabase,
                          hint: l10n.fieldDatabaseHint,
                          icon: Icons.storage_outlined,
                          controller: _database,
                          onChanged: cubit.setDatabase,
                          textInputAction: TextInputAction.done,
                          textDirection: TextDirection.ltr,
                          onSubmitted: (_) => _continue(),
                          errorText: l10n.lookup(
                            form.errorFor(ConnectionField.database),
                          ),
                        ),

                        if (form.probe != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          _ProbeResult(probe: form.probe!),
                        ],
                        if (form.failure != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          _InlineFailure(failure: form.failure!),
                        ],

                        const SizedBox(height: AppSpacing.xxl),
                        AppButton.outlined(
                          label: form.isProbing
                              ? l10n.connectionTesting
                              : l10n.actionTestConnection,
                          icon: Icons.refresh_rounded,
                          isBusy: form.isProbing,
                          onPressed: form.serverUrl.trim().isEmpty
                              ? null
                              : cubit.probe,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: l10n.actionContinue,
                          icon: Icons.arrow_forward_rounded,
                          onPressed: form.canSubmit ? _continue : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Lets the user pick from the list the server published.
  Future<void> _pickDatabase(ConnectionFormState form) async {
    final databases = form.probe?.databases ?? const <String>[];
    if (databases.isEmpty) return;

    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.detectPickTitle, style: theme.textTheme.titleLarge),
                  Text(
                    l10n.detectFoundCount(databases.length),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            // Shrink-wrapped but scrollable: an instance with fifty databases
            // must not push the sheet past the top of the screen.
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsetsDirectional.only(
                  bottom: AppSpacing.md,
                ),
                itemCount: databases.length,
                itemBuilder: (_, index) => ListTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: Text(
                    databases[index],
                    textDirection: TextDirection.ltr,
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(databases[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    context.read<ConnectionFormCubit>().acknowledgeDetection();
    if (chosen == null) return;

    _database.text = chosen;
    context.read<ConnectionFormCubit>().setDatabase(chosen);
  }
}

/// Shown when the server answers but keeps its database list private.
///
/// This is the default on most production instances, so it is framed as
/// information rather than as a failure — the user simply types the name.
class _DetectUnsupportedNotice extends StatelessWidget {
  const _DetectUnsupportedNotice();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
      child: AppCard(
        child: AppMediaRow(
          alignment: CrossAxisAlignment.start,
          leading: Icon(
            Icons.info_outline_rounded,
            size: AppDimens.iconLg,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          children: [
            Text(
              l10n.detectUnsupportedTitle,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.detectUnsupportedBody, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Green confirmation strip: the version the server reported.
class _ProbeResult extends StatelessWidget {
  const _ProbeResult({required this.probe});

  final ConnectionProbe probe;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    const tone = AppColors.statusAvailable;
    final ink = theme.brightness == Brightness.dark
        ? tone
        : AppColors.statusAvailableInk;

    return AppCard(
      backgroundColor: tone.withValues(alpha: AppOpacities.overlay),
      borderColor: tone.withValues(alpha: AppOpacities.chipBorder),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: AppDimens.iconLg,
            color: ink,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              l10n.connectionReachable(probe.serverVersion),
              style: theme.textTheme.bodySmall?.copyWith(
                color: ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A failure shown inline in a form, rather than taking over the screen.
///
/// Keeps the fields visible so the user can correct the thing the message is
/// telling them to correct.
class _InlineFailure extends StatelessWidget {
  const _InlineFailure({required this.failure});

  final Failure failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presented = FailurePresenter.present(AppL10n.of(context), failure);

    return AppCard(
      backgroundColor: AppColors.danger.withValues(alpha: AppOpacities.overlay),
      borderColor: AppColors.danger.withValues(alpha: AppOpacities.chipBorder),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                presented.icon,
                size: AppDimens.iconLg,
                color: AppColors.danger,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  presented.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(presented.body, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                size: AppDimens.iconSm,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  presented.fix,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
