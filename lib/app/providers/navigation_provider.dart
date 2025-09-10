import 'package:flutter/material.dart';

enum NavigationLevel {
  main, // Level 1: Tổng quan, Lớp học, Tài khoản
  classContext, // Level 2: Buổi học, QR điểm danh, Xin nghỉ (cho 1 lớp cụ thể)
}

class NavigationState {
  final NavigationLevel level;
  final String? selectedClassId;
  final String? selectedClassName;
  final int currentIndex;

  const NavigationState({
    required this.level,
    this.selectedClassId,
    this.selectedClassName,
    this.currentIndex = 0,
  });

  NavigationState copyWith({
    NavigationLevel? level,
    String? selectedClassId,
    String? selectedClassName,
    int? currentIndex,
  }) {
    return NavigationState(
      level: level ?? this.level,
      selectedClassId: selectedClassId ?? this.selectedClassId,
      selectedClassName: selectedClassName ?? this.selectedClassName,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

class NavigationProvider extends ChangeNotifier {
  NavigationState _state = const NavigationState(level: NavigationLevel.main);

  NavigationState get state => _state;
  NavigationLevel get currentLevel => _state.level;
  String? get selectedClassId => _state.selectedClassId;
  String? get selectedClassName => _state.selectedClassName;
  int get currentIndex => _state.currentIndex;

  // Navigate to main level (Level 1)
  void navigateToMainLevel({int index = 0}) {
    _state = NavigationState(level: NavigationLevel.main, currentIndex: index);
    notifyListeners();
  }

  // Navigate to class context level (Level 2)
  void navigateToClassContext({
    required String classId,
    required String className,
    int index = 0,
  }) {
    _state = NavigationState(
      level: NavigationLevel.classContext,
      selectedClassId: classId,
      selectedClassName: className,
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
