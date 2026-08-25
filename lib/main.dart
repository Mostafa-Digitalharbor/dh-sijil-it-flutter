import 'app/app.dart';
import 'bootstrap.dart';

/// Production entry point.
///
/// Kept to two lines on purpose: all startup work lives in `bootstrap()` so
/// flavour entry points (`main_dev.dart`, `main_staging.dart`) reuse it
/// verbatim.
Future<void> main() => bootstrap(SijilApp.new);
