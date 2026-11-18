# IntegriBoards invoicing

An invoicing workspace connected to Supabase project `gpfmclmdekqzhckjglro`.

## Run locally

```powershell
npm.cmd ci
npm.cmd run dev
```

Open the local address printed by Vite. `npm.cmd run build` creates the deployable `dist` directory.

## Use the app

1. Sign in with an account created by your administrator. Public account registration is temporarily disabled in both Supabase Auth and the app. Password resets remain available for existing accounts.
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
- Supabase security advisors currently flag leaked-password protection as disabled in the project's Auth settings; the billing tables retain their ownership policies.
- Browser interaction and print layout were not visually verified because no browser surface was available in the execution environment.

## Reference invoice format

The local invoice view and A4 print layout follow the supplied Integri Boards stationery: document metadata and logo, FROM/TO addresses, inclusive-price and exclusive/inclusive-total columns, banking details and balance due. Reference and sales-rep fields are saved on each invoice. Business and customer records support VAT numbers and separate physical addresses; business settings accept PNG/JPG/WebP logo uploads up to 400 KB. The included vector logo is a recreation; upload the original logo for exact branding.

Product unit prices remain exclusive of VAT. The inclusive-price column is calculated from the saved price and invoice tax rate. Discounts are displayed as zero; discount editing is not implemented. Invoice snapshots preserve the business details and logo at creation time. `invoice-reference-schema.sql` records the additive database update already applied to the project.

Run `node --test invoice-template.test.js` for invoice rounding, escaping and pagination checks.

## Quotes

Open **Quotes** and choose **Create quote**. Quotes use the same saved customers, products, VAT and stationery as invoices, with a separate quote number and validity date. They are excluded from invoice dashboard amounts.

Open a quote and click **Generate invoice from quote**, then confirm the invoice number, issue date and payment due date. Conversion creates a draft invoice from the quote's saved customer, business, product descriptions, prices, quantities, VAT, reference and notes. Changes to the current customer or product records do not change those quoted values. The original quote remains available and is marked Converted in the quote list, with a link to its invoice. A repeated conversion returns the existing invoice. Cancelled quotes cannot be converted.

`quotes-schema.sql` records the additive database change already applied to the connected project. `quotes-check.sql` verifies quote creation and conversion, snapshot preservation, duplicate prevention, cancelled-quote rejection and account isolation inside a rolled-back transaction.

## Board product attributes

Products have optional **Colour / finish** and **Board size (L × W × thickness)** text fields, for example `Storm Grey` and `2750 × 1830 × 16 mm`. They appear in the product list and document product selectors and can be searched. New quote and invoice items snapshot the attributes and print them beneath the product name; quote conversion preserves the quoted attributes. Existing document snapshots are left unchanged. `product-attributes-schema.sql` records the applied additive schema update, and `product-attributes-check.sql` verifies persistence and snapshot preservation in a rolled-back transaction.
