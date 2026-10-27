# Nest — household accounts

A native iOS 17+ app for personal and household finances, built from the supplied SwiftUI prototype. All money is recorded in AUD integer cents. The previous unrelated NestJS starter has been replaced; its commit remains in Git history.

## What the MVP does

The five tabs are **Home**, **Activity**, **Accounts**, **Budgets** and **More**. Home brings balances, monthly flows, quick entry, account tiles, budget progress and recent activity together. Reports, goals and data tools live under More. Appearance follows your device or a saved light/dark preference.

- **Your own workspace:** starts empty, with a separate fictional demo you can switch to without mixing records.
- **Activity:** add, edit, categorise and delete manual income, spending and transfers; search, filter and browse months. Pending items stay out of totals.
- **Accounts:** cash, bank, savings, credit-card and loan balances; custom accounts; a guided opening-balance form and balanced multi-line adjustments. Positive liability balances mean money owed.
- **Statement checks:** compare a dated closing balance, require an exact match, then lock included postings. Backdated changes cannot silently invalidate a checked statement.
- **Budgets:** category limits by month, actual spending, remaining amounts and clear overspending indicators.
- **Reports:** monthly income/spending, recorded net worth, trial balance and spreadsheet-safe journal CSV export.
- **Statement import:** validated CSV, review before saving, stable source IDs, repeat-import deduplication, and atomic import. See [the CSV format](Integration/CSV.md).
- **Backups:** versioned JSON export and confirmed restore of the complete workspace, including import IDs. The ledger, accounts, budgets and plans commit together in SwiftData.
- **Planning:** savings goals, debt payoff scenarios, lifestyle budgeting, trends and a labelled offline guide.

This MVP runs without sign-in, external accounts, API keys or payment. Live bank connections, live AI and paid subscriptions are not enabled. The archived service adapters and optional server remain for future work, but the user-facing app does not depend on them.

## Run on an iPhone simulator

1. On a Mac, install full Xcode 16+ with an iOS simulator runtime.
2. Open `Nest.xcodeproj`, choose the **Nest** scheme and an iPhone simulator, then Run.
3. Choose **Start my Nest** for personal records or **Explore with sample data**.
4. Start in **Accounts** to enter opening balances, then use **Activity** for income, spending and transfers.
5. For a physical device, select your signing team and a unique bundle identifier.

No CocoaPods or third-party app dependencies are required. SwiftUI, SwiftData, Charts, Observation and Foundation provide the native implementation.

## Checks

On a Mac with full Xcode selected:

```sh
swift test --parallel
brew install swiftlint # once, if not already installed
swiftlint lint --strict
xcodebuild -project Nest.xcodeproj -scheme Nest -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

The workflow in `.github/workflows/ios.yml` runs those checks on a Mac runner. macOS tests cover SwiftData workspace isolation, persistence across reopen and repeatable transactional restore.

On this Linux cloud environment:

```sh
bash Scripts/setup-linux.sh
```

That installs a checksum-verified Swift 6.0.3 toolchain under `/workspace/toolchains` when needed and runs actual Swift Testing core/service tests. It does **not** build SwiftUI or run an iPhone simulator. See [VALIDATION.md](VALIDATION.md) for tested and unverified capabilities.

## Storage and accounting

Personal records use `NestPersonal`; demo records use `NestDemo`. Planning data is in the same SwiftData store as the ledger. The prototype's old demo planning JSON is migrated on first use and retained on disk. SwiftData uses local storage with CloudKit disabled.

Every posted activity entry generates balanced debit/credit postings. Income credits Income, expenses debit their category, transfers move between balance-sheet accounts. Opening capital and loan proceeds are recorded as adjustments, not income. Credit-card purchases increase the liability; payments transfer funds from a bank account to the card. These are local manual books, not a connection to your bank, a tax return, or a guarantee that every transaction has been entered.

Use More → Workspace & data to export private backups. Deleting the app can delete local records. There is no automatic cross-device sync or joint-household sharing in this MVP. Debt and goal planners are notes and scenarios, not additional ledger assets/liabilities or automated transfers.

## UI and library choices

The archive's cream backgrounds and mint, peach and lilac palette are retained, with native forms, sheets, charts, progress indicators and accessible controls. SwiftLint from the suggested repositories is configured as a development check. See [DEPENDENCIES.md](DEPENDENCIES.md) for the library review and EasyUI access limitation.
