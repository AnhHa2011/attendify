import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

Future<void> save(String filename, String icsContent) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(icsContent, flush: true);
  await OpenFilex.open(file.path); // mở bằng app lịch/Calendar mặc định
}
