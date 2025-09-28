// WIDGET CHO CHỨC NĂNG THAM GIA môn - Tối ưu cho mobile
import 'package:attendify/features/student/presentation/pages/join_course_scanner_page.dart';

import '../../../../app_imports.dart';
import '../../../../core/data/services/courses_service.dart';

class JoinCoursePage extends StatefulWidget {
  const JoinCoursePage();

  @override
  State<JoinCoursePage> createState() => _JoinCoursePageState();
}

class _JoinCoursePageState extends State<JoinCoursePage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitJoinCourse({required String joinCode}) async {
    setState(() => _isLoading = true);
    try {
      final courseService = context.read<CourseService>();
      final auth = context.read<AuthProvider>();
      final user = auth.user!;

      await courseService.enrollStudent(
        joinCode: joinCode,
        studentUid: user.uid,
        studentName: user.displayName ?? 'N/A',
        studentEmail: user.email ?? 'N/A',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tham gia môn học thành công!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _codeController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _scanAndJoin() async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const JoinCourseScannerPage()),
    );
    if (scannedCode != null && scannedCode.isNotEmpty) {
      _codeController.text = scannedCode;
      await _submitJoinCourse(joinCode: scannedCode);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final padding = EdgeInsets.symmetric(
      horizontal: screenSize.width < 360 ? 16.0 : 24.0,
      vertical: 16.0,
    );

    return Scaffold(
      body: SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: screenSize.height - 100),
          child: Center(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header với icon - Responsive
                  Container(
                    padding: EdgeInsets.all(screenSize.width < 360 ? 16 : 20),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(
                            screenSize.width < 360 ? 12 : 16,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Icon(
                            Icons.group_add,
                            color: colorScheme.primary,
                            size: screenSize.width < 360 ? 36 : 48,
                          ),
                        ),
                        SizedBox(height: screenSize.width < 360 ? 12 : 16),
                        Text(
                          'Tham gia môn học',
                          style:
                              (screenSize.width < 360
                                      ? theme.textTheme.titleLarge
                                      : theme.textTheme.headlineSmall)
                                  ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nhập mã tham gia hoặc quét QR code',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: screenSize.width < 360 ? 24 : 32),

                  // Text Field - Responsive
                  TextFormField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: 'Mã tham gia',
                      hintText: 'Ví dụ: ABC123',
                      prefixIcon: Icon(
                        Icons.tag,
                        size: screenSize.width < 360 ? 20 : 24,
                      ),
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: screenSize.width < 360 ? 12 : 16,
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (_formKey.currentState!.validate()) {
                        _submitJoinCourse(joinCode: _codeController.text);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập mã tham gia';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: screenSize.width < 360 ? 16 : 20),

                  // Join Button - Responsive
                  FilledButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              _submitJoinCourse(joinCode: _codeController.text);
                            }
                          },
                    icon: _isLoading
                        ? const SizedBox.shrink()
                        : Icon(
                            Icons.login,
                            size: screenSize.width < 360 ? 18 : 20,
                          ),
                    label: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : const Text('Tham gia'),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: screenSize.width < 360 ? 12 : 16,
                      ),
                      textStyle: TextStyle(
                        fontSize: screenSize.width < 360 ? 14 : 16,
                      ),
                    ),
                  ),

                  SizedBox(height: screenSize.width < 360 ? 12 : 16),

                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'HOẶC',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            fontSize: screenSize.width < 360 ? 11 : 12,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),

                  SizedBox(height: screenSize.width < 360 ? 12 : 16),

                  // QR Scan Button - Responsive
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _scanAndJoin,
                    icon: Icon(
                      Icons.qr_code_scanner,
                      size: screenSize.width < 360 ? 18 : 20,
                    ),
                    label: const Text('Quét mã QR'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: screenSize.width < 360 ? 12 : 16,
                      ),
                      textStyle: TextStyle(
                        fontSize: screenSize.width < 360 ? 14 : 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
