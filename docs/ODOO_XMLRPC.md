# Odoo XML-RPC reference

Every call Sijil IT makes to Odoo, with the request it sends, the response it
expects, and the access right the calling user needs.

This is a reference for two readers who want opposite things:

- **A developer** debugging a screen that shows the wrong thing, who needs to
  know exactly what went on the wire.
- **An Odoo administrator** deciding which groups to grant, who needs to know
  what breaks if they withhold one.

The second reader is why every section ends with a *required rights* line and
a *what the user sees without it* line. A permissions document that only lists
rights makes the administrator guess at the consequence, and administrators
who guess grant everything.

For the *setup* side — creating an API key, which apps to install — see
[ODOO_SETUP.md](ODOO_SETUP.md). For version differences the app had to work
around, see [ODOO_COMPATIBILITY.md](ODOO_COMPATIBILITY.md).

---

## 1. Transport

Three endpoints, all XML-RPC over HTTP(S):

| Endpoint | Purpose | Authenticated |
|---|---|---|
| `/xmlrpc/2/common` | version probe, sign-in | no |
| `/xmlrpc/2/db` | database listing | no |
| `/xmlrpc/2/object` | everything else, via `execute_kw` | yes |

The client lives in [xml_rpc_client.dart](../lib/core/network/xmlrpc/xml_rpc_client.dart);
the codec that encodes and decodes the wire format is
[xml_rpc_codec.dart](../lib/core/network/xmlrpc/xml_rpc_codec.dart). Nothing
above the `core/network` layer builds a payload by hand.

### The shape of every authenticated call

`execute_kw` takes **seven positional parameters**, in this order. Odoo rejects
a keyword-style call outright, which is worth knowing before debugging a
`TypeError` that looks like it came from the model:

```
execute_kw(
  db,          # string   — database name
  uid,         # int      — from authenticate, not the login
  secret,      # string   — password or API key
  model,       # string   — e.g. "maintenance.equipment"
  method,      # string   — e.g. "search_read"
  args,        # array    — positional args for the method
  kwargs,      # struct   — keyword args: fields, limit, offset, order, context
)
```

Built once, in
[`OdooObjectService.executeKw`](../lib/core/network/odoo/odoo_object_service.dart).

### Context

The app sends an explicit `context` when it has one to send, rather than
letting Odoo fall back to the server default. Without it, dates come back in
the *server's* timezone rather than the user's, which is how an assignment made
at 9 pm Cairo time shows up dated the next day.

---

## 2. Connection & authentication

### 2.1 `common.version` — the connection probe

The cheapest call that proves a URL is an Odoo server, and it needs no
credentials. This is what the **Test Connection** button on the connection
screen sends.

```xml
<methodCall>
  <methodName>version</methodName>
  <params/>
</methodCall>
```

Response (Odoo 19):

```json
{
  "server_version": "19.0",
  "server_version_info": [19, 0, 0, "final", 0, ""],
  "server_serie": "19.0",
  "protocol_version": 1
}
```

The app **records** this and does not branch on it. Feature decisions come from
probing `ir.model`, never from the version number — see §5 below and
[ARCHITECTURE.md](ARCHITECTURE.md) §5.

> **Required rights:** none.
> **Without it:** the URL is not an Odoo server, or a proxy is answering. The
> app says so plainly rather than reporting a login failure.

### 2.2 `db.list` — optional

```
db.list()  →  ["company-production", "company-staging"]
```

Most production instances disable this, and that is a correct configuration
rather than a fault. When the server refuses, the app falls back to a free-text
database field with no error shown. Never treat a refusal here as a failed
connection.

### 2.3 `common.authenticate` — sign-in

```
authenticate(db, login, secret, {})  →  uid  (int)   on success
                                     →  false        on bad credentials
```

Odoo returns `false` rather than raising, so `false` must be handled as data.
Treating "no fault" as "signed in" is how an app lets a wrong password through
to the first `execute_kw`, where it surfaces as an incomprehensible
`AccessDenied`.

The `uid` is what every later call carries. The secret goes to the OS keychain
([`CredentialVault`](../lib/core/security/credential_vault.dart)) and never to
shared preferences, the cache, or any log line.

> **Required rights:** an active user record.
> **Without it:** "Wrong username, password or API key."

### 2.4 `res.users.read` — who is signed in

```
execute_kw(db, uid, secret, "res.users", "read",
           [[uid]],
           {"fields": ["id","name","login","email","company_id","partner_id","lang","tz"]})
```

Used for the greeting header and the account block in Settings.

> **Required rights:** `read` on `res.users` — every internal user has this on
> their own record.

---

## 3. Capability probing

