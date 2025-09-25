// lib/features/student/presentation/pages/student_class_list_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/providers/auth_provider.dart';
import '../../../classes/data/services/class_service.dart';
import '../../../common/data/models/class_model.dart';
import '../classes/student_class_detail_page.dart';

class StudentClassListPage extends StatelessWidget {
  const StudentClassListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final classService = context.read<ClassService>();
    final auth = context.watch<AuthProvider>();
    final studentId = auth.user?.uid;

    if (studentId == null) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Các lớp đã tham gia'),
        ),
        body: const Center(child: Text('Không thể xác thực người dùng.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Lớp học của tôi'),
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
      body: StreamBuilder<List<ClassModel>>(
        stream: classService.getRichEnrolledClassesStream(studentId),
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

          final richClasses = snap.data ?? [];

          if (richClasses.isEmpty) {
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
                      'Chưa tham gia lớp học nào',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hãy vào mục "Tham gia lớp" để bắt đầu tham gia các lớp học.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        // Navigate back to join class page
                        DefaultTabController.of(
                          context,
                        )?.animateTo(2); // Index 2 is join class
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Tham gia lớp'),
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
              itemCount: richClasses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final classInfo = richClasses[i];

                return _ClassCard(
                  classInfo: classInfo,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            StudentClassDetailPage(classId: classInfo.id),
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

class _ClassCard extends StatelessWidget {
  final ClassModel classInfo;
  final VoidCallback onTap;

  const _ClassCard({required this.classInfo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                  // Class Icon
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

                  // Class Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          classInfo.classCode,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          classInfo.className,
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
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
