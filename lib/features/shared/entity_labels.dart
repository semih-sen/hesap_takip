import '../../data/database/tables/enums.dart';
import '../../l10n/generated/app_localizations.dart';

/// Maps an [AccountType] to its localized Turkish label (no hardcoded strings
/// in widgets — everything routes through the ARB).
String accountTypeLabel(AppLocalizations l10n, AccountType type) =>
    switch (type) {
      AccountType.bank => l10n.accountTypeBank,
      AccountType.cash => l10n.accountTypeCash,
      AccountType.creditCard => l10n.accountTypeCreditCard,
      AccountType.person => l10n.accountTypePerson,
      AccountType.investment => l10n.accountTypeInvestment,
      AccountType.other => l10n.accountTypeOther,
    };

/// Maps a [CategoryType] to its localized Turkish label.
String categoryTypeLabel(AppLocalizations l10n, CategoryType type) =>
    switch (type) {
      CategoryType.income => l10n.categoryTypeIncome,
      CategoryType.expense => l10n.categoryTypeExpense,
    };

/// Maps a [TransactionType] to its localized Turkish label.
String transactionTypeLabel(AppLocalizations l10n, TransactionType type) =>
    switch (type) {
      TransactionType.income => l10n.transactionTypeIncome,
      TransactionType.expense => l10n.transactionTypeExpense,
      TransactionType.transfer => l10n.transactionTypeTransfer,
    };

/// Maps a [TransactionStatus] to its localized Turkish label (filter toggles).
String transactionStatusLabel(
  AppLocalizations l10n,
  TransactionStatus status,
) => switch (status) {
  TransactionStatus.completed => l10n.transactionStatusCompleted,
  TransactionStatus.pending => l10n.transactionStatusPending,
  TransactionStatus.scheduled => l10n.transactionStatusScheduled,
  TransactionStatus.cancelled => l10n.transactionStatusCancelled,
};
