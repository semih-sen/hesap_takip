import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/recurring.dart';

part 'recurring_dao.g.dart';

/// Data access for [RecurringRules] and the [RecurringRuleCategories] junction.
@DriftAccessor(tables: [RecurringRules, RecurringRuleCategories])
class RecurringDao extends DatabaseAccessor<AppDatabase>
    with _$RecurringDaoMixin {
  RecurringDao(super.db);

  Future<int> createRule(RecurringRulesCompanion entry) =>
      into(recurringRules).insert(entry);

  Future<bool> updateRule(RecurringRule entry) =>
      update(recurringRules).replace(entry);

  Future<int> deleteRule(int id) =>
      (delete(recurringRules)..where((t) => t.id.equals(id))).go();

  Future<RecurringRule?> getRuleById(int id) =>
      (select(recurringRules)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<RecurringRule>> watchAllRules() => (select(
    recurringRules,
  )..orderBy([(t) => OrderingTerm(expression: t.createdAt)])).watch();

  Stream<List<RecurringRule>> watchActiveRules() =>
      (select(recurringRules)..where((t) => t.isActive.equals(true))).watch();

  Future<void> addCategory(int ruleId, int categoryId) {
    return into(recurringRuleCategories).insert(
      RecurringRuleCategoriesCompanion.insert(
        ruleId: ruleId,
        categoryId: categoryId,
      ),
    );
  }
}
