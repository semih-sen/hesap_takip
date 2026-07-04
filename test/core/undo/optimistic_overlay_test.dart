import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/core/undo/optimistic_overlay.dart';
import 'package:hesap_takip/core/undo/pending_action_queue.dart';
import 'package:hesap_takip/core/undo/undoable_action.dart';

/// A minimal domain-like item for the overlay unit tests.
class _Item {
  const _Item(this.id, this.name);
  final int id;
  final String name;
}

/// A hand-rolled action so the overlay can be tested without a database.
class _FakeAction extends UndoableAction {
  _FakeAction(this.target, this.effect);

  @override
  final EntityRef target;
  @override
  final UndoEffect effect;
  @override
  String get label => 'fake';
  @override
  Future<bool> canCommit(dynamic db) async => true;
  @override
  Future<void> commit(dynamic db) async {}
}

PendingEntry _entry(String id, EntityRef ref, UndoEffect effect) =>
    PendingEntry(
      id: id,
      action: _FakeAction(ref, effect),
      queuedAt: DateTime(2026, 1, 1),
    );

EntityRef _walletRef(int id) => EntityRef(UndoEntityType.wallet, id);

void main() {
  final List<_Item> base = <_Item>[
    const _Item(1, 'A'),
    const _Item(2, 'B'),
    const _Item(3, 'C'),
  ];

  List<_Item> overlay(List<PendingEntry> queue) => applyOverlay<_Item>(
    base: base,
    queue: queue,
    refOf: (_Item i) => _walletRef(i.id),
  );

  test('empty queue passes the list through unchanged', () {
    final List<_Item> result = overlay(const <PendingEntry>[]);
    expect(result.map((i) => i.id), <int>[1, 2, 3]);
  });

  test('a pending DELETE hides its target', () {
    final List<PendingEntry> queue = <PendingEntry>[
      _entry('e', _walletRef(2), const DeleteEffect()),
    ];
    expect(queue.isPendingDeleted(_walletRef(2)), isTrue);
    expect(overlay(queue).map((i) => i.id), <int>[1, 3]);
  });

  test('removing the entry re-shows the item (undo reverts the overlay)', () {
    final List<PendingEntry> queue = <PendingEntry>[
      _entry('e', _walletRef(2), const DeleteEffect()),
    ];
    final List<PendingEntry> afterUndo = queue
        .where((PendingEntry e) => e.id != 'e')
        .toList();
    expect(overlay(afterUndo).map((i) => i.id), <int>[1, 2, 3]);
  });

  test('a pending UPDATE substitutes the new value', () {
    const _Item replacement = _Item(2, 'B-edited');
    final List<PendingEntry> queue = <PendingEntry>[
      _entry('e', _walletRef(2), const UpdateEffect(replacement)),
    ];
    expect(queue.overrideFor(_walletRef(2)), same(replacement));
    final List<_Item> result = overlay(queue);
    expect(result[1].name, 'B-edited');
    expect(result.map((i) => i.id), <int>[1, 2, 3]);
  });

  test('overrideFor/isPendingDeleted are null/false for untargeted refs', () {
    final List<PendingEntry> queue = <PendingEntry>[
      _entry('e', _walletRef(2), const DeleteEffect()),
    ];
    expect(queue.overrideFor(_walletRef(1)), isNull);
    expect(queue.isPendingDeleted(_walletRef(3)), isFalse);
  });
}
