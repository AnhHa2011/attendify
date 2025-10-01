// lib/features/student/presentation/pages/student_course_list_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/providers/auth_provider.dart';
import '../../../../core/data/models/rich_course_model.dart';
import '../../../../core/data/services/courses_service.dart';
import '../courses/student_course_detail_page.dart';
import 'join_course_page.dart';

class StudentCourseListPage extends StatelessWidget {
  const StudentCourseListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final courseService = context.read<CourseService>();
    final auth = context.watch<AuthProvider>();
    final studentId = auth.user?.uid;

    if (studentId == null) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Các môn đã tham gia'),
        ),
        body: const Center(child: Text('Không thể xác thực người dùng.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Môn học của tôi'),
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Add refresh functionality
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: StreamBuilder<List<RichCourseModel>>(
        stream: courseService.getRichEnrolledCoursesStream(studentId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Đã xảy ra lỗi',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snap.error}',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final richCourses = snap.data ?? [];

          if (richCourses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 80,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Chưa tham gia môn học nào',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hãy vào mục "Tham gia môn" để bắt đầu tham gia các môn học.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const JoinCoursePage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Tham gia môn'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // TODO: Implement refresh logic
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: richCourses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final richCourse = richCourses[i];
                final courseInfo = richCourse.courseInfo;
                final lecturer = richCourse.lecturer;

                return _CourseCard(
                  richCourse: richCourse,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            StudentCourseDetailPage(courseCode: courseInfo.id),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final RichCourseModel richCourse;
  final VoidCallback onTap;

  const _CourseCard({required this.richCourse, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final courseInfo = richCourse.courseInfo;
    final lecturer = richCourse.lecturer;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Course Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.class_,
                      color: colorScheme.onPrimaryContainer,
                      size: 28,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Course Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          courseInfo.courseCode,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          courseInfo.courseName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Arrow Icon
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),

              const SizedBox(height: 16),
              // Lecturer Info
              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'GV: ${lecturer?.displayName ?? "Chưa phân công"}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
