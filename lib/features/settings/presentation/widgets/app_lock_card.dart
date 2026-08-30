import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_segmented.dart';
import '../cubit/app_lock_cubit.dart';

/// The "require unlock" switch.
///
/// ## Why turning it on asks straight away
///
/// The switch does not take the user's word for it — flipping it on shows the
/// system prompt immediately, and stays off unless that prompt is answered.
/// Two reasons, and both are about the next launch rather than this one: the
/// user finds out now whether their device will actually let them back in, and
/// a switch that enrolled a lock nobody ever tested is a switch that strands
/// somebody at the door with no way back to Settings.
///
/// ## Why it can be absent
///
/// A device with no screen lock at all has nothing to ask for. The row still
/// appears — disabled, with the reason written out — rather than vanishing,
/// because a setting that is missing looks like a setting the app forgot,
/// and the fix ("set up a screen lock") is one the user can act on.
///
/// That sentence waits for the answer, though. Asking the OS is a round trip,
/// and printing "this device has no screen lock" while the question is still
/// in flight is a claim about the user's phone that is wrong on most of them.
/// Until it lands the row is simply inert.
class AppLockCard extends StatelessWidget {
  const AppLockCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final cubit = context.watch<AppLockCubit>();
    final state = cubit.state;

    return SectionCard(
      title: l10n.lockSettingsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppCheckRow(
            label: l10n.lockSettingsSubtitle,
            value: cubit.isEnabled,
            onChanged: state.hasDeviceLock
                ? (value) =>
                      cubit.setEnabled(value: value, reason: l10n.lockReason)
                : null,
          ),
          if (state.isProbed && !state.hasDeviceLock) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.lockUnavailable,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
