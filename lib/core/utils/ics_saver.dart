import 'ics_saver_stub.dart'
    if (dart.library.html) 'ics_saver_web.dart'
    if (dart.library.io) 'ics_saver_io.dart'
    as impl;

class IcsSaver {
  static Future<void> save(String filename, String icsContent) =>
      impl.save(filename, icsContent);
}
