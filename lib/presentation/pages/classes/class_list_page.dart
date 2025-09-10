import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/providers/class_provider.dart';
import '../../../data/models/class_model.dart';
import 'class_detail_page.dart';
import 'create_class_page.dart';

class ClassListPage extends StatelessWidget {
  const ClassListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stream = context.watch<ClassProvider>().myClasses();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lớp của tôi'),
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateClassPage()),
              );
            },
            icon: const Icon(Icons.add),
            tooltip: 'Tạo lớp',
          ),
        ],
      ),
      body: StreamBuilder<List<ClassModel>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('Chưa có lớp nào'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = items[i];
              return ListTile(
                title: Text('${c.classCode} • ${c.className}'),
                subtitle: Text(
                  'GV: ${c.lecturerName} — Mã tham gia: ${c.joinCode}',
                ),
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
