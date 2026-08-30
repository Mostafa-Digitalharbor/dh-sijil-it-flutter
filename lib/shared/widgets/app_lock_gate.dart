import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_spacing.dart';
import '../../features/settings/presentation/cubit/app_lock_cubit.dart';
import '../../l10n/generated/app_localizations.dart';
import 'app_button.dart';
import 'app_logo.dart';

/// Covers the app while it is locked.
///
/// ## Why it covers rather than replaces
///
/// The lock is a fact about the app, not a destination. Routing it as a page
/// would mean throwing away whatever navigation stack the user had built — the
/// half-filled return, the asset three taps deep — every time the phone spent
/// a minute in a pocket. Painting over the top keeps all of it and gives it
/// back the moment the unlock lands.
///
/// The cover is opaque on purpose. A blurred or dimmed screen behind a lock is
/// still the company's asset register legible to whoever is holding the phone,
/// which is precisely the person this exists to stop.
class AppLockGate extends StatelessWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppLockCubit, AppLockState>(
      builder: (context, state) {
        if (!state.isBlocking) return child;

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[child, const _LockScreen()],
        );
      },
    );
  }
}

/// What the user sees while the app is locked.
class _LockScreen extends StatefulWidget {
  const _LockScreen();

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  @override
  void initState() {
    super.initState();
    // The prompt is asked for here rather than in `AppLockCubit.start`,
    // because the reason string is translated and the translations only exist
    // below `Localizations` — which is also, conveniently, the first frame
    // there is anything to cover.
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptIfLocked());
  }

  void _promptIfLocked() {
    if (!mounted) return;
    final cubit = context.read<AppLockCubit>();
    if (cubit.state.status != AppLockStatus.locked) return;
    unawaited(cubit.unlock(AppL10n.of(context).lockReason));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final state = context.watch<AppLockCubit>().state;

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimens.dialogMaxWidth,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const AppLogo.monogram(
                    size: AppDimens.tileLg,
                    onDarkSurface: true,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: AppDimens.iconXxl,
                    color: AppColors.mint,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.lockTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    // Says what is at stake rather than "authentication
                    // required": the user is being interrupted, and the least
                    // the screen can do is explain why it is worth it.
                    state.wasRefused ? l10n.lockFailed : l10n.lockBody,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.heroSubdued,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton.accent(
                    label: l10n.lockUnlock,
                    icon: Icons.fingerprint_rounded,
                    isBusy: state.isPrompting,
                    onPressed: state.isPrompting
                        ? null
                        : () => unawaited(
                            context.read<AppLockCubit>().unlock(
                              l10n.lockReason,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
