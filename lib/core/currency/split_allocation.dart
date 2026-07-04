/// Thrown when a set of per-category split allocations cannot be reconciled
/// with the transaction total (PROJECT_PLAN §5.1 / §6).
///
/// Carries the offending numbers so the UI can surface a precise, localized
/// Turkish message.
class SplitAllocationException implements Exception {
  const SplitAllocationException(this.totalMinor, this.allocatedMinor);

  /// The transaction total the split had to sum to.
  final int totalMinor;

  /// The sum the caller's non-last allocations already reached.
  final int allocatedMinor;

  @override
  String toString() =>
      'SplitAllocationException: allocations ($allocatedMinor) cannot be '
      'reconciled with total ($totalMinor)';
}

/// Reconciles per-category split [allocations] so they sum EXACTLY to
/// [totalMinor], with the **last** allocation absorbing any rounding remainder
/// (PROJECT_PLAN §6: "the last allocation absorbs the rounding remainder so
/// allocations always sum to the total").
///
/// Rules:
/// - An empty list is invalid.
/// - Every allocation must be strictly positive (a zero/negative split is
///   meaningless).
/// - The last allocation is recomputed to `totalMinor − Σ(others)`. If that is
///   not strictly positive the earlier allocations already meet or exceed the
///   total (an over-split) → [SplitAllocationException].
///
/// Passing allocations that already sum exactly returns them unchanged.
List<int> resolveSplitAllocations(int totalMinor, List<int> allocations) {
  if (allocations.isEmpty) {
    throw SplitAllocationException(totalMinor, 0);
  }
  for (int i = 0; i < allocations.length - 1; i++) {
    if (allocations[i] <= 0) {
      throw SplitAllocationException(totalMinor, allocations[i]);
    }
  }
  if (allocations.last <= 0) {
    throw SplitAllocationException(totalMinor, allocations.last);
  }

  final int sumExceptLast = allocations
      .take(allocations.length - 1)
      .fold<int>(0, (int acc, int a) => acc + a);
  final int adjustedLast = totalMinor - sumExceptLast;
  if (adjustedLast <= 0) {
    // The non-last allocations already reached/exceeded the total.
    throw SplitAllocationException(totalMinor, sumExceptLast);
  }

  return <int>[...allocations.take(allocations.length - 1), adjustedLast];
}
