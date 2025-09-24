// lib/features/classes/presentation/pages/class_detail_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

import '../../../common/data/models/session_model.dart';
import '../../../common/data/models/user_model.dart';
import '../../../common/data/models/class_model.dart';
import '../../../../../app/providers/auth_provider.dart';
import '../../../sessions/presentation/pages/data/services/session_service.dart';
import '../../../sessions/presentation/pages/session_detail_page.dart';
import '../../data/services/class_service.dart';
import '../../widgets/dynamic_qr_code_dialog.dart';

class ClassDetailPage extends StatefulWidget {
  final String classId;
  const ClassDetailPage({super.key, required this.classId});

  @override
  State<ClassDetailPage> createState() => _ClassDetailPageState();
}

class _ClassDetailPageState extends State<ClassDetailPage>
    with SingleTickerProviderStateMixin {
  // === THÊM STATE: Khai báo TabController ===
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Khởi tạo TabController với 2 tab
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    // Hủy controller khi widget bị xóa để tránh rò rỉ bộ nhớ
    _tabController.dispose();
    super.dispose();
  }

  // Hàm chịu trách nhiệm bật điểm danh và hiển thị dialog QR động (Logic không đổi)
  Future<void> _showDynamicQrForSession(SessionModel session) async {
    final sessionService = context.read<SessionService>();
    try {
      if (session.status != SessionStatus.inProgress) {
        await sessionService.startAttendanceForSession(session.id);
      } else {
        await sessionService.toggleAttendance(session.id, true);
      }

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => DynamicQrCodeDialog(
          classId: widget.classId,
          sessionId: session.id,
          sessionTitle: session.title,
        ),
      ).then((_) {
        sessionService.toggleAttendance(session.id, false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã đóng điểm danh.')));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi bắt đầu điểm danh: $e')));
    }
  }

  // Hàm này hiển thị danh sách buổi học hôm nay để giảng viên chọn
  void _showTodaySessionsDialog() {
    final sessionService = context.read<SessionService>();
    showDialog(
      // Sử dụng showDialog thay vì showModalBottomSheet
      context: context,
      builder: (context) {
        return StreamBuilder<List<SessionModel>>(
          stream: sessionService.getTodaySessionsForClass(widget.classId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return AlertDialog(
                title: const Text('Lỗi'),
                content: Text('${snapshot.error}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Đóng'),
                  ),
                ],
              );
            }

            final sessionsToday = snapshot.data ?? [];

            if (sessionsToday.isEmpty) {
              return AlertDialog(
                title: const Text('Thông báo'),
                content: const Text(
                  'Không có buổi học nào được lên lịch hôm nay.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              );
            }

            // Sắp xếp lại danh sách: Đang diễn ra > Sắp diễn ra > Đã kết thúc
            sessionsToday.sort((a, b) {
              int statusValue(SessionStatus status) {
                switch (status) {
                  case SessionStatus.inProgress:
                    return 0;
                  case SessionStatus.scheduled:
                    return 1;
                  default:
                    return 2;
                }
              }

              return statusValue(a.status).compareTo(statusValue(b.status));
            });

            // Giao diện Dialog
            return AlertDialog(
              title: const Text('Chọn buổi học để điểm danh'),
              // Bọc nội dung trong SizedBox để tránh lỗi tràn layout
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sessionsToday.length,
                  itemBuilder: (context, index) {
                    final session = sessionsToday[index];
                    final isCompleted =
                        session.status == SessionStatus.completed;
                    final isOngoing =
                        session.status == SessionStatus.inProgress;
                    final colorScheme = Theme.of(context).colorScheme;

                    return ListTile(
                      leading: Icon(
                        Icons.qr_code_scanner_outlined,
                        color: isCompleted
                            ? Colors.grey
                            : colorScheme.onSurface,
                      ),
                      title: Text(
                        session.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? Colors.grey
                              : colorScheme.onSurface,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: Text(
                        'Bắt đầu lúc: ${DateFormat.Hm().format(session.startTime)}',
                        style: TextStyle(
                          color: isCompleted ? Colors.grey : null,
                        ),
                      ),
                      trailing: isCompleted
                          ? const Chip(
                              label: Text('Đã kết thúc'),
                              padding: EdgeInsets.zero,
                            )
                          : (isOngoing
                                ? Chip(
                                    label: const Text('Đang diễn ra'),
                                    backgroundColor:
                                        Colors.greenAccent.shade100,
                                    labelStyle: TextStyle(
                                      color: Colors.green.shade900,
                                    ),
                                    padding: EdgeInsets.zero,
                                  )
                                : null),
                      onTap: isCompleted
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              _showDynamicQrForSession(session);
                            },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Huỷ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final classSvc = context.read<ClassService>();
    final sessionSvc = context.read<SessionService>();
    final auth = context.watch<AuthProvider>();
    final isLecturer = auth.role == UserRole.lecture;

    return StreamBuilder<RichClassModel>(
      stream: classSvc.getRichClassStream(widget.classId),
      builder: (context, classSnap) {
        if (classSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (classSnap.hasError || !classSnap.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Text(classSnap.error?.toString() ?? 'Không tìm thấy lớp'),
            ),
          );
        }

        final richClass = classSnap.data!;
        final classInfo = richClass.classInfo;
        final courses = richClass.courses;
        final lecturer = richClass.lecturer;
        final courseNames = courses.map((c) => c.courseName).join(' | ');

        return Scaffold(
          appBar: AppBar(title: Text(classInfo.className)),
          floatingActionButton: isLecturer
              ? FloatingActionButton.extended(
                  onPressed: _showTodaySessionsDialog,
                  label: const Text('Tạo mã QR'),
                  icon: const Icon(Icons.qr_code_2_outlined),
                )
              : null,

          // === TÁI CẤU TRÚC BODY: SỬ DỤNG TABS ===
          body: Column(
            children: [
              // --- PHẦN 1: THÔNG TIN CỐ ĐỊNH BÊN TRÊN ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.class_)),
                    title: Text(
                      courseNames.isNotEmpty ? courseNames : 'Chưa có môn học',
                    ),
                    subtitle: Text(
                      'GV: ${lecturer?.displayName ?? "..."}\nHọc kỳ: ${classInfo.semester}',
                    ),
                    isThreeLine: true,
                  ),
                ),
              ),

              // --- PHẦN 2: THANH CHỌN TAB ---
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.event_note_outlined), text: 'Buổi học'),
                  Tab(icon: Icon(Icons.people_outline), text: 'Sinh viên'),
                ],
              ),

              // --- PHẦN 3: NỘI DUNG CỦA TỪNG TAB ---
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // --- NỘI DUNG TAB 1: DANH SÁCH BUỔI HỌC ---
                    _buildSessionList(sessionSvc, classInfo),

                    // --- NỘI DUNG TAB 2: DANH SÁCH SINH VIÊN ---
                    _buildStudentList(classSvc, classInfo, isLecturer),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // === TÁCH WIDGET: Tạo hàm riêng cho danh sách buổi học ===
  Widget _buildSessionList(SessionService sessionSvc, ClassModel classInfo) {
    return StreamBuilder<List<SessionModel>>(
      stream: sessionSvc.sessionsOfClass(widget.classId),
      builder: (context, sessionSnap) {
        if (sessionSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final sessions = sessionSnap.data ?? [];
        if (sessions.isEmpty) {
          return const Center(child: Text('Chưa có buổi học nào.'));
        }
        // Bỏ shrinkWrap và physics để nó tự cuộn trong TabBarView
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.event_note_outlined, size: 28),
                title: Text(session.title),
                subtitle: Row(
                  children: [
                    Text(
                      '${DateFormat('dd/MM/yyyy HH:mm').format(session.startTime)} • ',
                    ),
                    _SessionStatusChip(status: session.status),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SessionDetailPage(
                        session: session,
                        classInfo: classInfo,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // === TÁCH WIDGET: Tạo hàm riêng cho danh sách sinh viên ===
  Widget _buildStudentList(
    ClassService classSvc,
    ClassModel classInfo,
    bool isLecturer,
  ) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: classSvc.getEnrolledStudents(classInfo.id),
      builder: (context, ms) {
        if (ms.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final members = ms.data ?? [];
        if (members.isEmpty) {
          return const Center(child: Text('Chưa có sinh viên nào.'));
        }
        // Bỏ shrinkWrap và physics để nó tự cuộn
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, i) {
            final m = members[i];
            final studentName = m['displayName'] ?? 'N/A';
            final studentEmail = m['email'] ?? 'N/A';
            final enrollmentId = m['enrollmentId'];

            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(studentName),
                subtitle: Text(studentEmail),
                trailing: isLecturer
                    ? IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () async {
                          // --- BẮT ĐẦU LOGIC XOÁ MỚI ---

                          // B1: Kiểm tra xem enrollmentId có tồn tại không
                          if (enrollmentId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Không tìm thấy thông tin để xoá.',
                                ),
                              ),
                            );
                            return;
                          }

                          // B2: Hiển thị hộp thoại xác nhận
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Xác nhận xoá'),
                                content: Text(
                                  'Bạn có chắc chắn muốn xoá sinh viên "$studentName" khỏi lớp học không?',
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('HUỶ'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text(
                                      'XOÁ',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );

                          // B3: Nếu người dùng xác nhận, tiến hành xoá
                          if (confirm == true) {
                            try {
                              // Gọi hàm từ service
                              await context
                                  .read<ClassService>()
                                  .removeStudentFromClass(enrollmentId);

                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Đã xoá sinh viên "$studentName".',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              // Cập nhật lại UI để danh sách làm mới
                              setState(() {});
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().replaceFirst(
                                      "Exception: ",
                                      "",
                                    ),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}

// @override
// Widget build(BuildContext context) {
//   final classSvc = context.read<ClassService>();
//   final sessionSvc = context.read<SessionService>();
//   final auth = context.watch<AuthProvider>();
//   final isLecturer = auth.role == UserRole.lecture;

//   return StreamBuilder<RichClassModel>(
//     stream: classSvc.getRichClassStream(widget.classId),
//     builder: (context, classSnap) {
//       if (classSnap.connectionState == ConnectionState.waiting) {
//         return const Scaffold(
//           body: Center(child: CircularProgressIndicator()),
//         );
//       }
//       if (classSnap.hasError || !classSnap.hasData) {
//         return Scaffold(
//           appBar: AppBar(),
//           body: Center(
//             child: Text(classSnap.error?.toString() ?? 'Không tìm thấy lớp'),
//           ),
//         );
//       }

//       final richClass = classSnap.data!;
//       final classInfo = richClass.classInfo;
//       final courses = richClass.courses;
//       final lecturer = richClass.lecturer;
//       final courseNames = courses.map((c) => c.courseName).join(' | ');

//       return Scaffold(
//         appBar: AppBar(title: Text(classInfo.className)),
//         floatingActionButton: isLecturer
//             ? FloatingActionButton.extended(
//                 onPressed: _showTodaySessionsDialog,
//                 label: const Text('Tạo mã QR'),
//                 icon: const Icon(Icons.qr_code_2_outlined),
//               )
//             : null,
//         body: ListView(
//           padding: const EdgeInsets.fromLTRB(
//             16,
//             16,
//             16,
//             80,
//           ), // Thêm padding dưới để FAB không che mất
//           children: [
//             Card(
//               child: ListTile(
//                 leading: const CircleAvatar(child: Icon(Icons.class_)),
//                 title: Text(
//                   courseNames.isNotEmpty ? courseNames : 'Chưa có môn học',
//                 ),
//                 subtitle: Text(
//                   'Lớp: ${classInfo.className}\nGV: ${lecturer?.displayName ?? "..."}\nHọc kỳ: ${classInfo.semester}',
//                 ),
//                 isThreeLine: true,
//               ),
//             ),
//             const SizedBox(height: 16),
//             Card(
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 12),
//                 child: Column(
//                   children: [
//                     Text(
//                       'Mã tham gia lớp: ${classInfo.joinCode}',
//                       style: Theme.of(context).textTheme.titleMedium,
//                     ),
//                     const SizedBox(height: 8),
//                     QrImageView(data: classInfo.joinCode, size: 180),
//                     if (isLecturer)
//                       TextButton.icon(
//                         icon: const Icon(Icons.refresh, size: 20),
//                         label: const Text('Tạo mã mới'),
//                         onPressed: () async =>
//                             await classSvc.regenerateJoinCode(classInfo.id),
//                       ),
//                   ],
//                 ),
//               ),
//             ),
//             const SizedBox(height: 24),
//             // === THAY ĐỔI 3: Bỏ nút cũ ra khỏi danh sách ===
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 8.0),
//               // Chỉ còn lại tiêu đề, nút đã được chuyển thành FAB
//               child: Text(
//                 'Các buổi học',
//                 style: Theme.of(context).textTheme.titleLarge,
//               ),
//             ),
//             const SizedBox(height: 8),

//             // === NÂNG CẤP GIAO DIỆN: Hiển thị trạng thái buổi học ===
//             StreamBuilder<List<SessionModel>>(
//               stream: sessionSvc.sessionsOfClass(widget.classId),
//               builder: (context, sessionSnap) {
//                 if (sessionSnap.connectionState == ConnectionState.waiting) {
//                   return const Center(child: CircularProgressIndicator());
//                 }
//                 final sessions = sessionSnap.data ?? [];
//                 if (sessions.isEmpty) {
//                   return const Card(
//                     child: Padding(
//                       padding: EdgeInsets.all(16),
//                       child: Center(
//                         child: Text('Chưa có buổi học nào được tạo.'),
//                       ),
//                     ),
//                   );
//                 }
//                 return ListView.builder(
//                   shrinkWrap: true,
//                   physics: const NeverScrollableScrollPhysics(),
//                   itemCount: sessions.length,
//                   itemBuilder: (context, index) {
//                     final session = sessions[index];
//                     return Card(
//                       margin: const EdgeInsets.only(bottom: 8),
//                       child: ListTile(
//                         leading: const Icon(
//                           Icons.event_note_outlined,
//                           size: 28,
//                         ),
//                         title: Text(session.title),
//                         subtitle: Row(
//                           children: [
//                             Text(
//                               '${DateFormat('dd/MM/yyyy HH:mm').format(session.startTime)} • ',
//                             ),
//                             // Sử dụng widget helper để hiển thị trạng thái
//                             _SessionStatusChip(status: session.status),
//                           ],
//                         ),
//                         trailing: const Icon(Icons.chevron_right),
//                         onTap: () {
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) => SessionDetailPage(
//                                 session: session,
//                                 classInfo: classInfo,
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//             const SizedBox(height: 24),

//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 8.0),
//               child: Text(
//                 'Danh sách sinh viên',
//                 style: Theme.of(context).textTheme.titleLarge,
//               ),
//             ),
//             const SizedBox(height: 8),
//             FutureBuilder<List<Map<String, dynamic>>>(
//               future: classSvc.getEnrolledStudents(classInfo.id),
//               builder: (context, ms) {
//                 if (ms.connectionState == ConnectionState.waiting) {
//                   return const Center(child: CircularProgressIndicator());
//                 }
//                 final members = ms.data ?? [];
//                 if (members.isEmpty) {
//                   return const Card(
//                     child: Padding(
//                       padding: EdgeInsets.all(16),
//                       child: Center(
//                         child: Text('Chưa có sinh viên nào tham gia.'),
//                       ),
//                     ),
//                   );
//                 }

//                 return Card(
//                   clipBehavior: Clip.antiAlias,
//                   child: ListView.separated(
//                     shrinkWrap: true,
//                     physics: const NeverScrollableScrollPhysics(),
//                     itemCount: members.length,
//                     separatorBuilder: (_, __) => const Divider(height: 1),
//                     itemBuilder: (context, i) {
//                       final m = members[i];
//                       // Lấy ra các thông tin cần thiết từ map
//                       final studentName = m['displayName'] ?? 'N/A';
//                       final studentEmail = m['email'] ?? 'N/A';
//                       final enrollmentId =
//                           m['enrollmentId']; // ID để thực hiện việc xoá

//                       return ListTile(
//                         leading: const Icon(Icons.person_outline),
//                         title: Text(studentName),
//                         subtitle: Text(studentEmail),
//                         trailing: isLecturer
//                             ? IconButton(
//                                 icon: const Icon(
//                                   Icons.delete_outline,
//                                   color: Colors.red,
//                                 ),
//                                 onPressed: () async {
//                                   // --- BẮT ĐẦU LOGIC XOÁ MỚI ---

//                                   // B1: Kiểm tra xem enrollmentId có tồn tại không
//                                   if (enrollmentId == null) {
//                                     ScaffoldMessenger.of(
//                                       context,
//                                     ).showSnackBar(
//                                       const SnackBar(
//                                         content: Text(
//                                           'Không tìm thấy thông tin để xoá.',
//                                         ),
//                                       ),
//                                     );
//                                     return;
//                                   }

//                                   // B2: Hiển thị hộp thoại xác nhận
//                                   final confirm = await showDialog<bool>(
//                                     context: context,
//                                     builder: (BuildContext context) {
//                                       return AlertDialog(
//                                         title: const Text('Xác nhận xoá'),
//                                         content: Text(
//                                           'Bạn có chắc chắn muốn xoá sinh viên "$studentName" khỏi lớp học không?',
//                                         ),
//                                         actions: <Widget>[
//                                           TextButton(
//                                             onPressed: () => Navigator.of(
//                                               context,
//                                             ).pop(false),
//                                             child: const Text('HUỶ'),
//                                           ),
//                                           TextButton(
//                                             onPressed: () => Navigator.of(
//                                               context,
//                                             ).pop(true),
//                                             child: const Text(
//                                               'XOÁ',
//                                               style: TextStyle(
//                                                 color: Colors.red,
//                                               ),
//                                             ),
//                                           ),
//                                         ],
//                                       );
//                                     },
//                                   );

//                                   // B3: Nếu người dùng xác nhận, tiến hành xoá
//                                   if (confirm == true) {
//                                     try {
//                                       // Gọi hàm từ service
//                                       await context
//                                           .read<ClassService>()
//                                           .removeStudentFromClass(
//                                             enrollmentId,
//                                           );

//                                       if (!mounted) return;
//                                       ScaffoldMessenger.of(
//                                         context,
//                                       ).showSnackBar(
//                                         SnackBar(
//                                           content: Text(
//                                             'Đã xoá sinh viên "$studentName".',
//                                           ),
//                                           backgroundColor: Colors.green,
//                                         ),
//                                       );
//                                       // Cập nhật lại UI để danh sách làm mới
//                                       setState(() {});
//                                     } catch (e) {
//                                       if (!mounted) return;
//                                       ScaffoldMessenger.of(
//                                         context,
//                                       ).showSnackBar(
//                                         SnackBar(
//                                           content: Text(
//                                             e.toString().replaceFirst(
//                                               "Exception: ",
//                                               "",
//                                             ),
//                                           ),
//                                           backgroundColor: Colors.red,
//                                         ),
//                                       );
//                                     }
//                                   }
//                                 },
//                               )
//                             : null,
//                       );
//                     },
//                   ),
//                 );
//               },
//             ),
//           ],
//         ),
//       );
//     },
//   );
// }

// === WIDGET HELPER MỚI: Để hiển thị trạng thái buổi học ===
class _SessionStatusChip extends StatelessWidget {
  final SessionStatus status;

  const _SessionStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    String text;
    Color backgroundColor;
    Color textColor = Colors.black87;

    switch (status) {
      case SessionStatus.inProgress:
        text = 'Đang diễn ra';
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade900;
        break;
      case SessionStatus.completed:
        text = 'Đã kết thúc';
        backgroundColor = Colors.grey.shade300;
        textColor = Colors.grey.shade800;
        break;
      case SessionStatus.scheduled:
        text = 'Sắp diễn ra';
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade900;
        break;
      case SessionStatus.cancelled:
        text = 'Đã hủy';
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade900;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
