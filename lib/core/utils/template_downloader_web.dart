import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:html' as html;

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
  try {
    // 1) Đọc bytes từ assets (đảm bảo pubspec.yaml có khai báo)
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();

    // 2) Tạo Blob chuẩn .xlsx và URL tạm
    final blob = html.Blob([
      bytes,
    ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);

    // 3) Tạo <a download> và click sau một nhịp (tránh xung đột popup/menu)
    final anchor = html.AnchorElement()
      ..href = url
      ..download = assetPath.split('/').last
      ..style.display = 'none';
    html.document.body?.append(anchor);

    // Đợi 1 tick để chắc phần tử đã gắn vào DOM (nhất là khi gọi từ PopupMenu)
    await Future<void>.delayed(const Duration(milliseconds: 50));

    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  } on FlutterError {
    // Fallback: mở asset trực tiếp theo URL tuyệt đối (để bạn thấy 404 nếu sai path)
    final absolute = Uri.base.resolve(assetPath).toString();
    html.window.open(absolute, '_blank');
  } catch (e) {
    // Fallback cuối: mở asset trực tiếp
    final absolute = Uri.base.resolve(assetPath).toString();
    html.window.open(absolute, '_blank');
  }
}
