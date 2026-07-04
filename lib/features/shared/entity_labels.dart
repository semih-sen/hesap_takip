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
