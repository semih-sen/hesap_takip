import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/models/recurring_rule.dart';
import '../../../data/repositories/recurring_repository.dart';
import '../services/recurring_service.dart';

part 'recurring_providers.g.dart';

/// Cold-start recurring generation, run once. Wired above `MaterialApp.router`
/// as a fire-and-forget `ref.watch` — a local SQLite batch, so the first frame
/// is never gated on it (§B.5). Yields the number of transactions generated.
@riverpod
Future<int> recurringGeneration(Ref ref) {
  return ref.watch(recurringServiceProvider).generateDueEntries(DateTime.now());
}

/// All recurring rules (active + paused), newest-config-first, for the CRUD
/// list screen. Delegates to the repository stream.
@riverpod
Stream<List<RecurringRule>> recurringRules(Ref ref) {
  return ref.watch(recurringRepositoryProvider).watchRules();
}
