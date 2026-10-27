# Import a statement

In More → Import statement CSV, choose a UTF-8 file (maximum 10 MB / 10,000 rows). Nothing is saved until you review the preview and tap Import. All new rows save together or none do.

Columns must be in this order:

```csv
id,date,description,amount,type,category,account,to_account
bank-001,2026-10-01,Weekly groceries,85.50,expense,Groceries,Everyday account,
bank-002,2026-10-02,Salary,3200.00,income,Income,Everyday account,
bank-003,2026-10-03,Save for a rainy day,300.00,transfer,Transfers,Everyday account,Savings account
```

- Use stable transaction IDs from your bank, not row numbers that change between exports. Duplicate IDs within a file are rejected. Existing IDs within the same account are skipped on repeat import.
- Dates are `YYYY-MM-DD`, interpreted in the device's local calendar/time zone. Invalid or future dates are rejected.
- Amounts are positive AUD values with at most two decimal places, without currency signs or separators. `type` supplies the direction: `expense`, `income` or `transfer`.
- Account and category names must already exist in Nest. Matching ignores letter case.
- `to_account` is required only for transfers and must differ from the source account. Record each transfer once; do not import a second copy from the destination account's statement.
- Commas, line breaks and quotes in descriptions follow standard CSV quoting. A quote is escaped as `""` within a quoted field.
- Stable IDs and account names are retained through JSON backup/restore. Journal CSV export is a report, not a bank-import file; use JSON for complete restore.

Remove affected statement checks before importing older transactions into an already checked period. Account balances are only as complete as the records you enter. Importing transactions is not the same as connecting a live bank.
