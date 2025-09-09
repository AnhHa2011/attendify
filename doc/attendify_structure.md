# Cấu trúc thư mục Attendify

```
attendify/
├── android/                    # Code native Android
├── ios/                       # Code native iOS
├── web/                       # Code web
├── macos/                     # Code macOS
├── windows/                   # Code Windows
├── linux/                     # Code Linux
├── lib/                       # Thư mục chính làm việc
│   ├── main.dart             # Entry point
│   │
│   ├── core/                 # Core utilities và configurations
│   │   ├── config/
│   │   │   ├── app_config.dart
│   │   │   ├── firebase_config.dart
│   │   │   └── theme_config.dart
│   │   ├── constants/
│   │   │   ├── app_constants.dart
│   │   │   ├── firestore_collections.dart
│   │   │   └── route_names.dart
│   │   ├── errors/
│   │   │   ├── exceptions.dart
│   │   │   └── failures.dart
│   │   ├── network/
│   │   │   └── network_info.dart
│   │   ├── utils/
│   │   │   ├── validators.dart
│   │   │   ├── date_helpers.dart
│   │   │   ├── device_utils.dart
│   │   │   ├── location_utils.dart
│   │   │   └── qr_utils.dart
│   │   └── widgets/
│   │       ├── custom_button.dart
│   │       ├── custom_text_field.dart
│   │       ├── loading_indicator.dart
│   │       ├── error_widget.dart
│   │       └── confirmation_dialog.dart
│   │
│   ├── data/                 # Data layer (Repository pattern)
│   │   ├── datasources/
│   │   │   ├── local/
│   │   │   │   └── shared_preferences_helper.dart
│   │   │   └── remote/
│   │   │       ├── auth_remote_datasource.dart
│   │   │       ├── user_remote_datasource.dart
│   │   │       ├── class_remote_datasource.dart
│   │   │       ├── session_remote_datasource.dart
│   │   │       └── attendance_remote_datasource.dart
│   │   ├── models/
│   │   │   ├── user_model.dart
│   │   │   ├── class_model.dart
│   │   │   ├── enrollment_model.dart
│   │   │   ├── session_model.dart
│   │   │   ├── attendance_record_model.dart
│   │   │   └── leave_request_model.dart
│   │   └── repositories/
│   │       ├── auth_repository_impl.dart
│   │       ├── user_repository_impl.dart
│   │       ├── class_repository_impl.dart
│   │       ├── session_repository_impl.dart
│   │       └── attendance_repository_impl.dart
│   │
│   ├── domain/               # Business logic layer
│   │   ├── entities/
│   │   │   ├── user.dart
│   │   │   ├── class.dart
│   │   │   ├── enrollment.dart
│   │   │   ├── session.dart
│   │   │   ├── attendance_record.dart
│   │   │   └── leave_request.dart
│   │   ├── repositories/     # Abstract repositories
│   │   │   ├── auth_repository.dart
│   │   │   ├── user_repository.dart
│   │   │   ├── class_repository.dart
│   │   │   ├── session_repository.dart
│   │   │   └── attendance_repository.dart
│   │   └── usecases/
│   │       ├── auth/
│   │       │   ├── login_usecase.dart
│   │       │   ├── register_usecase.dart
│   │       │   └── logout_usecase.dart
│   │       ├── lecturer/
│   │       │   ├── create_class_usecase.dart
│   │       │   ├── manage_students_usecase.dart
│   │       │   ├── create_session_usecase.dart
│   │       │   └── generate_qr_usecase.dart
│   │       └── student/
│   │           ├── join_class_usecase.dart
│   │           ├── scan_qr_usecase.dart
│   │           └── submit_attendance_usecase.dart
│   │
│   ├── presentation/         # UI layer
│   │   ├── blocs/           # State management với BLoC
│   │   │   ├── auth/
│   │   │   │   ├── auth_bloc.dart
│   │   │   │   ├── auth_event.dart
│   │   │   │   └── auth_state.dart
│   │   │   ├── lecturer/
│   │   │   │   ├── class_management/
│   │   │   │   ├── session_management/
│   │   │   │   └── attendance_management/
│   │   │   └── student/
│   │   │       ├── class_participation/
│   │   │       ├── attendance/
│   │   │       └── schedule/
│   │   ├── pages/
│   │   │   ├── splash/
│   │   │   │   └── splash_page.dart
│   │   │   ├── auth/
│   │   │   │   ├── login_page.dart
│   │   │   │   └── register_page.dart
│   │   │   ├── common/
│   │   │   │   ├── home_page.dart
│   │   │   │   └── profile_page.dart
│   │   │   ├── lecturer/
│   │   │   │   ├── dashboard/
│   │   │   │   │   └── lecturer_dashboard_page.dart
│   │   │   │   ├── class_management/
│   │   │   │   │   ├── class_list_page.dart
│   │   │   │   │   ├── create_class_page.dart
│   │   │   │   │   ├── class_detail_page.dart
│   │   │   │   │   └── student_management_page.dart
│   │   │   │   ├── session_management/
│   │   │   │   │   ├── session_list_page.dart
│   │   │   │   │   ├── create_session_page.dart
│   │   │   │   │   └── qr_display_page.dart
│   │   │   │   ├── attendance_management/
│   │   │   │   │   ├── attendance_overview_page.dart
│   │   │   │   │   └── attendance_detail_page.dart
│   │   │   │   ├── leave_requests/
│   │   │   │   │   └── leave_request_management_page.dart
│   │   │   │   └── reports/
│   │   │   │       ├── attendance_report_page.dart
│   │   │   │       └── export_data_page.dart
│   │   │   └── student/
│   │   │       ├── dashboard/
│   │   │       │   └── student_dashboard_page.dart
│   │   │       ├── class_participation/
│   │   │       │   ├── class_list_page.dart
│   │   │       │   └── join_class_page.dart
│   │   │       ├── schedule/
│   │   │       │   └── schedule_page.dart
│   │   │       ├── attendance/
│   │   │       │   ├── qr_scanner_page.dart
│   │   │       │   └── attendance_history_page.dart
│   │   │       └── leave_requests/
│   │   │           ├── create_leave_request_page.dart
│   │   │           └── leave_request_status_page.dart
│   │   ├── widgets/
│   │   │   ├── common/
│   │   │   │   ├── app_bar_widget.dart
│   │   │   │   ├── bottom_navigation_widget.dart
│   │   │   │   ├── drawer_widget.dart
│   │   │   │   └── card_widget.dart
│   │   │   ├── lecturer/
│   │   │   │   ├── class_card_widget.dart
│   │   │   │   ├── student_list_widget.dart
│   │   │   │   ├── qr_display_widget.dart
│   │   │   │   └── attendance_stats_widget.dart
│   │   │   └── student/
│   │   │       ├── class_tile_widget.dart
│   │   │       ├── schedule_tile_widget.dart
│   │   │       ├── qr_scanner_widget.dart
│   │   │       └── attendance_status_widget.dart
│   │   └── routes/
│   │       ├── app_router.dart
│   │       └── route_generator.dart
│   │
│   ├── services/            # External services
│   │   ├── firebase/
│   │   │   ├── firebase_auth_service.dart
│   │   │   ├── firestore_service.dart
│   │   │   ├── firebase_storage_service.dart
│   │   │   └── cloud_functions_service.dart
│   │   ├── location/
│   │   │   └── location_service.dart
│   │   ├── camera/
│   │   │   └── camera_service.dart
│   │   ├── notification/
│   │   │   └── notification_service.dart
│   │   ├── permission/
│   │   │   └── permission_service.dart
│   │   └── export/
│   │       └── export_service.dart
│   │
│   └── app.dart            # App widget chính
│
├── assets/                 # Tài nguyên
│   ├── images/
│   │   ├── logo.png
│   │   ├── splash_background.png
│   │   └── icons/
│   ├── fonts/
│   └── translations/       # Đa ngôn ngữ
│       ├── en.json
│       └── vi.json
│
├── test/                   # Unit tests
│   ├── data/
│   ├── domain/
│   ├── presentation/
│   └── services/
│
├── integration_test/       # Integration tests
│
├── firebase/              # Firebase configurations
│   ├── functions/         # Cloud Functions
│   │   ├── src/
│   │   ├── package.json
│   │   └── index.js
│   ├── firestore.rules   # Firestore security rules
│   └── storage.rules     # Storage security rules
│
├── pubspec.yaml          # Dependencies
├── pubspec.lock
├── analysis_options.yaml # Linting rules
├── README.md
└── .gitignore
```

