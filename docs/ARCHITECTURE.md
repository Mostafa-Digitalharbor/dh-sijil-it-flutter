# Sijil IT — Architecture

Standalone Flutter IT Asset Management app talking directly to a **stock Odoo
instance over XML-RPC**. No custom Odoo addon, no middleware, no Digital
Harbor backend.

---

## 1. The one rule everything else follows

```
UI (Widget)
   │  reads state, fires intents
   ▼
Cubit  ..................... the ViewModel (MVVM)
   │  calls
   ▼
UseCase  ................... one verb of application behaviour
   │  calls
   ▼
Repository (interface)  .... domain-owned contract
   │  implemented by
   ▼
RepositoryImpl  ............ data layer: cache + remote, Either<Failure, T>
   │  calls
   ▼
DataSource  ................ speaks Odoo models, domains and fields
   │  calls
   ▼
OdooObjectService  ......... the only place that builds `execute_kw`
   │  calls
   ▼
XmlRpcClient  .............. transport, knows nothing about Odoo
   │
   ▼
HTTPS → Standard Odoo (standard models, standard ACLs, standard XML-RPC)
```

**Dependencies point inward only.** `domain/` imports nothing from `data/` or
`presentation/`. A widget that imports `OdooObjectService` is a bug, and the
PR template checks for it (spec §18).

---

## 2. Clean Architecture + MVVM, together

They are not competing ideas here — they operate at different scopes.

| Concern | Clean Architecture answer | MVVM answer |
|---|---|---|
| Where does business logic live? | `domain/usecases` | — |
| What does the screen bind to? | — | The Cubit (ViewModel) |
| What does the screen render? | — | An immutable `ViewState` |
| Who talks to Odoo? | `data/datasources` | — |
| Who owns navigation? | — | Router, driven by state |

Concretely: **the Cubit is the ViewModel.** It holds no widgets, no
`BuildContext` and no RPC code. It calls use cases, maps the result into an
immutable state object, and emits it. That makes every screen testable with
`bloc_test` and zero Flutter surface.

```dart
class AssetListCubit extends Cubit<AssetListState> {
  AssetListCubit(this._getAssets) : super(const AssetListState());

  final GetAssetsPage _getAssets;   // use case, injected

  Future<void> load({bool refresh = false}) async {
    emit(state.copyWith(status: refresh ? ViewStatus.refreshing : ViewStatus.loading));

    final result = await _getAssets(AssetQuery(page: state.nextPage, filters: state.filters));

    emit(result.fold(
      (failure) => state.copyWith(status: ViewStatus.failure, failure: failure),
      (page)    => state.copyWith(status: ViewStatus.success, page: state.page.merge(page)),
    ));
  }
}
```

---

## 3. Folder map

```
lib/
├── main.dart                      entry point, two lines
├── bootstrap.dart                 error zones, DI, Bloc observer, runApp
│
├── app/                           composition root — wires, never decides
│   ├── app.dart                   MaterialApp.router
│   ├── di/injector.dart           get_it service locator
│   ├── router/                    go_router graph + auth gate + tab shell
│   ├── observers/                 BlocObserver
│   └── theme/                     colours, spacing, type, Material 3 themes
│
├── core/                          feature-agnostic engine
│   ├── constants/                 Odoo model & field catalog, storage keys
│   ├── error/                     exceptions → failures → user-facing text
│   ├── network/
│   │   ├── xmlrpc/                codec + Dio client (Odoo-agnostic)
│   │   ├── odoo/                  auth, execute_kw, capabilities, domains
│   │   └── connectivity/
│   ├── storage/
│   │   ├── secure/                (credentials live in core/security)
│   │   ├── cache/                 CacheStore interface + encrypted Hive impl
│   │   └── preferences/
│   ├── security/                  CredentialVault, LogSanitizer
│   ├── pagination/                PageRequest, PaginatedResult
│   └── usecase/                   UseCase base types
│
├── shared/                        cross-feature presentation
│   ├── cubit/view_state.dart      ViewStatus + ViewState base
│   ├── cubit/async_guards.dart    RequestTicket (stale-response guard),
│   │                              Debouncer — five Cubits had their own copy
│   ├── utils/app_number.dart      counts follow the language (§6b of l10n)
│   ├── utils/app_text.dart        the `·` separator, in one place
│   └── widgets/                   StatusChip, AppTitleBlock, skeletons,
│                                  empty & error views
│
└── features/<feature>/
    ├── data/{datasources,models,mappers,repositories}
    ├── domain/{entities,repositories,usecases}
    └── presentation/{cubit,pages,widgets}
```

