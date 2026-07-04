import '../../data/database/app_database.dart';

/// The kinds of entity an [UndoableAction] can target. Used by [EntityRef] so
/// the optimistic overlay can match a queued action to a list item by identity.
enum UndoEntityType { transaction, category, wallet, account }

/// A stable identity for an entity: its [type] plus its integer primary key.
///
/// Value equality lets the overlay look up "is there a pending action for this
/// row?" cheaply and correctly across list rebuilds.
class EntityRef {
  const EntityRef(this.type, this.id);

  final UndoEntityType type;
  final int id;

  @override
  bool operator ==(Object other) =>
      other is EntityRef && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);

  @override
  String toString() => 'EntityRef(${type.name}, $id)';
}

/// What a queued action will do to its target, from the overlay's point of view.
///
/// A plain `sealed` hierarchy (no Freezed needed): the overlay switches on the
/// two cases to decide whether to hide a row ([DeleteEffect]) or substitute a
/// new value for it ([UpdateEffect]).
sealed class UndoEffect {
  const UndoEffect();
}

/// The target row should disappear from the visible list during the window.
class DeleteEffect extends UndoEffect {
  const DeleteEffect();
}

/// The target row should render as [newValue] during the window.
class UpdateEffect extends UndoEffect {
  const UpdateEffect(this.newValue);

  /// The optimistic replacement (a domain model of the target's type).
  final Object newValue;
}

/// A deferred, reversible mutation (Command Pattern, PROJECT_PLAN §8.5).
///
/// The REAL Drift write happens only in [commit], invoked by `UndoService`
/// after the undo window expires (or on a lifecycle flush). During the window
/// the database is untouched and the UI shows an optimistic overlay derived from
/// [target] + [effect].
abstract class UndoableAction {
  const UndoableAction();

  /// User-facing, already-localized Turkish text for the SnackBar. The UI caller
  /// resolves it from the ARB and passes it in, so no Turkish is hardcoded here.
  String get label;

  /// Identity of the row this action affects (drives the overlay).
  EntityRef get target;

  /// How the overlay should render the target while the action is pending.
  UndoEffect get effect;

  /// Enqueue-time pre-check for whether [commit] can succeed — e.g. FK
  /// deletability. Async because that answer requires a DB read (a deliberate
  /// deviation from a synchronous sketch: deletability is not knowable without
  /// querying). If this returns false the UI must show a message and NOT queue.
  Future<bool> canCommit(AppDatabase db);

  /// The real write. Runs INSIDE `appDatabase.transaction(...)` supplied by
  /// `UndoService`, so implementations just perform their DAO calls.
  Future<void> commit(AppDatabase db);
}
