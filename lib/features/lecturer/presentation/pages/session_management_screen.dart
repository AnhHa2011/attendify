import 'package:flutter/material.dart';

class SessionManagement extends StatelessWidget {
  final String? courseCode;

  const SessionManagement({Key? key, this.courseCode}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Quản lý buổi học'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: const Center(
        child: Text('Session Management  - To be implemented'),
      ),
    );
  }
}