Features: `connection`, `auth`, `dashboard`, `assets`, `assignment`,
`attachments`, `audit`, `employees`, `handover`, `maintenance`, `scanner`,
`settings`.

---

## 4. Design patterns, and where each one earns its place

| Pattern | Where | Why it is there |
|---|---|---|
| **Repository** | `domain/repositories` + `data/repositories` | Domain depends on a contract, not on Odoo |
| **Service Locator (DI)** | `app/di/injector.dart` | One graph, every layer swappable in tests |
| **Facade** | `OdooObjectService` | Hides `execute_kw` positional-arg noise behind `searchRead`, `create`, … |
| **Adapter / Mapper** | `data/mappers/*` | Odoo record → domain entity; isolates field-name churn between Odoo versions |
| **Builder** | `OdooDomainBuilder` | Odoo's prefix-notation domains, assembled safely and readably |
| **Strategy** | `AssetSource` + per-source data sources | `maintenance.equipment` vs `stock.lot` chosen at runtime |
| **Chain of responsibility** | `AssetStatusResolver` | Odoo field → derived → local overlay, in precedence order |
| **Decorator** | `CachedAssetRepository` wrapping `RemoteAssetRepository` | Caching added without touching the remote implementation |
| **Template Method** | `UseCase<T, Params>` | Uniform call shape and error contract for every action |
| **Observer** | `OdooSessionManager.changes`, `BlocObserver` | Session changes re-run the router guard; state transitions are traced |
| **Value Object** | `Warranty`, `OdooNameRef`, `PageRequest` | Equality by value; pure, trivially testable calculations |
| **Result / Either** | `ResultFuture<T>` | Errors are values, not control flow — no exception reaches a widget |
| **Singleton** | Clients, stores, session manager | One socket pool, one keystore handle, one cache |

### SOLID in this codebase

- **S** — `XmlRpcCodec` encodes/decodes; `DioXmlRpcClient` moves bytes;
  `OdooObjectService` speaks Odoo. Three reasons to change, three classes.
- **O** — Supporting a new asset backing model means adding an `AssetSource`
  strategy, not editing existing ones.
- **L** — Every `CacheStore` implementation honours the same contract; the
  Hive one can be replaced by Isar with no caller change.
- **I** — `XmlRpcClient` exposes one method. Repositories depend on narrow
  interfaces, never on a god-object client.
- **D** — Everything is registered and injected against an interface.

---

## 5. Odoo compatibility strategy (spec §§2, 17, 28)

The app must run on Odoo 17, 18 and 19, on instances where optional apps may
or may not be installed — and must never crash because something is missing.

**Nothing is assumed. Everything is probed.**

```
Login succeeds
      │
      ▼
OdooCapabilityService.probeAll()
      │
      ├── ir.model  → does `maintenance.equipment` exist?
      ├── ir.model  → does `hr.employee` exist?
      ├── ir.model  → `stock.lot` or the pre-16 `stock.production.lot`?
      └── fields_get → which fields does this version actually expose?
      │
      ▼
OdooCapabilities  →  UI shows / hides features, repositories pick a strategy
```

Two rules follow from this:

1. **Every read set is intersected before it is sent.**
   `supportedFields(model, EquipmentFields.readSet)` drops anything this
   instance lacks, so a trimmed or older Odoo never returns an invalid-field
   fault.
2. **Feature detection beats version sniffing.** `serverVersion` is recorded
   for diagnostics; behaviour keys off `modelExists` / `fieldExists`.

