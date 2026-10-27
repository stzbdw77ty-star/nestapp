> Archived integration reference. The current household MVP is fully offline: live AI selection and membership navigation are hidden. These adapters are not connected by setting Info keys alone; implementing and validating live services is future work. See the root README for the current product.

# Nest integration setup

The offline product features are implemented. The live connection work below remains dependent on external accounts and infrastructure; the sample workspace must not be treated as a production release.

## Bank connections

`NestServices.LiveBank` implements the typed client interface. `BankingView` runs the functional `DemoBank` path and imports three months of fictional history. It intentionally cannot import live transactions into the sample database.

Before enabling real banking:

1. Select Yodlee or Basiq and obtain the applicable Australian Open Banking access arrangement, sandbox credentials and commercial terms.
2. Implement sign-in and a separate user-scoped live store. Complete account deletion and consent revocation before release.
3. Implement the three server routes below with the selected provider. The bundled server currently returns 503 for these routes; **it is not a Yodlee integration**.
4. Store provider secrets and user/provider mappings server-side. Use an authenticated, short-lived link session. For Yodlee, follow the FastLink iOS guide for native-browser OAuth handling and callback validation; simply opening an arbitrary FastLink URL is insufficient.
5. Maintain durable canonical transaction IDs across pending/posting transitions, pagination and corrections. Classify internal transfers, preserve user category overrides and support removed/reversed transactions. Reject unsupported currencies rather than summing them as AUD.

Contract (authenticated HTTPS, user identity derived from the session; no client-provided user ID):

| Route | Response |
|---|---|
| POST `/v1/bank/link` | `{id, url, expiresAt}`; URL on the backend origin, ISO-8601 expiry |
| GET `/v1/bank/snapshot` | `BankSnapshot` DTO: accounts, canonical transactions, fetchedAt |
| DELETE `/v1/bank/connection` | `{ok:true}` only after provider consent/access is revoked |

The production snapshot service must reconcile a complete stored ledger, not return an incomplete provider page. Accounts and transactions have explicit currency; this prototype accepts AUD only. Fetch dates use ISO-8601 without fractional seconds.

## Finance companion

The app uses `LocalCoach` by default, a labelled offline guide with prepared responses. It is not a language model. `LiveCoach` is implemented and calls POST `/v1/coach`.

The Swift Vapor server in `Server/` implements that route using the OpenAI Responses API. Set server-side environment variables `OPENAI_API_KEY` and `OPENAI_MODEL` to an enabled model. Do not embed these values in the app. `store:false` disables response storage; it does not imply all provider logging is disabled. Review provider retention and consent requirements before real data use.

The server also requires `SESSION_VALIDATION_URL` (HTTPS) and `SESSION_VALIDATION_SECRET`. This is a **trusted backend identity/entitlement service you must supply**, not an implemented sign-in service. It receives `{sessionToken}` with server-to-server bearer authentication and returns:

```json
{"active":true,"sub":"opaque-user-id","expiresAt":1800000000,"premiumActive":true}
```

That service must verify user sessions and App Store entitlements independently. Do not trust a client claim that a subscription is active. Missing configuration fails closed. The server applies a per-user 30-request/hour in-memory development limit; production needs shared durable rate limits, timeouts and monitoring. The AI policy is a starting point requiring adversarial evaluation before release, not a regulatory guarantee.

Run the server with `swift run --package-path Server NestServer` after resolving dependencies. It binds to loopback; put an authenticated HTTPS deployment in front before using the app adapter. It has not been compiled or deployed in this environment.

To wire the app after implementing sign-in, put the verified short-lived Nest session in `SessionKeychain.store`, set `NestAPIBaseURL` in the app Info configuration, and handle expiry, refresh and sign-out. No sign-in UI or session issuer is included yet. The companion reveals the AI option only with both a valid HTTPS base URL and stored session, and requires explicit summary-sharing consent. Raw merchant/account data is not included in the structured summary. Questions can still contain user-entered personal information.

## StoreKit membership

The StoreKit implementation loads `com.nest.monthly`, checks seven-day free-trial eligibility, purchases, restores, listens for transaction updates and refreshes verified entitlements. It accepts only a monthly product. Product display prices come from StoreKit; fallback copy is explicitly a planned price.

1. Create an auto-renewable monthly product in App Store Connect using `com.nest.monthly` (or change the constant).
2. Configure the intended Australian A$10 price using the available price point and a one-week free introductory offer for eligible users.
3. Publish genuine privacy and terms pages; set `NestPrivacyURL` and `NestTermsURL` to their HTTPS URLs.
4. Keep `NestPurchasesEnabled` false until the paid service is deliverable. Set it true only for StoreKit sandbox/local testing or a fully reviewed launch.
5. Configure App Store Server Notifications V2 and server-side entitlement verification, including expiry, refunds, billing retry and grace periods. Feed this into the trusted session/entitlement service above.

The sample workspace stays available without payment. Live bank and AI access must be gated by the server. Client entitlements alone do not secure a backend. No trial timer or paid-access bypass is implemented.

## Still needed for a release

Full Xcode/iOS build and UI tests; native sign-in; backend deployment and persistent user database; approved provider integration; privacy/consent/data deletion; server subscription validation; professional review of financial-advice boundaries; app icon and App Store metadata; accessibility/device testing. None of those are silently marked complete by this prototype.

## Primary references

- https://developer.yodlee.com/resources/yodlee/fastlink-4/docs/integrating_fastLink4_for_iOS
- https://developer.yodlee.com/resources/yodlee/fastlink-4/docs/documentation
- https://developers.openai.com/api/docs/guides/migrate-to-responses
- https://developer.apple.com/documentation/storekit/product
- https://developer.apple.com/documentation/storekit/transaction/currententitlements
- https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions/
- https://www.asic.gov.au/regulatory-resources/financial-services/giving-financial-product-advice
