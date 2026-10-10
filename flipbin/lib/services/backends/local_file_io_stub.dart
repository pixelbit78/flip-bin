import 'dart:typed_data';

Future<void> downloadBytes(String fileName, Uint8List bytes) async {
  throw UnsupportedError('File download is only available on web');
}

Future<Uint8List?> pickFileBytes({String accept = ''}) async {
  throw UnsupportedError('File picking is only available on web');
}

Future<String?> fetchText(String url) async {
  throw UnsupportedError('fetch is only available on web');
}

/// Removes QA-only browser storage (DB + `qa.` prefs). Web only.
void wipeQaStorage(String dbName) {}

/// Forces drift's web schema-version key (QA legacy fixture). Web only.
void setDriftSchemaVersion(String dbName, int version) {}

void reloadPage() {}
