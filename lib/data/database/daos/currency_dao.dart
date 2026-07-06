import 'package:drift/drift.dart';
import '../../../core/currency/currency.dart';

import '../app_database.dart';
import '../tables/currencies.dart';

part 'currency_dao.g.dart';

@DriftAccessor(tables: [Currencies])
class CurrencyDao extends DatabaseAccessor<AppDatabase>
    with _$CurrencyDaoMixin {
  CurrencyDao(super.db);

  Stream<List<Currency>> watchAll() {
    return select(currencies).watch().map(
          (List<CurrencyData> rows) => rows.map(_mapRow).toList(),
        );
  }

  Future<List<Currency>> getAll() async {
    final List<CurrencyData> rows = await select(currencies).get();
    return rows.map(_mapRow).toList();
  }

  Future<void> insertOrUpdate(Currency currency) {
    return into(currencies).insertOnConflictUpdate(
      CurrenciesCompanion.insert(
        code: currency.code,
        symbol: currency.symbol,
        minorDigits: currency.minorDigits,
        symbolOnLeft: currency.symbolOnLeft,
      ),
    );
  }

  Currency _mapRow(CurrencyData row) {
    return Currency(
      code: row.code,
      symbol: row.symbol,
      minorDigits: row.minorDigits,
      symbolOnLeft: row.symbolOnLeft,
    );
  }

  Future<void> deleteCurrency(String code) {
    return (delete(currencies)..where((t) => t.code.equals(code))).go();
  }

  /// Returns true if this currency code is used by any wallet or transaction.
  Future<bool> isInUse(String code) async {
    final bool usedInWallets = await _isUsedInWallets(code);
    if (usedInWallets) return true;

    // Check transactions (if a currency is used directly in transactions).
    // Transactions always belong to a wallet which has a currency, 
    // but cross-currency transfers might record it, or settings baseCurrencyCode.
    final bool isBaseCurrency = await _isBaseCurrency(code);
    return isBaseCurrency;
  }

  Future<bool> _isUsedInWallets(String code) async {
    final countExp = db.wallets.id.count();
    final query = db.selectOnly(db.wallets)
      ..addColumns([countExp])
      ..where(db.wallets.currencyCode.equals(code));
    final row = await query.getSingle();
    final int count = row.read(countExp) ?? 0;
    return count > 0;
  }

  Future<bool> _isBaseCurrency(String code) async {
    final settings = await db.select(db.appSettings).getSingle();
    return settings.baseCurrencyCode == code;
  }
}
