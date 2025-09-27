import 'package:flutter/material.dart';

enum NavigationLevel {
  main, // Level 1: Tổng quan, Lớp học, Tài khoản
  courseContext, // Level 2: Buổi học, QR điểm danh, Xin nghỉ (cho 1 lớp cụ thể)
}

class NavigationState {
  final NavigationLevel level;
  final String? selectedcourseCode;
  final String? selectedCourseName;
  final int currentIndex;

  const NavigationState({
    required this.level,
    this.selectedcourseCode,
    this.selectedCourseName,
    this.currentIndex = 0,
  });

  NavigationState copyWith({
    NavigationLevel? level,
    String? selectedcourseCode,
    String? selectedCourseName,
    int? currentIndex,
  }) {
    return NavigationState(
      level: level ?? this.level,
      selectedcourseCode: selectedcourseCode ?? this.selectedcourseCode,
      selectedCourseName: selectedCourseName ?? this.selectedCourseName,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

class NavigationProvider extends ChangeNotifier {
  NavigationState _state = const NavigationState(level: NavigationLevel.main);

  NavigationState get state => _state;
  NavigationLevel get currentLevel => _state.level;
  String? get selectedcourseCode => _state.selectedcourseCode;
  String? get selectedCourseName => _state.selectedCourseName;
  int get currentIndex => _state.currentIndex;

  // Navigate to main level (Level 1)
  void navigateToMainLevel({int index = 0}) {
    _state = NavigationState(level: NavigationLevel.main, currentIndex: index);
    notifyListeners();
  }

  // Navigate to course context level (Level 2)
  void navigateToCourseContext({
    required String courseCode,
    required String courseName,
    int index = 0,
  }) {
    _state = NavigationState(
      level: NavigationLevel.courseContext,
      selectedcourseCode: courseCode,
      selectedCourseName: courseName,
      currentIndex: index,
    );
    notifyListeners();
  }

  // Set current index in current level
  void setCurrentIndex(int index) {
    _state = _state.copyWith(currentIndex: index);
    notifyListeners();
  }
}