Before any feature screen loads, the app asks Odoo what it can support. This is
what lets one build serve an instance with Maintenance and HR, an instance with
Maintenance only, and an instance with neither.

### 3.1 `ir.model.search_read` — which models exist

```
execute_kw(db, uid, secret, "ir.model", "search_read",
           [[["model", "in", ["maintenance.equipment", "maintenance.request",
                              "hr.employee", "hr.department",
                              "product.product", "stock.lot",
                              "mail.message"]]]],
           {"fields": ["model"]})
```

The answer decides:

| Present | Consequence |
|---|---|
| `maintenance.equipment` | assets are backed by Maintenance (the preferred source) |
| `maintenance.request` | the Maintenance tile and the "Report issue" action appear |
| `hr.employee` | assignment, the Employees tab and the handover recipient picker work |
| `mail.message` | history, chatter notes and the three overlay statuses work |
| none of the asset models | the app says the instance cannot host assets, and says which app to install |

Implemented in
[odoo_capability_service.dart](../lib/core/network/odoo/odoo_capability_service.dart).

> **Required rights:** `read` on `ir.model`. Granted to every internal user by
> default.
> **Without it:** the app cannot tell a missing app from a missing right, so it
> degrades to its most conservative shape — assets only.

### 3.2 `fields_get` — which fields exist on this instance

```
execute_kw(db, uid, secret, "maintenance.equipment", "fields_get",
           [],
           {"attributes": ["string", "type", "required", "readonly", "selection"]})
```

Two things depend on this:

- **Optional fields.** A customer who removed `warranty_date` gets a detail
  screen without a warranty block, not a crash.
- **Required fields.** Odoo really does mark
  `maintenance.equipment.effective_date` mandatory, and really does reject a
  `create` that sends `false` for it, because that overrides the default the
  constraint relies on. The form reads the requirement rather than hardcoding a
  list that goes stale.

> **Required rights:** `read` on the model.

### 3.3 `check_access_rights` — what this user may do

```
execute_kw(db, uid, secret, "maintenance.equipment", "check_access_rights",
           ["create"],
           {"raise_exception": false})
   →  true | false
```

Called once per operation (`create`, `write`, `unlink`) when the asset list or
detail screen loads. The result hides the create FAB, the Edit button, the
Delete menu entry and the Assign/Return actions rather than letting them fail.

Two deliberate behaviours:

- **A failure here is treated as "yes".** The method was renamed
  `check_access` in newer Odoo; an error means "unknown", and the app lets the
  real operation surface the real ACL message rather than hiding a button the
  user may in fact be allowed to press.
- **Record rules are not covered.** `check_access_rights` answers about the
  *model*; a row-level rule can still refuse one particular record. That
  refusal is caught and shown as a permissions message — never as a traceback.
  Both paths are covered by
  [acl_matrix_test.dart](../test/matrix/acl_matrix_test.dart).

---

## 4. Assets — `maintenance.equipment`

The field set the app reads, in full:

```
id, name, serial_no, model, category_id, partner_id, employee_id,
department_id, equipment_assign_to, assign_date, effective_date, cost,
warranty_date, scrap_date, note, owner_user_id, maintenance_open_count,
company_id, write_date, create_date
```

### 4.1 List — `search_count` + `search_read`

Two calls, deliberately. The count drives the "247 assets" header and the
pagination footer; without it the UI can only say "more", which is the
difference between a scrollbar and a guess.

```
execute_kw(db, uid, secret, "maintenance.equipment", "search_count",
           [DOMAIN], {})

execute_kw(db, uid, secret, "maintenance.equipment", "search_read",
           [DOMAIN],
           {"fields": [...], "limit": 20, "offset": 0, "order": "write_date desc"})
```

`DOMAIN` is built by
[odoo_domain_builder.dart](../lib/core/network/odoo/odoo_domain_builder.dart)
from the filter sheet. Only narrowings Odoo can evaluate go into it — warranty
buckets and the three overlay statuses have no server-side field and are
applied after the read.

**The app never fetches everything.** `limit` is always set. A 12 000-asset
instance is a normal instance.

> **Required rights:** `read`.
> **Without it:** a locked failure view naming the model, not an empty list. An
> empty list would read as "you have no assets", which is a different fact.

### 4.2 Detail — `read`

```
execute_kw(db, uid, secret, "maintenance.equipment", "read",
           [[101]],
           {"fields": [...]})
```

`read` rather than a second `search_read`: the id is already known, and
`search_read` would re-run a search to find one record the caller is holding.

### 4.3 Create

