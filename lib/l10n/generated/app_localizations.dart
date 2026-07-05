import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('tr')];

  /// Application display name shown in the app bar and task switcher.
  ///
  /// In tr, this message translates to:
  /// **'Hesap Takip'**
  String get appTitle;

  /// Bottom navigation label for the dashboard/summary tab.
  ///
  /// In tr, this message translates to:
  /// **'Panel'**
  String get navDashboard;

  /// Bottom navigation label for the accounts tab.
  ///
  /// In tr, this message translates to:
  /// **'Hesaplar'**
  String get navAccounts;

  /// Bottom navigation label for the categories tab.
  ///
  /// In tr, this message translates to:
  /// **'Kategoriler'**
  String get navCategories;

  /// Bottom navigation label for the settings tab.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get navSettings;

  /// App bar title for the dashboard screen.
  ///
  /// In tr, this message translates to:
  /// **'Panel'**
  String get dashboardTitle;

  /// App bar title for the accounts screen.
  ///
  /// In tr, this message translates to:
  /// **'Hesaplar'**
  String get accountsTitle;

  /// App bar title for the categories screen.
  ///
  /// In tr, this message translates to:
  /// **'Kategoriler'**
  String get categoriesTitle;

  /// App bar title for the settings screen.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get settingsTitle;

  /// Generic message shown on placeholder screens before the feature is built.
  ///
  /// In tr, this message translates to:
  /// **'Bu bölüm yakında eklenecek.'**
  String get placeholderComingSoon;

  /// Save button label.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get actionSave;

  /// Cancel button label.
  ///
  /// In tr, this message translates to:
  /// **'İptal'**
  String get actionCancel;

  /// Delete menu/button label.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get actionDelete;

  /// Edit menu/button label.
  ///
  /// In tr, this message translates to:
  /// **'Düzenle'**
  String get actionEdit;

  /// Archive menu label.
  ///
  /// In tr, this message translates to:
  /// **'Arşivle'**
  String get actionArchive;

  /// Unarchive menu label.
  ///
  /// In tr, this message translates to:
  /// **'Arşivden çıkar'**
  String get actionUnarchive;

  /// Undo action on the SnackBar.
  ///
  /// In tr, this message translates to:
  /// **'Geri al'**
  String get actionUndo;

  /// Retry button on an error state.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get actionRetry;

  /// Add-wallet button label.
  ///
  /// In tr, this message translates to:
  /// **'Cüzdan ekle'**
  String get actionAddWallet;

  /// Generic error-state message.
  ///
  /// In tr, this message translates to:
  /// **'Bir hata oluştu.'**
  String get errorGeneric;

  /// Required-field validation message.
  ///
  /// In tr, this message translates to:
  /// **'Bu alan gerekli.'**
  String get validationRequired;

  /// Invalid monetary amount validation message.
  ///
  /// In tr, this message translates to:
  /// **'Geçersiz tutar.'**
  String get validationInvalidAmount;

  /// Badge shown on archived accounts/wallets.
  ///
  /// In tr, this message translates to:
  /// **'Arşivli'**
  String get archivedBadge;

  /// Color picker label.
  ///
  /// In tr, this message translates to:
  /// **'Renk'**
  String get colorLabel;

  /// Icon picker label.
  ///
  /// In tr, this message translates to:
  /// **'Simge'**
  String get iconLabel;

  /// Empty-state title on the accounts screen.
  ///
  /// In tr, this message translates to:
  /// **'Henüz hesap yok'**
  String get accountsEmptyTitle;

  /// Empty-state message on the accounts screen.
  ///
  /// In tr, this message translates to:
  /// **'İlk hesabınızı ekleyerek başlayın.'**
  String get accountsEmptyMessage;

  /// Add-account button / form title.
  ///
  /// In tr, this message translates to:
  /// **'Hesap ekle'**
  String get accountAdd;

  /// Edit-account form title.
  ///
  /// In tr, this message translates to:
  /// **'Hesabı düzenle'**
  String get accountEdit;

  /// Account name field label.
  ///
  /// In tr, this message translates to:
  /// **'Hesap adı'**
  String get accountNameLabel;

  /// Account type field label.
  ///
  /// In tr, this message translates to:
  /// **'Hesap türü'**
  String get accountTypeLabel;

  /// SnackBar text after queuing an account delete.
  ///
  /// In tr, this message translates to:
  /// **'{name} silindi'**
  String accountDeleted(String name);

  /// Message when an account cannot be deleted due to existing wallets.
  ///
  /// In tr, this message translates to:
  /// **'Bu hesabın cüzdanları var. Önce cüzdanları silin veya taşıyın.'**
  String get accountDeleteBlocked;

  /// Account type: bank.
  ///
  /// In tr, this message translates to:
  /// **'Banka'**
  String get accountTypeBank;

  /// Account type: cash.
  ///
  /// In tr, this message translates to:
  /// **'Nakit'**
  String get accountTypeCash;

  /// Account type: credit card.
  ///
  /// In tr, this message translates to:
  /// **'Kredi kartı'**
  String get accountTypeCreditCard;

  /// Account type: person.
  ///
  /// In tr, this message translates to:
  /// **'Kişi'**
  String get accountTypePerson;

  /// Account type: investment.
  ///
  /// In tr, this message translates to:
  /// **'Yatırım'**
  String get accountTypeInvestment;

  /// Account type: other.
  ///
  /// In tr, this message translates to:
  /// **'Diğer'**
  String get accountTypeOther;

  /// Empty-state under an account with no wallets.
  ///
  /// In tr, this message translates to:
  /// **'Bu hesapta cüzdan yok.'**
  String get walletsEmpty;

  /// Add-wallet form title.
  ///
  /// In tr, this message translates to:
  /// **'Cüzdan ekle'**
  String get walletAdd;

  /// Edit-wallet form title.
  ///
  /// In tr, this message translates to:
  /// **'Cüzdanı düzenle'**
  String get walletEdit;

  /// Wallet name field label.
  ///
  /// In tr, this message translates to:
  /// **'Cüzdan adı'**
  String get walletNameLabel;

  /// Wallet currency field label.
  ///
  /// In tr, this message translates to:
  /// **'Para birimi'**
  String get walletCurrencyLabel;

  /// Wallet initial balance field label.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç bakiyesi'**
  String get walletInitialBalanceLabel;

  /// Hint explaining wallet currency is immutable after creation.
  ///
  /// In tr, this message translates to:
  /// **'Para birimi, cüzdan oluşturulduktan sonra değiştirilemez.'**
  String get walletCurrencyFixedHint;

  /// SnackBar text after queuing a wallet delete.
  ///
  /// In tr, this message translates to:
  /// **'{name} silindi'**
  String walletDeleted(String name);

  /// Message when a wallet cannot be deleted due to existing transactions.
  ///
  /// In tr, this message translates to:
  /// **'Bu cüzdanda işlemler var, silinemez. Bunun yerine arşivleyin.'**
  String get walletDeleteBlocked;

  /// Invalid exchange-rate validation message.
  ///
  /// In tr, this message translates to:
  /// **'Geçersiz kur.'**
  String get validationInvalidRate;

  /// Error shown when per-category split allocations do not reconcile with the transaction total.
  ///
  /// In tr, this message translates to:
  /// **'Kategori tutarları işlem tutarıyla eşleşmiyor.'**
  String get validationSplitMismatch;

  /// Category type: income tab/segment label.
  ///
  /// In tr, this message translates to:
  /// **'Gelir'**
  String get categoryTypeIncome;

  /// Category type: expense tab/segment label.
  ///
  /// In tr, this message translates to:
  /// **'Gider'**
  String get categoryTypeExpense;

  /// Empty-state title on a categories tab.
  ///
  /// In tr, this message translates to:
  /// **'Henüz kategori yok'**
  String get categoriesEmptyTitle;

  /// Empty-state message on a categories tab.
  ///
  /// In tr, this message translates to:
  /// **'İlk kategorinizi ekleyerek başlayın.'**
  String get categoriesEmptyMessage;

  /// Add-category button / form title.
  ///
  /// In tr, this message translates to:
  /// **'Kategori ekle'**
  String get categoryAdd;

  /// Edit-category form title.
  ///
  /// In tr, this message translates to:
  /// **'Kategoriyi düzenle'**
  String get categoryEdit;

  /// Category name field label.
  ///
  /// In tr, this message translates to:
  /// **'Kategori adı'**
  String get categoryNameLabel;

  /// Category type selector label.
  ///
  /// In tr, this message translates to:
  /// **'Tür'**
  String get categoryTypeLabel;

  /// Hint explaining the type of a referenced category is locked.
  ///
  /// In tr, this message translates to:
  /// **'Kullanılan bir kategorinin türü değiştirilemez.'**
  String get categoryTypeLockedHint;

  /// Parent category dropdown label.
  ///
  /// In tr, this message translates to:
  /// **'Üst kategori'**
  String get categoryParentLabel;

  /// Dropdown option meaning no parent (top-level category).
  ///
  /// In tr, this message translates to:
  /// **'Yok (üst kategori)'**
  String get categoryParentNone;

  /// Hint under the parent dropdown explaining child inherits parent type.
  ///
  /// In tr, this message translates to:
  /// **'İsteğe bağlı. Alt kategori, üst kategorinin türünü alır.'**
  String get categoryParentHint;

  /// Hint explaining a category with children cannot be nested.
  ///
  /// In tr, this message translates to:
  /// **'Alt kategorileri olan bir kategori başka bir kategoriye taşınamaz.'**
  String get categoryParentDisabledHint;

  /// Tooltip for the toggle that reveals archived categories.
  ///
  /// In tr, this message translates to:
  /// **'Arşivlileri göster'**
  String get categoryShowArchived;

  /// Tooltip for the toggle that hides archived categories.
  ///
  /// In tr, this message translates to:
  /// **'Arşivlileri gizle'**
  String get categoryHideArchived;

  /// SnackBar text after queuing a category delete.
  ///
  /// In tr, this message translates to:
  /// **'{name} silindi'**
  String categoryDeleted(String name);

  /// Message when a category cannot be deleted because it is referenced or has children.
  ///
  /// In tr, this message translates to:
  /// **'Bu kategori kullanılıyor veya alt kategorileri var, silinemez. Bunun yerine arşivleyin.'**
  String get categoryDeleteBlocked;

  /// Add-transaction button / form title.
  ///
  /// In tr, this message translates to:
  /// **'İşlem ekle'**
  String get transactionAdd;

  /// Edit-transaction form title.
  ///
  /// In tr, this message translates to:
  /// **'İşlemi düzenle'**
  String get transactionEdit;

  /// SnackBar text after queuing a transaction delete.
  ///
  /// In tr, this message translates to:
  /// **'İşlem silindi'**
  String get transactionDeleted;

  /// Transaction type: income.
  ///
  /// In tr, this message translates to:
  /// **'Gelir'**
  String get transactionTypeIncome;

  /// Transaction type: expense.
  ///
  /// In tr, this message translates to:
  /// **'Gider'**
  String get transactionTypeExpense;

  /// Transaction type: transfer.
  ///
  /// In tr, this message translates to:
  /// **'Transfer'**
  String get transactionTypeTransfer;

  /// Wallet picker label on the transaction form.
  ///
  /// In tr, this message translates to:
  /// **'Cüzdan'**
  String get transactionWalletLabel;

  /// Amount field label on the transaction form.
  ///
  /// In tr, this message translates to:
  /// **'Tutar'**
  String get transactionAmountLabel;

  /// Exchange-rate field label showing the wallet and base currency codes.
  ///
  /// In tr, this message translates to:
  /// **'Kur ({from} → {base})'**
  String transactionRateLabel(String from, String base);

  /// Value-date field label on the transaction form.
  ///
  /// In tr, this message translates to:
  /// **'Tarih'**
  String get transactionDateLabel;

  /// Categories multi-select label on the transaction form.
  ///
  /// In tr, this message translates to:
  /// **'Kategoriler'**
  String get transactionCategoriesLabel;

  /// Message shown when no categories exist for the selected type.
  ///
  /// In tr, this message translates to:
  /// **'Bu tür için kategori yok. Önce bir kategori ekleyin.'**
  String get transactionNoCategories;

  /// Toggle enabling per-category split amounts.
  ///
  /// In tr, this message translates to:
  /// **'Kategorilere böl'**
  String get transactionSplitLabel;

  /// Note field label on the transaction form.
  ///
  /// In tr, this message translates to:
  /// **'Not (isteğe bağlı)'**
  String get transactionNoteLabel;

  /// Payee field label on the transaction form.
  ///
  /// In tr, this message translates to:
  /// **'Alıcı/Ödeyen (isteğe bağlı)'**
  String get transactionPayeeLabel;

  /// Empty-state title on the dashboard transaction list.
  ///
  /// In tr, this message translates to:
  /// **'Henüz işlem yok'**
  String get transactionsEmptyTitle;

  /// Empty-state message on the dashboard transaction list.
  ///
  /// In tr, this message translates to:
  /// **'İlk gelir veya giderinizi ekleyin.'**
  String get transactionsEmptyMessage;

  /// Transaction status: completed.
  ///
  /// In tr, this message translates to:
  /// **'Tamamlandı'**
  String get transactionStatusCompleted;

  /// Transaction status: pending.
  ///
  /// In tr, this message translates to:
  /// **'Bekliyor'**
  String get transactionStatusPending;

  /// Transaction status: scheduled.
  ///
  /// In tr, this message translates to:
  /// **'Planlandı'**
  String get transactionStatusScheduled;

  /// Transaction status: cancelled.
  ///
  /// In tr, this message translates to:
  /// **'İptal edildi'**
  String get transactionStatusCancelled;

  /// Row 3 label under a pending parent bill showing settled over planned amounts.
  ///
  /// In tr, this message translates to:
  /// **'Kısmen ödendi: {settled}/{planned}'**
  String transactionPartiallyPaid(String settled, String planned);

  /// Row 3 label on a transfer row naming the counter wallet.
  ///
  /// In tr, this message translates to:
  /// **'Transfer → {wallet}'**
  String transactionTransferTo(String wallet);

  /// Row 3 chip marking a recurring-generated transaction.
  ///
  /// In tr, this message translates to:
  /// **'Tekrarlayan'**
  String get transactionRecurringChip;

  /// Sticky section header for transactions dated today.
  ///
  /// In tr, this message translates to:
  /// **'Bugün'**
  String get dateToday;

  /// Sticky section header for transactions dated yesterday.
  ///
  /// In tr, this message translates to:
  /// **'Dün'**
  String get dateYesterday;

  /// Transaction list filter sheet title / filter button tooltip.
  ///
  /// In tr, this message translates to:
  /// **'Filtrele'**
  String get filterTitle;

  /// Reset action clearing all list filters.
  ///
  /// In tr, this message translates to:
  /// **'Sıfırla'**
  String get filterReset;

  /// Apply/close button on the filter sheet.
  ///
  /// In tr, this message translates to:
  /// **'Uygula'**
  String get filterApply;

  /// Clear a single filter facet (e.g. the date range).
  ///
  /// In tr, this message translates to:
  /// **'Temizle'**
  String get filterClear;

  /// Filter choice meaning no narrowing (all types / all statuses).
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get filterAll;

  /// Search field label on the filter sheet (note / payee / category).
  ///
  /// In tr, this message translates to:
  /// **'Ara'**
  String get filterSearchLabel;

  /// Date-range section label on the filter sheet.
  ///
  /// In tr, this message translates to:
  /// **'Tarih aralığı'**
  String get filterDateRangeLabel;

  /// Button text when no date range is selected (all time).
  ///
  /// In tr, this message translates to:
  /// **'Tüm zamanlar'**
  String get filterDateRangeAll;

  /// Transaction-type section label on the filter sheet.
  ///
  /// In tr, this message translates to:
  /// **'Tür'**
  String get filterTypeLabel;

  /// Transaction-status section label on the filter sheet.
  ///
  /// In tr, this message translates to:
  /// **'Durum'**
  String get filterStatusLabel;

  /// Wallets multi-select section label on the filter sheet.
  ///
  /// In tr, this message translates to:
  /// **'Cüzdanlar'**
  String get filterWalletsLabel;

  /// Shown when there are no wallets to filter by.
  ///
  /// In tr, this message translates to:
  /// **'Cüzdan yok.'**
  String get filterNoWallets;

  /// Categories multi-select section label on the filter sheet.
  ///
  /// In tr, this message translates to:
  /// **'Kategoriler'**
  String get filterCategoriesLabel;

  /// Shown when there are no categories to filter by.
  ///
  /// In tr, this message translates to:
  /// **'Kategori yok.'**
  String get filterNoCategories;

  /// Section title for the dashboard summary card.
  ///
  /// In tr, this message translates to:
  /// **'Özet'**
  String get summaryTitle;

  /// Summary figure label: total income for the period.
  ///
  /// In tr, this message translates to:
  /// **'Gelir'**
  String get summaryIncome;

  /// Summary figure label: total expense for the period.
  ///
  /// In tr, this message translates to:
  /// **'Gider'**
  String get summaryExpense;

  /// Summary figure label: net (income minus expense) for the period.
  ///
  /// In tr, this message translates to:
  /// **'Net'**
  String get summaryNet;

  /// Selector chip aggregating the summary over all accounts.
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get summaryAccountsAll;

  /// Label/tooltip for the summary account selector.
  ///
  /// In tr, this message translates to:
  /// **'Hesap seç'**
  String get summarySelectAccount;

  /// Period preset: the last 30 days.
  ///
  /// In tr, this message translates to:
  /// **'Son 30 gün'**
  String get summaryPeriodLast30Days;

  /// Period preset: all time.
  ///
  /// In tr, this message translates to:
  /// **'Tüm zamanlar'**
  String get summaryPeriodAllTime;

  /// Period preset: a custom date range chosen via the date-range picker.
  ///
  /// In tr, this message translates to:
  /// **'Özel'**
  String get summaryPeriodCustom;

  /// Tooltip for the button navigating to the previous month.
  ///
  /// In tr, this message translates to:
  /// **'Önceki ay'**
  String get summaryPeriodPrevious;

  /// Tooltip for the button navigating to the next month.
  ///
  /// In tr, this message translates to:
  /// **'Sonraki ay'**
  String get summaryPeriodNext;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
