import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/currency/currency.dart';
import '../database/app_database.dart';
import '../database/app_database_provider.dart';
import '../database/daos/currency_dao.dart';

part 'currency_repository.g.dart';

class CurrencyRepository {
  CurrencyRepository(this._dao);

  final CurrencyDao _dao;

  Stream<List<Currency>> watchAllCurrencies() {
    return _dao.watchAll();
  }
  
  Future<List<Currency>> getAllCurrencies() {
    return _dao.getAll();
  }

  Future<void> saveCurrency(Currency currency) {
    return _dao.insertOrUpdate(currency);
  }

  Future<void> deleteCurrency(String code) {
    return _dao.deleteCurrency(code);
  }
  
  Future<bool> isCurrencyInUse(String code) {
    return _dao.isInUse(code);
  }
}

@Riverpod(keepAlive: true)
CurrencyRepository currencyRepository(Ref ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return CurrencyRepository(db.currencyDao);
}
