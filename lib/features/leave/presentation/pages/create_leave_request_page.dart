import 'package:attendify/features/leave/data/services/leave_request_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../../data/models/leave_request_model.dart';

class CreateLeaveRequestPage extends StatefulWidget {
  const CreateLeaveRequestPage({super.key});

  @override
  State<CreateLeaveRequestPage> createState() => _CreateLeaveRequestPageState();
}

class _CreateLeaveRequestPageState extends State<CreateLeaveRequestPage> {
  final _reasonCtl = TextEditingController();
  final _ds = LeaveRequestService();

  String? _classId;
  String? _className;

  String? _subjectId; // nếu lớp có nhiều môn
  String? _subjectName;

  String? _sessionId;
  DateTime? _sessionDate;

  bool _submitting = false;

  String? _uid() => FirebaseAuth.instance.currentUser?.uid;

  // ------------------------
  // 1) STREAM LỚP TỪ ENROLLMENTS → CLASSES
  // ------------------------
  Stream<List<DocumentSnapshot>> _studentClassesStream() async* {
    final uid = _uid();
    if (uid == null) {
      yield [];
      return;
    }
    final firestore = FirebaseFirestore.instance;

    // B1: enrollments by student
    final enrollSnap = await firestore
        .collection(FirestoreCollections.enrollments)
        .where('studentUid', isEqualTo: uid)
        .get();

    final classIds = enrollSnap.docs
        .map((d) => (d.data()['classId'] as String?) ?? '')
        .where((e) => e.isNotEmpty)
        .toList();

    if (classIds.isEmpty) {
      yield [];
      return;
    }

    // Firestore whereIn ≤ 10 → chia mẻ
    final List<DocumentSnapshot> allClasses = [];
    for (var i = 0; i < classIds.length; i += 10) {
      final chunk = classIds.sublist(
        i,
        i + 10 > classIds.length ? classIds.length : i + 10,
      );
      final snap = await firestore
          .collection(FirestoreCollections.classes)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      allClasses.addAll(snap.docs);
    }

    // sort theo tên hiển thị
    allClasses.sort((a, b) {
      final am = (a.data() as Map<String, dynamic>? ?? {});
      final bm = (b.data() as Map<String, dynamic>? ?? {});
      final an = (am['className'] ?? am['name'] ?? a.id).toString();
      final bn = (bm['className'] ?? bm['name'] ?? b.id).toString();
      return an.toLowerCase().compareTo(bn.toLowerCase());
    });

    yield allClasses;
  }

