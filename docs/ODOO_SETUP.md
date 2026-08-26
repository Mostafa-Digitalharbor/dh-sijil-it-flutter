# Odoo setup for Sijil IT

What an Odoo administrator needs to do before their team can use the app.

**Sijil IT installs nothing on your Odoo.** No addon, no custom module, no
new field. It signs in as an ordinary Odoo user over the standard XML-RPC API
and reads and writes the models you already have. Everything below is
configuration in the Odoo interface — there is no server-side deployment step
and nothing to redeploy when the app updates.

Two consequences worth stating up front, because they answer the two questions
administrators actually ask:

- **Your permissions are the app's permissions.** Sijil IT cannot show or
  change anything the signed-in Odoo user could not show or change in the web
  client. There is no service account, no elevated path, no bypass.
- **Removing the app changes nothing.** Every record it writes is a normal
  Odoo record. Uninstall the phone app and your data is exactly where it was,
  readable in the web client.

---

## 1. What to install

| Odoo app | Required? | What you lose without it |
|---|---|---|
| **Maintenance** | **Yes** | Everything. This is where assets live. |
| **Employees** (HR) | Strongly recommended | Assignment, the Employees tab, handover. The asset register still works. |
| **Discuss** (`mail`) | Yes — installed by default | History, and the Reserved / Damaged / Lost statuses. |

Install from **Apps** in Odoo. Search "Maintenance", then "Employees".

### Supported versions

Odoo **17, 18 and 19**, Community or Enterprise, on-premise or Odoo Online
(`*.odoo.com`).

The app does not check your version number to decide what to do. It asks the
server which models and fields exist and adapts to the answer, so a customised
instance — a removed field, an extra one, a renamed stage — works without a
build change on our side. Version differences that *cannot* be probed are
handled explicitly and documented in
[ODOO_COMPATIBILITY.md](ODOO_COMPATIBILITY.md).

---

## 2. Create an API key (recommended over a password)

An API key is a credential that works only for the API. It cannot be used to
log into the Odoo web interface, it is revocable on its own without changing
anyone's password, and it is not affected by two-factor authentication.

**If your Odoo has 2FA enabled, an API key is not optional — a password will
not authenticate over XML-RPC.**

Each user creates their own:

1. Click your avatar (top right) → **My Profile** (or **Preferences**).
2. Open the **Account Security** tab.
3. Click **New API Key**.
4. Give it a name — `Sijil IT — Mostafa's phone` is a better name than
   `key1`, because the point of naming it is knowing which one to revoke when
   a phone is lost.
5. Copy the key **immediately**. Odoo shows it once and never again.

To revoke: same tab, delete the key. The phone is signed out on its next call.

> As an administrator you can also create keys for other users via
> **Settings → Users & Companies → Users → (user) → Account Security**.

---

## 3. Permissions

### The short version

Give the user the **Maintenance / User** group. Add **Employees / Officer** (or
any group with read access to `hr.employee`) if they need to assign equipment
to people.

That is the whole answer for a normal IT technician. The rest of this section
is for the cases where it is not.

### What each right actually unlocks

Everything the app touches is in this table. Withhold a right and the app hides
the corresponding action rather than letting the user press a button that can
only fail.

| Model | Right | What it enables | What the user sees without it |
|---|---|---|---|
| `maintenance.equipment` | read | the asset list, detail, dashboard, scanning | a "you are not allowed" screen naming the model |
| | create | the **+** button | no **+** button |
| | write | Edit, Assign, Return, status changes | no Edit, no Assign, no Return |
| | unlink | Delete | no Delete entry in the menu |
| `hr.employee` | read | Employees tab, assignment, handover picker | those screens are hidden; assets still work |
| `maintenance.request` | read | the Maintenance tile | the tile is not shown |
| | create | "Report issue" on an asset | the button is absent |
| `mail.message` | read | asset history | the History screen is hidden |
| `ir.attachment` | read | viewing photos and signatures | photo strips are empty |
| | create | attaching a return photo or signature | the camera button is hidden |

`ir.model`, `res.users` and `ir.model.fields` are also read, to discover what
the instance supports. Every internal Odoo user can already read these.

### A read-only auditor

Someone who should see everything and change nothing:

1. Give them **Maintenance / User**.
2. **Settings → Technical → Security → Access Rights**, find the
   `maintenance.equipment` rule for that group, and clear **Write**, **Create**
   and **Delete**.

The app reads this configuration through `check_access_rights` and removes
every action they cannot perform — the create button, the edit button, the
delete entry, and the Assign and Return buttons. Verified by
[acl_matrix_test.dart](../test/matrix/acl_matrix_test.dart), which runs this
exact configuration on every build.

### Record rules and multi-company

Record rules are honoured because the app never bypasses them: every call runs
as the signed-in user. A rule limiting a technician to their own company's
equipment limits the app the same way, with no configuration on our side.

One thing a record rule can do that a group cannot: refuse **one record** while
allowing the model in general. The app cannot predict that in advance, so it
shows the action and, if Odoo refuses, explains the refusal in words instead of
showing a Python traceback.

---

## 4. What the user enters on their phone

Three fields, once, on first launch:

| Field | Example | Notes |
|---|---|---|
| **Server URL** | `https://company.odoo.com` | `company.odoo.com` works too — the app adds `https://`. |
| **Database** | `company-production` | Case-sensitive. See below. |
| **Username** | `you@company.com` | The Odoo login, usually an email. |

Then a password or API key on the sign-in screen.

### The database name

This is the field that generates support tickets, so it is worth pre-empting.

- On **Odoo Online**, the database name is usually the subdomain — for
  `company.odoo.com` it is typically `company`.
