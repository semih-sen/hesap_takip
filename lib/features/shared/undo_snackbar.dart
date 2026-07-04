import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/undo/undo_service.dart';
import '../../l10n/generated/app_localizations.dart';

/// Shows the Material 3 undo SnackBar after an action was queued.
///
/// The [message] is the already-localized action label; the SnackBar duration
/// matches the undo window, and tapping "Geri al" cancels the pending action
/// (which reverts the optimistic overlay). Showing a new SnackBar dismisses the
/// current one — consistent with the queue's supersede semantics.
void showUndoSnackBar(
  BuildContext context,
  WidgetRef ref, {
  required String pendingId,
  required String message,
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final UndoService undo = ref.read(undoServiceProvider);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: undo.window,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: l10n.actionUndo,
          onPressed: () => undo.undo(pendingId),
        ),
      ),
    );
}

/// Shows a plain informational SnackBar (e.g. an FK-restricted delete message).
void showInfoSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}
