import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flipbin/database/database.dart';

/// Singleton provider for the Drift database instance.
final databaseProvider = Provider<FlipBinDatabase>((ref) {
  final db = FlipBinDatabase();
  ref.onDispose(() => db.close());
  return db;
});