  // ------------------------
  // 2) SUBJECT PICKER (tuỳ kiến trúc; nếu 1 lớp = 1 môn có thể bỏ phần này)
  //    Ưu tiên subcollection: classes/{classId}/subjects
  // ------------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> _subjectsOfClass(String classId) {
    return FirebaseFirestore.instance
        .collection(FirestoreCollections.classes)
        .doc(classId)
        .collection('subjects')
        .orderBy('name')
        .snapshots();
  }

  // ------------------------
  // 3) SESSIONS THEO LỚP
  //    Top-level: sessions.where(classId == _classId).orderBy(date)
  //    Fallback subcollection: classes/{classId}/sessions
  // ------------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> _sessionsByClass(String classId) {
    final col = FirebaseFirestore.instance
        .collection(FirestoreCollections.sessions)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data() ?? {},
          toFirestore: (m, _) => m,
        );
    return col
        .where('classId', isEqualTo: classId)
        .orderBy('startTime', descending: false)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _sessionsSubOfClass(
    String classId,
  ) {
    return FirebaseFirestore.instance
        .collection(FirestoreCollections.classes)
        .doc(classId)
        .collection('sessions')
        .orderBy('startTime', descending: false)
        .snapshots();
  }

  // ------------------------
  // 4) WIDGETS PICKER
  // ------------------------
  Widget _classPicker() {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _studentClassesStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snap.hasError) {
          return Text(
            'Lỗi lớp: ${snap.error}',
            style: const TextStyle(color: Colors.redAccent),
          );
        }
        final docs = (snap.data ?? []);
        if (docs.isEmpty) return const Text('Bạn chưa ghi danh lớp nào.');

        final validValue = docs.any((d) => d.id == _classId) ? _classId : null;

        return DropdownButtonFormField<String>(
          isExpanded: true,
          value: validValue,
          items: docs.map((d) {
            final data = (d.data() as Map<String, dynamic>? ?? {});
            final displayName = (data['className'] ?? data['name'] ?? d.id)
                .toString();
            return DropdownMenuItem<String>(
              value: d.id,
              child: Text(displayName, overflow: TextOverflow.ellipsis),
              onTap: () => _className = displayName,
            );
          }).toList(),
          onChanged: (v) {
            setState(() {
              _classId = v;
              _subjectId = null;
              _subjectName = null;
              _sessionId = null;
              _sessionDate = null;
            });
          },
          decoration: const InputDecoration(labelText: 'Lớp'),
        );
      },
    );
  }

  Widget _subjectPicker() {
    if (_classId == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _subjectsOfClass(_classId!),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            'Lỗi môn: ${snap.error}',
            style: const TextStyle(color: Colors.redAccent),
          );
        }
        if (!snap.hasData) return const LinearProgressIndicator();

        final docs = snap.data!.docs;
        if (docs.isEmpty)
          return const SizedBox.shrink(); // nếu lớp chỉ có 1 môn mặc định

        final validValue = docs.any((d) => d.id == _subjectId)
            ? _subjectId
            : null;

        return DropdownButtonFormField<String>(
          isExpanded: true,
          value: validValue,
          items: docs.map((d) {
            final m = d.data();
            final name = (m['name'] ?? d.id).toString();
            return DropdownMenuItem<String>(
              value: d.id,
              child: Text(name, overflow: TextOverflow.ellipsis),
              onTap: () => _subjectName = name,
            );
          }).toList(),
          onChanged: (v) => setState(() => _subjectId = v),
          decoration: const InputDecoration(labelText: 'Môn (nếu có)'),
        );
      },
    );
  }

  Widget _sessionPicker() {
    if (_classId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _sessionsByClass(_classId!), // ưu tiên top-level
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
          // thử subcollection nếu top-level trống
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _sessionsSubOfClass(_classId!),
            builder: (context, subSnap) {
              if (subSnap.hasError) {
                return Text(
                  'Lỗi buổi (sub): ${subSnap.error}',
                  style: const TextStyle(color: Colors.redAccent),
                );
              }
              if (!subSnap.hasData) return const LinearProgressIndicator();

              final subDocs = subSnap.data!.docs;
              if (subDocs.isEmpty)
                return const Text('Chưa có buổi học cho lớp này.');

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
        final ts = (m['date'] as Timestamp?)?.toDate();
        final order = m['order'];
        final title = ts != null
            ? 'Buổi ${order ?? ''} • ${_fmt(ts)}'
            : (m['name'] ?? 'Buổi ${order ?? d.id}').toString();
        return DropdownMenuItem<String>(
          value: d.id,
          child: Text(title, overflow: TextOverflow.ellipsis),
          onTap: () => _sessionDate = ts,
        );
      }).toList(),
      onChanged: (v) => setState(() => _sessionId = v),
      decoration: const InputDecoration(labelText: 'Buổi học'),
    );
  }

  // ------------------------
  // 5) SUBMIT
  // ------------------------
  Future<void> _submit() async {
    final reason = _reasonCtl.text.trim();
    if (_classId == null || _sessionId == null || reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn lớp, buổi và nhập lý do')),
      );
      return;
    }

    setState(() => _submitting = true);

    final user = FirebaseAuth.instance.currentUser!;
    final req = LeaveRequestModel(
      studentId: user.uid,
      studentName: user.displayName,
      classId: _classId!,
      className: _className,
      subjectId: _subjectId,
      subjectName: _subjectName,
      sessionId: _sessionId!,
      sessionDate: _sessionDate,
      reason: reason,
    );

    try {
      await _ds.create(req);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi yêu cầu (đang chờ duyệt)')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _reasonCtl.dispose();
    super.dispose();
  }

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
            _classPicker(),
            const SizedBox(height: 12),
            _subjectPicker(),
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
