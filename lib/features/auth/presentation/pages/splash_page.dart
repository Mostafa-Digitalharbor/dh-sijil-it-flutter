import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../cubit/auth_cubit.dart';

/// Boot screen.
///
/// Its only job is to start [AuthCubit.restore] exactly once and show the
/// brand while it runs; the router's redirect moves on as soon as the status
/// resolves. Kept deliberately dumb — a splash that makes decisions is a
/// splash that flashes the wrong screen.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    // Deferred to the first frame so the router is mounted before the
    // resulting state change triggers a redirect.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<AuthCubit>();
      if (cubit.state.status == AuthStatus.unknown) {
        cubit.restore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.navy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The splash paints navy in both themes, so the mark is pinned to
            // the dark variant rather than following the theme.
            const AppLogo.monogram(
              size: AppDimens.emptyStateIconBox,
              onDarkSurface: true,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              AppConstants.appName,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.onBrand,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.appTagline,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.heroSubdued,
              ),
            ),
            const SizedBox(height: AppSpacing.huge),
            const SizedBox(
              width: AppDimens.iconXxl,
              height: AppDimens.iconXxl,
              child: CircularProgressIndicator(
                strokeWidth: AppDimens.progressStrokeThick,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.mint),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.splashRestoring,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.heroSubdued,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