```
execute_kw(db, uid, secret, "maintenance.equipment", "create",
           [{"name": "Dell Latitude 5440",
             "serial_no": "SJL-0244",
             "category_id": 1,
             "effective_date": "2026-03-01"}],
           {})
   →  9001  (the new id)
```

Fields the instance does not have are dropped before sending, not sent as
`false`. Required fields the instance *does* have are never sent as `false` —
see §3.2.

> **Required rights:** `create` and `write`.
> **Without it:** the "+" button is not shown at all.

### 4.4 Update

```
execute_kw(db, uid, secret, "maintenance.equipment", "write",
           [[101], {"employee_id": 11, "assign_date": "2026-03-01"}],
           {})
   →  true
```

> **Required rights:** `write`.
> **Without it:** no Edit button, no Assign, no Return, no status change.

### 4.5 Delete

```
execute_kw(db, uid, secret, "maintenance.equipment", "unlink", [[101]], {})
   →  true
```

> **Required rights:** `unlink`.
> **Without it:** the Delete entry is absent from the overflow menu.

### 4.6 Grouped counts — `read_group`

Powers the dashboard's status breakdown and the category chart without pulling
every record to the handset.

```
execute_kw(db, uid, secret, "maintenance.equipment", "read_group",
           [DOMAIN, ["id"], ["category_id"]],
           {"lazy": true})
   →  [{"category_id": [1, "Laptop"], "__count": 42, "__domain": [...]}, ...]
```

Odoo 17+ returns `__count`. Older shapes emit `<field>_count`; the decoder
accepts both.

> **Required rights:** `read`.

---

## 5. Employees — `hr.employee`

Fields read: `id, name, department_id, job_id, job_title, work_email,
work_phone, mobile_phone, company_id`.

### 5.1 List and detail

`search_count` + `search_read` + `read`, exactly as §4.1–4.2.

### 5.2 The picker — `name_search`

Used by the assign screen and the handover recipient picker, because it honours
Odoo's own record rules and display-name logic rather than the app inventing a
match rule.

**Two signatures exist and the app speaks both:**

```
# Odoo 17, 18
name_search(name="mos", args=[], operator="ilike", limit=20)

# Odoo 19
name_search(name="mos", domain=[], limit=20)
```

Each version raises `TypeError: unexpected keyword argument` for the other's
names, and there is no field to probe. The client tries the 19 shape, falls
back on a fault, and **memoises which worked** — one extra round trip on the
first call of the process, none after. Paying it on every keystroke of a
typeahead is the difference between a picker that feels instant and one that
does not.

Response:

```json
[[11, "Mostafa Bader"], [12, "Ahmed Salah"]]
```

`name_search` returns only id and display name, so the matched ids are read
back in **one** follow-up `read` rather than one per row.

Covered by [name_search_compat_test.dart](../test/unit/core/name_search_compat_test.dart)
and [version_matrix_test.dart](../test/matrix/version_matrix_test.dart).

> **Required rights:** `read` on `hr.employee`.
> **Without it:** the Employees tab and every assignment flow are hidden. The
> asset register still works — losing HR must not cost the app its core job.

---

## 6. Maintenance — `maintenance.request`

```
search_count / search_read / read / create / write
```

on `maintenance.request`, plus `maintenance.stage` for the stage list.

Stages are **configurable per instance**, so "closed" cannot be a hardcoded id.
The app reads `maintenance.stage` and uses the `done` flag Odoo sets on the
closing stage.

```
execute_kw(db, uid, secret, "maintenance.request", "create",
           [{"name": "Screen flickering",
             "equipment_id": 101,
             "maintenance_type": "corrective",
             "request_date": "2026-03-01"}],
           {})
```

> **Required rights:** `read` on `maintenance.request` and `maintenance.stage`;
> `create` to report an issue.
> **Without the model:** the Maintenance tile is not shown on the More tab and
> the "Report issue" button is absent from asset detail.

---

## 7. Chatter — `mail.message`

The chatter is not decoration here. It is where the app records **history** and
where the three statuses Odoo has no field for actually live.

### 7.1 Posting — `message_post`

```
execute_kw(db, uid, secret, "maintenance.equipment", "message_post",
           [[101]],
           {"body": "Assigned to Mostafa Bader on 2026-03-01",
            "subtype_xmlid": "mail.mt_note"})
```

`mail.mt_note` — an internal log note, not a message that emails followers.
Handing someone a laptop should not send email to everyone following the
record.

### 7.2 Reading — `search_read` on `mail.message`

```
execute_kw(db, uid, secret, "mail.message", "search_read",
           [[["model", "=", "maintenance.equipment"],
             ["res_id", "=", 101]]],
           {"fields": ["id","body","subject","date","author_id",
                       "message_type","subtype_id"],
            "order": "date desc", "limit": 50})
```

