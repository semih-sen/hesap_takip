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

  /// One-shot fetch of active rules for the batch generation job (which must not
  /// hold a live stream subscription). Mirrors [watchActiveRules]'s filter.
  Future<List<RecurringRule>> getActiveRules() =>
      (select(recurringRules)..where((t) => t.isActive.equals(true))).get();

  Future<void> addCategory(int ruleId, int categoryId) {
    return into(recurringRuleCategories).insert(
      RecurringRuleCategoriesCompanion.insert(
        ruleId: ruleId,
        categoryId: categoryId,
      ),
    );
  }

  /// The category ids linked to [ruleId] (order-insensitive). Used to copy a
  /// rule's categories onto each generated transaction, and to prefill the form.
  Future<List<int>> getCategoryIdsForRule(int ruleId) async {
    final List<RecurringRuleCategory> rows =
        await (select(recurringRuleCategories)
              ..where((t) => t.ruleId.equals(ruleId)))
            .get();
    return rows.map((RecurringRuleCategory r) => r.categoryId).toList();
  }

  /// Replaces ALL category links for [ruleId] with [categoryIds]. Callers that
  /// also mutate the rule row wrap this in one `db.transaction`.
  Future<void> replaceCategoryLinks(int ruleId, List<int> categoryIds) async {
    await (delete(
      recurringRuleCategories,
    )..where((t) => t.ruleId.equals(ruleId))).go();
    if (categoryIds.isEmpty) {
      return;
    }
    await batch(
      (Batch b) => b.insertAll(recurringRuleCategories, <RecurringRuleCategoriesCompanion>[
        for (final int id in categoryIds)
          RecurringRuleCategoriesCompanion.insert(ruleId: ruleId, categoryId: id),
      ]),
    );
  }

  /// Records that an occurrence dated [lastGeneratedDate] was generated for
  /// [ruleId], advancing the cached [generatedCount]. A targeted column write
  /// (not a full-row replace) so concurrent fields are untouched.
  Future<void> markGenerated(
    int ruleId, {
    required DateTime lastGeneratedDate,
    required int generatedCount,
  }) {
    return (update(recurringRules)..where((t) => t.id.equals(ruleId))).write(
      RecurringRulesCompanion(
        lastGeneratedDate: Value(lastGeneratedDate),
        generatedCount: Value(generatedCount),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Sets [ruleId]'s `endDate` (used by "this and future" series edits to stop a
  /// rule's future generation without touching already-generated rows).
  Future<void> setEndDate(int ruleId, DateTime endDate) {
    return (update(recurringRules)..where((t) => t.id.equals(ruleId))).write(
      RecurringRulesCompanion(
        endDate: Value(endDate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Flips [ruleId]'s active flag (pause/resume; no undo, matching category
  /// archive-toggle).
  Future<void> setActive(int ruleId, bool isActive) {
    return (update(recurringRules)..where((t) => t.id.equals(ruleId))).write(
      RecurringRulesCompanion(
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
