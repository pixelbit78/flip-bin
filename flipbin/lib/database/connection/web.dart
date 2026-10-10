// ignore_for_file: deprecated_member_use
import 'package:drift/drift.dart';
import 'package:drift/web.dart';
import 'package:flipbin/config/env.dart';

QueryExecutor openConnection() {
  return WebDatabase(Env.dbName);
}
