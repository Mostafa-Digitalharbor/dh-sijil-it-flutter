# App content — Data safety (أمان البيانات)

What to declare on the Play **Data safety** form. Play asks this again on every
update, so keep this file in step with the code.

**These answers assume crash reporting is on** — i.e. the uploaded build was
compiled with `SENTRY_DSN`. Without it the SDK is never initialised, and the
last two categories drop off. See "Crash reporting" in the README.

---

## Step 2 — Security and data collection

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** |
| What account creation methods does your app offer? | **Does not allow users to create an account** |
| Additional badges (independent security review) | skip |

"Encrypted in transit" holds on three levels: `OdooConnection.parseBaseUrl`
rejects any scheme that is not `https`, Android sets
`usesCleartextTraffic="false"`, and iOS ships no ATS exception.

The app has no sign-up. Accounts are created in Odoo by an administrator; the
app only signs in with one that already exists.

---

## Step 3 — Data types

Tick exactly these, and nothing else:

| Category | Tick |
|---|---|
| Location | — |
| **Personal info** | User IDs · Email address |
| Financial info | — |
| Health and fitness | — |
| Messages | — |
| **Photos and videos** | Photos |
| Audio files | — |
| Files and docs | — |
| Calendar | — |
| Contacts | — |
| **App activity** | Other user-generated content |
| Web browsing | — |
| **App info and performance** | Crash logs · Diagnostics |
| **Device or other IDs** | Device or other IDs |

Seven boxes with crash reporting on; four without it (drop the last two rows).

### Why each one

- **User IDs, Email address** — the login is sent to the Odoo server. The
  username field hints `you@company.com`, and Odoo uses the email as the login
  by default. Play has no data type for a password.
- **Photos** — asset condition photos, uploaded to Odoo as an attachment.
- **Other user-generated content** — handover signatures, asset notes and
  maintenance fault descriptions.
- **Crash logs, Diagnostics, Device or other IDs** — Sentry. Screenshots, view
  hierarchies, request bodies and tap breadcrumbs are all off and every event is
  scrubbed, but a crash report still carries a stack trace, device model, OS
  version and the SDK's installation id.

### Deliberately not ticked

- **Audio files** — voice search hands the audio to the operating system's own
  speech recogniser and receives text back. No SDK in the app collects audio.
- **Files and docs** — PDF/CSV export writes to a temp directory and hands the
  file to the system share sheet. Nothing leaves the device unless the user
  sends it.
- **Contacts** — the Email and Call buttons open the mail app or dialler with
  the address prefilled. The address book is never read.
- **Location** — the app declares no location permission at all.

Employee names, emails and phone numbers shown in the app are **not** collection:
they travel from the customer's server to the device. Play defines collection as
data leaving the device.

---

## Keep this consistent

`docs/PRIVACY_POLICY.md` lists the same set. Play compares the two, so a change
in one has to land in the other.

---

## Step 4 — Data usage and handling

Nothing is shared. Play does not count a transfer to a service provider acting
for the developer, and the Odoo instance is the user's own organisation's
backend, not a third party they are being handed to.

Nothing is processed ephemerally either: the login is kept in the device
keystore, and everything else is written to Odoo or to Sentry.

| Data type | Collected | Shared | Ephemeral | Required / optional | Purposes |
|---|---|---|---|---|---|
| User IDs | Yes | No | No | **Required** | App functionality · Account management |
| Email address | Yes | No | No | **Required** | App functionality · Account management |
| Photos | Yes | No | No | **Optional** | App functionality |
| Other user-generated content | Yes | No | No | **Optional** | App functionality |
| Crash logs | Yes | No | No | **Required** | App functionality · Analytics |
| Diagnostics | Yes | No | No | **Required** | App functionality · Analytics |
| Device or other IDs | Yes | No | No | **Required** | Analytics |

### Where required / optional comes from

- **Login** is required: there is no guest mode, and no screen works before the
  connection and sign-in flow completes.
- **Photos and user-generated content** are optional: a user can search, browse
  assets and read maintenance requests without ever attaching a photo or
  signing a handover. The signature is mandatory *inside* the handover flow
  (`handoverSignatureRequired` blocks it), but that flow is one feature among
  several, and the notes and fault descriptions in the same category are free
  text nobody has to fill in.
- **Crash reporting** is required, in Play's sense of "users can't turn this
  off": the settings screen offers theme and language only, and there is no
  telemetry preference key. Whether it runs at all is fixed when the binary is
  built, not by the person holding the phone.

### If asked about deletion

Answer **yes**, users can request deletion. The local copy goes with sign-out or
uninstall; the business records live in the customer's Odoo and are deleted by
that organisation's administrator. The privacy policy says so and gives a
contact address. The separate *account deletion* requirement does not apply —
the app cannot create accounts.
