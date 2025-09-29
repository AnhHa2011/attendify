// lib/features/admin/domain/export/export_syllabus_pdf_service.dart

import 'package:attendify/app_imports.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ExportSyllabusPdfService {
  static Future<Uint8List> export(CourseModel course) async {
    final pdf = pw.Document();

    // Tải font hỗ trợ tiếng Việt (đảm bảo đường dẫn đúng)
    // 1. Tải cả font regular và bold
    final regularFontData = await rootBundle.load(
      "assets/fonts/Mali/Mali-Regular.ttf",
    );
    final boldFontData = await rootBundle.load(
      "assets/fonts/Mali/Mali-Bold.ttf",
    );

    // 2. Tạo theme với cả hai font
    // - `base`: font dùng cho chữ thường
    // - `bold`: font dùng khi có yêu cầu `fontWeight: pw.FontWeight.bold`
    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(regularFontData),
      bold: pw.Font.ttf(boldFontData),
    );

    pdf.addPage(
      pw.Page(
        // Dùng Page là đủ cho nội dung ngắn gọn
        theme: theme, // 3. Áp dụng theme đã tạo vào trang
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Tiêu đề
              pw.Header(
                level: 0,
                child: pw.Center(
                  child: pw.Text(
                    'ĐỀ CƯƠNG MÔN HỌC',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 25),

              // === PHẦN 1: THÔNG TIN CHUNG ===
              // Tận dụng các trường có sẵn
              _buildSectionTitle('1. Thông tin chung'),
              _buildInfoRow('Tên môn học:', course.courseName),
              _buildInfoRow('Mã môn học:', course.courseCode),
              _buildInfoRow(
                'Giảng viên phụ trách:',
                course.lecturerName ?? 'Chưa có',
              ),
              _buildInfoRow('Học kỳ:', course.semester),
              _buildInfoRow('Số tín chỉ:', '${course.credits}'),
              _buildInfoRow(
                'Thời gian dự kiến:',
                'Từ ${DateFormat('dd/MM/yyyy').format(course.startDate)} đến ${DateFormat('dd/MM/yyyy').format(course.endDate)}',
              ),
              pw.SizedBox(height: 20),

              // === PHẦN 2: MÔ TẢ MÔN HỌC ===
              // Sử dụng trường 'description' một cách linh hoạt
              _buildSectionTitle('2. Mô tả môn học'),
              pw.Text(
                course.description.isNotEmpty
                    ? course.description
                    : 'Chưa có mô tả chi tiết. Môn học sẽ cung cấp các kiến thức và kỹ năng nền tảng về...',
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 20),

              // === PHẦN 3: QUY ĐỊNH CỦA MÔN HỌC ===
              // Sử dụng trường 'maxAbsences'
              _buildSectionTitle('3. Quy định của môn học'),
              _buildInfoRow(
                'Số buổi vắng tối đa cho phép:',
                '${course.maxAbsences} buổi',
              ),
              _buildInfoRow(
                'Yêu cầu khác:',
                'Sinh viên cần chủ động tham gia các hoạt động trên lớp và hoàn thành bài tập về nhà đầy đủ, đúng hạn.',
              ),
              pw.SizedBox(height: 20),

              // === PHẦN 4: ĐÁNH GIÁ KẾT QUẢ HỌC TẬP ===
              // Sử dụng nội dung mẫu vì chưa có dữ liệu
              _buildSectionTitle('4. Đánh giá kết quả học tập'),
              pw.Text(
                'Chi tiết về hình thức và trọng số điểm sẽ được giảng viên phổ biến vào buổi học đầu tiên. Tỷ lệ tham khảo như sau:',
              ),
              pw.SizedBox(height: 8),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Bullet(text: 'Điểm chuyên cần: 10%'),
                    pw.Bullet(text: 'Điểm kiểm tra giữa kỳ: 30%'),
                    pw.Bullet(text: 'Điểm thi cuối kỳ: 60%'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // Các hàm helper này được giữ nguyên, chỉ chỉnh sửa một chút cho đẹp hơn
  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 2),
      margin: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 1.5, color: PdfColors.black),
        ),
      ),
      child: pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 150, // Tăng chiều rộng để không bị xuống dòng
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }
}
