# Sijil IT

Standalone Flutter app for IT asset management, integrated directly with
**Odoo over XML-RPC**.

No custom Odoo addon. No middleware. No Digital Harbor backend. Point it at a
stock Odoo instance with a URL, a database, a username and a password or API
key, and it works.

- **Odoo 17, 18, 19** — compatibility is detected at runtime, not assumed
- **Android & iOS**, phone and tablet layouts
- **Clean Architecture + MVVM**, Cubit for state, `get_it` for DI
- **English and Arabic**, full RTL, light and dark
- Standard models only: `maintenance.equipment`, `hr.employee`,
  `maintenance.request`, `stock.lot`, `product.product`

---

## Getting started

```bash
flutter --version        # 3.35.3 or newer
flutter pub get
flutter gen-l10n         # regenerates AppL10n from lib/l10n/*.arb
flutter run
```

On first launch the app asks for your Odoo connection:

| Field | Example |
|---|---|
| Server URL | `https://company.odoo.com` |
| Database | `company-production` |
| Username | `admin@company.com` |
| Password / API key | `••••••••` |

An **API key** is recommended over a password. In Odoo: *Preferences →
Account Security → New API Key*.

---

## Quality gate

The same three commands CI runs — run them before every push:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos --fatal-warnings
flutter test
```

## Adding a string

Add the key to `lib/l10n/app_en.arb` **and** `lib/l10n/app_ar.arb`, then run
`flutter gen-l10n`. The ARB parity test fails the build if the Arabic side is
missing, mismatched, or still in English.

---

## Project layout

```
lib/
├── app/         composition root: DI, router, theme, observers
├── core/        XML-RPC + Odoo services, storage, security, errors
├── shared/      cross-feature widgets and the base ViewState
└── features/    connection · auth · dashboard · assets · assignment
                 employees · maintenance · scanner · settings
```

Each feature follows `data/` → `domain/` → `presentation/`, with
dependencies pointing inward only.

Full detail: **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**
Roadmap: **[docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md)**

---

## Which Odoo apps unlock which features

The app probes `ir.model` at login and adapts. Nothing is required.

| Odoo app installed | Unlocks |
|---|---|
| *(none)* | Connection, login, settings |
| **Maintenance** | Assets (full CRUD), warranty, categories |
| **Maintenance** + **Employees** | Assignment, return, employee directory |
| **Maintenance** (requests) | Maintenance list, history, create request |
| **Inventory** | Fallback asset source via `stock.lot` |

Features whose backing model is missing are hidden, never broken.

---

## Security

- Credentials live in the iOS Keychain / Android EncryptedSharedPreferences
  via `flutter_secure_storage` — never in Hive, never in SharedPreferences,
  never in an app state object.
- Every log line passes through `LogSanitizer`; passwords, API keys, tokens
  and basic-auth URLs are redacted, with tests to prove it.
- The local cache is encrypted at rest by the platform — iOS Data Protection
  on every file in the container, Android file-based encryption plus
  `allowBackup="false"` so the boxes cannot be pulled off with `adb backup`.
  The app ships no cipher of its own, which is what keeps it exempt from US
  export-compliance filing; see the note in `hive_cache_store.dart` before
  adding one.
- HTTPS is the default and cleartext traffic is disabled on Android.
  Certificate validation is never disabled.
- Odoo ACLs are always respected — the app never works around a permission
  error, it explains it.
- QR codes carry `asset://<id>` and nothing else.

---

## CI/CD

| Workflow | Trigger | Does |
|---|---|---|
| `ci.yml` | push, PR | format · analyze · test + coverage · Android debug APK · iOS unsigned build |
| `release.yml` | `v*` tag | re-runs the gate · signed AAB + APK · GitHub release |

Release signing needs four repository secrets:
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.

### Crash reporting

`CrashReporter` reads its DSN from `String.fromEnvironment('SENTRY_DSN')`, so a
build that is not given one never initialises the SDK — not initialised and
silent, but absent. That is deliberate: it makes "this build reports nowhere" a
property of the binary rather than a setting someone could flip.

CI takes it from the `SENTRY_DSN` repository secret. Locally, put it in `.env`
(git-ignored) and pass the file:

    SENTRY_DSN=https://<key>@<org>.ingest.<region>.sentry.io/<project>
    SENTRY_ENVIRONMENT=production

    flutter build appbundle --release --dart-define-from-file=.env

Leave the file off and the same build reports nothing, which is the shape a
customer who does not want telemetry should get.

Whether the DSN is compiled in changes the **Data safety** declaration on the
Play listing: a build with one collects crash logs, diagnostics and a device
identifier, and all three have to be declared. See `store-assets/DATA-SAFETY.md`.

---

## Status

Phase 0 (foundation) is complete: architecture, XML-RPC layer, capability
detection, security, caching, theming, bundled fonts, English/Arabic with RTL,
routing, CI/CD and 33 passing tests.
Feature phases are tracked in
[docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md).
