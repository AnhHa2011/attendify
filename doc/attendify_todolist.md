# Todo List Chi Tiết - Attendify

## Phase 1: Thiết lập dự án và cấu hình cơ bản (Tuần 1)

### 1.1 Khởi tạo dự án
- [ ] Tạo dự án Flutter mới với `flutter create attendify`
- [ ] Cấu hình hỗ trợ đa nền tảng (web, iOS, macOS, Android, desktop)
- [ ] Thiết lập cấu trúc thư mục theo kiến trúc Clean Architecture
- [ ] Cấu hình `pubspec.yaml` với tất cả dependencies cần thiết

### 1.2 Thiết lập Firebase
- [ ] Tạo project Firebase mới
- [ ] Cấu hình Firebase cho từng platform:
  - [ ] Android: `google-services.json`
  - [ ] iOS: `GoogleService-Info.plist`
  - [ ] Web: Firebase config
  - [ ] macOS: Firebase config
- [ ] Chạy `flutterfire configure`
- [ ] Thiết lập Firebase Authentication
- [ ] Thiết lập Cloud Firestore
- [ ] Thiết lập Firebase Storage (tùy chọn)
- [ ] Thiết lập Cloud Functions

### 1.3 Cấu hình cơ bản
- [ ] Tạo `core/config/app_config.dart`
- [ ] Tạo `core/config/theme_config.dart`
- [ ] Tạo `core/constants/app_constants.dart`
- [ ] Tạo `core/constants/firestore_collections.dart`
- [ ] Thiết lập routing với GoRouter

## Phase 2: Xây dựng Data Layer (Tuần 2)

### 2.1 Models
- [ ] Tạo `UserModel` với đầy đủ fields và methods
- [ ] Tạo `ClassModel` cho quản lý lớp học
- [ ] Tạo `EnrollmentModel` cho ghi danh sinh viên
- [ ] Tạo `SessionModel` cho buổi học
- [ ] Tạo `AttendanceRecordModel` cho điểm danh
- [ ] Tạo `LeaveRequestModel` cho yêu cầu xin nghỉ
- [ ] Tạo `NotificationModel` cho thông báo

### 2.2 Data Sources
- [ ] Tạo `AuthRemoteDataSource` với Firebase Auth
- [ ] Tạo `UserRemoteDataSource` với Firestore
- [ ] Tạo `ClassRemoteDataSource` với Firestore
- [ ] Tạo `SessionRemoteDataSource` với Firestore
- [ ] Tạo `AttendanceRemoteDataSource` với Firestore
- [ ] Tạo `LeaveRequestRemoteDataSource` với Firestore
- [ ] Tạo `SharedPreferencesHelper` cho local storage

### 2.3 Repositories Implementation
- [ ] Implement `AuthRepositoryImpl`
- [ ] Implement `UserRepositoryImpl`
- [ ] Implement `ClassRepositoryImpl`
- [ ] Implement `SessionRepositoryImpl`
- [ ] Implement `AttendanceRepositoryImpl`
- [ ] Implement `LeaveRequestRepositoryImpl`

## Phase 3: Xây dựng Domain Layer (Tuần 3)

### 3.1 Entities
- [ ] Tạo các entity classes tương ứng với models
- [ ] Định nghĩa business rules trong entities

### 3.2 Repository Interfaces
- [ ] Tạo abstract repository interfaces
- [ ] Định nghĩa methods cần thiết cho từng repository

### 3.3 Use Cases
#### Auth Use Cases
- [ ] `LoginUseCase`
- [ ] `RegisterUseCase`
- [ ] `LogoutUseCase`
- [ ] `GetCurrentUserUseCase`
- [ ] `UpdateProfileUseCase`

#### Lecturer Use Cases
- [ ] `CreateClassUseCase`
- [ ] `UpdateClassUseCase`
- [ ] `DeleteClassUseCase`
- [ ] `GetLecturerClassesUseCase`
- [ ] `AddStudentToClassUseCase`
- [ ] `RemoveStudentFromClassUseCase`
- [ ] `CreateSessionUseCase`
- [ ] `EndSessionUseCase`
- [ ] `GenerateQRTokenUseCase`
- [ ] `GetAttendanceReportUseCase`
- [ ] `ApproveLeaveRequestUseCase`

