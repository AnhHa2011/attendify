// lib/presentation/widgets/role_picker_dialog.dart
import 'package:flutter/material.dart';
import '../data/models/user_model.dart';

Future<UserRole?> showRolePickerDialog(BuildContext context) async {
  var selected = UserRole.student;
  return showDialog<UserRole>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Chọn vai trò'),
      content: StatefulBuilder(
        builder: (_, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<UserRole>(
              value: UserRole.admin,
              groupValue: selected,
              onChanged: (v) => setState(() => selected = v!),
              title: const Text('Admin'),
            ),
            RadioListTile<UserRole>(
              value: UserRole.lecture,
              groupValue: selected,
              onChanged: (v) => setState(() => selected = v!),
              title: const Text('Giảng viên'),
            ),
            RadioListTile<UserRole>(
              value: UserRole.student,
              groupValue: selected,
              onChanged: (v) => setState(() => selected = v!),
              title: const Text('Sinh viên'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, null),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, selected),
          child: const Text('Xác nhận'),
        ),
      ],
    ),
  );
}
