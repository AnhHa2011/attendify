import 'package:flutter/material.dart';
import '../../../../../core/data/models/user_model.dart';
import '../../../data/services/admin_service.dart';
import 'user_bulk_import_page.dart';
import 'user_form_page.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final adminService = AdminService();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Tìm theo tên, email,... của người dùng',
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(30)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.school), text: 'Giảng viên'),
            Tab(icon: Icon(Icons.person), text: 'Sinh viên'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList(UserRole.lecture),
          _buildUserList(UserRole.student),
        ],
      ),

      // Nút thêm ở góc dưới bên phải
      floatingActionButton: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'single') {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const UserFormPage()));
          } else if (value == 'bulk') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UserBulkImportPage()),
            );
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'single',
            child: ListTile(
              leading: Icon(Icons.add),
              title: Text('Thêm 1 người dùng'),
            ),
          ),
          PopupMenuItem(
            value: 'bulk',
            child: ListTile(
              leading: Icon(Icons.upload_file),
              title: Text('Thêm từ Excel'),
            ),
          ),
        ],
        // hiển thị như FAB
        child: FloatingActionButton(
          heroTag: 'fab_user_management_page',
          onPressed: null,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildUserList(UserRole role) {
    return StreamBuilder<List<UserModel>>(
      stream: adminService.getUsersStreamByRole(role),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Lỗi tải dữ liệu'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allUsers = snapshot.data!;

        // Apply search filter
        final filteredUsers = _searchQuery.isEmpty
            ? allUsers
            : allUsers.where((user) {
                final searchLower = _searchQuery.toLowerCase();
                return user.displayName.toLowerCase().contains(searchLower) ||
                    user.email.toLowerCase().contains(searchLower) ||
                    user.role.name.toLowerCase().contains(searchLower);
              }).toList();

        if (allUsers.isEmpty) {
          return const Center(child: Text('Chưa có người dùng'));
        }

        if (filteredUsers.isEmpty && _searchQuery.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'Không tìm thấy người dùng nào\nphù hợp với "${_searchQuery}"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  child: const Text('Xóa bộ lọc'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Search result info
            if (_searchQuery.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: Text(
                  'Tìm thấy ${filteredUsers.length} kết quả cho "${_searchQuery}"',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            // User list
            Expanded(
              child: ListView.builder(
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = filteredUsers[index];
                  return _buildUserTile(user);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserTile(UserModel user) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(
          user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
        ),
      ),
      title: _highlightSearchText(user.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _highlightSearchText(user.email),
          Text(
            user.role == UserRole.lecture ? 'Giảng viên' : 'Sinh viên',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Sửa',
            onPressed: () => _editUser(context, user),
          ),
          IconButton(
            icon: const Icon(Icons.vpn_key_outlined),
            tooltip: 'Gửi email đặt lại mật khẩu (Admin)',
            onPressed: () =>
                _resetPasswordAsAdmin(context, adminService, user.email),
          ),
          IconButton(
            icon: const Icon(
              Icons.block,
              color: Colors.red,
            ), // Đổi icon cho phù hợp hơn
            tooltip: 'Vô hiệu hoá', // <-- Sửa tooltip
            onPressed: () =>
                _deactivateUser(context, adminService, user), // <-- Gọi hàm mới
          ),
        ],
      ),
    );
  }

  Future<void> _deactivateUser(
    BuildContext context,
    AdminService adminService,
    UserModel user,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Vô hiệu hoá người dùng'), // <-- Sửa tiêu đề
        content: Text(
          'Bạn có chắc muốn vô hiệu hoá tài khoản "${user.email}"?\n\nNgười dùng này sẽ không thể đăng nhập được nữa.',
        ), // <-- Sửa nội dung
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red, // Làm nổi bật nút nguy hiểm
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vô hiệu hoá'), // <-- Sửa nút
          ),
        ],
      ),
    );

    if (confirm == true) {
      final uid = user.uid;
      if (uid.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không xác định được UID người dùng')),
          );
        }
        return;
      }

      try {
        // Gọi hàm service đã được cập nhật
        await adminService.deactivateUser(uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã vô hiệu hoá tài khoản')),
          ); // <-- Sửa thông báo
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi vô hiệu hoá người dùng: $e')),
          ); // <-- Sửa thông báo lỗi
        }
      }
    }
  }

  Widget _highlightSearchText(String text) {
    if (_searchQuery.isEmpty) {
      return Text(text);
    }

    final searchLower = _searchQuery.toLowerCase();
    final textLower = text.toLowerCase();

    if (!textLower.contains(searchLower)) {
      return Text(text);
    }

    final startIndex = textLower.indexOf(searchLower);
    final endIndex = startIndex + searchLower.length;

    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: [
          if (startIndex > 0) TextSpan(text: text.substring(0, startIndex)),
          TextSpan(
            text: text.substring(startIndex, endIndex),
            style: TextStyle(
              backgroundColor: Colors.yellow.shade200,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (endIndex < text.length) TextSpan(text: text.substring(endIndex)),
        ],
      ),
    );
  }

  void _editUser(BuildContext context, UserModel user) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => UserFormPage(user: user)));
  }

  Future<void> _deleteUser(
    BuildContext context,
    AdminService adminService,
    UserModel user,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá người dùng'),
        content: Text('Bạn có chắc muốn xoá tài khoản "${user.email}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final uid = user.uid;
      if (uid.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không xác định được UID người dùng')),
          );
        }
        return;
      }

      try {
        await adminService.deleteUser(uid);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Đã xoá tài khoản')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi xóa người dùng: $e')));
        }
      }
    }
  }

  Future<void> _resetPasswordAsAdmin(
    BuildContext context,
    AdminService adminService,
    String email,
  ) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tài khoản này chưa có email hợp lệ')),
      );
      return;
    }

    // xác nhận trước khi gửi
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Gửi email đặt lại mật khẩu'),
        content: Text('Bạn muốn gửi email đặt lại mật khẩu tới: $email ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gửi'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await adminService.sendPasswordResetForUserAsAdmin(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã gửi email đặt lại mật khẩu tới $email')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}