- On **on-premise**, it is whatever it was named at creation.
- It is **case-sensitive**.

The app offers a **Detect databases** button, which calls Odoo's `db.list`.
Most production servers disable that call, and that is a correct and common
configuration rather than a fault — the app simply falls back to a free-text
field with no error. So have the exact name ready for your users; do not rely
on detection.

### Test Connection

The connection screen has a **Test Connection** button that runs before any
credentials are entered. It confirms the URL is reachable and is genuinely an
Odoo server, and reports the version it found. Have your users press it first —
it separates "wrong address" from "wrong password", which are otherwise
indistinguishable from the sign-in screen.

---

## 5. Security notes for your review

Worth knowing before you approve the app for your organisation.

**Credentials.** The password or API key is written to the OS keychain — iOS
Keychain, Android Keystore-backed encrypted storage. Never to preferences,
never to the cache, never to a log line. Two things enforce the last one on
every build: every log line goes through the
[log sanitizer](../lib/core/security/log_sanitizer.dart), whose redaction rules
are unit-tested against passwords, API keys and basic-auth URLs; and a
conventions test fails the build if any file in `lib` calls `print` or
`debugPrint` directly, which is the one way a secret could route around the
sanitizer.

**Transport.** Whatever your server uses. Use HTTPS. The app will connect over
plain HTTP if you point it at one, because on-premise instances behind a VPN
sometimes are — that is your decision to make, not ours to block, but it is a
decision.

**On-device cache.** The asset list and reference data are cached in an
encrypted Hive box so the app opens instantly and survives a dead spot in a
server room. Signing out clears it.

**Telemetry.** No analytics, no usage tracking, no advertising SDK. There is
one optional outbound destination and it is worth being precise about:

*Crash reporting.* Builds **may** be compiled with a Sentry DSN, in which case
an unhandled crash sends a report to Sentry. Whether your build has one is
visible in **More → Settings → Diagnostics**. What that report contains is
constrained deliberately:

| Sent | Not sent |
|---|---|
| exception type, message and stack trace | your Odoo password or API key |
| the app version, OS version, device model | the signed-in user's name, login or email |
| the URL *path* that failed (e.g. `/xmlrpc/2/object`) | request bodies, headers, cookies, query strings |
| breadcrumbs of app navigation | screenshots or view hierarchies |

Every field leaving the device passes through the same sanitizer the logs use,
and the `user` block is cleared outright. This is enforced by
[crash_reporter_test.dart](../test/unit/core/observability/crash_reporter_test.dart),
which asserts on the *outgoing* event rather than on the sanitizer, so a future
SDK upgrade that starts attaching something new fails the build.

**If you want no third-party traffic at all**, ask for a build with no DSN
compiled in. The SDK is then never initialised — not initialised-and-quiet —
and the app talks to your Odoo and to nothing else.

**What it writes.** Field updates on `maintenance.equipment` and
`maintenance.request`, log notes on the chatter, and attachments. All standard
records, all attributed to the signed-in user, all visible in the web client
and in Odoo's own audit trail.

---

## 6. The three statuses that are not Odoo fields

**Reserved**, **Damaged** and **Lost** have no field in standard Odoo, and
Sijil IT is not allowed to add one (that would mean shipping an addon, which
the whole design avoids).

They are recorded as **log notes on the asset's chatter**, and read back from
there. Practical consequences you should know:

- ✅ The status is **shared** — every phone and the web client see the same
  value, because it lives on the server.
- ✅ It is **visible in Odoo**, as a note in the record's message history.
- ✅ It works on **existing data** — every note the app has ever written parses
  — so there is nothing to migrate.
- ⚠️ You **cannot filter or group by it** in the Odoo web client, because it is
  not a field. Inside Sijil IT you can.
- ⚠️ It needs `mail.message`. On an instance without Discuss, those three
  statuses are unavailable; Available, Assigned, Under maintenance and Retired
  still work, because those come from real fields.

If you would rather have a real field with real filters, that is a small custom
module on your side (`x_sijil_status`, a selection field). The app prefers a
native field when it finds one and falls back to the chatter when it does not —
so adding it later needs no change to the app.

---

## 7. Checklist

Before handing the app to your team:

- [ ] **Maintenance** app installed
- [ ] **Employees** app installed, if you want assignment
- [ ] Each user has an API key, or you have confirmed password auth works
      (it will not if 2FA is on)
- [ ] Users are in **Maintenance / User**
- [ ] Users who assign equipment can read `hr.employee`
- [ ] You have the exact **database name** written down
- [ ] The server URL is reachable from the phones — check mobile data, not just
      office Wi-Fi, if the instance is on-premise
- [ ] **Test Connection** passes from one phone before you roll out to twenty

---

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| "That doesn't look like an Odoo server" | wrong URL, or a proxy or login page is answering | check the URL in a browser; it should show Odoo |
| "Database not found" | wrong name, or wrong case | names are case-sensitive; confirm the exact string |
| "Wrong username, password or API key" | bad credentials — **or 2FA is on and a password was used** | issue an API key (§2) |
| Employee picker is always empty | no read access on `hr.employee` | add **Employees / Officer** or an equivalent group |
| No Maintenance tile | `maintenance.request` missing or unreadable | install the Maintenance app |
| Buttons missing that should be there | the ACLs say the user may not | §3, then check record rules |
| "You are not allowed to write assets" on one record only | a **record rule**, not a group | §3, "Record rules and multi-company" |

For the exact calls behind any of these — request, response and the right
required — see [ODOO_XMLRPC.md](ODOO_XMLRPC.md).
