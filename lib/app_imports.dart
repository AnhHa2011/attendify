export 'dart:math';
export 'package:flutter/material.dart';

export 'package:cloud_firestore/cloud_firestore.dart';
export 'package:attendify/core/constants/firestore_collections.dart';
export 'package:firebase_auth/firebase_auth.dart';
export 'package:flutter/services.dart';
export 'package:provider/provider.dart';
export 'package:flutter/foundation.dart' hide kIsWasm;
export 'dart:convert';
//Service
export 'features/admin/data/services/admin_service.dart';

//model
export 'features/common/data/models/class_model.dart';
export 'features/common/data/models/class_schedule_model.dart';
export 'features/common/data/models/course_model.dart';
export 'features/common/data/models/leave_request_model.dart';
export 'features/common/data/models/lecturer_lite.dart';
export 'features/common/data/models/session_model.dart';
export 'features/common/data/models/user_model.dart';
//layouts
export 'features/common/presentation/layouts/role_layout.dart';
