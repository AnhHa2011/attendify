import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

const _assetMap = {
  'course': 'assets/templates/course_import_template.xlsx',
  'class': 'assets/templates/class_import_template.xlsx',
  // 'class_enroll':
  //     'assets/templates/attendify_class_with_enrollments_template.xlsx',
  'user': 'assets/templates/user_import_template.xlsx',
  'enrollment': 'assets/templates/enrollment_import_template.xlsx',
};

Future<void> download(String kind) async {
  final assetPath = _assetMap[kind]!;
  final data = await rootBundle.load(assetPath);
  final bytes = data.buffer.asUint8List();

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${assetPath.split('/').last}');
  await file.writeAsBytes(bytes);

  await OpenFilex.open(file.path);
}
