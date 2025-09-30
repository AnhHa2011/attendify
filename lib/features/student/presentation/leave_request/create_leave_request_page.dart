// lib/features/student/presentation/pages/create_leave_request_page.dart

import 'package:attendify/features/student/data/services/student_leave_request_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/data/models/leave_request_model.dart';

class CreateLeaveRequestPage extends StatefulWidget {
  const CreateLeaveRequestPage({super.key});

  @override
  State<CreateLeaveRequestPage> createState() => _CreateLeaveRequestPageState();
}

class _CreateLeaveRequestPageState extends State<CreateLeaveRequestPage> {
  final _reasonCtl = TextEditingController();
  final _service = StudentLeaveRequestService();

  String? _courseCode;
  String? _courseName;
  String? _lecturerId;

  String? _sessionId;
  String? _sessionName;
  DateTime? _sessionDate;

  bool _submitting = false;

  String? _uid() => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    _reasonCtl.dispose();
    super.dispose();
  }

  // ------------------------
  // 1) STREAM CÁC MÔN TỪ ENROLLMENTS → COURSES
  // ------------------------
  Stream<List<DocumentSnapshot>> _studentCoursesStream() async* {
    final uid = _uid();
    if (uid == null) {
      yield [];
      return;
    }
    final firestore = FirebaseFirestore.instance;

    // Lấy các enrollments theo sinh viên
    final enrollSnap = await firestore
        .collection(FirestoreCollections.enrollments)
        .where('studentId', isEqualTo: uid)
        .get();

    final courseCodes = enrollSnap.docs
        .map((d) => (d.data()['courseCode'] as String?) ?? '')
        .where((e) => e.isNotEmpty)
        .toList();

    if (courseCodes.isEmpty) {
      yield [];
      return;
    }

    // Firestore whereIn ≤ 10 → chia mẻ
    final List<DocumentSnapshot> allCourses = [];
    for (var i = 0; i < courseCodes.length; i += 10) {
      final chunk = courseCodes.sublist(
        i,
        i + 10 > courseCodes.length ? courseCodes.length : i + 10,
      );
      final snap = await firestore
          .collection(FirestoreCollections.courses)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      allCourses.addAll(snap.docs);
    }

    // sort theo tên hiển thị
    allCourses.sort((a, b) {
      final am = (a.data() as Map<String, dynamic>? ?? {});
      final bm = (b.data() as Map<String, dynamic>? ?? {});
      final an = (am['courseName'] ?? am['name'] ?? a.id).toString();
      final bn = (bm['courseName'] ?? bm['name'] ?? b.id).toString();
      return an.toLowerCase().compareTo(bn.toLowerCase());
    });

    yield allCourses;
  }

  // ------------------------
  // 2) SESSIONS THEO MÔN
  //    Top-level: sessions.where(courseCode == _courseCode).orderBy(date)
  //    Fallback subcollection: courses/{courseCode}/sessions
  // ------------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> _sessionsByCourse(
    String courseCode,
  ) {
    final col = FirebaseFirestore.instance
        .collection(FirestoreCollections.sessions)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data() ?? {},
          toFirestore: (m, _) => m,
        );
    return col
        .where('courseCode', isEqualTo: courseCode)
        .orderBy('startTime', descending: false)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _sessionsSubOfCourse(
    String courseCode,
  ) {
    return FirebaseFirestore.instance
        .collection(FirestoreCollections.courses)
        .doc(courseCode)
        .collection('sessions')
        .orderBy('startTime', descending: false)
        .snapshots();
  }

  // ------------------------
  // 3) WIDGETS PICKER
  // ------------------------
  Widget _coursePicker() {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _studentCoursesStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snap.hasError) {
          return Text(
            'Lỗi môn học: ${snap.error}',
            style: const TextStyle(color: Colors.redAccent),
          );
        }
        final docs = (snap.data ?? []);
        if (docs.isEmpty) return const Text('Bạn chưa tham gia môn học nào.');

        final validValue = docs.any((d) => d.id == _courseCode)
            ? _courseCode
            : null;

        return DropdownButtonFormField<String>(
          isExpanded: true,
          value: validValue,
          items: docs.map((d) {
            final data = (d.data() as Map<String, dynamic>? ?? {});
            final displayName = (data['courseName'] ?? data['name'] ?? d.id)
                .toString();
            return DropdownMenuItem<String>(
              value: d.id,
              child: Text(displayName, overflow: TextOverflow.ellipsis),
              onTap: () => _courseName = displayName,
            );
          }).toList(),
          onChanged: (v) {
            setState(() {
              _courseCode = v;
              _sessionId = null;
              _sessionName = null;
              _sessionDate = null;

              // Phòng trường hợp onTap ở item không chạy, gán lại _courseName
              final doc = docs.firstWhere(
                (d) => d.id == v,
                orElse: () => docs.first,
              );
              final data = (doc.data() as Map<String, dynamic>? ?? {});
              _courseName = data['courseName'].toString();
              _courseCode = data['courseCode'].toString();
              _lecturerId = data['lecturerId'].toString();
            });
          },
          decoration: const InputDecoration(labelText: 'Môn học'),
        );
      },
    );
  }

  Widget _sessionPicker() {
    if (_courseCode == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _sessionsByCourse(_courseCode!), // ưu tiên top-level
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            'Lỗi buổi học: ${snap.error}',
            style: const TextStyle(color: Colors.redAccent),
          );
        }
        if (!snap.hasData) return const LinearProgressIndicator();

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          // Thử subcollection nếu top-level trống
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _sessionsSubOfCourse(_courseCode!),
            builder: (context, subSnap) {
              if (subSnap.hasError) {
                return Text(
                  'Lỗi buổi (sub): ${subSnap.error}',
                  style: const TextStyle(color: Colors.redAccent),
                );
              }
              if (!subSnap.hasData) return const LinearProgressIndicator();

              final subDocs = subSnap.data!.docs;
              if (subDocs.isEmpty) {
                return const Text('Chưa có buổi học cho môn học này.');
              }
              return _buildSessionDropdown(subDocs);
            },
          );
        }
        return _buildSessionDropdown(docs);
      },
    );
  }

  Widget _buildSessionDropdown(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final validValue = docs.any((d) => d.id == _sessionId) ? _sessionId : null;

    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: validValue,
      items: docs.map((d) {
        final m = d.data();
        // Ưu tiên 'date', fallback 'startTime'
        final DateTime? ts = (m['startTime'] as Timestamp?)?.toDate();

        final order = m['order'];
        final title = ts != null
            ? 'Buổi ${order ?? ''} • ${_fmt(ts)}'
            : (m['title'] ?? 'Buổi học');

        return DropdownMenuItem<String>(
          value: d.id,
          child: Text(title, overflow: TextOverflow.ellipsis),
          onTap: () => _sessionDate = ts, // có thể là null nếu dữ liệu thiếu
        );
      }).toList(),
      onChanged: (v) => setState(() => _sessionId = v),
      decoration: const InputDecoration(labelText: 'Buổi học'),
    );
  }

  // ------------------------
  // 4) SUBMIT
  // ------------------------
  Future<void> _submit() async {
    final reason = _reasonCtl.text.trim();
    if (_courseCode == null || _sessionId == null || reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn môn học, buổi và nhập lý do'),
        ),
      );
      return;
    }

    if (_sessionDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buổi học thiếu ngày giờ (sessionDate)')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final req = LeaveRequestModel(
        id: '',
        studentId: user.uid,
        studentName: user.displayName ?? '',
        studentEmail: user.email ?? '',
        courseCode: _courseCode!,
        courseName: _courseName ?? '',
        lecturerId: _lecturerId ?? '',
        sessionId: _sessionId!,
        sessionName: '',
        sessionDate: _sessionDate!,
        reason: reason,
        status: 'pending', // ✅ lưu đúng chuỗi
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        requestDate: DateTime.now(),
      );

      // QUAN TRỌNG: ensure create() dùng await và collection đúng
      // Ví dụ trong StudentLeaveRequestService:
      // await FirebaseFirestore.instance.collection(FirestoreCollections.leaveRequests).add(req.toMap());
      await _service.create(req);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi yêu cầu (đang chờ duyệt)')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi gửi: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ------------------------
  // 5) UI
  // ------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Xin nghỉ'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _coursePicker(),
            const SizedBox(height: 12),
            _sessionPicker(),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reasonCtl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Lý do xin nghỉ',
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: const Icon(Icons.cloud_upload),
                label: Text(_submitting ? 'Đang gửi…' : 'Gửi yêu cầu'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
