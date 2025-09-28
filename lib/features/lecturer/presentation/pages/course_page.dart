import 'dart:async';
import 'package:attendify/core/data/models/course_model.dart';
import 'package:attendify/core/data/services/courses_service.dart';
import 'package:attendify/features/lecturer/services/lecturer_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../courses/presentation/pages/course_detail_page.dart';
import 'course_detail_page.dart'; // màn hình chi tiết

class CoursePage extends StatefulWidget {
  const CoursePage({Key? key}) : super(key: key);

  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  final CourseService _coursesService = CourseService();
  final LecturerService _lectureService = LecturerService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<CourseModel> courses = [];
  StreamSubscription<List<CourseModel>>? _sub;

  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    await _sub?.cancel();
    _sub = _lectureService
        .getCourseByLecturer(_auth.currentUser!.uid) // stream từ repo
        .listen(
          (courseList) {
            if (!mounted) return;
            setState(() {
              courses = courseList;
              isLoading = false;
            });
          },
          onError: (e) {
            if (!mounted) return;
            setState(() {
              error = e.toString();
              isLoading = false;
            });
          },
        );
  }

  Widget _buildCourseList() {
    if (courses.isEmpty) {
      return const Center(child: Text("Chưa có môn học nào"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        final course = courses[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            leading: const Icon(Icons.school, size: 32),
            title: Text(
              course.courseName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "Mã: ${course.courseCode} • Tín chỉ: ${course.credits}",
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Chuyển sang màn hình chi tiết/chỉnh sửa
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CourseDetailPage(courseModel: course),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(error ?? 'Có lỗi xảy ra'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadCourses, child: const Text("Thử lại")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Danh sách môn học")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? _buildErrorWidget()
          : _buildCourseList(),
    );
  }
}
