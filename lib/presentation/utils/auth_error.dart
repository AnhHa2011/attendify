import 'package:firebase_auth/firebase_auth.dart';

String authErrorText(Object error) {
  // Luôn “đỡ” lỗi lạ
  const fallback = 'Có lỗi xảy ra, vui lòng thử lại.';

  if (error is FirebaseAuthException) {
    switch (error.code) {
      // Đăng nhập email/password
      case 'user-not-found':
        return 'Tài khoản không tồn tại.';
      case 'wrong-password':
        return 'Mật khẩu không đúng.';
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'user-disabled':
        return 'Tài khoản đã bị vô hiệu hoá, liên hệ quản trị viên.';
      case 'too-many-requests':
        return 'Bạn đã thử quá nhiều lần. Vui lòng thử lại sau ít phút.';
      case 'network-request-failed':
        return 'Không có kết nối mạng. Vui lòng kiểm tra mạng và thử lại.';

      // Đăng ký email/password
      case 'email-already-in-use':
        return 'Email này đã được sử dụng.';
      case 'weak-password':
        return 'Mật khẩu quá yếu. Vui lòng đặt mật khẩu mạnh hơn.';
      case 'operation-not-allowed':
        return 'Phương thức đăng nhập này đang bị tắt trên hệ thống.';

      // Đăng nhập Google / liên kết tài khoản
      case 'account-exists-with-different-credential':
        return 'Email này đã đăng ký bằng phương thức khác. Hãy đăng nhập bằng phương thức trước đó.';
      case 'invalid-credential':
        return 'Thông tin đăng nhập không hợp lệ. Hãy thử lại.';
      case 'popup-closed-by-user': // web
      case 'aborted-by-user': // mình ném ra khi user huỷ
        return 'Bạn đã huỷ thao tác đăng nhập.';

      // Reset mật khẩu
      case 'missing-email':
        return 'Vui lòng nhập email để khôi phục mật khẩu.';

      default:
        // Có thể log error.code để theo dõi
        return fallback;
    }
  }

  // Ngoài FirebaseAuthException: trả fallback
  return fallback;
}
