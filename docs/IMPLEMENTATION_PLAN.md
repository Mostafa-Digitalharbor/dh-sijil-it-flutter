# Sijil IT — Implementation Plan

Twelve phases. Each one is independently shippable, ends with a working app,
and maps to specific acceptance criteria from the brief.

**Legend** — ✅ done · 🔨 next · ⬜ not started

> **Status.** Phases 0–10 are built and green against a live Odoo 19 Enterprise
> instance: 329 tests, analyzer clean, every screen implemented. What remains is
> Phase 11 (release hardening: signing, store tracks, the ACL and version
> matrices) and Phase 12 (the two Odoo docs). See
> `docs/ODOO_COMPATIBILITY.md` for the version differences found in the field.

---

## Phase 0 — Foundation ✅

Already in the repository.

| Delivered | Files |
|---|---|
| Clean Architecture + MVVM folder tree | `lib/{app,core,shared,features}` |
| XML-RPC codec (encode/decode/faults) | `core/network/xmlrpc/xml_rpc_codec.dart` |
| Transport client, Odoo-agnostic | `core/network/xmlrpc/xml_rpc_client.dart` |
| `execute_kw` facade — all 9 required ops | `core/network/odoo/odoo_object_service.dart` |
| Capability service (`modelExists`/`fieldExists`/`getFields`) | `core/network/odoo/odoo_capability_service.dart` |
| Domain builder | `core/network/odoo/odoo_domain_builder.dart` |
| Session manager | `core/network/odoo/odoo_session_manager.dart` |
| Credential vault + log sanitizer | `core/security/` |
| Encrypted Hive cache | `core/storage/cache/` |
| Error hierarchy + mapper | `core/error/` |
| Pagination primitives | `core/pagination/` |
| Theme, DI, router, 5-tab shell | `app/` |
| Bundled fonts: Space Grotesk + IBM Plex Sans Arabic | `assets/fonts/` |
| English + Arabic strings, RTL, theme/locale Cubit | `lib/l10n/`, `features/settings/` |
| All 17 screens routed as stubs | `features/*/presentation/pages/` |
| CI/CD pipelines | `.github/workflows/` |
| 33 unit tests, analyzer clean | `test/unit/` |

**Verify:** `flutter analyze --fatal-infos --fatal-warnings && flutter test`

---

## Phase 1 — Test harness for Odoo ✅

Before writing feature code, make Odoo testable without a server.

- `test/fixtures/` — recorded XML-RPC responses from a real Odoo 18
  (`common.version`, `authenticate`, `fields_get`, `search_read`, an
  `AccessError` fault).
- `FakeXmlRpcClient` that replays fixtures by method + model.
- Test helper that builds a signed-in `OdooSessionManager`.

**Why first:** every later phase gets fast, offline, deterministic tests, and
the recorded faults let error handling be built against real Odoo output
rather than guesses.

**Done when:** a repository test runs green with no network.

---

## Phase 2 — Connection & authentication ✅
*Spec §§3, 21, 25 · Acceptance criteria 1, 2, 3, 12*

Screens: Splash, Odoo Connection, Login.

| Layer | Work |
|---|---|
| domain | `TestConnection`, `SignIn`, `SignOut`, `RestoreSession` use cases |
| data | `ConnectionRepositoryImpl`, `AuthRepositoryImpl` |
| presentation | `ConnectionCubit`, `AuthCubit` + real Connection/Login UI |

Details:
- URL normalisation (`company.odoo.com` → `https://company.odoo.com`).
- **Test Connection** calls `common.version` — cheapest unauthenticated probe.
- Optional `db.list`; when the server refuses it (the common production
  setting), fall back to a free-text database field without an error.
- Password vs API-key toggle; secret goes only to `CredentialVault`.
- On success: probe capabilities, cache the profile, route to Dashboard.

**Done when:** a real Odoo instance can be connected to and signed into with
only URL + database + username + password/API key, credentials survive a
restart, and a wrong password shows a friendly message.

---

