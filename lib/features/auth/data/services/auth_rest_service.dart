import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';

class AuthRestService {
  AuthRestService();

  /// Tạo user qua REST API (signUp) và trả về localId (uid)
  /// Yêu cầu: bật Email/Password Sign-in trong Firebase Authentication.
  Future<String> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final apiKey =
        Firebase.app().options.apiKey; // lấy từ cấu hình Firebase web
    final url = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey',
    );

    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );

    if (resp.statusCode != 200) {
      // lấy message dễ hiểu
      final body = jsonDecode(resp.body);
      final err = body['error']?['message'] ?? resp.body;
      throw Exception('signUp failed: $err');
    }

    final data = jsonDecode(resp.body);
    final localId = data['localId']?.toString();
    if (localId == null || localId.isEmpty) {
      throw Exception('Missing localId from signUp response.');
    }
    return localId;
  }
}
