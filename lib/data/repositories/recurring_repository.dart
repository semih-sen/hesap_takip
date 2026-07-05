import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart' as db;
import '../database/app_database_provider.dart';
import '../models/mappers/recurring_mapper.dart';
import '../models/recurring_rule.dart';

part 'recurring_repository.g.dart';

/// Reactive data API for recurring rules, returning DOMAIN [RecurringRule]
/// models. The generation engine (`RecurringService`) lands in Phase 10.
abstract interface class RecurringRepository {
  /// Recurring rules; only `isActive` ones when [activeOnly] is true.
  Stream<List<RecurringRule>> watchRules({bool activeOnly = false});

  /// One-shot fetch of the active rules (for batch generation, not a stream).
  Future<List<RecurringRule>> getActiveRules();

  /// The rule with [id], or `null`.
  Future<RecurringRule?> findRule(int id);

  /// Inserts [rule] and returns the new row id.
  Future<int> createRule(RecurringRule rule);

  /// Replaces the stored rule matching [rule]'s id.
  Future<void> updateRule(RecurringRule rule);

  /// Hard-deletes the rule (cascades its category links).
  Future<void> deleteRule(int id);

  /// The category ids linked to [ruleId].
  Future<List<int>> getCategoryIds(int ruleId);

  /// Replaces ALL category links for [ruleId] with [categoryIds].
  Future<void> setCategories(int ruleId, List<int> categoryIds);

  /// Pauses/resumes [ruleId] (toggles `isActive`; no undo).
  Future<void> setActive(int ruleId, bool isActive);

  /// Caps [ruleId]'s future generation at [endDate] (series-edit "this and
  /// future"), leaving already-generated rows untouched.
  Future<void> setEndDate(int ruleId, DateTime endDate);
}

class DriftRecurringRepository implements RecurringRepository {
  DriftRecurringRepository(this._db);

  final db.AppDatabase _db;

  @override
  Stream<List<RecurringRule>> watchRules({bool activeOnly = false}) {
    final Stream<List<db.RecurringRule>> rows = activeOnly
        ? _db.recurringDao.watchActiveRules()
        : _db.recurringDao.watchAllRules();
    return rows.map((list) => list.map((row) => row.toDomain()).toList());
  }

  @override
  Future<List<RecurringRule>> getActiveRules() async =>
      (await _db.recurringDao.getActiveRules())
          .map((row) => row.toDomain())
          .toList();

  @override
  Future<RecurringRule?> findRule(int id) async =>
      (await _db.recurringDao.getRuleById(id))?.toDomain();

  @override
  Future<int> createRule(RecurringRule rule) =>
      _db.recurringDao.createRule(rule.toInsertCompanion());

  @override
  Future<void> updateRule(RecurringRule rule) =>
      _db.recurringDao.updateRule(rule.toRow());

  @override
  Future<void> deleteRule(int id) => _db.recurringDao.deleteRule(id);

  @override
  Future<List<int>> getCategoryIds(int ruleId) =>
      _db.recurringDao.getCategoryIdsForRule(ruleId);

  @override
  Future<void> setCategories(int ruleId, List<int> categoryIds) =>
      _db.recurringDao.replaceCategoryLinks(ruleId, categoryIds);

  @override
  Future<void> setActive(int ruleId, bool isActive) =>
      _db.recurringDao.setActive(ruleId, isActive);

  @override
  Future<void> setEndDate(int ruleId, DateTime endDate) =>
      _db.recurringDao.setEndDate(ruleId, endDate);
}

/// App-lifetime singleton recurring-rule repository.
@Riverpod(keepAlive: true)
RecurringRepository recurringRepository(Ref ref) =>
    DriftRecurringRepository(ref.watch(appDatabaseProvider));
