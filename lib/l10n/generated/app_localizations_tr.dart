// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Hesap Takip';

  @override
  String get navDashboard => 'Panel';

  @override
  String get navAccounts => 'Hesaplar';

  @override
  String get navCategories => 'Kategoriler';

  @override
  String get navSettings => 'Ayarlar';

  @override
  String get dashboardTitle => 'Panel';

  @override
  String get accountsTitle => 'Hesaplar';

  @override
  String get categoriesTitle => 'Kategoriler';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get placeholderComingSoon => 'Bu bölüm yakında eklenecek.';

  @override
  String get actionSave => 'Kaydet';

  @override
  String get actionCancel => 'İptal';

  @override
  String get actionDelete => 'Sil';

  @override
  String get actionEdit => 'Düzenle';

  @override
  String get actionArchive => 'Arşivle';

  @override
  String get actionUnarchive => 'Arşivden çıkar';

  @override
  String get actionUndo => 'Geri al';

  @override
  String get actionRetry => 'Tekrar dene';

  @override
  String get actionAddWallet => 'Cüzdan ekle';

  @override
  String get errorGeneric => 'Bir hata oluştu.';

  @override
  String get validationRequired => 'Bu alan gerekli.';

  @override
  String get validationInvalidAmount => 'Geçersiz tutar.';

  @override
  String get archivedBadge => 'Arşivli';

  @override
  String get colorLabel => 'Renk';

  @override
  String get iconLabel => 'Simge';

  @override
  String get accountsEmptyTitle => 'Henüz hesap yok';

  @override
  String get accountsEmptyMessage => 'İlk hesabınızı ekleyerek başlayın.';

  @override
  String get accountAdd => 'Hesap ekle';

  @override
  String get accountEdit => 'Hesabı düzenle';

  @override
  String get accountNameLabel => 'Hesap adı';

  @override
  String get accountTypeLabel => 'Hesap türü';

  @override
  String accountDeleted(String name) {
    return '$name silindi';
  }

  @override
  String get accountDeleteBlocked =>
      'Bu hesabın cüzdanları var. Önce cüzdanları silin veya taşıyın.';

  @override
  String get accountTypeBank => 'Banka';

  @override
  String get accountTypeCash => 'Nakit';

  @override
  String get accountTypeCreditCard => 'Kredi kartı';

  @override
  String get accountTypePerson => 'Kişi';

  @override
  String get accountTypeInvestment => 'Yatırım';

  @override
  String get accountTypeOther => 'Diğer';

  @override
  String get walletsEmpty => 'Bu hesapta cüzdan yok.';

  @override
  String get walletAdd => 'Cüzdan ekle';

  @override
  String get walletEdit => 'Cüzdanı düzenle';

  @override
  String get walletNameLabel => 'Cüzdan adı';

  @override
  String get walletCurrencyLabel => 'Para birimi';

  @override
  String get walletInitialBalanceLabel => 'Başlangıç bakiyesi';

  @override
  String get walletCurrencyFixedHint =>
      'Para birimi, cüzdan oluşturulduktan sonra değiştirilemez.';

  @override
  String walletDeleted(String name) {
    return '$name silindi';
  }

  @override
  String get walletDeleteBlocked =>
      'Bu cüzdanda işlemler var, silinemez. Bunun yerine arşivleyin.';
}
