/// Product-wide constants. Anything tunable lives here, never inline.
abstract final class AppConstants {
  static const String appName = 'Sijil IT';
  static const String appTagline = 'IT Asset Management';

  /// XML-RPC endpoints exposed by every standard Odoo instance (spec §1).
  static const String xmlRpcCommonPath = '/xmlrpc/2/common';
  static const String xmlRpcObjectPath = '/xmlrpc/2/object';
  static const String xmlRpcDbPath = '/xmlrpc/2/db';

  /// The web client's database list.
  ///
  /// Not part of the XML-RPC surface above: it is the JSON route Odoo's own
  /// login page calls, and the app uses it for one thing — reading the
  /// database list on a hosted instance, where `/xmlrpc/2/db` is disabled and
  /// answers `AccessDenied` to every caller.
  static const String webDatabaseListPath = '/web/database/list';

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 45);
  static const Duration sendTimeout = Duration(seconds: 30);

  /// The longest `Retry-After` the app will quote back to a user.
  ///
  /// A proxy shedding load sometimes asks for an hour, which is true and
  /// useless on a screen somebody is standing in front of. Past this the
  /// message drops the number and says "wait a moment" instead — the same
  /// advice without the false precision of a countdown nobody will sit out.
  static const Duration maxQuotedRetryWait = Duration(minutes: 10);

  /// How long capability metadata (`ir.model` / `fields_get`) stays cached
  /// before a background refresh. Settings offers a manual refresh too.
  static const Duration metadataTtl = Duration(hours: 12);

  static const int defaultPageSize = 50;

  /// Warranty buckets used by the dashboard and the warranty filter (spec §15).
  static const int warrantyWarningDays = 30;
  static const int warrantyNoticeDays = 90;

  /// Scheme for QR payloads. Carries only an internal identifier, never
  /// credentials or session data (spec §12).
  static const String qrScheme = 'asset';

  /// How many chatter entries the dashboard's activity feed shows.
  /// Photos shown for one record. Past this the strip shows a "+N" badge
  /// rather than paging: nobody attaches thirty photos to a repair, and if
  /// they did, scrolling them on a detail screen is not the answer.
  static const int attachmentListLimit = 24;

  /// The dashboard trend: how many months it covers, how many dated records
  /// it needs before it will draw anything, and the cap on the single-column
  /// read that feeds it.
  static const int trendMonths = 12;
  static const int trendMinimumRecords = 6;
  static const int trendScanLimit = 3000;

  /// The audit reads its expected set in one pass before the walk starts, so
  /// the count is against a fixed target. The cap is a guard against someone
  /// choosing "everything" on a fleet where that is not a walk-around job:
  /// past this the scope picker is the answer, not a longer read.
  static const int auditPageSize = 200;
  static const int auditMaxAssets = 1000;

  /// Chatter entries read for an asset's history. Deep enough to cover a
  /// device's whole service life, shallow enough to stay one round trip.
  static const int historyLimit = 60;

  static const int activityFeedLimit = 12;

  /// How deep the status-note scan goes when reading a page of assets.
  ///
  /// The three states Odoo has no field for are recorded as chatter notes, and
  /// a page of fifty assets is read with one filtered query. Most assets never
  /// carry one of these notes, so this is generous by an order of magnitude —
  /// deliberately, because the failure mode of it being too small is a status
  /// quietly reverting to the derived one on a colleague's phone.
  static const int markerNoteScanLimit = 400;

  /// How long the app may be in the background before the lock comes back on.
  ///
  /// Not zero, and the reason is the rest of the product: the camera
  /// permission dialog, the photo picker, the OS share sheet and the unlock
  /// prompt itself all background the app. Locking on every pause would put
  /// the prompt in front of somebody who never left the room — twice during a
  /// single return, once for the picker and once for the share.
  ///
  /// Half a minute is long enough to cover those and short enough that a phone
  /// put down on a desk is locked before anybody else picks it up.
  static const Duration appLockGrace = Duration(seconds: 30);

  /// How close to its expected return date an asset has to be before the app
  /// says so.
  ///
  /// Three days rather than a week: the point of the warning is that somebody
  /// can still act on it — send a reminder, book the desk — and a badge that
  /// lights up seven days out is one that is lit most of the time and read
  /// none of it.
  static const int returnDueSoonDays = 3;

  /// How deep the due-date note scan goes when reading a page of assets.
  ///
  /// Matches [markerNoteScanLimit] and for the same reason: a due date is
  /// recorded as a chatter note, and a limit too small means an asset quietly
  /// loses the date somebody set for it.
  static const int dueNoteScanLimit = markerNoteScanLimit;

  /// How many assets one multi-select action may carry.
  ///
  /// A bulk write is a single `write` over the whole set, so the ceiling is
  /// not Odoo's — it is the label sheet's and the user's. Past a couple of
  /// hundred rows nobody is reviewing what they selected, and "move these to
  /// Finance" stops being a decision and becomes an accident.
  static const int bulkSelectionLimit = 200;

  /// The label sheet's grid. Three across and eight down is the standard
  /// 24-per-page address-label stock A4 sheets are sold in, so the output
  /// lines up with paper somebody can actually buy.
  static const int labelSheetColumns = 3;
  static const int labelSheetRows = 8;

  /// How many category bars the dashboard draws before it stops being a chart.
  static const int categoryChartLimit = 6;

  /// How long an IT asset is assumed to earn its keep, in months.
  ///
  /// Five years. Not a fact about any particular laptop — it is the figure
  /// finance departments actually depreciate IT equipment over, and it is what
  /// makes "this machine is four and a half years old" mean something to
  /// somebody deciding a budget.
  ///
  /// Deliberately one number rather than a table per category. A per-category
  /// figure would be more accurate and would also be wrong on every instance
  /// that categorises differently from ours — and the screen it feeds is a
  /// prompt to think, not a depreciation schedule.
  static const int assetServiceLifeMonths = 60;

  /// How close to the end of that life an asset has to be before the app says
  /// so. Six months: long enough to get a purchase through an approval cycle.
  static const int assetReplacementNoticeMonths = 6;

  /// One employee's holdings fit in a single page; paging four rows would be
  /// ceremony for nothing.
  static const int employeeAssetsPageSize = 100;

  /// How far either side of today a date may be picked. Assets have dates in
  /// both directions: a warranty runs forward, a late-recorded handover back.
  static const int datePickerYearsBack = 25;
  static const int datePickerYearsForward = 15;

  /// The last day of the forward window, so the range ends on a year boundary
  /// rather than on today's date N years out.
  static const int decemberMonth = 12;
  static const int decemberLastDay = 31;

  /// Return photos are evidence of a scratch, not print artwork. Capping them
  /// keeps one payload with up to five attachments from timing out on a phone.
  static const double photoMaxWidth = 1600;
  static const int photoQuality = 70;

  /// Photos accepted in one pick. A phone camera JPEG is 8-12 MB and
  /// `ir.attachment` stores it base64-encoded — a third larger again — so an
  /// unbounded multi-pick is how one repair eats an Odoo Online quota.
  static const int maxPhotosPerPick = 6;

  const AppConstants._();
}

