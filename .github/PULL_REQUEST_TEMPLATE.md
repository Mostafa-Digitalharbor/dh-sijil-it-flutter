## What changed

<!-- One paragraph. Link the spec section this implements, e.g. "spec section 7". -->

## Architecture checklist

- [ ] No XML-RPC call is made from a widget (spec section 18)
- [ ] Repository returns `Either<Failure, T>` — no exception crosses into the UI
- [ ] Field reads go through `OdooCapabilityService.supportedFields` (spec section 17)
- [ ] No hardcoded Odoo record id (spec section 10)
- [ ] List queries are paginated (spec section 20)
- [ ] No password, API key or session id can reach a log (spec section 25)
- [ ] Cubit registered as a factory in the DI module
- [ ] Loading, empty and error states all handled (spec section 26)

## Testing

- [ ] Unit tests for new domain logic
- [ ] Verified against a real Odoo instance (state version)