Results are memoised in RAM and persisted with a 12-hour TTL. Settings →
*Refresh Odoo metadata* clears both.

### Which standard model backs an "asset"?

| Preference | Model | Why |
|---|---|---|
| 1 | `maintenance.equipment` | Richest stock fit: `serial_no`, `model`, `category_id`, `employee_id`, `department_id`, `assign_date`, `cost`, `warranty_date`, `partner_id`, `scrap_date`, plus native maintenance requests |
| 2 | `stock.lot` | Serial-tracked inventory items |
| 3 | `product.product` | Last resort, no serial tracking |
| — | none | The app says so plainly instead of failing |

---

## 6. Asset status: the documented local abstraction (spec §6)

Standard Odoo has no single IT-asset status field, and §2 forbids adding one
via an addon. Status is therefore **resolved**, in this precedence order:

1. **A real Odoo field, if the customer already has one.**
   The resolver checks for a configurable selection field (default
   `x_sijil_status`). If it exists, Odoo is the sole source of truth and steps
   2–3 are skipped entirely.

2. **Derived from standard fields** — no local storage needed:

   | Result | Condition |
   |---|---|
   | `retired` | `scrap_date` is set |
   | `underMaintenance` | `maintenance_open_count > 0` |
   | `assigned` | `employee_id` is set |
   | `available` | otherwise |

3. **A note in the asset's Odoo chatter**, only for the three states standard
   Odoo genuinely cannot express: `reserved`, `damaged`, `lost`.

### Where those three actually live

They used to live in an encrypted Hive box and nowhere else, which meant the
handset that recorded "Damaged" was the only one that knew: a colleague opening
the same asset saw `available`, and so did the web client. Since the first
release the app had also been posting a note on every one of those writes.
That note was the record all along — nothing read it back.

`AssetStateStore` now does, and the rules are:

- **The note is the write.** `AssetNoteVocabulary.statusNote` composes it and
  `statusIn` parses it, in one class, off one label table — so a reworded label
  cannot orphan every state ever recorded. A failed post fails the operation;
  it is not best-effort, because there is nowhere else the fact would land.
- **Reads take the newest note per asset**, one filtered `mail.message` query
  for a whole page (`OdooChatterService.latestBodies`), not one call per row.
- **A note recording a derivable state clears the overlay.** Moving an asset
  back to Available leaves nothing behind to resurrect.
- **It never contradicts a fact Odoo can prove.** An asset with `employee_id`
  set reads as `assigned` whatever the log says.
- **`local_asset_state` is now a mirror**, for offline reads and to keep a list
  from waiting on a round trip. Odoo wins on the next successful read, and
  Settings → *Clear cache* may drop it without losing anything.
- The UI marks these three (`StatusChip.isLocal`) — no longer to say "only on
  this phone", but because someone filtering by a status field in the Odoo web
  client will not find them.

It works retroactively: every status note already in the customer's database
parses, so there is no migration and nothing to backfill.

If the customer later adds a real status field, the resolver picks it up on
the next metadata refresh and the log stops being consulted — no migration, no
code change.

---

## 6b. Handover: one event, several records

Standard Odoo has no object meaning "these four things went to this person at
this moment". A handover is therefore N assignments, and the design problem is
keeping it legible as one event without inventing a model.

**One note, not two.** `HandoverRepositoryImpl` delegates each write to
`AssetRepository.assign` — which owns the field mapping, the cache
invalidation and the `changes` announcement, and re-implementing it here is how
the detail screen behind the workflow ends up reading "Available" for an asset
that just changed hands. The bundle context rides along as the assign note's
*tail* (`AssetNoteVocabulary.handoverDetail`), so each asset's chatter carries
one entry and the history screen shows one row.

**Every asset names the whole bundle.** Opening one laptop's record and finding
"and these three went with it" is the question a handover note is actually
asked, and a note that only names itself cannot answer it.

