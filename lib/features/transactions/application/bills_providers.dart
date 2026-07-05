import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/undo/optimistic_overlay.dart';
import '../../../core/undo/pending_action_queue.dart';
import '../../../core/undo/undoable_action.dart';
import '../../../data/database/app_database.dart' as db;
import '../../../data/database/app_database_provider.dart';
import '../../../data/database/tables/enums.dart';

part 'bills_providers.g.dart';

/// Immutable, presentational view-model for one bill/receivable (a pending or
/// completed parent). All money fields are minor units in the bill's own
/// [currencyCode]. [remainingMinor] is `planned − settled`, clamped at 0.
class BillRow {
  const BillRow({
    required this.id,
    required this.type,
    required this.status,
    required this.title,
    required this.plannedMinor,
    required this.settledMinor,
    required this.currencyCode,
    required this.valueDate,
    this.payee,
    this.note,
  });

  final int id;
  final TransactionType type;
  final TransactionStatus status;

  /// Payee, else note; null → the widget falls back to the type label.
  final String? title;
  final int plannedMinor;
  final int settledMinor;
  final String currencyCode;
  final DateTime valueDate;
  final String? payee;
  final String? note;

  int get remainingMinor {
    final int r = plannedMinor - settledMinor;
    return r < 0 ? 0 : r;
  }

  /// Fraction settled in `[0, 1]` for the progress bar.
  double get progress =>
      plannedMinor <= 0 ? 0 : (settledMinor / plannedMinor).clamp(0.0, 1.0);

  bool get isFullySettled => settledMinor >= plannedMinor;
}

/// Immutable view-model for one child payment on a bill's history. Carries what
/// the history tile and the reversal action need — never a Drift row (riverpod
/// codegen cannot emit an import-prefixed Drift type in a provider signature).
class PaymentRow {
  const PaymentRow({
    required this.id,
    required this.parentId,
    required this.amountMinor,
    required this.currencyCode,
    required this.valueDate,
    required this.settledContribMinor,
    this.note,
  });

  final int id;
  final int parentId;
  final int amountMinor;
  final String currencyCode;
  final DateTime valueDate;

  /// This child's contribution in the PARENT's currency (restored on reversal).
  final int settledContribMinor;
  final String? note;
}

PaymentRow _toPaymentRow(db.Transaction t) => PaymentRow(
  id: t.id,
  parentId: t.parentTransactionId ?? 0,
  amountMinor: t.amountMinor,
  currencyCode: t.currencyCode,
  valueDate: t.valueDate,
  settledContribMinor: t.settledContribMinor ?? 0,
  note: _clean(t.note),
);

BillRow _toBillRow(db.Transaction t) => BillRow(
  id: t.id,
  type: t.type,
  status: t.status,
  title: _clean(t.payee) ?? _clean(t.note),
  plannedMinor: t.plannedAmountMinor ?? 0,
  settledMinor: t.settledAmountMinor ?? 0,
  currencyCode: t.currencyCode,
  valueDate: t.valueDate,
  payee: _clean(t.payee),
  note: _clean(t.note),
);

String? _clean(String? value) {
  if (value == null) {
    return null;
  }
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// All bill-parents (pending + completed) newest-first, straight from the DB.
@riverpod
Stream<List<BillRow>> billParents(Ref ref) => ref
    .watch(appDatabaseProvider)
    .transactionDao
    .watchBillParents()
    .map(
      (List<db.Transaction> rows) =>
          rows.map(_toBillRow).toList(growable: false),
    );

/// Bills as the user should SEE them = the DB stream with the pending-undo
/// overlay applied (a queued bill delete disappears instantly, reappears on
/// undo). Only PENDING bills are surfaced on the screen.
@riverpod
List<BillRow> visibleBills(Ref ref) {
  final List<BillRow> base =
      ref.watch(billParentsProvider).asData?.value ?? const <BillRow>[];
  final List<PendingEntry> queue = ref.watch(pendingActionQueueProvider);
  final List<BillRow> overlaid = applyOverlay<BillRow>(
    base: base,
    queue: queue,
    refOf: (BillRow b) => EntityRef(UndoEntityType.transaction, b.id),
  );
  return overlaid
      .where((BillRow b) => b.status == TransactionStatus.pending)
      .toList(growable: false);
}

/// One bill by [id] from the current visible stream, or null once it is gone.
@riverpod
BillRow? bill(Ref ref, int id) {
  for (final BillRow b in ref.watch(billParentsProvider).asData?.value ??
      const <BillRow>[]) {
    if (b.id == id) {
      return b;
    }
  }
  return null;
}

/// The child payments of the bill [parentId], oldest-first.
@riverpod
Stream<List<PaymentRow>> billChildren(Ref ref, int parentId) => ref
    .watch(appDatabaseProvider)
    .transactionDao
    .watchChildren(parentId)
    .map(
      (List<db.Transaction> rows) =>
          rows.map(_toPaymentRow).toList(growable: false),
    );

/// Child payments as the user should SEE them = the DB stream with the
/// pending-undo overlay applied (a queued reversal disappears instantly).
@riverpod
List<PaymentRow> visibleBillChildren(Ref ref, int parentId) {
  final List<PaymentRow> base =
      ref.watch(billChildrenProvider(parentId)).asData?.value ??
      const <PaymentRow>[];
  final List<PendingEntry> queue = ref.watch(pendingActionQueueProvider);
  return applyOverlay<PaymentRow>(
    base: base,
    queue: queue,
    refOf: (PaymentRow c) => EntityRef(UndoEntityType.transaction, c.id),
  );
}
