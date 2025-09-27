import 'course_model.dart';
import 'user_model.dart';

class RichCourseModel {
  final CourseModel courseInfo;
  final UserModel? lecturer;

  RichCourseModel({required this.courseInfo, this.lecturer});
}