**The signature is the point.** An assignment note records that IT *says* it
handed something over; a signature records that the recipient agreed. It is
required here — a bundle without one is the per-asset assign flow, which still
exists for when the recipient is not standing there. The PNG is exported
black-on-white whatever the theme (its audience is Odoo's web client) and
attached to *every* asset in the bundle, because there is no central record to
attach it to and an attachment nobody thinks to open is not evidence.

**Partial success is a result, not an error.** Odoo can accept the first three
writes and refuse the fourth. `HandoverReceipt` names what landed and what did
not, and the screen offers to retry only the refusals — reporting the whole
thing as failed is what makes a user hand the first three assets over twice.
An attachment that fails is counted, never rolled back: the assignment is the
fact and the image is the evidence, and undoing a correct record to protect a
thumbnail is the wrong trade.

---

## 7. Error handling (spec §22)

**The classification is tested against faults recorded from the customer's
live Odoo 19.0+e**, not against invented text — `test/unit/core/error/
odoo_fault_mapping_test.dart`. That distinction found a real defect: Odoo 19
sends a constraint failure with **no exception class in the fault at all**
("The operation cannot be completed: Missing required value for the field
'Subjects'"), so the one sentence that says what to fix was reaching the user
as a generic "server problem, try again".

Two rules the presenter enforces, both covered by tests over *every*
`FailureKind`:

- **Every kind has a title, a cause and a fix, in both languages.** The switch
  is exhaustive, so adding a kind without wording is a compile error.
- **Anything Odoo names is named back.** The refused operation is an
  `OdooOperation` enum, not the raw ORM verb — it lands inside a translated
  sentence, and "unlink" there was both untranslated and jargon.

```
DioException / XmlRpcFault / FormatException
        │  caught in the transport & data layers
        ▼
AppException            typed, still technical
        │  ErrorMapper.map()
        ▼
Failure                 sanitized userMessage + optional technicalDetails
        │  Either.left
        ▼
Cubit state.failure  →  ErrorStateView renders userMessage only
```

- A raw XML-RPC stack trace **never** reaches the UI. `technicalDetails` is
  visible only in Settings → Diagnostics.
- Odoo `AccessError` is classified from the fault string and rendered as
  *"You don't have permission… contact your Odoo administrator"* (spec §21).
  ACLs are never bypassed; `check_access_rights` is used to hide actions
  ahead of time where possible.
- Odoo's own `UserError` / `ValidationError` text is already written for end
  users, so it is forwarded verbatim.

---

## 8. Security (spec §25)

| Requirement | How it is enforced |
|---|---|
| HTTPS in production | `OdooConnection.parseBaseUrl` defaults to `https://`; Android `usesCleartextTraffic="false"` |
| Certificate validation | Left at Flutter's secure default; no override exists in the codebase |
| Credentials stored securely | `CredentialVault` only — Keychain / EncryptedSharedPreferences |
| Never in SQLite/Hive | Hive boxes are opened for the cache alone; secrets have no adapter and no key there |
| Never logged | Every log line passes `LogSanitizer.scrub`; five regression tests guard it |
| Secret not held in memory | `OdooSessionManager.requireSecret()` fetches per call; it lives only in that stack frame, never in a state object |
| Cache at rest | Hive boxes are AES-encrypted with a per-install key from the keystore |
| QR safety | Payload is `asset://<id>` only — no URL, database, or token (spec §12) |

---

## 9. Caching (spec §24)

**Odoo is the source of truth.** The cache is disposable and exists to make
cold starts fast and brief network gaps survivable.

| Data | Box | TTL |
|---|---|---|
| Model/field metadata | `cache_metadata` | 12 h |
| Categories, departments | `cache_categories` | 6 h |
| Employees | `cache_employees` | 6 h |
| Asset list pages | `cache_assets` | 6 h |
| User profile | `cache_user_profile` | 6 h |
| Recorded-status mirror | `local_asset_state` | never expires; Odoo is the record (see §6) |

Read path is a **decorator**: `CachedXRepository` returns fresh cache
immediately, otherwise calls the remote repository and writes through. Every
write goes to Odoo first; the cache entry is invalidated on success.

---

## 10. Pagination (spec §20)

No unbounded query exists in the codebase. `PageRequest(offset, limit=50,
order)` plus a `search_count` for the same domain produces `PaginatedResult`,
which knows `hasMore` and merges pages for infinite scroll.

---

## 11. Theming and typography

Design tokens come from the Sijil logo: navy `#16255C`, mint `#2FE3A8`,
surface `#F5F7FB`.

- `AppColors` — the only place a `Color(0x…)` literal may appear. Includes
  darkened `…Ink` variants used for chip *text* in light mode: mint and amber
  at full saturation miss 4.5:1 on a 12% tint.
- `AppSpacing` / `AppRadii` — 4-pt scale; no raw numbers in widgets.
- Light and dark are both first-class (spec §26). In dark mode the primary
  colour becomes mint and navy becomes the surface, so the accent never sits
  on a navy ground.

### Two font families, one TextStyle

| Family | Role | File |
|---|---|---|
| **Space Grotesk** | Latin UI face | `SpaceGrotesk-Variable.ttf` |
| **IBM Plex Sans Arabic** | Arabic glyphs | four static weights |

Space Grotesk ships **zero Arabic glyphs**. Rather than branching the theme by
locale, IBM Plex Sans Arabic is registered as a per-glyph
`fontFamilyFallback`. Asset records mix scripts constantly
(`ماك بوك برو M4 · DH-LAP-0027`), and a fallback resolves per glyph — so one
`TextStyle` renders both halves correctly and no widget ever asks what the
locale is.

**Weight ceiling: 700.** The bundled Space Grotesk is a variable font with a
`wght` axis of 300–700. Asking for `w800` produces a synthesised faux-bold, so
`AppTypography.boldest` is the hard stop — use it instead of a literal weight.

Both fonts are bundled, not fetched: the app renders correctly on a first cold
launch with no connectivity.

---

## 11b. Localisation (English + Arabic, LTR + RTL)

- Strings live in `lib/l10n/app_en.arb` (template) and `app_ar.arb`.
  `flutter gen-l10n` produces `lib/l10n/generated/app_localizations.dart` as
  `AppL10n`; CI regenerates rather than trusting the checkout.
- `AppSettingsCubit` owns theme mode and locale, sits above the router, and
  persists both through `AppPreferences`. A `null` locale follows the device.
- **RTL is not implemented per widget.** Selecting Arabic sets
  `MaterialApp.locale`, and Flutter flips the whole tree. What that requires
  of feature code is only this: use `EdgeInsetsDirectional` over `EdgeInsets`,
  `start`/`end` over `left`/`right`, and mirror directional icons.
- `test/unit/l10n/arb_parity_test.dart` fails the build on a missing Arabic
  key, a mismatched placeholder, or a value left as its English source —
  because `gen-l10n` silently falls back to English otherwise, and the gap
  only surfaces to an Arabic-speaking user.

---

## 12. Testing strategy

| Level | Scope | Tooling |
|---|---|---|
| Unit — pure | Codec, domain builder, warranty, sanitizer, mappers | `flutter_test` |
| Unit — repository | Data layer against a fake `XmlRpcClient` fed recorded Odoo XML | `mocktail` |
| Cubit | State sequences per screen | `bloc_test` |
| Widget | Shared widgets, status/warranty chips, states | `flutter_test` |
| Integration | Login → list → detail → assign → return, against a demo Odoo | `integration_test` |

Currently green: 29 tests across the codec, domain builder, warranty
calculator and log sanitizer.

---

## 13. CI/CD

`.github/workflows/ci.yml` on every push and PR:

1. `dart format --set-exit-if-changed`
2. `flutter analyze --fatal-infos --fatal-warnings`
3. `flutter test --coverage`
4. Android debug APK build
5. iOS unsigned build

`.github/workflows/release.yml` on a `v*` tag: re-runs the gate, restores the
keystore from secrets, builds a signed AAB + APK, wipes the signing material,
and publishes a GitHub release.
