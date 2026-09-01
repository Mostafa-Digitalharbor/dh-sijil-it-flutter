import 'package:flutter/material.dart';

import '../../../../app/di/injector.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/storage/preferences/app_preferences.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/utils/app_date_format.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_segmented.dart';

/// How long the device may go on using a saved Odoo sign-in.
///
/// ## What this is guarding
///
/// The credential in the keychain is a working Odoo login, not a token the
/// server can revoke — standard Odoo has nothing to revoke it *with* over
/// XML-RPC. Before this existed it stayed valid for as long as the app was
/// installed, so a handset lost in month one was still a way into the asset
/// register in month nine, and the only thing that stopped it was somebody
/// noticing and changing the password centrally.
///
/// ## Why the window is idle time
///
/// It counts from the last time the app successfully reached Odoo, not from
/// when the password was typed. A technician who opens the app every morning
/// is never signed out; a phone in a drawer is. Measuring from sign-in instead
/// would have logged out the people using it most, which is how a security
/// setting gets turned off.
///
/// ## Why "Never" is offered
///
/// Because it is the honest name for what the app did before, and a customer
/// on a shared shop-floor device with no other way in should be able to choose
/// it deliberately rather than discover the default has locked them out. The
/// default is thirty days.
class SessionCard extends StatefulWidget {
  const SessionCard({super.key});

  @override
  State<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<SessionCard> {
  late final AppPreferences _preferences = sl<AppPreferences>();
  late int _maxAgeDays = _preferences.sessionMaxAgeDays;

  Future<void> _setMaxAge(int days) async {
    await _preferences.setSessionMaxAgeDays(days);
    if (mounted) setState(() => _maxAgeDays = days);
  }

  /// When the current session lapses, or null when it cannot.
  DateTime? get _expiresOn {
    if (_maxAgeDays <= AppPreferences.sessionNeverExpires) return null;
    final last = _preferences.lastAuthenticated;
    if (last == null) return null;
    return last.add(Duration(days: _maxAgeDays));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final expiresOn = _expiresOn;

    return SectionCard(
      title: l10n.sessionTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(l10n.sessionSubtitle, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          AppSegmented<int>(
            value: _maxAgeDays,
            semanticLabel: l10n.sessionTitle,
            onChanged: _setMaxAge,
            options: <SegmentOption<int>>[
              for (final days in AppPreferences.sessionMaxAgeOptions)
                SegmentOption<int>(
                  value: days,
                  label: l10n.sessionMaxAgeDays(days),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            // The date, not the policy, when there is one to give: "signs out
            // on 3 October" is something a person can plan around in a way
            // that "30 days" is not.
            expiresOn != null
                ? l10n.sessionExpiresOn(context.dates.dayLong(expiresOn))
                : l10n.sessionNeverExpiresNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.sessionExplain,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
