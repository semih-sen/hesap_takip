/// Domain enums persisted via Drift's `intEnum<T>()` (stored as their index).
///
/// PROJECT_PLAN §5.1. The integer index is the on-disk representation, so the
/// ORDER of these values is part of the schema — never reorder or remove a
/// value without a migration.
library;

/// Kind of account that groups one or more wallets.
enum AccountType { bank, cash, creditCard, person, investment, other }

/// Whether a category applies to income or expense.
enum CategoryType { income, expense }

/// What a transaction represents.
enum TransactionType { income, expense, transfer }

/// Which way money moves, decoupled from [TransactionType].
///
/// income → inflow, expense → outflow, transfer-out leg → outflow,
/// transfer-in leg → inflow. This keeps balance math unambiguous (§5.1).
enum FlowDirection { inflow, outflow }

/// Lifecycle state of a transaction. Only [completed] rows affect balances.
enum TransactionStatus { completed, pending, scheduled, cancelled }

/// Recurrence cadence for a recurring rule.
enum RecurrenceFrequency { daily, weekly, monthly, yearly }