/// Brand asset paths bundled with the app.
///
/// Each mark ships in two forms. The light set is the navy artwork; the dark
/// set replaces that navy with the dark theme's ink and leaves the mint accent
/// alone, because mint already reads on a dark ground and is the brand's
/// accent. Never reference these directly from a screen — `AppLogo` picks the
/// right one from the surface it is drawn on.
abstract final class AppAssets {
  static const String logoLockup = 'assets/sijil-lockup.png';
  static const String logoLockupDark = 'assets/sijil-lockup-dark.png';

  static const String logoMonogram = 'assets/sijil-monogram.png';
  static const String logoMonogramDark = 'assets/sijil-monogram-dark.png';

  static const String logoWordmark = 'assets/sijil-wordmark.png';
  static const String logoWordmarkDark = 'assets/sijil-wordmark-dark.png';

  /// Launcher icon. No dark variant: it is drawn on the user's wallpaper,
  /// not on one of our surfaces.
  static const String appIcon = 'assets/sijil-app-icon.png';

  static const String hero = 'assets/sijil-hero.png';

  /// Faces loaded at runtime rather than through the manifest.
  ///
  /// The `pdf` package embeds a font by reading its bytes, so unlike the UI
  /// type — which `pubspec.yaml` registers and Flutter resolves by family —
  /// these are addressed by path and belong here with the images.
  ///
  /// The Arabic face is used for Latin too: a receipt written in English
  /// still carries Arabic asset names, and a font without those glyphs prints
  /// them as empty boxes.
  static const String pdfFontRegular =
      'assets/fonts/IBMPlexSansArabic-Regular.ttf';
  static const String pdfFontBold =
      'assets/fonts/IBMPlexSansArabic-SemiBold.ttf';
  static const String pdfFontMono = 'assets/fonts/JetBrainsMono-Variable.ttf';

  const AppAssets._();
}
