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
