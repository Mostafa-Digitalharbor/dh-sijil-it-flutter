import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_tiles.dart';
import '../../../../shared/widgets/skeletons.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../domain/entities/handover.dart';
import '../cubit/handover_cubit.dart';

/// Picks several assets to add to a handover.
///
/// A multi-select sheet rather than a picker that closes on each tap, because
/// a bundle is by definition more than one thing: choosing four assets through
/// a single-select picker is four round trips through the same search.
///
/// Only assignable assets are offered, and only ones not already in the
/// bundle — an asset that is already on the list is not a choice, and leaving
/// it visible invites the tap that does nothing.
class AssetPickerSheet extends StatefulWidget {
  const AssetPickerSheet({required this.alreadyChosen, super.key});

  final Set<int> alreadyChosen;

  static Future<List<Asset>?> show(
    BuildContext context, {
    required HandoverCubit cubit,
  }) {
    final chosen = cubit.state.bundle.map((a) => a.id).toSet();

    return showModalBottomSheet<List<Asset>>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => BlocProvider<HandoverCubit>.value(
        value: cubit,
        child: AssetPickerSheet(alreadyChosen: chosen),
      ),
    );
  }

  @override
  State<AssetPickerSheet> createState() => _AssetPickerSheetState();
}

class _AssetPickerSheetState extends State<AssetPickerSheet> {
  final TextEditingController _search = TextEditingController();
  final Map<int, Asset> _picked = <int, Asset>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// How much room the bundle still has, so the sheet cannot hand back more
  /// than the bundle can hold.
  int get _remaining => HandoverBundle.maxAssets - widget.alreadyChosen.length;

  void _toggle(Asset asset) {
    setState(() {
      if (_picked.containsKey(asset.id)) {
        _picked.remove(asset.id);
      } else if (_picked.length < _remaining) {
        _picked[asset.id] = asset;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final screen = context.screen;
    final cubit = context.read<HandoverCubit>();

    return BlocBuilder<HandoverCubit, HandoverState>(
      builder: (context, state) {
        final options = state.available
            .where((a) => !widget.alreadyChosen.contains(a.id))
            .toList(growable: false);

        return SafeArea(
          top: false,
          child: Padding(
            // The keyboard is up the whole time this sheet is used — the first
            // thing anyone does is type a name.
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: screen.gutter,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        l10n.handoverPickAssets,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.handoverPickAssetsBody,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppSearchField(
                        controller: _search,
                        hint: l10n.handoverSearchAssets,
                        onChanged: cubit.searchAssets,
                        onClear: () => cubit.searchAssets(''),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Flexible(
                  child: _Results(
                    options: options,
                    hasMore: state.hasMoreAssets,
                    isLoadingMore: state.isLoadingMoreAssets,
                    onLoadMore: context.read<HandoverCubit>().loadMoreAssets,
                    picked: _picked,
                    isSearching: state.isSearchingAssets,
                    onToggle: _toggle,
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: screen.gutter,
                    end: screen.gutter,
                    top: AppSpacing.sm,
                    bottom: AppSpacing.lg,
                  ),
                  // Filled once there is something to add, outlined while the
                  // only thing it can do is close. A "Cancel" in full accent
                  // is the loudest thing on the sheet inviting the one tap
                  // that abandons what the user came here to do.
                  child: _picked.isEmpty
                      ? AppButton.outlined(
                          label: l10n.actionCancel,
                          onPressed: () => Navigator.of(context).pop(),
                        )
                      : AppButton(
                          label: l10n.handoverAddCount(_picked.length),
                          onPressed: () => Navigator.of(
                            context,
                          ).pop(_picked.values.toList()),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.options,
    required this.picked,
    required this.isSearching,
    required this.onToggle,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  final List<Asset> options;
  final Map<int, Asset> picked;
  final bool isSearching;
  final ValueChanged<Asset> onToggle;

  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final screen = context.screen;

    if (isSearching && options.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: SkeletonRowList(showChips: false),
      );
    }

    if (options.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          l10n.handoverNoAssignableAssets,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    // One extra slot when there is more to read. Reaching it is what asks
    // for the next page — the sheet is short and its list is shrink-wrapped,
    // so a scroll-position listener would have nothing dependable to measure.
    final footer = hasMore ? 1 : 0;

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsetsDirectional.only(
        start: screen.gutter,
        end: screen.gutter,
      ),
      itemCount: options.length + footer,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index >= options.length) {
          return _LoadMoreRow(isLoading: isLoadingMore, onVisible: onLoadMore);
        }

        final asset = options[index];
        return AppSelectableTile(
          title: asset.name,
          subtitle: asset.assetTag ?? asset.serialNumber ?? asset.model ?? '',
          selected: picked.containsKey(asset.id),
          onTap: () => onToggle(asset),
        );
      },
    );
  }
}

/// The last row of the picker: asks for the next page as soon as it is built.
///
/// A `StatefulWidget` only so the request fires once per mount. Built inside
/// `itemBuilder`, this is reached exactly when the row scrolls into range, and
/// the callback is scheduled after the frame because emitting Cubit state
/// during a build is what turns a paging trigger into a "setState during
/// build" crash.
class _LoadMoreRow extends StatefulWidget {
  const _LoadMoreRow({required this.isLoading, required this.onVisible});

  final bool isLoading;
  final VoidCallback onVisible;

  @override
  State<_LoadMoreRow> createState() => _LoadMoreRowState();
}

class _LoadMoreRowState extends State<_LoadMoreRow> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onVisible();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsetsDirectional.all(AppSpacing.md),
      child: Center(
        child: SizedBox(
          width: AppDimens.iconXl,
          height: AppDimens.iconXl,
          child: CircularProgressIndicator(
            strokeWidth: AppDimens.progressStroke,
          ),
        ),
      ),
    );
  }
}
