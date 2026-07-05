import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'undoable_action.dart';

part 'pending_action_queue.g.dart';

/// One queued, not-yet-committed action plus its bookkeeping.
class PendingEntry {
  const PendingEntry({
    required this.id,
    required this.action,
    required this.queuedAt,
  });

  /// Opaque unique id (used to cancel/commit/undo this specific entry).
  final String id;
  final UndoableAction action;
  final DateTime queuedAt;
}

/// Pure, reactive query helpers over the queue state, used by the optimistic
/// overlay. Kept as an extension on the list so the overlay stays reactive by
/// simply `ref.watch`-ing the queue provider's value.
extension PendingQueueView on List<PendingEntry> {
  /// The pending entry affecting [ref], or null. Uses [UndoableAction.affects]
  /// so a multi-leg action (transfer delete) matches every row it touches.
  PendingEntry? entryForTarget(EntityRef ref) {
    for (final PendingEntry entry in this) {
      if (entry.action.affects(ref)) {
        return entry;
      }
    }
    return null;
  }

  /// Whether [ref] has a pending DELETE (so the overlay hides it).
  bool isPendingDeleted(EntityRef ref) {
    final PendingEntry? entry = entryForTarget(ref);
    return entry != null && entry.action.effect is DeleteEffect;
  }

  /// The optimistic replacement value for [ref] if a pending UPDATE targets it,
  /// else null (so the overlay shows the DB truth).
  Object? overrideFor(EntityRef ref) {
    final PendingEntry? entry = entryForTarget(ref);
    final UndoEffect? effect = entry?.action.effect;
    return effect is UpdateEffect ? effect.newValue : null;
  }
}

/// App-lifetime queue of pending [UndoableAction]s (PROJECT_PLAN §8.5).
///
/// This Notifier owns only the STATE; timers and the actual commits live in
/// `UndoService`. Widgets watch this provider so the overlay recomputes whenever
/// the queue changes.
@Riverpod(keepAlive: true)
class PendingActionQueue extends _$PendingActionQueue {
  @override
  List<PendingEntry> build() => const <PendingEntry>[];

  /// Public read of the current entries (the notifier's `state` is protected).
  /// `UndoService` uses this to locate entries by id/target.
  List<PendingEntry> get entries => state;

  /// Appends [entry].
  void add(PendingEntry entry) {
    state = <PendingEntry>[...state, entry];
  }

  /// Removes the entry with [id] (no-op if absent). Removing an entry reverts
  /// the overlay implicitly — the list once again reflects the DB.
  void remove(String id) {
    state = state
        .where((PendingEntry entry) => entry.id != id)
        .toList(growable: false);
  }
}
