import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

Future<String> backupDatabase() async {
  final src = join(await getDatabasesPath(), 'workout.db');
  final dir = await getApplicationDocumentsDirectory();
  final dest = join(dir.path, 'forge_backup.db');
  await File(src).copy(dest);
  return dest;
}

Future<void> restoreDatabase(String sourcePath) async {
  final dest = join(await getDatabasesPath(), 'workout.db');
  await File(sourcePath).copy(dest);
}
