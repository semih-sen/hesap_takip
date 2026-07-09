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
  String get accountDefaultLabel => 'Varsayılan hesap';

  @override
  String get accountDefaultHint => 'Gösterge paneli bu hesapla açılır';

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
  String get summaryNet => 'Bakiye';

  @override
  String get summaryCarriedOver => 'Devreden';

  @override
  String get summaryCurrentCash => 'Bugünkü Kasa';

  @override
  String get summaryCarryForward => 'Devredecek';

  @override
  String get summaryCollected => 'Tahsilat';

  @override
  String get summaryReceivable => 'Alacak';

  @override
  String get summaryPayable => 'Borç';

  @override
  String get summaryPaid => 'Ödeme';

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

  @override
  String get transferAdd => 'Transfer ekle';

  @override
  String get transferEdit => 'Transferi düzenle';

  @override
  String get transferFromLabel => 'Gönderen cüzdan';

  @override
  String get transferToLabel => 'Alan cüzdan';

  @override
  String get transferFromAmountLabel => 'Gönderilen tutar';

  @override
  String get transferToAmountLabel => 'Alınan tutar';

  @override
  String transferRateLabel(String from, String to) {
    return 'Kur ($from → $to)';
  }

  @override
  String get transferDeleted => 'Transfer silindi';

  @override
  String get transferErrorSameWallet =>
      'Gönderen ve alan cüzdan farklı olmalı.';

  @override
  String get transferErrorNonPositive => 'Tutar sıfırdan büyük olmalı.';

  @override
  String get transferErrorArchived => 'Arşivli cüzdanlarla transfer yapılamaz.';

  @override
  String get transferErrorMissingWallet => 'Cüzdan bulunamadı.';

  @override
  String get transferNeedsTwoWallets =>
      'Transfer için en az iki cüzdan gerekir.';

  @override
  String get pendingChipDebt => 'Borç';

  @override
  String get pendingChipReceivable => 'Alacak';

  @override
  String pendingDue(String date) {
    return 'Vade: $date';
  }

  @override
  String get pendingOverdue => 'Gecikmiş';

  @override
  String get settlePayTitle => 'Öde';

  @override
  String get settleCollectTitle => 'Tahsil et';

  @override
  String get settleAmountLabel => 'Tutar';

  @override
  String settleRemaining(String amount) {
    return 'Kalan: $amount';
  }

  @override
  String get settleDateLabel => 'Ödeme tarihi';

  @override
  String validationOverpayment(String remaining) {
    return 'Tutar kalanı ($remaining) aşamaz.';
  }

  @override
  String get settledExpense => 'Ödendi';

  @override
  String get settledIncome => 'Tahsil edildi';

  @override
  String get recurringTitle => 'Tekrarlayan işlemler';

  @override
  String get recurringAdd => 'Kural ekle';

  @override
  String get recurringEdit => 'Kuralı düzenle';

  @override
  String get recurringDeleted => 'Kural silindi';

  @override
  String get recurringEmptyTitle => 'Henüz tekrarlayan işlem yok';

  @override
  String get recurringEmptyMessage =>
      'Kira, maaş, abonelik gibi düzenli işlemler için kural ekleyin.';

  @override
  String get recurringGenerateNow => 'Şimdi oluştur';

  @override
  String recurringGeneratedCount(int count) {
    return '$count işlem oluşturuldu';
  }

  @override
  String get recurringGeneratedNone => 'Yeni işlem yok';

  @override
  String get recurringPausedBadge => 'Duraklatıldı';

  @override
  String get recurringActionPause => 'Duraklat';

  @override
  String get recurringActionResume => 'Sürdür';

  @override
  String get recurringNameLabel => 'Ad';

  @override
  String get recurringWalletLabel => 'Cüzdan';

  @override
  String get recurringAmountLabel => 'Tutar';

  @override
  String get recurringFrequencyLabel => 'Sıklık';

  @override
  String get recurringFrequencyDaily => 'Günlük';

  @override
  String get recurringFrequencyWeekly => 'Haftalık';

  @override
  String get recurringFrequencyMonthly => 'Aylık';

  @override
  String get recurringFrequencyYearly => 'Yıllık';

  @override
  String recurringIntervalLabel(int count, String unit) {
    return 'Her $count $unit';
  }

  @override
  String get recurringUnitDay => 'gün';

  @override
  String get recurringUnitWeek => 'hafta';

  @override
  String get recurringUnitMonth => 'ay';

  @override
  String get recurringUnitYear => 'yıl';

  @override
  String get recurringByMonthDayLabel => 'Ayın günü';

  @override
  String get recurringByWeekdayLabel => 'Haftanın günü';

  @override
  String get recurringStartDateLabel => 'Başlangıç tarihi';

  @override
  String get recurringEndDateLabel => 'Bitiş tarihi (isteğe bağlı)';

  @override
  String get recurringEndDateClear => 'Bitiş tarihini kaldır';

  @override
  String get recurringMaxOccurrencesLabel => 'En fazla tekrar (isteğe bağlı)';

  @override
  String get recurringAutoPostLabel => 'Otomatik işle';

  @override
  String get recurringAutoPostCaption =>
      'Açık: işlem tamamlanmış olarak eklenir. Kapalı: onay bekleyen (borç/alacak) olarak eklenir.';

  @override
  String get recurringNoteLabel => 'Not (isteğe bağlı)';

  @override
  String get recurringCategoriesLabel => 'Kategoriler';

  @override
  String get recurringValidationEndBeforeStart =>
      'Bitiş tarihi başlangıçtan önce olamaz.';

  @override
  String recurringSummaryEvery(int count, String unit) {
    return 'Her $count $unit';
  }

  @override
  String recurringSummaryMonthDay(int day) {
    return 'gün $day';
  }

  @override
  String get recurringEditScopeTitle => 'Tekrarlayan işlem';

  @override
  String get recurringEditScopeMessage =>
      'Bu işlem bir kurala bağlı. Neyi düzenlemek istiyorsunuz?';

  @override
  String get recurringEditScopeThisOnly => 'Yalnızca bu işlem';

  @override
  String get recurringEditScopeThisAndFuture => 'Bu ve gelecekteki işlemler';

  @override
  String get listOverdueCarriedNotice => 'Gecikmiş işlemler de gösteriliyor';

  @override
  String accountTotalLabel(String amount) {
    return 'Toplam: $amount';
  }

  @override
  String get actionContinue => 'Devam et';

  @override
  String get actionClose => 'Kapat';

  @override
  String get settingsBaseCurrencyLabel => 'Ana para birimi';

  @override
  String get settingsFirstDayOfWeekLabel => 'Haftanın ilk günü';

  @override
  String get settingsFirstDayMonday => 'Pazartesi';

  @override
  String get settingsFirstDaySunday => 'Pazar';

  @override
  String get settingsExchangeRatesLabel => 'Döviz kurları';

  @override
  String get settingsExchangeRatesSubtitle =>
      'Kayıtlı kurları görüntüle ve düzenle';

  @override
  String get settingsBackupLabel => 'Yedekleme';

  @override
  String get settingsBackupExport => 'Yedek al';

  @override
  String get settingsBackupImport => 'Yedeği geri yükle';

  @override
  String get settingsSectionGeneral => 'Genel';

  @override
  String get settingsAboutLabel => 'Hakkında';

  @override
  String get settingsDeveloperLabel => 'Geliştirici';

  @override
  String get settingsAppVersionLabel => 'Uygulama sürümü';

  @override
  String settingsAppVersionValue(String version, String buildNumber) {
    return '$version ($buildNumber)';
  }

  @override
  String get baseCurrencyChangeWarningTitle => 'Ana para birimini değiştir';

  @override
  String get baseCurrencyChangeWarningBody =>
      'Geçmiş işlemler, kaydedildikleri kur ve ana para birimi tutarıyla kalır; hiçbiri yeniden hesaplanmaz. Yalnızca bundan sonraki yeni işlemler yeni ana para birimine göre kaydedilir. Bu nedenle değişiklik tarihini kapsayan raporlar, eski ve yeni para birimine göre dönüştürülmüş tutarları birlikte gösterebilir.';

  @override
  String get exchangeRatesTitle => 'Döviz kurları';

  @override
  String get exchangeRateAdd => 'Kur ekle';

  @override
  String get exchangeRatesEmpty => 'Kayıtlı kur yok';

  @override
  String get exchangeRateFromLabel => 'Kaynak para birimi';

  @override
  String get exchangeRateToLabel => 'Hedef para birimi';

  @override
  String get exchangeRateValueLabel => 'Kur';

  @override
  String get exchangeRateDateLabel => 'Tarih';

  @override
  String get exchangeRateSameCurrency =>
      'Kaynak ve hedef para birimi farklı olmalı.';

  @override
  String get exchangeRateDeleteTitle => 'Kuru sil';

  @override
  String get exchangeRateDeleteBody => 'Bu kur kaydı silinsin mi?';

  @override
  String get backupImportWarningTitle => 'Yedeği geri yükle';

  @override
  String get backupImportWarningBody =>
      'Bu işlem mevcut tüm verilerinizin üzerine yazacaktır. Bu işlem geri alınamaz. Emin misiniz?';

  @override
  String get backupImportSuccessTitle => 'Geri yükleme tamamlandı';

  @override
  String get backupImportSuccessBody =>
      'Değişikliklerin tamamının uygulanması için lütfen uygulamayı kapatıp yeniden açın.';

  @override
  String get backupImportInvalid =>
      'Geçersiz veya desteklenmeyen yedek dosyası.';

  @override
  String get backupExportSuccess => 'Yedek dosyası oluşturuldu.';

  @override
  String get backupError => 'Bir hata oluştu.';
}
