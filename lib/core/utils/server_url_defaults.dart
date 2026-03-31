import 'package:flutter/foundation.dart';

class ServerUrlDefaults {
  ServerUrlDefaults._();

  static String get value {
    if (kIsWeb) {
      return Uri.base.origin;
    }
    return 'http://10.0.0.52:18080';
  }
}
