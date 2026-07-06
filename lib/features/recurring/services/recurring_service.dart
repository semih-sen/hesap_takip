import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/currency/currency_service.dart';
import '../../../core/date/app_date.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/app_database_provider.dart';
import '../../../data/database/tables/enums.dart';

part 'recurring_service.g.dart';

/// The recurring-transaction generation engine (PROJECT_PLAN §8.4 / Phase 10).
///
/// Follows the plain-service-over-[AppDatabase] convention of `TransferService`
/// / `SettlementService`. [generateDueEntries] walks every active rule, emitting
/// each scheduled occurrence dated on-or-before `now` that has not been emitted
/// yet, and advancing the rule's `lastGeneratedDate`/`generatedCount`.
///
/// Occurrences are settle-in-place compatible (Phase 9 rework): a non-`autoPost`
/// occurrence is a **plain pending row** (`status: pending`, no
/// `plannedAmountMinor`/`settledAmountMinor`), immediately usable by the
/// swipe-to-settle flow. `autoPost` occurrences are `completed` and move
/// balances. Each occurrence's base snapshot is resolved FRESH at generation
/// time from the cached rate (§6), never re-derived later.
class RecurringService {
  RecurringService(this._db, this._currency);

  final AppDatabase _db;
  final CurrencyService _currency;

  /// Malformed-rule safety valve: the per-rule occurrence loop never iterates
  /// more than this many times (a bug that fails to advance the anchor would
  /// otherwise spin forever).
  static const int _maxIterationsPerRule = 10000;

  /// Generates every due occurrence across all active rules, returning the count
  /// of transactions actually inserted (for the "generate now" UI feedback).
  /// Idempotent: re-running for the same [now] inserts nothing new.
  Future<int> generateDueEntries(DateTime now) async {
    final DateTime today = AppDate.dateOnly(now);
    final DateTime horizon = AppDate.addMonthsClamped(today, 6);
    final List<RecurringRule> rules = await _db.recurringDao.getActiveRules();
    final String base = (await _db.settingsDao.getSettings()).baseCurrencyCode;
    int totalInserted = 0;
    for (final RecurringRule rule in rules) {
      totalInserted += await _generateForRule(rule, today, horizon, base);
    }
    return totalInserted;
  }

  Future<int> _generateForRule(
    RecurringRule rule,
    DateTime today,
    DateTime horizon,
    String base,
  ) async {
    final DateTime start = AppDate.dateOnly(rule.startDate);
    final DateTime? endDate = rule.endDate == null
        ? null
        : AppDate.dateOnly(rule.endDate!);
    // Anchor = last occurrence already accounted for (EXCLUSIVE). The initial
    // anchor is the day before startDate so the first occurrence is startDate.
    DateTime anchor = rule.lastGeneratedDate == null
        ? start.subtract(const Duration(days: 1))
        : AppDate.dateOnly(rule.lastGeneratedDate!);
    int generatedCount = rule.generatedCount;
    int inserted = 0;
    int guard = 0;

    while (true) {
      if (++guard > _maxIterationsPerRule) {
        break;
      }
      final DateTime? next = nextOccurrenceAfter(anchor, rule);
      if (next == null || next.isAfter(horizon)) {
        break;
      }
      if (endDate != null && next.isAfter(endDate)) {
        break;
      }
      if (rule.maxOccurrences != null &&
          generatedCount >= rule.maxOccurrences!) {
        break;
      }

      final _RateSnapshot snap = await _resolveSnapshot(rule, base, next);
      final bool isProjected = next.isAfter(today);
      bool didInsert = false;
      try {
        await _db.transaction(() async {
          final int txnId = await _db.transactionDao.createTransaction(
            TransactionsCompanion.insert(
              walletId: rule.walletId,
              type: rule.type,
              flowDirection: rule.flowDirection,
              // Explicit override: generation now projects into the future,
              // so any future transaction must be pending.
              status: (rule.autoPost && !isProjected)
                  ? TransactionStatus.completed
                  : TransactionStatus.pending,
              amountMinor: rule.amountMinor,
              currencyCode: rule.currencyCode,
              exchangeRateToBase: snap.rate,
              baseAmountMinor: snap.baseMinor,
              valueDate: next,
              note: Value(rule.note),
              recurringRuleId: Value(rule.id),
            ),
          );
          final List<int> catIds = await _db.recurringDao.getCategoryIdsForRule(
            rule.id,
          );
          for (final int catId in catIds) {
            await _db.transactionDao.addCategory(txnId, catId);
          }
          generatedCount += 1;
          await _db.recurringDao.markGenerated(
            rule.id,
            lastGeneratedDate: next,
            generatedCount: generatedCount,
          );
          didInsert = true;
        });
      } catch (e) {
        // Idempotency guard: the partial unique index ux_txn_recurring_date
        // rejects a duplicate (recurring_rule_id, value_date). Skip it and keep
        // going; never abort the rule's remaining occurrences. Anything else is
        // a real error.
        if (!e.toString().contains('UNIQUE constraint')) {
          rethrow;
        }
      }
      if (didInsert) {
        inserted += 1;
      }
      anchor = next;
    }
    return inserted;
  }

