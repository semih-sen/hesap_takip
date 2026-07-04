import 'pending_action_queue.dart';
import 'undoable_action.dart';

/// Applies the pending-action [queue] over a base list from a repo stream —
/// the ONLY place the visible list diverges from the DB (PROJECT_PLAN §8.5).
///
/// For each item: drop it if a pending DELETE targets it; otherwise substitute
/// the pending UPDATE's new value if one targets it. Reusable across entities so
/// accounts/wallets (and later transactions/categories) don't duplicate this.
List<T> applyOverlay<T>({
  required List<T> base,
  required List<PendingEntry> queue,
  required EntityRef Function(T item) refOf,
}) {
  final List<T> result = <T>[];
  for (final T item in base) {
    final EntityRef ref = refOf(item);
    if (queue.isPendingDeleted(ref)) {
      continue;
    }
    final Object? override = queue.overrideFor(ref);
    result.add(override is T ? override : item);
  }
  return result;
}
