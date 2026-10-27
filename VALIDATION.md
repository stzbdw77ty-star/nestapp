# Validation — 28 October 2026

## Verified in this Linux cloud instance

- Swift 6.0.3 installed from the official Swift distribution, with its detached release signature verified against Swift's published release keys. Reusable setup pins that artifact's SHA-256 and keeps TLS/checksum verification enabled.
- `bash Scripts/setup-linux.sh` builds NestCore and the cross-platform NestServices sources and runs real Swift Testing tests. **31 tests passed** in the verified run. XCTest prints a separate zero-test compatibility summary; the tests here execute under Swift Testing.
- Coverage includes exact AUD parsing, month boundaries, pending/transfer exclusions, debt amortisation, goals and projections; balanced account postings, credit-card/loan normal balances, profit/net-worth arithmetic, reconciliation mismatches/backdated changes, journal CSV escaping; statement CSV quoting/validation/stable IDs; backup round-trip, import metadata, budgets and legacy decoding.
- Swift syntax parsing passes for the SwiftUI/iOS sources and Apple-only persistence tests. This does not establish an iOS SDK build.

## Native UI changes awaiting visual verification

The Home dashboard now includes a plum gradient balance card, monthly flow summary, pastel account tiles, budget progress and recent activity. Colour assets supply distinct light/dark values, with saved system/light/dark appearance. An account opening-balance form avoids requiring debit/credit knowledge for setup. These SwiftUI sources pass syntax parsing, but they have not been rendered in this Linux instance; the supplied Design PNGs are the original archive previews, not screenshots of the new dashboard.

## Requires a Mac / full Xcode

The `.github/workflows/ios.yml` workflow runs SwiftLint, the complete Swift test suite (including SwiftData tests), and an iPhone Simulator app build on `macos-15`. A simulator app artifact is uploaded after a successful build.

The four SwiftData tests cover empty personal startup, demo isolation, repeatable transactional restore and persistent records after reopening a disk store. These cannot execute in Linux.

The first Mac workflow was triggered by commit `d3e937d` and was observed queued. Until it is observed passing, the full native app build and these four persistence tests remain unverified. Manual iPhone checks also remain: editor cancellation/deletion, statement check locking/unlocking, CSV import preview and repeat import, file exporter/importer permissions and restore, workspace switching, Dynamic Type, VoiceOver, dark mode and device signing.

## Known MVP boundaries

- Local single-device AUD records only; no live bank sync, shared household sync, automatic recurring transactions or multi-currency conversion.
- The CSV importer requires the documented columns and existing names. Users must prepare differing bank formats and record a transfer only once.
- Statement matching requires the complete posted balance at a cutoff. It is not a bank feed or a line-by-line uncleared-item matching engine.
- Financial calculations describe recorded data and scenarios, not investment or tax advice. Goal/debt planning notes do not automatically create ledger balances.
- Live banking, live AI, the optional server, App Store purchases and production deployment are not validated or enabled by this MVP.
- EasyUI's components page and competitor web/App Store research are blocked by the environment proxy (403). No EasyUI code or artwork has been used. Required domain additions are saved in the environment draft, not yet verified as applied.