## Phase 3 — Reference data & the capability gate ✅
*Spec §§10, 17, 24, 28*

- `CategoryRepository` — categories from `maintenance.equipment.category` (or
  `product.category`), never hardcoded IDs.
- `DepartmentRepository`, `EmployeeRepository` from `hr.*`.
- `CapabilityCubit` exposing `OdooCapabilities` app-wide; the More tab hides
  Maintenance when the app is absent.
- Cache-write-through decorators for all three.

**Done when:** the app runs against an Odoo with **no** Maintenance and **no**
HR installed and shows a coherent, reduced UI instead of an error.

---

## Phase 4 — Assets: list, detail, CRUD ✅
*Spec §§5, 11, 14, 17, 20, 21 · Acceptance criteria 4, 8, 11, 13*

The largest phase. Screens: Asset List, Asset Details, Create, Edit.

| Layer | Work |
|---|---|
| domain | `Asset` ✅, `AssetQuery`, `AssetRepository`, `GetAssetsPage`, `GetAsset`, `CreateAsset`, `UpdateAsset`, `DeleteAsset` |
| data | `AssetSourceStrategy` + `MaintenanceEquipmentDataSource`; `AssetMapper`; `AssetStatusResolver`; `CachedAssetRepository` decorator |
| presentation | `AssetListCubit` (search + filters + infinite scroll), `AssetDetailCubit`, `AssetFormCubit` |

Details:
- Search across name / tag / serial / model / manufacturer via
  `OdooDomainBuilder.searchAcross`, debounced 350 ms.
- Filters: status, category, employee, department, manufacturer, warranty.
- Read sets intersected through `supportedFields` before every query.
- Detail screen sections exactly as §14.
- Create/Edit form renders only fields the instance exposes; `check_access_rights`
  hides Edit/Delete the user cannot perform.

**Done when:** 500+ assets scroll smoothly at 50/page, search and every filter
work, and an ACL-restricted user sees a clear permission message rather than
a crash.

---

## Phase 5 — Dashboard ✅
*Spec §4*

- `GetDashboardSummary` — parallel `search_count` per status (counts, not
  record fetches), `read_group` for the category breakdown.
- Recent activity from `mail.message` when available, else the most recently
  written assets.
- KPI cards, category bars (`fl_chart`), activity feed, pull-to-refresh,
  skeletons.

**Done when:** the dashboard loads in a handful of counted queries rather than
by downloading the asset table.

---

## Phase 6 — QR & barcode ✅
*Spec §§12, 13 · Acceptance criterion 7*

- `AssetQrPage` — `qr_flutter`, payload `asset://<id>` only, printable/shareable.
- `ScannerPage` — `mobile_scanner`, camera permission flow with a clear denial
  state, torch and pause-on-detect.
- `ResolveScannedCode` use case: `asset://<id>` → open detail; anything else →
  treat as serial/barcode and `search_read` on `serial_no`; no match → a
  helpful empty state offering to create the asset.

**Done when:** scanning a printed asset QR opens its detail screen, and
scanning an unknown barcode fails gracefully.

---

## Phase 7 — Assignment & return ✅
*Spec §§7, 8 · Acceptance criterion 6*

- `AssignAsset` — employee picker via `name_search` (typeahead, no hardcoded
  IDs), assignment date, notes → writes `employee_id` + `assign_date`, posts a
  chatter note.
- `ReturnAsset` — return date, condition (Good / Minor Damage / Damaged /
  Needs Maintenance), notes, optional photos as `ir.attachment` → clears the
  assignment and applies `ReturnCondition.resultingStatus`.
- Damaged / Needs Maintenance offers to open a `maintenance.request` when the
  Maintenance app is present.

**Done when:** an asset can be assigned and returned end-to-end and the change
is visible in the Odoo web client.

---

## Phase 8 — Employees ✅
*Spec §9 · Acceptance criterion 5*

Screens: Employee List, Employee Details, Employee Assets.

