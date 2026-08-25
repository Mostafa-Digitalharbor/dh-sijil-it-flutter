import '../../../../core/utils/typedefs.dart';
import '../entities/handover.dart';

/// Handing a set of assets to one person against their signature.
abstract interface class HandoverRepository {
  /// Records the bundle and returns what landed.
  ///
  /// Returns `Left` only when the bundle could not be attempted at all. A
  /// bundle Odoo partly refused comes back as `Right(receipt)` with the
  /// refusals named in it — see [HandoverReceipt] for why that distinction is
  /// the whole contract.
  ResultFuture<HandoverReceipt> submit(HandoverBundle bundle);
}
