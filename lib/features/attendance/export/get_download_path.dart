import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String> getDownloadPath() async {
  if (Platform.isAndroid) {
    // Android có thư mục downloads riêng
    final dir = Directory('/storage/emulated/0/Download');
    if (await dir.exists()) return dir.path;
    return (await getExternalStorageDirectory())!.path;
  } else if (Platform.isIOS) {
    return (await getApplicationDocumentsDirectory()).path;
  } else {
    return (await getDownloadsDirectory())!.path; // macOS/Windows
  }
}