#### Student Use Cases
- [ ] `JoinClassUseCase`
- [ ] `GetStudentClassesUseCase`
- [ ] `ScanQRUseCase`
- [ ] `SubmitAttendanceUseCase`
- [ ] `GetAttendanceHistoryUseCase`
- [ ] `CreateLeaveRequestUseCase`
- [ ] `GetScheduleUseCase`

## Phase 4: Xây dựng Presentation Layer - Core (Tuần 4)

### 4.1 State Management (BLoC)
- [ ] Tạo `AuthBloc` với states và events
- [ ] Tạo `UserBloc` cho quản lý user profile
- [ ] Thiết lập BlocProvider và MultiBlocProvider

### 4.2 Common Widgets
- [ ] `CustomButton` widget
- [ ] `CustomTextField` widget
- [ ] `LoadingIndicator` widget
- [ ] `ErrorWidget` custom
- [ ] `ConfirmationDialog` widget
- [ ] `CustomAppBar` widget
- [ ] `CustomCard` widget

### 4.3 Core Pages
- [ ] `SplashPage` với logic kiểm tra authentication
- [ ] `LoginPage` với form validation
- [ ] `RegisterPage` với role selection
- [ ] `ProfilePage` cho cả lecturer và student

## Phase 5: Lecturer Features (Tuần 5-6)

### 5.1 Lecturer Dashboard
- [ ] Tạo `LecturerDashboardPage`
- [ ] Hiển thị overview classes, sessions, statistics
- [ ] Navigation drawer cho lecturer features

### 5.2 Class Management
- [ ] `ClassListPage` - danh sách lớp của giảng viên
- [ ] `CreateClassPage` - tạo lớp mới
- [ ] `ClassDetailPage` - chi tiết lớp học
- [ ] `StudentManagementPage` - quản lý sinh viên trong lớp
- [ ] Logic thêm/xóa sinh viên
- [ ] Import danh sách sinh viên từ Excel

### 5.3 Session Management
- [ ] `SessionListPage` - danh sách buổi học
- [ ] `CreateSessionPage` - tạo buổi học mới
- [ ] `QRDisplayPage` - hiển thị QR code động
- [ ] Logic tạo và refresh QR token
- [ ] Real-time attendance tracking

### 5.4 Attendance Management
- [ ] `AttendanceOverviewPage` - tổng quan điểm danh
- [ ] `AttendanceDetailPage` - chi tiết buổi điểm danh
- [ ] Chỉnh sửa trạng thái điểm danh thủ công
- [ ] Xem danh sách sinh viên đã/chưa điểm danh

### 5.5 Leave Request Management
- [ ] `LeaveRequestManagementPage`
- [ ] Xem danh sách yêu cầu xin nghỉ
- [ ] Approve/reject leave requests
- [ ] Thêm ghi chú khi duyệt

### 5.6 Reports & Export
- [ ] `AttendanceReportPage` - báo cáo chuyên cần
- [ ] `ExportDataPage` - xuất dữ liệu
- [ ] Xuất Excel/PDF reports
- [ ] Thống kê theo sinh viên, theo lớp
- [ ] Charts và visualizations

## Phase 6: Student Features (Tuần 7-8)

### 6.1 Student Dashboard
- [ ] Tạo `StudentDashboardPage`
- [ ] Hiển thị classes, upcoming sessions, attendance rate
- [ ] Quick access to scan QR

### 6.2 Class Participation
- [ ] `ClassListPage` - danh sách lớp đã tham gia
- [ ] `JoinClassPage` - tham gia lớp bằng mã/QR
- [ ] Logic join class và enrollment

### 6.3 Schedule Management
- [ ] `SchedulePage` - thời khóa biểu
- [ ] Xem lịch theo ngày/tuần/tháng
- [ ] Chi tiết session (tên môn, giảng viên, phòng, thời gian)

