import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/error/failure_presenter.dart';
import '../../../../core/network/odoo/odoo_connection.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/app_segmented.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../cubit/auth_cubit.dart';

/// Signs the user in against the already-configured Odoo instance (spec §3).
///
/// Shows the saved connection rather than asking for it again — changing
/// servers is a deliberate, separate action.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _secret = TextEditingController();
  bool _obscure = true;
  bool _keepSignedIn = true;

  @override
  void dispose() {
    _secret.dispose();
    super.dispose();
  }

  void _submit(OdooConnection connection) {
    if (_secret.text.isEmpty) return;
    FocusScope.of(context).unfocus();
    context.read<AuthCubit>().signIn(
      connection: connection,
      secret: _secret.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final connection = state.connection;

        // The router only routes here with a saved connection, so this is a
        // defensive fallback rather than a reachable state.
        if (connection == null) return const SizedBox.shrink();

        return Scaffold(
          backgroundColor: isDark ? AppColors.surfaceDark : AppColors.navy,
          body: Column(
            children: [
              _BrandBand(
                subtitle: l10n.loginSubtitle,
                title: l10n.loginWelcomeBack,
              ),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadii.xl + 6),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: _LoginForm(
                      connection: connection,
                      state: state,
                      secret: _secret,
                      obscure: _obscure,
                      keepSignedIn: _keepSignedIn,
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
                      onToggleKeep: (value) =>
                          setState(() => _keepSignedIn = value),
                      onSubmit: () => _submit(connection),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The navy header — the only full-bleed brand moment in the app.
class _BrandBand extends StatelessWidget {
  const _BrandBand({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = context.screen;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: screen.gutter + AppSpacing.sm,
          end: screen.gutter + AppSpacing.sm,
          top: AppSpacing.xxl,
          bottom: AppSpacing.xxxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // The band is navy in both themes; the mark follows the band, not
            // the theme.
            const AppLogo.monogram(
              size: AppDimens.logoMonogramSize,
              onDarkSurface: true,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.heroSubdued,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.connection,
    required this.state,
    required this.secret,
    required this.obscure,
    required this.keepSignedIn,
    required this.onToggleObscure,
    required this.onToggleKeep,
    required this.onSubmit,
  });

  final OdooConnection connection;
  final AuthState state;
  final TextEditingController secret;
  final bool obscure;
  final bool keepSignedIn;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool> onToggleKeep;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final screen = context.screen;

    return ListView(
      padding: EdgeInsetsDirectional.only(
        start: screen.gutter + AppSpacing.sm,
        end: screen.gutter + AppSpacing.sm,
        top: AppSpacing.xl,
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
                _ConnectionSummary(connection: connection),
                const SizedBox(height: AppSpacing.xxl),

                AppTextField(
                  label: l10n.fieldUsername,
                  controller: TextEditingController(text: connection.username),
                  enabled: false,
                  icon: Icons.person_outline_rounded,
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: AppSpacing.lg),

                AppTextField(
                  label: connection.authMode == OdooAuthMode.apiKey
                      ? l10n.authModeApiKey
                      : l10n.authModePassword,
                  hint: connection.authMode == OdooAuthMode.apiKey
                      ? l10n.fieldApiKeyHint
                      : l10n.fieldPasswordHint,
                  icon: Icons.lock_outline_rounded,
                  controller: secret,
                  obscure: obscure,
                  onToggleObscure: onToggleObscure,
                  textInputAction: TextInputAction.done,
                  textDirection: TextDirection.ltr,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => onSubmit(),
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                Row(
                  children: [
                    Expanded(
                      child: AppCheckRow(
                        label: l10n.loginKeepSignedIn,
                        value: keepSignedIn,
                        onChanged: onToggleKeep,
                      ),
                    ),
                    AppTextAction(
                      label: l10n.loginNeedApiKey,
                      onPressed: () => _showApiKeyHelp(context),
                    ),
                  ],
                ),

                if (state.failure != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _FailureBanner(state: state),
                ],

                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: state.isBusy
                      ? l10n.actionSigningIn
                      : l10n.actionSignIn,
                  isBusy: state.isBusy,
                  onPressed: state.isBusy ? null : onSubmit,
                ),

                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: AppDimens.iconMd,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          l10n.loginAclNotice,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        l10n.loginDifferentServer,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    AppTextAction(
                      label: l10n.loginSwitchServer,
                      onPressed: () =>
                          context.read<AuthCubit>().forgetConnection(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showApiKeyHelp(BuildContext context) {
    final l10n = AppL10n.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.errorInvalidCredentialsFix),
          duration: AppDurations.snackBar,
        ),
      );
  }
}

/// The saved server, shown so the user knows what they are signing into.
class _ConnectionSummary extends StatelessWidget {
  const _ConnectionSummary({required this.connection});

  final OdooConnection connection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return AppCard(
      child: Row(
        children: [
          Icon(
            Icons.dns_outlined,
            size: AppDimens.iconXl,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    connection.baseUrl.host,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    connection.database,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppTextAction(
            label: l10n.actionChange,
            onPressed: () => context.read<AuthCubit>().forgetConnection(),
          ),
        ],
      ),
    );
  }
}

/// Sign-in failures render inline so the password field stays visible and the
/// fix can be acted on immediately.
class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.state});

  final AuthState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presented = FailurePresenter.present(
      AppL10n.of(context),
      state.failure!,
    );

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
          Text(
            presented.fix,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
