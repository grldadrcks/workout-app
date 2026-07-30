Future<String> backupDatabase() async {
  throw UnsupportedError('Backup not supported on web');
}

Future<void> restoreDatabase(String sourcePath) async {
  throw UnsupportedError('Restore not supported on web');
}
