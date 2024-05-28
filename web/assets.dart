import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as HTML;
import 'dart:convert';

import 'package:chronosgl/chronosgl.dart';

bool _isLoaded = false;
Map<String, Uint8List>? _data;

Map<String, Uint8List> _decode(String metaText, String dataText) {
  Map<String, dynamic> meta = jsonDecode(metaText);
  Uint8List data = base64Decode(dataText);
  return meta.map<String, Uint8List>((String key, dynamic value) {
    Map<String, dynamic> file = value;
    return MapEntry(
        key, Uint8List.sublistView(data, file['start'], file['end']));
  });
}

void _init() {
  if (_isLoaded) {
    return;
  }
  final metaElement = HTML.document.getElementById('file-meta');
  final dataElement = HTML.document.getElementById('file-data');
  if (metaElement != null && dataElement != null) {
    _data = _decode((metaElement as HTML.ScriptElement).text!,
        (dataElement as HTML.ScriptElement).text!);
  }
  _isLoaded = true;
}

// Returns the URL to access a given piece of data.
String getURL(String path, String type) {
  _init();
  if (_data == null) {
    return path;
  }
  final data = _data![path];
  if (data == null) {
    throw "No such file: $path";
  }
  final blob = HTML.Blob([data], type);
  final url = HTML.Url.createObjectUrlFromBlob(blob);
  print("HAVE BLOB: ${url}");
  return url;
}

Future<dynamic> _fetch(String path, String type) {
  final c = Completer<dynamic>();
  final req = HTML.HttpRequest();
  req
    ..open('GET', path)
    ..responseType = type
    ..onError.listen((event) {
      c.completeError("Failed to load: $path");
    })
    ..onLoadEnd.listen((event) {
      final status = req.status;
      if (status != null && 200 <= status && status <= 299) {
        return c.complete(req.response);
      }
      c.completeError("Failed to load: $path");
    })
    ..send();
  return c.future;
}

// Returns the given chunk of data, as a string.
Future<String> getText(String path) {
  _init();
  if (_data == null) {
    return _fetch(path, 'String').then((dynamic data) => data as String);
  }
  final data = _data![path];
  if (data == null) {
    throw "No such file: $path";
  }
  return Future.value(utf8.decode(data));
}

// Returns the given chunk of data.
Future<Uint8List> getData(String path) {
  _init();
  if (_data == null) {
    return _fetch(path, 'arraybuffer')
        .then((dynamic data) => Uint8List.view(data as ByteBuffer));
  }
  final data = _data![path];
  if (data == null) {
    throw "No such file: $path";
  }
  return Future.value(data);
}

Future<HTML.ImageElement> loadImage(String path) {
  return LoadImage(getURL(path, 'image/png'));
}