## Packages cần thiết trong pubspec.yaml

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Firebase
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  google_sign_in: ^6.1.6
  cloud_firestore: ^4.13.6
  firebase_storage: ^11.5.6
  cloud_functions: ^4.6.6
  
  # State Management
  flutter_bloc: ^8.1.3
  equatable: ^2.0.5
  
  # UI
  cupertino_icons: ^1.0.6
  material_design_icons_flutter: ^7.0.7296
  
  # QR Code
  qr_flutter: ^4.1.0
  mobile_scanner: ^3.5.6
  
  # Location & Device
  geolocator: ^10.1.0
  device_info_plus: ^9.1.1
  permission_handler: ^11.0.1
  
  # Network & Utils
  dio: ^5.4.0
  connectivity_plus: ^5.0.2
  shared_preferences: ^2.2.2
  
  # File & Export
  file_picker: ^6.1.1
  excel: ^2.1.0
  pdf: ^3.10.7
  share_plus: ^7.2.1
  
  # Date & Time
  intl: ^0.18.1
  
  # Routing
  go_router: ^12.1.3
  
  # Image
  cached_network_image: ^3.3.0
  image_picker: ^1.0.4
  
  # Notification
  flutter_local_notifications: ^16.3.0
  
  # Charts (for reports)
  fl_chart: ^0.65.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  build_runner: ^2.4.7
  mockito: ^5.4.4
```