  /// The first scheduled occurrence strictly after [anchor] for [rule], or null
  /// if the frequency is unsupported. The first-ever occurrence (anchor before
  /// `startDate`) is `startDate` itself; thereafter the cadence advances by
  /// `interval` units, honoring `byMonthDay` (monthly/yearly) and `byWeekday`
  /// (weekly). Monthly/yearly clamp via [AppDate.addMonthsClamped] so a
  /// 31st-of-month rule never drifts.
  DateTime? nextOccurrenceAfter(DateTime anchor, RecurringRule rule) {
    final DateTime start = AppDate.dateOnly(rule.startDate);
    if (anchor.isBefore(start)) {
      return start;
    }
    final int interval = rule.interval < 1 ? 1 : rule.interval;
    switch (rule.frequency) {
      case RecurrenceFrequency.daily:
        return anchor.add(Duration(days: interval));
      case RecurrenceFrequency.weekly:
        DateTime base = anchor.add(Duration(days: 7 * interval));
        if (rule.byWeekday != null) {
          base = base.add(Duration(days: rule.byWeekday! - base.weekday));
        }
        return base;
      case RecurrenceFrequency.monthly:
        return AppDate.addMonthsClamped(
          anchor,
          interval,
          dayOverride: rule.byMonthDay ?? start.day,
        );
      case RecurrenceFrequency.yearly:
        return AppDate.addMonthsClamped(
          anchor,
          12 * interval,
          dayOverride: rule.byMonthDay ?? start.day,
        );
    }
  }

  Future<_RateSnapshot> _resolveSnapshot(
    RecurringRule rule,
    String base,
    DateTime asOf,
  ) async {
    if (rule.currencyCode == base) {
      return _RateSnapshot(Decimal.one, rule.amountMinor);
    }
    final ExchangeRate? cached = await _db.exchangeRateDao.getLatestRate(
      baseCurrency: rule.currencyCode,
      quoteCurrency: base,
      asOf: asOf,
    );
    final Decimal rate = cached?.rate ?? Decimal.one;
    final int baseMinor = _currency.convertMinor(
      amountMinor: rule.amountMinor,
      fromCode: rule.currencyCode,
      toCode: base,
      rate: rate,
    );
    return _RateSnapshot(rate, baseMinor);
  }
}

/// A resolved rate + base-amount snapshot for one generated occurrence.
class _RateSnapshot {
  const _RateSnapshot(this.rate, this.baseMinor);
  final Decimal rate;
  final int baseMinor;
}

/// App-lifetime singleton [RecurringService].
@Riverpod(keepAlive: true)
RecurringService recurringService(Ref ref) =>
    RecurringService(ref.watch(appDatabaseProvider), ref.watch(currencyServiceProvider));
