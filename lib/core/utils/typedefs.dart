import 'package:dartz/dartz.dart';

import '../error/failures.dart';

/// Every repository method returns one of these: an explicit success value or
/// a sanitized [Failure]. No exceptions cross the domain boundary.
typedef ResultFuture<T> = Future<Either<Failure, T>>;

/// Synchronous variant, used by pure calculators (warranty state, etc).
typedef Result<T> = Either<Failure, T>;

/// Raw Odoo record as returned by `search_read` / `read`.
typedef OdooRecord = Map<String, dynamic>;

/// A list of raw Odoo records.
typedef OdooRecords = List<Map<String, dynamic>>;

/// An Odoo search domain, e.g. `[['state', '=', 'assigned']]`.
typedef OdooDomain = List<dynamic>;
