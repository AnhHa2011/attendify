const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Khởi tạo Firebase Admin SDK
admin.initializeApp();

/**
 * Cloud Function để tạo người dùng mới và gán vai trò (role) từ phía admin.
 * Chỉ có thể gọi bởi user có role = "admin".
 */
exports.createUserByAdmin = functions.https.onCall(async (data, context) => {
  // 1. Kiểm tra bảo mật: Người gọi phải là admin
  if (
    !context.auth ||
    !context.auth.token ||
    context.auth.token.role !== "admin"
  ) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Chỉ có quản trị viên mới có quyền thực hiện hành động này."
    );
  }

  // 2. Lấy dữ liệu từ client
  const { email, password, displayName, role } = data;

  if (!email || !password || !displayName || !role) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Vui lòng cung cấp đầy đủ thông tin: email, password, displayName, role."
    );
  }

  try {
    // 3. Tạo người dùng trong Firebase Authentication
    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName,
    });

    // 4. Gán role cho user
    await admin.auth().setCustomUserClaims(userRecord.uid, { role });

    // 5. Lưu thông tin vào Firestore
    await admin.firestore().collection("users").doc(userRecord.uid).set({
      displayName,
      email,
      role,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      message: `Tạo người dùng ${userRecord.email} thành công.`,
      uid: userRecord.uid,
    };
  } catch (error) {
    if (error.code === "auth/email-already-exists") {
      throw new functions.https.HttpsError(
        "already-exists",
        "Email này đã được sử dụng bởi một tài khoản khác."
      );
    }
    throw new functions.https.HttpsError("internal", error.message);
  }
});
