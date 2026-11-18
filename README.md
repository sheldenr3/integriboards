# IntegriBoards invoicing

An invoicing workspace connected to Supabase project `gpfmclmdekqzhckjglro`.

## Run locally

```powershell
npm.cmd ci
npm.cmd run dev
```

Open the local address printed by Vite. `npm.cmd run build` creates the deployable `dist` directory.

## Use the app

1. Create an account and confirm your email, then sign in.
2. Enter your business details in Settings, including payment information.
3. Add customers and products. Product prices are entered in ZAR.
4. Create an invoice by selecting a customer and products and entering quantities, dates and tax.
5. Open the invoice to update its status or print it / save it as a PDF through your browser.

The app does not send invoices or process payments. Setting an invoice to Sent records its status. Currency selections change the invoice denomination; they do not convert product prices.

## Database and security

The live database is already configured. `invoicing-schema.sql` records the initial schema; do not rerun it on the configured project. It creates five `billing_*` tables with row level security, ownership policies, composite foreign keys and an authenticated invoice creation function. Invoice creation is transactional and snapshots customer, business and product details. Each account sees its own data; there is no shared team workspace.

The frontend uses only the publishable key. The personal access token and service role credentials are not part of the app. Email confirmation and password recovery use Supabase Auth; delivery depends on the project's mail configuration and provider limits. The deployed origin and localhost development origins are allowed auth redirects.

`database-check.sql` verifies invoice amounts, atomic rollback, account isolation and rejection of cross-account writes in a transaction that rolls back its fixtures. Run only in a controlled verification session with database owner privileges.

## Validation

- Production build passes.
- Dependency audit: zero known vulnerabilities after updating Vite to 6.4.6.
- Database checks pass and fixtures are rolled back.
- Supabase security advisors report no findings.
- Browser interaction and print layout were not visually verified because no browser surface was available in the execution environment.
