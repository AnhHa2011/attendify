import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../data/models/class_model.dart';
import '../../../services/firebase/class_service.dart';

class ClassDetailPage extends StatelessWidget {
  final String classId;
  const ClassDetailPage({super.key, required this.classId});

  @override
  Widget build(BuildContext context) {
    // 👉 Dùng thẳng service, KHÔNG còn phụ thuộc ClassProvider
    final svc = context.read<ClassService>();

    return StreamBuilder<ClassModel>(
      stream: svc.classStream(classId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: Text('Không tìm thấy lớp')),
          );
        }
        final c = snap.data!;
        return Scaffold(
          appBar: AppBar(
            title: Text('${c.classCode} - ${c.className}'),
            actions: [
              IconButton(
                tooltip: 'Đổi mã tham gia',
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  await svc.regenerateJoinCode(c.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã tạo mã tham gia mới')),
                    );
                  }
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.class_)),
                  title: Text(c.className),
                  subtitle: Text(
                    'Mã: ${c.classCode}\nGV: ${c.lecturerName} (${c.lecturerEmail})',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Text(
                        'Mã tham gia: ${c.joinCode}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      QrImageView(
                        data: c.joinCode,
                        size: 180,
                        version: QrVersions.auto,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Danh sách sinh viên',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: svc.membersStream(c.id),
                builder: (context, ms) {
                  if (ms.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final members = ms.data ?? [];
                  if (members.isEmpty) {
                    return const Text('Chưa có sinh viên tham gia');
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: members.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final m = members[i];
                      return ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(m['displayName'] ?? ''),
                        subtitle: Text(m['email'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await svc.removeMember(c.id, m['id']);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Đã xoá ${m['displayName'] ?? ''}',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
