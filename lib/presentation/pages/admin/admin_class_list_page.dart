import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/providers/admin_class_provider.dart';
import '../../../data/models/class_model.dart';
import '../classes/class_detail_page.dart';

class AdminClassListPage extends StatefulWidget {
  const AdminClassListPage({super.key});

  @override
  State<AdminClassListPage> createState() => _AdminClassListPageState();
}

class _AdminClassListPageState extends State<AdminClassListPage> {
  String? _selectedLecturerUid;

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AdminClassProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Tất cả lớp học')),
      body: Column(
        children: [
          // Filter theo giảng viên
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: StreamBuilder<List<Map<String, String>>>(
              stream: prov.lecturers(),
              builder: (context, snap) {
                final list = snap.data ?? [];
                return DropdownButtonFormField<String>(
                  value: _selectedLecturerUid,
                  hint: const Text('Lọc theo giảng viên'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Tất cả giảng viên'),
                    ),
                    ...list.map(
                      (m) => DropdownMenuItem<String>(
                        value: m['uid'],
                        child: Text('${m['name']} — ${m['email']}'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedLecturerUid = v),
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ClassModel>>(
              stream: _selectedLecturerUid == null
                  ? prov.allClasses()
                  : prov.classesOfLecturer(_selectedLecturerUid!),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snap.data ?? [];
                if (items.isEmpty)
                  return const Center(child: Text('Không có lớp nào'));
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = items[i];
                    return ListTile(
                      title: Text('${c.classCode} • ${c.className}'),
                      subtitle: Text(
                        'GV: ${c.lecturerName} — Mã: ${c.joinCode}',
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
          ),
        ],
      ),
    );
  }
}
