import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/undo/optimistic_overlay.dart';
import '../../../core/undo/pending_action_queue.dart';
import '../../../core/undo/undoable_action.dart';
import '../../../data/models/account.dart';
import '../../../data/repositories/account_repository.dart';

part 'accounts_providers.g.dart';

/// Raw reactive account stream from the repository.
@riverpod
Stream<List<Account>> accountsStream(Ref ref) =>
    ref.watch(accountRepositoryProvider).watchAccounts();

/// Accounts as the user should SEE them = DB stream with the pending-undo
/// overlay applied (a queued delete disappears instantly; a queued update shows
/// its new value). Recomputes when either the stream or the queue changes.
@riverpod
List<Account> visibleAccounts(Ref ref) {
  final List<Account> base =
      ref.watch(accountsStreamProvider).asData?.value ?? const <Account>[];
  final List<PendingEntry> queue = ref.watch(pendingActionQueueProvider);
  return applyOverlay<Account>(
    base: base,
    queue: queue,
    refOf: (Account a) => EntityRef(UndoEntityType.account, a.id),
  );
}