### 7.3 Why Reserved, Damaged and Lost live here

Standard Odoo has no field for these three, and the spec forbids shipping an
addon to create one. They used to be held in an encrypted box on the device,
which worked exactly once: the phone that recorded "Damaged" was the only phone
that knew. A colleague opening the same asset saw "Available", and so did the
web client.

So the note **is** the write:

```
write → the note is posted to the asset's chatter
      → the local box mirrors it for offline reads
read  → Odoo's newest status note wins
      → the mirror answers only when Odoo cannot be reached
```

This works on data already in the customer's database — every status note ever
written parses — so there is no migration and nothing to backfill. See
[asset_state_store.dart](../lib/features/assets/data/services/asset_state_store.dart).

> **Required rights:** `read` on `mail.message` to see history; the ability to
> post a note (implied by `write` on the record) to change one of the three
> statuses.
> **Without `mail.message`:** history is hidden and the three overlay statuses
> are unavailable. Available / Assigned / Under maintenance / Retired still
> work, because those come from real Odoo fields.

---

## 8. Attachments — `ir.attachment`

Return-condition photos, maintenance photos and handover signatures.

### 8.1 List (metadata only)

```
execute_kw(db, uid, secret, "ir.attachment", "search_read",
           [[["res_model", "=", "maintenance.equipment"], ["res_id", "=", 101]]],
           {"fields": ["name", "mimetype", "file_size"]})
```

`datas` is deliberately **not** in this field list. It is the base64 payload,
and pulling twelve of them to render a row of thumbnails is how a list screen
becomes a 40 MB download.

### 8.2 Fetch one

```
execute_kw(db, uid, secret, "ir.attachment", "read",
           [[501]], {"fields": ["datas"]})
```

### 8.3 Upload

```
execute_kw(db, uid, secret, "ir.attachment", "create",
           [{"name": "return-20260301-a3f2.jpg",
             "datas": "<base64>",
             "res_model": "maintenance.equipment",
             "res_id": 101,
             "mimetype": "image/jpeg"}],
           {})
```

Photos are downscaled and re-encoded on the device before upload. A 12-megapixel
phone photo of a laptop lid is not more evidence than a 1600px one; it is the
same evidence and a much longer wait on site Wi-Fi.

> **Required rights:** `read` on `ir.attachment` to view; `create` to add.
> **Without `create`:** the camera button is hidden. A return still records —
> losing the photo weakens the proof, and blocking a correct return to protect
> a thumbnail would be the wrong trade.

---

## 9. Errors

Odoo signals failure with an XML-RPC `<fault>` whose `faultString` is a Python
traceback. The app never shows one. [error_mapper.dart](../lib/core/error/error_mapper.dart)
matches on the exception class name inside it:

| Odoo fault contains | Mapped to | What the user reads |
|---|---|---|
| `AccessDenied` | `invalidCredentials` / `sessionExpired` | "Wrong username, password or API key" |
| `AccessError` | `accessDenied` | "You are not allowed to *write* *assets*. Ask your Odoo administrator…" |
| `ValidationError`, `UserError` | `businessRule` | Odoo's own message, which is written for a user |
| `MissingError` | `recordNotFound` | "That asset no longer exists" |
| `KeyError: 'Object … doesn't exist'` | `modelUnavailable` | "This Odoo does not have the Maintenance app" |
| HTTP 5xx, socket error | `serverUnreachable` | "Cannot reach the server" |

**One ordering detail that matters:** a wrong *database* name produces a fault
that also contains `AccessDenied`. Checking for permissions first misreports a
typo as a permissions problem and sends the user to their administrator instead
of to the database field. The database check runs first, deliberately —
[error_mapper.dart:84](../lib/core/error/error_mapper.dart#L84).

---

## 10. The minimum viable Odoo user

The smallest set of groups that makes the app fully functional:

| Group | Gives |
|---|---|
| **Maintenance / User** | read, create, write, unlink on `maintenance.equipment` and `maintenance.request` |
| **Employees / Officer** *(or read access to `hr.employee`)* | the employee picker, assignment, the Employees tab |

Everything else the app touches — `ir.model`, `res.users`, `mail.message`,
`ir.attachment` — is readable by any internal user by default.

A **read-only auditor** needs only *Maintenance / User* with write and unlink
withdrawn on `maintenance.equipment`. The app hides every action they cannot
perform rather than letting them fail; that configuration is one of the rows in
[acl_matrix_test.dart](../test/matrix/acl_matrix_test.dart).

Step-by-step setup instructions are in [ODOO_SETUP.md](ODOO_SETUP.md).