- Directory with search and department filter, paginated.
- Profile: name, department, job position, work email, avatar.
- Assets held by the employee, tapping through to asset detail.

---

## Phase 9 — Maintenance ✅
*Spec §16 · Acceptance criterion 10*

Only reachable when `maintenance.request` exists.

- List with stage/type/priority filters; detail with history.
- Create a request from an asset.
- Maintenance section on the asset detail screen (previous / current / next).

**Done when:** removing the Maintenance app from the test instance hides the
feature cleanly with zero errors in the log.

---

## Phase 10 — Settings, warranty views & polish ✅
*Spec §§15, 22, 23, 26*

- Settings: connection info, signed-in user, database, app version, Test
  Connection, Clear cache, Refresh Odoo metadata, theme switch, Sign out.
- Diagnostics screen — sanitized recent failures only.
- Warranty filter set (Expired / ≤30 d / ≤90 d / Valid) and a dashboard
  attention card.
- UX pass: skeletons everywhere, empty states, error states,
  pull-to-refresh, tablet two-pane on the list screens, dark mode audit.

---

## Phase 11 — Hardening & release ⬜
*Acceptance criteria 9, 14, 15*

- ACL matrix test: read-only user, no-create user, no-delete user.
- Version matrix: Odoo 17, 18, 19 — with and without HR and Maintenance.
- Offline behaviour, session expiry, timeout, wrong URL, wrong DB.
- App icons and splash from the Sijil brand assets.
- Android signing secrets in GitHub; iOS certificates and `flutter build ipa`.
- Play Console internal track; TestFlight.

---

## Phase 12 — Documentation & handover ⬜

- `README.md` — setup, configuration, build, release.
- `docs/ARCHITECTURE.md` ✅
- `docs/ODOO_XMLRPC.md` — every call the app makes, with request/response
  samples and the required Odoo access rights.
- `docs/ODOO_SETUP.md` — what a customer's admin needs to do (create an API
  key, which apps unlock which features).

---

## Dependency order

```
Phase 0 ✅
   │
   ▼
Phase 1  (test harness)
   │
   ▼
Phase 2  (connection + auth)  ← everything below needs a session
   │
   ▼
Phase 3  (reference data + capabilities)
   │
   ▼
Phase 4  (assets)  ← the spine of the product
   │
   ├──► Phase 5  (dashboard)
   ├──► Phase 6  (QR / barcode)
   ├──► Phase 7  (assign / return)   ← needs Phase 3 employees
   ├──► Phase 8  (employees)
   └──► Phase 9  (maintenance)
             │
             ▼
        Phase 10 (settings + polish)
             │
             ▼
        Phase 11 (hardening + release)
             │
             ▼
        Phase 12 (docs)
```

Phases 5, 6, 8 and 9 are independent of one another once Phase 4 lands and can
run in parallel across developers.

---

## Deliverables checklist (spec §30)

| Deliverable | Phase |
|---|---|
| Complete Flutter source code | 0–12 |
| Android build | 0 (debug) · 11 (signed) |
| iOS-compatible project | 0 (unsigned) · 11 (signed) |
| Odoo XML-RPC service | 0 ✅ |
| Secure authentication | 2 |
| Asset dashboard | 5 |
| Asset CRUD | 4 |
| Employee integration | 3, 8 |
| Assignment workflow | 7 |
| Return workflow | 7 |
| QR generation | 6 |
| QR scanning | 6 |
| Search and filtering | 4 |
| Warranty handling | 4 (calc ✅), 10 (views) |
| Maintenance integration when available | 9 |
| Dynamic model/field detection | 0 ✅ |
| Pagination | 0 ✅ (primitives), 4 (applied) |
| Local caching | 0 ✅ (engine), 3–4 (applied) |
| Proper permission handling | 4, 11 |
| Error handling | 0 ✅ |
| Dark/light theme | 0 ✅ |
| Arabic + English with RTL | 0 ✅ |
| README | 12 |
| Architecture documentation | 0 ✅ |
| XML-RPC integration documentation | 12 |
