# Odoo compatibility notes

Differences between Odoo versions that the app actually had to handle, found by
running it against a live **Odoo 19.0+e** instance rather than by reading the
release notes. Each one is a bug that reached a screen before it was fixed.

The app targets Odoo **17, 18 and 19** (spec §28) and probes rather than
version-sniffs (docs/ARCHITECTURE.md §5). These are the cases where probing a
*field* was not enough, because the difference was in a method signature or a
server-side constraint.

---

## 1. `name_search` renamed its parameters in 19

| Version | Signature |
|---|---|
| 17, 18 | `name_search(name='', args=None, operator='ilike', limit=100)` |
| 19 | `name_search(name='', domain=None, limit=100)` |

Each version raises `TypeError: unexpected keyword argument` for the other's
names. There is no field to probe, so `OdooObjectService.nameSearch` calls the
19 shape, falls back to the legacy one on a fault, and memoises which worked —
one extra round trip on the first call of the process, none after.

**Symptom before the fix:** the assignment screen's employee picker showed no
candidates on Odoo 19, because the lookup faulted and the Cubit — correctly —
left the previous (empty) list alone rather than showing "nobody by that name".

Covered by `test/unit/core/name_search_compat_test.dart`, which drives both
signatures through the fake.

---

## 2. `effective_date` is required on `maintenance.equipment`

Stock Odoo marks it mandatory. Odoo also supplies a default — but only when the
key is **absent** from the create payload.

```python
create({'name': 'X'})                      # ok, default applies
create({'name': 'X', 'effective_date': False})   # ValidationError
```

The app used to send Odoo's "empty" sentinel `False` for every field the user
left blank, which overrode the default and then failed the constraint. So
creating an asset without a purchase date — most of them — was rejected
outright.

`AssetMapper.toWriteValues` now takes the instance's required-field set from
`fields_get` and omits a key rather than clearing it. The same rule applies on
update, so an instance that mandates an assignment date does not reject the
return that would have emptied it.

Covered by `test/widget/asset_form_test.dart`; the fake reproduces the
constraint, including the absent-versus-`False` distinction.

---

## 3. `message_post` escapes an HTML body over XML-RPC

Passing `body='<p>Assigned…</p>'` stores
`<p>&lt;p&gt;Assigned…&lt;/p&gt;</p>` — the chatter then shows the literal tags
to whoever opens the record in the web client.

The app sends **plain text** and lets Odoo wrap it. Because Odoo puts the whole
note in one `<p>`, and HTML collapses newlines, the headline and the user's own
note are joined with an em dash rather than a line break.

---

## 4. A many2one is written as an id and read back as a pair

```python
write([id], {'employee_id': 11})
read([id], ['employee_id'])   # -> {'employee_id': [11, 'Mostafa Bader']}
```

Not a version difference — but the same asymmetry caught the test fake, which
stored the bare int and so made every read-after-write look like an *empty*
relation to `OdooValueReader.readRef`. An asset assigned a moment earlier still
read "Unassigned", and the test that should have caught it passed because it
inspected the raw row instead of what the app could parse.

`FakeOdooData` now resolves relational writes into `[id, name]` pairs, the way
the server does.

---

## 5. `db.list` is disabled on Odoo Online, but the JSON endpoint is not

`/xmlrpc/2/db` → `AccessDenied`, which the connection screen already treats as
"this server keeps its list private" rather than an error (spec §3).

Worth knowing: `POST /web/database/list` **does** answer on the same host, and
is how the database name for the reference instance was found. The app does not
use it — it is a web-client endpoint, not part of the XML-RPC contract the spec
scopes the integration to — but it is the fastest way to answer "what is this
customer's database called" during support.

---

## Reference instance

The behaviour above was verified against:

- **Odoo 19.0+e** (Odoo Online), Maintenance + Employees installed
- 24 equipment records across every status the app renders, 9 employees,
  6 maintenance requests

`test/integration/odoo_api_test.dart` exercises the same calls against the
in-process fake, so the suite stays runnable with no network.
