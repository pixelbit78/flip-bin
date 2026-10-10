import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> downloadBytes(String fileName, Uint8List bytes) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(
        type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
  );
  final url = web.URL.createObjectURL(blob);
  final a = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName;
  web.document.body!.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
}

Future<Uint8List?> pickFileBytes({String accept = ''}) {
  final completer = Completer<Uint8List?>();
  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = accept;
  input.onchange = ((web.Event _) {
    final file = input.files?.item(0);
    if (file == null) {
      completer.complete(null);
      return;
    }
    file.arrayBuffer().toDart.then((buf) {
      completer.complete(buf.toDart.asUint8List());
    }, onError: completer.completeError);
  }).toJS;
  input.oncancel = ((web.Event _) {
    if (!completer.isCompleted) completer.complete(null);
  }).toJS;
  input.click();
  return completer.future;
}

Future<String?> fetchText(String url) async {
  final resp = await web.window.fetch(url.toJS).toDart;
  if (!resp.ok) return null;
  final text = await resp.text().toDart;
  return text.toDart;
}

/// Removes QA-only browser storage: drift's localStorage DB for [dbName] and
/// every SharedPreferences key under `flutter.qa.`. Never touches prod keys.
void wipeQaStorage(String dbName) {
  assert(dbName != 'flipbin', 'refusing to wipe the prod DB');
  if (dbName == 'flipbin') return;
  final ls = web.window.localStorage;
  final doomed = <String>[];
  for (var i = 0; i < ls.length; i++) {
    final k = ls.key(i);
    if (k == null) continue;
    if (k == 'moor_db_str_$dbName' ||
        k == 'moor_db_version_$dbName' ||
        k.startsWith('flutter.qa.')) {
      doomed.add(k);
    }
  }
  for (final k in doomed) {
    ls.removeItem(k);
  }
}

void setDriftSchemaVersion(String dbName, int version) {
  if (dbName == 'flipbin') return;
  web.window.localStorage.setItem('moor_db_version_$dbName', '$version');
}

void reloadPage() => web.window.location.reload();
