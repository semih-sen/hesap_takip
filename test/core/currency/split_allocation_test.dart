import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/core/currency/split_allocation.dart';

void main() {
  group('resolveSplitAllocations', () {
    test('allocations that already sum exactly are unchanged', () {
      expect(
        resolveSplitAllocations(1000, <int>[300, 300, 400]),
        <int>[300, 300, 400],
      );
    });

    test('the last allocation absorbs a rounding remainder', () {
      // The provided last (401) is overwritten so the set sums exactly to 1000.
      final List<int> result = resolveSplitAllocations(1000, <int>[300, 300, 401]);
      expect(result, <int>[300, 300, 400]);
      expect(result.fold<int>(0, (int a, int b) => a + b), 1000);
    });

    test('a single allocation absorbs the whole total', () {
      expect(resolveSplitAllocations(1000, <int>[999]), <int>[1000]);
    });

    test('over-split (earlier allocations exceed the total) is rejected', () {
      expect(
        () => resolveSplitAllocations(1000, <int>[1100, 50]),
        throwsA(isA<SplitAllocationException>()),
      );
    });

    test('a non-positive non-last allocation is rejected', () {
      expect(
        () => resolveSplitAllocations(1000, <int>[0, 500]),
        throwsA(isA<SplitAllocationException>()),
      );
    });

    test('a non-positive last allocation is rejected', () {
      expect(
        () => resolveSplitAllocations(1000, <int>[500, -1]),
        throwsA(isA<SplitAllocationException>()),
      );
    });

    test('empty allocations are rejected', () {
      expect(
        () => resolveSplitAllocations(1000, <int>[]),
        throwsA(isA<SplitAllocationException>()),
      );
    });
  });
}
