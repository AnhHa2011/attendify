// Wrapper: luôn import với alias 'impl' theo nền tảng.
// - Web  -> template_downloader_web.dart
// - IO   -> template_downloader_io.dart
// - Fallback -> template_downloader_stub.dart

import 'template_downloader_stub.dart'
    if (dart.library.html) 'template_downloader_web.dart'
    if (dart.library.io) 'template_downloader_io.dart'
    as impl;

class TemplateDownloader {
  /// kind: 'course' | 'class' | 'class_enroll' | 'user'
  static Future<void> download(String kind) => impl.download(kind);
}
