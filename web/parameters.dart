const bool kReleaseMode = true;
const bool kDebugMode = !kReleaseMode;

void _addParameter(StringBuffer buf, String key, String? value) {
  if (buf.isEmpty) {
    buf.write('#');
  } else {
    buf.write('&');
  }
  buf.write(Uri.encodeQueryComponent(key));
  if (value != null) {
    buf.write('=');
    buf.write(Uri.encodeQueryComponent(value));
  }
}

class Parameters {
  String? section;
  bool debug = false;
  int start = 0;

  // Encode the parameters as a URL fragment. This will return either the empty
  // string, or a URL fragment starting with '#'.
  String encode() {
    var buf = StringBuffer();
    if (section != null) {
      _addParameter(buf, 'section', section);
    }
    if (debug != kDebugMode) {
      _addParameter(buf, debug ? 'debug' : 'release', null);
    }
    if (start != 0) {
      _addParameter(buf, 'start', start.toString());
    }
    return buf.toString();
  }

  // Decode the parameters from a URL fragment. The input should either be the
  // empty string, or a URL fragment starting with '#'.
  void decode(String hash) {
    section = null;
    debug = kDebugMode;
    start = 0;
    if (hash.length > 1) {
      for (final item in hash.substring(1).split('&')) {
        final equals = item.indexOf('=');
        String key;
        String? value;
        if (equals >= 0) {
          key = Uri.decodeQueryComponent(item.substring(0, equals));
          value = Uri.decodeQueryComponent(item.substring(equals + 1));
        } else {
          key = Uri.decodeQueryComponent(item);
          value = null;
        }
        switch (key) {
          case 'section':
            section = value;
            break;
          case 'debug':
            debug = true;
            break;
          case 'release':
            debug = false;
            break;
          case 'start':
            start = value == null ? 0 : (int.tryParse(value) ?? 0);
            break;
          default:
            print("Unknown parameter in URL: ${item}");
            break;
        }
      }
    }
  }
}
