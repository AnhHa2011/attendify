import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/providers/student_class_provider.dart';
import '../../../data/models/class_model.dart';
import '../classes/class_detail_page.dart';

class StudentClassListPage extends StatelessWidget {
  const StudentClassListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stream = context.watch<StudentClassProvider>().myEnrolledClasses();

    return Scaffold(
      appBar: AppBar(title: const Text('Lớp của tôi (SV)')),
      body: StreamBuilder<List<ClassModel>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? [];
          if (items.isEmpty)
            return const Center(child: Text('Chưa tham gia lớp nào'));
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = items[i];
              return ListTile(
                title: Text('${c.classCode} • ${c.className}'),
                subtitle: Text('GV: ${c.lecturerName}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClassDetailPage(classId: c.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
