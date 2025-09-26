import 'package:flutter/material.dart';
import '../../../../common/data/models/user_model.dart';
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
  late AdminService adminService;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    adminService = AdminService(); // hoặc từ Provider
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();

    // Clear cache nếu cần
    imageCache.clear();
    imageCache.clearLiveImages();

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
                    onPressed: _searchController.clear,
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
          heroTag: 'fab_user_management_page', // icon hợp lý hơn dấu +
          onPressed: null,
          child: const Icon(Icons.add), // PopupMenuButton xử lý việc mở menu
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

        // ✅ THÊM FILTER LOGIC
        final filteredUsers = _searchQuery.isEmpty
            ? allUsers
            : allUsers.where((user) {
                final query = _searchQuery.toLowerCase();
                return user.displayName.toLowerCase().contains(query) ||
                    user.email.toLowerCase().contains(query) ||
                    user.role.name.toLowerCase().contains(query);
              }).toList();

        if (filteredUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'Chưa có người dùng'
                      : 'Không tìm thấy kết quả',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                if (_searchQuery.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                    },
                    child: const Text('Xóa bộ lọc'),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredUsers.length, // ✅ Sử dụng filteredUsers
          itemBuilder: (context, index) {
            final user = filteredUsers[index]; // ✅ Sử dụng filteredUsers
            return ListTile(
              leading: CircleAvatar(
                child: Text(
                  user.displayName.isNotEmpty
                      ? user.displayName[0].toUpperCase()
                      : '?',
                ),
              ),
              title: Text(user.displayName),
              subtitle: Text('${user.email} • ${user.role.name}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Sửa',
                    onPressed: () => _editUser(context, user),
                  ),
                  IconButton(
                    icon: const Icon(Icons.vpn_key_outlined),
                    tooltip: 'Gửi email đặt lại mật khẩu (Admin)',
                    onPressed: () => _resetPasswordAsAdmin(
                      context,
                      adminService,
                      user.email,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Xoá',
                    onPressed: () => _deleteUser(context, adminService, user),
                  ),
                ],
              ),
            );
          },
        );
      },
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không xác định được UID người dùng')),
        );
        return;
      }
      await adminService.deleteUser(uid);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xoá tài khoản')));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã gửi email đặt lại mật khẩu tới $email')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}
