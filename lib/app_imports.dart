export 'dart:math';
export 'package:flutter/material.dart';

export 'package:cloud_firestore/cloud_firestore.dart';
export 'package:attendify/core/constants/firestore_collections.dart';
export 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
export 'package:flutter/services.dart';
export 'package:provider/provider.dart';
export 'package:flutter/foundation.dart' hide kIsWasm;
export 'dart:convert';

// Providers <-- BẠN CÓ THỂ THÊM VÀO ĐÂY
export 'app/providers/auth_provider.dart'; // <--- THÊM DÒNG NÀY

//Service
export 'features/admin/data/services/admin_service.dart';

//model
export 'core/data/models/class_model.dart';
export 'core/data/models/course_model.dart';
export 'core/data/models/leave_request_model.dart';
export 'core/data/models/lecturer_lite.dart';
export 'core/data/models/session_model.dart';
export 'core/data/models/user_model.dart';
//layouts
export 'core/presentation/layouts/role_layout.dart';
