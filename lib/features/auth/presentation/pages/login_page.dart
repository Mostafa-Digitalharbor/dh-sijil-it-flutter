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
import '../../../../shared/utils/l10n_lookup.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/app_segmented.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../cubit/auth_cubit.dart';

/// Second of the two first-run screens: *who you are* (spec §3).
///
/// Takes the server and database as settled — the previous screen chose them,
/// and the summary card at the top says which — and asks only for the pair
/// that changes: the username and the password or API key.
///
/// ## Going back
///
/// The three auth screens are swapped by the router's redirect rather than
/// pushed onto a stack, so there is no route to pop. Back is therefore a state
/// change: [AuthCubit.editConnection] returns to `configuring`, the redirect
/// notices, and the server screen comes back with its fields intact. The
/// system back gesture is wired to the same call, because a back button that
/// works and a back swipe that closes the app is worse than neither.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _secret = TextEditingController();

  /// Which credential the user says they are typing.
  ///
  /// Local to this screen rather than part of the saved connection until a
  /// sign-in succeeds: it is a statement about the secret being entered now,
  /// and the secret never leaves this widget.
  OdooAuthMode _authMode = OdooAuthMode.password;

  bool _obscure = true;
  bool _keepSignedIn = true;

  /// Validation keys for the two fields, or null when they are fine.
  String? _usernameError;
  String? _secretError;

  @override
  void initState() {
    super.initState();

    // Prefilled once, here, rather than on every build from the Bloc value:
    // assigning to a `TextEditingController` notifies its field, and doing
    // that during a build is how a "markNeedsBuild during build" crash gets
    // written. Once is also all that is correct — a rebuild mid-typing must
    // not put the old username back under the cursor.
    //
    // Empty after the server screen, filled after a sign-out: the connection
    // is already in state by the time the router mounts this page, because
    // that state is what routed here.
    final connection = context.read<AuthCubit>().state.connection;
    if (connection != null) {
      _username.text = connection.username;
      _authMode = connection.authMode;
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _secret.dispose();
    super.dispose();
  }

  void _submit(OdooConnection connection) {
    final username = _username.text.trim();
    final secret = _secret.text;

    setState(() {
      _usernameError = username.isEmpty ? _ValidationKeys.username : null;
      _secretError = secret.isEmpty ? _ValidationKeys.credential : null;
    });
    if (_usernameError != null || _secretError != null) return;

    FocusScope.of(context).unfocus();
    context.read<AuthCubit>().signIn(
      connection: connection.copyWith(username: username, authMode: _authMode),
      secret: secret,
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

        // The router only routes here with a connection, so this is a
        // defensive fallback rather than a reachable state.
        if (connection == null) return const SizedBox.shrink();

        return PopScope(
          // Handled here instead of popping: there is nothing on the stack
          // below this screen, so the default would close the app.
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _back(context);
          },
          child: Scaffold(
            backgroundColor: isDark ? AppColors.surfaceDark : AppColors.navy,
            body: Column(
              children: [
                _BrandBand(
                  subtitle: l10n.loginSubtitle,
                  title: l10n.loginWelcomeBack,
                  onBack: () => _back(context),
                ),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadii.sheetTop),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: _LoginForm(
                        connection: connection,
                        state: state,
                        username: _username,
                        secret: _secret,
                        authMode: _authMode,
                        obscure: _obscure,
                        keepSignedIn: _keepSignedIn,
                        usernameError: _usernameError,
                        secretError: _secretError,
                        onAuthMode: (mode) => setState(() {
                          _authMode = mode;
                          _secretError = null;
                        }),
                        onToggleObscure: () =>
                            setState(() => _obscure = !_obscure),
                        onToggleKeep: (value) =>
                            setState(() => _keepSignedIn = value),
                        onUsernameChanged: (_) {
                          if (_usernameError != null) {
                            setState(() => _usernameError = null);
                          }
                        },
                        onSecretChanged: (_) {
                          if (_secretError != null) {
                            setState(() => _secretError = null);
                          }
                        },
                        onSubmit: () => _submit(connection),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _back(BuildContext context) {
    FocusScope.of(context).unfocus();
    context.read<AuthCubit>().editConnection();
  }
}

/// The navy header — the only full-bleed brand moment in the app.
class _BrandBand extends StatelessWidget {
  const _BrandBand({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final screen = context.screen;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: screen.gutter + AppSpacing.sm,
          end: screen.gutter + AppSpacing.sm,
          top: AppSpacing.md,
          bottom: AppSpacing.xxxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Unbordered and transparent: a bordered box would read as a
            // control floating on the brand band rather than part of it. The
            // glyph mirrors itself in Arabic, so back always points the way
            // the user came from.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: l10n.loginBackToServer,
                bordered: false,
                color: Colors.white,
                onPressed: onBack,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

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
    required this.username,
    required this.secret,
    required this.authMode,
    required this.obscure,
    required this.keepSignedIn,
    required this.usernameError,
    required this.secretError,
    required this.onAuthMode,
    required this.onToggleObscure,
    required this.onToggleKeep,
    required this.onUsernameChanged,
    required this.onSecretChanged,
    required this.onSubmit,
  });

  final OdooConnection connection;
  final AuthState state;
  final TextEditingController username;
  final TextEditingController secret;
  final OdooAuthMode authMode;
  final bool obscure;
  final bool keepSignedIn;
  final String? usernameError;
  final String? secretError;
  final ValueChanged<OdooAuthMode> onAuthMode;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool> onToggleKeep;
  final ValueChanged<String> onUsernameChanged;
  final ValueChanged<String> onSecretChanged;
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
                  hint: l10n.fieldUsernameHint,
                  icon: Icons.person_outline_rounded,
                  controller: username,
                  onChanged: onUsernameChanged,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  textDirection: TextDirection.ltr,
                  autofillHints: const [AutofillHints.username],
                  errorText: l10n.lookup(usernameError),
                ),
                const SizedBox(height: AppSpacing.lg),

                AppTextField(
                  label: l10n.fieldCredential,
                  hint: authMode == OdooAuthMode.apiKey
                      ? l10n.fieldApiKeyHint
                      : l10n.fieldPasswordHint,
                  icon: authMode == OdooAuthMode.apiKey
                      ? Icons.vpn_key_outlined
                      : Icons.lock_outline_rounded,
                  controller: secret,
                  obscure: obscure,
                  onChanged: onSecretChanged,
                  onToggleObscure: onToggleObscure,
                  textInputAction: TextInputAction.done,
                  textDirection: TextDirection.ltr,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => onSubmit(),
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  errorText: l10n.lookup(secretError),
                  // A password and an API key go to the same Odoo endpoint but
                  // are different things to look up, so the choice sits on the
                  // field it describes rather than in a settings screen.
                  action: AppSegmented<OdooAuthMode>(
                    compact: true,
                    semanticLabel: l10n.fieldCredential,
                    value: authMode,
                    onChanged: onAuthMode,
                    options: [
                      SegmentOption(
                        value: OdooAuthMode.password,
                        label: l10n.authModePassword,
                      ),
                      SegmentOption(
                        value: OdooAuthMode.apiKey,
                        label: l10n.authModeApiKey,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                _KeepSignedInRow(
                  keepSignedIn: keepSignedIn,
                  onToggleKeep: onToggleKeep,
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

                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: AppDimens.iconSm,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        l10n.credentialStorageNote,
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The chosen server, shown so the user knows what they are signing into.
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
            // A host and a database name are identifiers, not prose, so their
            // glyphs are ordered left-to-right in both languages — otherwise
            // an Arabic layout renders `dh-sijil.odoo.com` with its parts
            // rearranged.
            //
            // The direction is set per-[Text] rather than by wrapping this
            // column in a `Directionality`, because that wrapper also decides
            // what "start" means: the whole block aligned itself to the left
            // of an Arabic card and sat marooned there, a finger's width from
            // the icon it belongs to, with the gap on the wrong side.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    connection.baseUrl.host,
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    connection.database,
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // The same destination as the band's back arrow, offered again on
          // the thing it changes — a user reading the summary and finding the
          // database wrong should not have to look for the way back.
          AppTextAction(
            label: l10n.actionChange,
            onPressed: () => context.read<AuthCubit>().editConnection(),
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

/// Sentinel keys this screen resolves through `AppL10n`.
///
/// Same discipline as the Cubits': the widget decides *what* is wrong and the
/// lookup decides how to say it, so neither the check nor the message has to
/// know about the other's language.
abstract final class _ValidationKeys {
  static const String username = 'validationEnterUsername';
  static const String credential = 'validationEnterCredential';

  const _ValidationKeys._();
}

/// "Keep me signed in", with the API-key explainer beside it.
///
/// Side by side at ordinary text sizes, stacked once the user has turned text
/// up: the checkbox label and the link are both sentences, and at 1.6x on a
/// small phone they cannot share a line. Clipping either one costs the user
/// the sentence that explains what the field above wants — which is the whole
/// reason the link is on this screen and not in a help centre.
class _KeepSignedInRow extends StatelessWidget {
  const _KeepSignedInRow({
    required this.keepSignedIn,
    required this.onToggleKeep,
  });

  final bool keepSignedIn;
  final ValueChanged<bool> onToggleKeep;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final keep = AppCheckRow(
      label: l10n.loginKeepSignedIn,
      value: keepSignedIn,
      onChanged: onToggleKeep,
    );
    final help = AppTextAction(
      label: l10n.loginNeedApiKey,
      onPressed: () => _showApiKeyHelp(context),
    );

    if (context.screen.isLargeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[keep, help],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(child: keep),
        help,
      ],
    );
  }

  /// What an API key is and where to get one, asked in the place the question
  /// occurs to the user.
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
