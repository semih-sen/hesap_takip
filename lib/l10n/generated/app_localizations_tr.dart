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

  @override
  String get validationInvalidRate => 'Geçersiz kur.';

  @override
  String get validationSplitMismatch =>
      'Kategori tutarları işlem tutarıyla eşleşmiyor.';

  @override
  String get categoryTypeIncome => 'Gelir';

  @override
  String get categoryTypeExpense => 'Gider';

  @override
  String get categoriesEmptyTitle => 'Henüz kategori yok';

  @override
  String get categoriesEmptyMessage => 'İlk kategorinizi ekleyerek başlayın.';

  @override
  String get categoryAdd => 'Kategori ekle';

  @override
  String get categoryEdit => 'Kategoriyi düzenle';

  @override
  String get categoryNameLabel => 'Kategori adı';

  @override
  String get categoryTypeLabel => 'Tür';

  @override
  String get categoryTypeLockedHint =>
      'Kullanılan bir kategorinin türü değiştirilemez.';

  @override
  String get categoryParentLabel => 'Üst kategori';

  @override
  String get categoryParentNone => 'Yok (üst kategori)';

  @override
  String get categoryParentHint =>
      'İsteğe bağlı. Alt kategori, üst kategorinin türünü alır.';

  @override
  String get categoryParentDisabledHint =>
      'Alt kategorileri olan bir kategori başka bir kategoriye taşınamaz.';

  @override
  String get categoryShowArchived => 'Arşivlileri göster';

  @override
  String get categoryHideArchived => 'Arşivlileri gizle';

  @override
  String categoryDeleted(String name) {
    return '$name silindi';
  }

  @override
  String get categoryDeleteBlocked =>
      'Bu kategori kullanılıyor veya alt kategorileri var, silinemez. Bunun yerine arşivleyin.';

  @override
  String get transactionAdd => 'İşlem ekle';

  @override
  String get transactionEdit => 'İşlemi düzenle';

  @override
  String get transactionDeleted => 'İşlem silindi';

  @override
  String get transactionTypeIncome => 'Gelir';

  @override
  String get transactionTypeExpense => 'Gider';

  @override
  String get transactionTypeTransfer => 'Transfer';

  @override
  String get transactionWalletLabel => 'Cüzdan';

  @override
  String get transactionAmountLabel => 'Tutar';

  @override
  String transactionRateLabel(String from, String base) {
    return 'Kur ($from → $base)';
  }

  @override
  String get transactionDateLabel => 'Tarih';

  @override
  String get transactionCategoriesLabel => 'Kategoriler';

  @override
  String get transactionNoCategories =>
      'Bu tür için kategori yok. Önce bir kategori ekleyin.';

  @override
  String get transactionSplitLabel => 'Kategorilere böl';

  @override
  String get transactionNoteLabel => 'Not (isteğe bağlı)';

  @override
  String get transactionPayeeLabel => 'Alıcı/Ödeyen (isteğe bağlı)';

  @override
  String get transactionsEmptyTitle => 'Henüz işlem yok';

  @override
  String get transactionsEmptyMessage => 'İlk gelir veya giderinizi ekleyin.';

  @override
  String get transactionStatusCompleted => 'Tamamlandı';

  @override
  String get transactionStatusPending => 'Bekliyor';

  @override
  String get transactionStatusScheduled => 'Planlandı';

  @override
  String get transactionStatusCancelled => 'İptal edildi';

  @override
  String transactionPartiallyPaid(String settled, String planned) {
    return 'Kısmen ödendi: $settled/$planned';
  }

  @override
  String transactionTransferTo(String wallet) {
    return 'Transfer → $wallet';
  }

  @override
  String get transactionRecurringChip => 'Tekrarlayan';

  @override
  String get dateToday => 'Bugün';

  @override
  String get dateYesterday => 'Dün';

  @override
  String get filterTitle => 'Filtrele';

  @override
  String get filterReset => 'Sıfırla';

  @override
  String get filterApply => 'Uygula';

  @override
  String get filterClear => 'Temizle';

  @override
  String get filterAll => 'Tümü';

  @override
  String get filterSearchLabel => 'Ara';

  @override
  String get filterDateRangeLabel => 'Tarih aralığı';

  @override
  String get filterDateRangeAll => 'Tüm zamanlar';

  @override
  String get filterTypeLabel => 'Tür';

  @override
  String get filterStatusLabel => 'Durum';

  @override
  String get filterWalletsLabel => 'Cüzdanlar';

  @override
  String get filterNoWallets => 'Cüzdan yok.';

  @override
  String get filterCategoriesLabel => 'Kategoriler';

  @override
  String get filterNoCategories => 'Kategori yok.';

  @override
  String get summaryTitle => 'Özet';

  @override
  String get summaryIncome => 'Gelir';

  @override
  String get summaryExpense => 'Gider';

  @override
  String get summaryNet => 'Net';

  @override
  String get summaryAccountsAll => 'Tümü';

  @override
  String get summarySelectAccount => 'Hesap seç';

  @override
  String get summaryPeriodLast30Days => 'Son 30 gün';

  @override
  String get summaryPeriodAllTime => 'Tüm zamanlar';

  @override
  String get summaryPeriodCustom => 'Özel';

  @override
  String get summaryPeriodPrevious => 'Önceki ay';

  @override
  String get summaryPeriodNext => 'Sonraki ay';
}
