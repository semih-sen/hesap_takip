import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/database/app_database.dart';
import '../../data/database/app_database_provider.dart';
import 'pending_action_queue.dart';
import 'undoable_action.dart';

part 'undo_service.g.dart';

/// Orchestrates delayed-execution undo (PROJECT_PLAN §8.5).
///
/// Enqueue an [UndoableAction] → it is added to [PendingActionQueue] and a
/// single timer starts. During the window the DB is UNCHANGED (a crash simply
/// skips the destructive write — fail-safe). On expiry the action is committed
/// inside one Drift transaction; on [undo] it is dropped with no write.
class UndoService {
  UndoService(
    this._queue,
    this._db, {
    this.window = const Duration(milliseconds: 4500),
    this.onCommitError,
  });

  final PendingActionQueue _queue;
  final AppDatabase _db;

  /// Undo window; injectable so tests can drive a short, deterministic timer.
  final Duration window;

  /// Optional hook invoked if a commit throws (the entry is then dropped so the
  /// service never crashes). Given the enqueue-time `canCommit` pre-check, this
  /// is rare.
  final void Function(UndoableAction action, Object error)? onCommitError;

  final Map<String, Timer> _timers = <String, Timer>{};
  int _counter = 0;

  List<PendingEntry> get _entries => _queue.entries;

  /// Queues [action] for delayed commit and returns its pending id, or null if
  /// [UndoableAction.canCommit] rejected it (e.g. FK-restricted delete) — in
  /// which case nothing is queued and the UI must show a message instead.
  ///
  /// Single-flight per target: if the same target already has a pending entry,
  /// that prior entry is committed FIRST (deterministic ordering) before the new
  /// one is queued.
  Future<String?> enqueue(UndoableAction action) async {
    if (!await action.canCommit(_db)) {
      return null;
    }
    final PendingEntry? prior = _entries.entryForTarget(action.target);
    if (prior != null) {
      await commitNow(prior.id);
    }
    final String id = 'undo_${_counter++}';
    _queue.add(PendingEntry(id: id, action: action, queuedAt: DateTime.now()));
    _timers[id] = Timer(window, () {
      // Fire-and-forget: the timer callback cannot await.
      unawaited(commitNow(id));
    });
    return id;
  }

  /// Cancels the pending action [pendingId] without any DB write. The overlay
  /// reverts implicitly once the entry leaves the queue.
  void undo(String pendingId) {
    _timers.remove(pendingId)?.cancel();
    _queue.remove(pendingId);
  }

  /// Commits the pending action [pendingId] now (timer expiry or supersede),
  /// inside a single Drift transaction, then removes it from the queue. A commit
  /// failure is logged, the entry dropped, and [onCommitError] invoked — never a
  /// crash.
  Future<void> commitNow(String pendingId) async {
    _timers.remove(pendingId)?.cancel();
    final PendingEntry? entry = _entries.entryForTarget4Id(pendingId);
    if (entry == null) {
      return;
    }
    try {
      await _db.transaction(() => entry.action.commit(_db));
    } catch (error, stack) {
      debugPrint('UndoService commit failed for $pendingId: $error\n$stack');
      onCommitError?.call(entry.action, error);
    } finally {
      _queue.remove(pendingId);
    }
  }

  /// SAFETY NET: commits every pending entry immediately (called on app pause,
  /// see `app.dart`). Snapshots ids first so removals during iteration are safe.
  Future<void> flushAllNow() async {
    final List<String> ids = _entries
        .map((PendingEntry e) => e.id)
        .toList(growable: false);
    for (final String id in ids) {
      await commitNow(id);
    }
  }
}

extension on List<PendingEntry> {
  PendingEntry? entryForTarget4Id(String id) {
    for (final PendingEntry entry in this) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }
}

/// App-lifetime [UndoService], wired to the shared queue and database.
@Riverpod(keepAlive: true)
UndoService undoService(Ref ref) => UndoService(
  ref.watch(pendingActionQueueProvider.notifier),
  ref.watch(appDatabaseProvider),
);
