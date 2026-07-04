import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Opens the production database file lazily.
///
/// The file lives in the app documents directory and is opened on a background
/// isolate via [NativeDatabase.createInBackground] so schema creation and heavy
/// queries never block the UI isolate.
LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File(p.join(dir.path, 'hesap_takip.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
