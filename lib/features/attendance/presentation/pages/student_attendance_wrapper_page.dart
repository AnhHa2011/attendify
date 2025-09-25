import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'student_attendance_page.dart';

class StudentAttendanceWrapperPage extends StatelessWidget {
  const StudentAttendanceWrapperPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Bạn cần đăng nhập.')));
    }

    // Lấy danh sách enrollments để biết lớp sinh viên đã tham gia
    final enrollments = FirebaseFirestore.instance
        .collection('enrollments')
        .where('studentUid', isEqualTo: uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Lịch sử chuyên cần'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: enrollments,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Lỗi: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Bạn chưa tham gia lớp nào.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final classId = d['classId'] as String;
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('classes')
                    .doc(classId)
                    .get(),
                builder: (context, classSnap) {
                  if (!classSnap.hasData) {
                    return const ListTile(title: Text('Đang tải lớp...'));
                  }
                  final classData =
                      classSnap.data!.data() as Map<String, dynamic>? ?? {};
                  final className =
                      (classData['name'] ?? classData['className'] ?? classId)
                          .toString();
                  return ListTile(
                    title: Text(className),
                    subtitle: Text('Mã lớp: $classId'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentAttendancePage(
                            classId: classId,
                            className: className,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
