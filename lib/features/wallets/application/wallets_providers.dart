import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/undo/optimistic_overlay.dart';
import '../../../core/undo/pending_action_queue.dart';
import '../../../core/undo/undoable_action.dart';
import '../../../data/models/wallet.dart';
import '../../../data/repositories/wallet_repository.dart';

part 'wallets_providers.g.dart';

/// Raw reactive wallet stream for one account.
@riverpod
Stream<List<Wallet>> walletsStream(Ref ref, int accountId) =>
    ref.watch(walletRepositoryProvider).watchWallets(accountId: accountId);

/// All wallets across every account (for the transaction-form wallet picker).
@riverpod
Stream<List<Wallet>> allWallets(Ref ref) =>
    ref.watch(walletRepositoryProvider).watchWallets();

/// Wallets for [accountId] as the user should SEE them = DB stream with the
/// pending-undo overlay applied.
@riverpod
List<Wallet> visibleWallets(Ref ref, int accountId) {
  final List<Wallet> base =
      ref.watch(walletsStreamProvider(accountId)).asData?.value ??
      const <Wallet>[];
  final List<PendingEntry> queue = ref.watch(pendingActionQueueProvider);
  return applyOverlay<Wallet>(
    base: base,
    queue: queue,
    refOf: (Wallet w) => EntityRef(UndoEntityType.wallet, w.id),
  );
}