### 6.4 Attendance Features
- [ ] `QRScannerPage` - quét QR code
- [ ] `AttendanceHistoryPage` - lịch sử điểm danh
- [ ] Logic scan QR và submit attendance
- [ ] Validation location và device
- [ ] Hiển thị trạng thái điểm danh real-time

### 6.5 Leave Request Features
- [ ] `CreateLeaveRequestPage` - tạo yêu cầu xin nghỉ
- [ ] `LeaveRequestStatusPage` - theo dõi trạng thái
- [ ] Upload minh chứng (ảnh, PDF)
- [ ] Xem lịch sử yêu cầu

## Phase 7: Services và Features Nâng cao (Tuần 9)

### 7.1 Core Services
- [ ] `LocationService` - xử lý GPS
- [ ] `CameraService` - xử lý camera cho QR scan
- [ ] `PermissionService` - quản lý permissions
- [ ] `NotificationService` - push notifications
- [ ] `ExportService` - xuất file Excel/PDF

### 7.2 Security Features
- [ ] Device fingerprinting cho chống gian lận
- [ ] Location validation
- [ ] QR token validation và expiry
- [ ] Firestore security rules

### 7.3 Notification System
- [ ] Local notifications cho reminders
- [ ] Push notifications cho updates
- [ ] Notification cho leave request status
- [ ] Attendance warnings

## Phase 8: UI/UX và Polish (Tuần 10)

### 8.1 UI Improvements
- [ ] Responsive design cho tất cả platforms
- [ ] Dark/Light theme support
- [ ] Animations và transitions
- [ ] Custom icons và illustrations

### 8.2 User Experience
- [ ] Loading states và skeleton screens
- [ ] Error handling và user feedback
- [ ] Offline support cơ bản
- [ ] Pull-to-refresh functionality

### 8.3 Accessibility
- [ ] Screen reader support
- [ ] High contrast mode
- [ ] Font scaling support
- [ ] Keyboard navigation

## Phase 9: Testing (Tuần 11)

### 9.1 Unit Tests
- [ ] Test cho tất cả use cases
- [ ] Test cho repositories
- [ ] Test cho models và entities
- [ ] Test cho utils và helpers

### 9.2 Widget Tests
- [ ] Test cho common widgets
- [ ] Test cho pages chính
- [ ] Test cho form validation

### 9.3 Integration Tests
- [ ] End-to-end test flows
- [ ] Firebase integration tests
- [ ] QR scanning tests

## Phase 10: Deployment và Documentation (Tuần 12)

### 10.1 Cloud Functions
- [ ] Deploy attendance validation functions
- [ ] Deploy notification functions
- [ ] Configure Firebase triggers

### 10.2 Deployment
- [ ] Android: Play Store build
- [ ] iOS: App Store build  
- [ ] Web: Firebase Hosting
- [ ] Desktop: Platform-specific builds

### 10.3 Documentation
- [ ] API documentation
- [ ] User manual
- [ ] Developer documentation
- [ ] Deployment guide

## Bonus Features (Nếu có thời gian)

### Advanced Features
- [ ] Biometric authentication
- [ ] Face recognition cho điểm danh
- [ ] AI-powered attendance analytics
- [ ] Multi-language support
- [ ] Advanced reporting dashboard
- [ ] Integration với LMS systems
- [ ] Bulk operations
- [ ] Advanced search và filtering
- [ ] Data synchronization cho offline mode
- [ ] Admin panel cho quản lý hệ thống

### Performance Optimizations
- [ ] Image optimization và caching
- [ ] Database query optimization
- [ ] Lazy loading cho large lists
- [ ] Memory management
- [ ] Background processing

---

## Lưu ý quan trọng:

1. **Ưu tiên MVP trước**: Tập trung vào core features trước khi làm advanced features
2. **Test liên tục**: Sau mỗi feature, hãy test kỹ trước khi chuyển sang feature tiếp theo
3. **Security first**: Luôn đặt security lên hàng đầu, đặc biệt với authentication và data validation
4. **User feedback**: Thu thập feedback sớm và thường xuyên từ users
5. **Performance monitoring**: Theo dõi performance và optimize khi cần thiết