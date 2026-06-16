import 'package:flutter/material.dart';
import 'package:personal_tracking_money_project/utils/notification_manager.dart';
import 'package:sqflite/sqflite.dart';
import '../models/transaction_model.dart';
import '../utils/app_colors.dart';
import '../utils/theme_manager.dart';
import '../screens/change_password_screen.dart';
import '../screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../utils/database_helper.dart';
import 'notifications_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onDataChanged;
  final VoidCallback? onBackPressed;

  const SettingsScreen({super.key, this.onDataChanged, this.onBackPressed});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _username = "Người dùng";
  bool _isDarkMode = false;
  bool _isAutoSave = true;
  bool _isBudgetAlert = true;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _savedGoals = [];
  int _unreadNotifs = 0;

  Future<void> _loadUnreadNotifications() async {
    int count = await NotificationManager.getUnreadCount();
    if (mounted) setState(() => _unreadNotifs = count);
  }

  @override
  void initState() {
    super.initState();
    _isDarkMode = ThemeManager.isDarkModeNotifier.value;
    _loadUserData();
    _loadUnreadNotifications();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('avatarPath', pickedFile.path);

      setState(() {
        _imageFile = File(pickedFile.path);
      });

      _showMessage("Đã cập nhật ảnh đại diện!", isSuccess: true);
    }
  }

  void _showMessage(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isSuccess ? const Color(0xFF059669) : Colors.redAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final dbGoals = await DatabaseHelper.instance.getGoals();

    setState(() {
      _username = prefs.getString('currentUsername') ?? "Người dùng";
      String? path = prefs.getString('avatarPath');
      if (path != null) _imageFile = File(path);

      _isAutoSave = prefs.getBool('isAutoSave') ?? true;
      _isBudgetAlert = prefs.getBool('isMilestoneAlert') ?? true;
      _savedGoals = List<Map<String, dynamic>>.from(dbGoals);
    });
  }

  Future<void> _exportTransactions() async {
    try {
      final transactions = await DatabaseHelper.instance.getTransactions();

      if (transactions.isEmpty) {
        _showMessage("Bạn chưa có giao dịch nào để xuất!");
        return;
      }

      _showMessage("Đang tạo file dữ liệu...", isSuccess: true);

      StringBuffer csvData = StringBuffer();
      csvData.writeln("Ngày,Tiêu đề,Ghi chú,Số tiền,Mã Danh mục");

      for (var tx in transactions) {
        String date =
            "${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}/${tx.date.year}";
        csvData.writeln(
          '"$date","${tx.title}","${tx.subtitle}","${tx.amount}","${tx.category}"',
        );
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/savings_transactions.csv';
      final file = File(filePath);
      await file.writeAsString(csvData.toString());

      await Share.shareXFiles([
        XFile(filePath),
      ], text: 'Dữ liệu giao dịch từ Savings Tracker');
    } catch (e) {
      _showMessage("Lỗi khi xuất dữ liệu: $e");
    }
  }

  Future<void> _injectMockData() async {
    try {
      _showMessage("Đang tạo dữ liệu giả...", isSuccess: true);

      // TỰ ĐỘNG XÓA DỮ LIỆU CŨ TRƯỚC KHI BƠM ĐỂ CHỐNG LỖI TRÙNG LẶP
      await DatabaseHelper.instance.resetUserData();

      // Tính toán thời gian cho các tháng trước để làm dữ liệu hoàn thành
      final DateTime now = DateTime.now();
      DateTime m1 = DateTime(now.year, now.month - 1, 15);
      DateTime m2 = DateTime(now.year, now.month - 2, 10);
      DateTime m3 = DateTime(now.year, now.month - 3, 5);

      // 1. CÁC MỤC TIÊU ĐANG CHẠY (Bổ sung thêm trường 'period')
      await DatabaseHelper.instance.insertGoal({
        'name': 'Du lịch Nhật Bản',
        'target': 50000000.0,
        'saved': 15000000.0,
        'category': 0,
        'deadline': '2026-12-31',
        'period': 7,
      });
      await DatabaseHelper.instance.insertGoal({
        'name': 'Mua Macbook Pro',
        'target': 40000000.0,
        'saved': 8000000.0,
        'category': 1,
        'deadline': '2026-10-15',
        'period': 14,
      });

      // 2. CÁC MỤC TIÊU ĐÃ HOÀN THÀNH
      await DatabaseHelper.instance.insertGoal({
        'name': 'Mua xe máy',
        'target': 40000000.0,
        'saved': 40000000.0,
        'category': 1,
        'deadline': '${m1.year}-${m1.month.toString().padLeft(2, '0')}-${m1.day.toString().padLeft(2, '0')}',
        'period': 30,
      });
      await DatabaseHelper.instance.insertGoal({
        'name': 'Đóng học phí',
        'target': 15000000.0,
        'saved': 15000000.0,
        'category': 3,
        'deadline': '${m2.year}-${m2.month.toString().padLeft(2, '0')}-${m2.day.toString().padLeft(2, '0')}',
        'period': 7,
      });
      await DatabaseHelper.instance.insertGoal({
        'name': 'Quà sinh nhật Mẹ',
        'target': 5000000.0,
        'saved': 5000000.0,
        'category': 3,
        'deadline': '${m2.year}-${m2.month.toString().padLeft(2, '0')}-${m2.day.toString().padLeft(2, '0')}',
        'period': 7,
      });
      await DatabaseHelper.instance.insertGoal({
        'name': 'Đi Đà Lạt',
        'target': 6000000.0,
        'saved': 6000000.0,
        'category': 0,
        'deadline': '${m3.year}-${m3.month.toString().padLeft(2, '0')}-${m3.day.toString().padLeft(2, '0')}',
        'period': 7,
      });

      // 3. GIAO DỊCH GIẢ
      final List<TransactionModel> fakeTransactions = [
        TransactionModel(title: 'Du lịch Nhật Bản', subtitle: 'Nạp lương tháng này', amount: 5000000, date: now.subtract(const Duration(days: 2)), category: 0),
        TransactionModel(title: 'Quỹ khẩn cấp', subtitle: 'Làm tròn mua sắm', amount: 25000, date: now.subtract(const Duration(days: 1)), category: 2),
        TransactionModel(title: 'Mua Macbook Pro', subtitle: 'Thưởng dự án', amount: 3000000, date: DateTime(now.year, now.month - 1, 15), category: 1),
        TransactionModel(title: 'Quỹ khẩn cấp', subtitle: 'Bán đồ cũ', amount: 500000, date: DateTime(now.year, now.month - 1, 20), category: 2),
        TransactionModel(title: 'Du lịch Nhật Bản', subtitle: 'Tiền mừng tuổi', amount: 2000000, date: DateTime(now.year, 2, 10), category: 0),
        TransactionModel(title: 'Mua Macbook Pro', subtitle: 'Tiết kiệm ăn sáng', amount: 1500000, date: DateTime(now.year, 2, 28), category: 1),
        TransactionModel(title: 'Quỹ khẩn cấp', subtitle: 'Gửi lần đầu', amount: 1000000, date: DateTime(now.year - 1, 11, 15), category: 2),
        TransactionModel(title: 'Du lịch Nhật Bản', subtitle: 'Trích lương tháng 11', amount: 3000000, date: DateTime(now.year - 1, 11, 30), category: 0),

        // Giao dịch chốt sổ cho mục tiêu đã hoàn thành
        TransactionModel(title: 'Mua xe máy', subtitle: 'Hoàn tất mục tiêu', amount: 40000000, date: m1, category: 1),
        TransactionModel(title: 'Đóng học phí', subtitle: 'Tiết kiệm đủ', amount: 15000000, date: m2, category: 3),
        TransactionModel(title: 'Quà sinh nhật Mẹ', subtitle: 'Hoàn tất mục tiêu', amount: 5000000, date: m2, category: 3),
        TransactionModel(title: 'Đi Đà Lạt', subtitle: 'Chốt quỹ', amount: 6000000, date: m3, category: 0),
      ];

      for (var tx in fakeTransactions) {
        await DatabaseHelper.instance.insertTransaction(tx);
      }

      await _loadUserData();

      if (widget.onDataChanged != null) {
        widget.onDataChanged!();
      }

      _showMessage(
        "Đã tạo xong dữ liệu ảo! Hãy sang tab Biểu đồ hoặc Tổng quan để xem.",
        isSuccess: true,
      );
    } catch (e) {
      // Bắt lỗi đỏ lên màn hình nếu có sự cố
      _showMessage("Lỗi khi tạo dữ liệu: $e", isSuccess: false);
    }
  }

  Future<void> _resetLocalData() async {
    _showMessage("Đang dọn dẹp dữ liệu...");

    await DatabaseHelper.instance.resetUserData();
    await _loadUserData();

    if (widget.onDataChanged != null) {
      widget.onDataChanged!();
    }

    _showMessage("Đã dọn sạch toàn bộ dữ liệu!", isSuccess: true);
  }

  void _showAllGoalsBottomSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2937) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade600
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Tất Cả Mục Tiêu',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _savedGoals.isEmpty
                        ? Center(
                            child: Text(
                              "Bạn chưa có mục tiêu nào.",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _savedGoals.length,
                            itemBuilder: (context, index) {
                              final goal = _savedGoals[index];
                              Color barColor =
                                  (goal['name'] == 'Emergency Fund' ||
                                      goal['name'] == 'Quỹ khẩn cấp')
                                  ? AppColors.successGreen
                                  : AppColors.primaryBlue;

                              String displayName =
                                  goal['name'] == 'Emergency Fund'
                                  ? 'Quỹ khẩn cấp'
                                  : goal['name'];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF374151)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.transparent
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: _buildProgressItem(
                                  displayName,
                                  (goal['saved'] as num).toDouble(),
                                  (goal['target'] as num).toDouble(),
                                  barColor,
                                  isDark,
                                  deadline: goal['deadline'],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : AppColors.bgGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : AppColors.primaryBlue,
          ),
          onPressed: () {
            if (widget.onBackPressed != null) {
              widget.onBackPressed!();
            }
          },
        ),
        title: Text(
          "Cài đặt",
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.primaryBlue,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _unreadNotifs > 0,
              label: Text(_unreadNotifs.toString()),
              child: Icon(
                Icons.notifications_active,
                color: isDark ? Colors.white : AppColors.primaryBlue,
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              ).then((_) => _loadUnreadNotifications());
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
            child: CircleAvatar(
              radius: 16,
              backgroundImage: _imageFile != null
                  ? FileImage(_imageFile!) as ImageProvider
                  : NetworkImage(
                      'https://ui-avatars.com/api/?name=$_username&background=1E3A8A&color=fff',
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            _buildProfileSection(AppColors.primaryBlue, isDark),
            const SizedBox(height: 30),

            _buildSectionCard(
              title: "GIAO DIỆN",
              icon: Icons.palette_outlined,
              isDark: isDark,
              children: [
                _buildToggleRow("Chế độ tối", _isDarkMode, (val) async {
                  setState(() => _isDarkMode = val);
                  await ThemeManager.toggleTheme(val);
                }, isDark: isDark),
                Divider(
                  height: 1,
                  color: isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFE5E7EB),
                ),
                _buildActionRow(
                  "Ngôn ngữ",
                  trailingText: "Tiếng Việt",
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 20),

            _buildSectionCard(
              title: "QUẢN LÝ DỮ LIỆU",
              icon: Icons.storage_outlined,
              isDark: isDark,
              children: [
                _buildActionRow(
                  "Xuất lịch sử giao dịch",
                  icon: Icons.download_outlined,
                  isDark: isDark,
                  onTap: () async {
                    await _exportTransactions();
                  },
                ),
                Divider(
                  height: 1,
                  color: isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFE5E7EB),
                ),
                _buildActionRow(
                  "Tạo dữ liệu ảo (Test)",
                  icon: Icons.bug_report,
                  textColor: Colors.orange,
                  iconColor: Colors.orange,
                  isDark: isDark,
                  onTap: () async {
                    await _injectMockData();
                  },
                ),
                Divider(
                  height: 1,
                  color: isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFE5E7EB),
                ),
                _buildActionRow(
                  "Xóa sạch dữ liệu",
                  icon: Icons.delete_outline,
                  textColor: isDark ? Colors.redAccent : AppColors.dangerRed,
                  iconColor: isDark ? Colors.redAccent : AppColors.dangerRed,
                  isDark: isDark,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext dialogContext) {
                        return AlertDialog(
                          backgroundColor: isDark
                              ? const Color(0xFF1F2937)
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.redAccent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Cảnh báo",
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          content: Text(
                            "Hành động này sẽ xóa vĩnh viễn toàn bộ mục tiêu và giao dịch của bạn. Bạn có chắc chắn không?",
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.black87,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text(
                                "Hủy",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                Navigator.pop(dialogContext);
                                await _resetLocalData();
                              },
                              child: const Text("Xóa sạch"),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            _buildSectionCard(
              title: "TIẾT KIỆM CÁ NHÂN",
              icon: Icons.savings_outlined,
              isTitlePrimary: true,
              badgeText: "MỚI",
              isDark: isDark,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Mục tiêu tiết kiệm",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _showAllGoalsBottomSheet(isDark);
                      },
                      child: Text(
                        "Xem tất cả",
                        style: TextStyle(
                          color: isDark
                              ? Colors.blueAccent
                              : AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_savedGoals.isEmpty) ...[
                  _buildProgressItem(
                    "Quỹ khẩn cấp",
                    0,
                    5000000,
                    AppColors.successGreen,
                    isDark,
                    deadline: '31-12-2030',
                  ),
                  const SizedBox(height: 15),
                ] else ...[
                  ..._savedGoals.take(2).map((goal) {
                    Color barColor =
                        (goal['name'] == 'Emergency Fund' ||
                            goal['name'] == 'Quỹ khẩn cấp')
                        ? AppColors.successGreen
                        : AppColors.primaryBlue;

                    String displayName = goal['name'] == 'Emergency Fund'
                        ? 'Quỹ khẩn cấp'
                        : goal['name'];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: _buildProgressItem(
                        displayName,
                        (goal['saved'] as num).toDouble(),
                        (goal['target'] as num).toDouble(),
                        barColor,
                        isDark,
                        deadline: goal['deadline'],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 20),
                Divider(
                  height: 1,
                  color: isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFE5E7EB),
                ),
                const SizedBox(height: 15),

                Text(
                  "Quy tắc tiết kiệm tự động",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                _buildToggleRow(
                  "Làm tròn tiền nạp",
                  _isAutoSave,
                  (val) async {
                    setState(() => _isAutoSave = val);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('isAutoSave', val);
                  },
                  subtitle: "Chuyển tiền lẻ vào Quỹ khẩn cấp",
                  isDark: isDark,
                ),
                const SizedBox(height: 15),
                Divider(
                  height: 1,
                  color: isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFE5E7EB),
                ),
                const SizedBox(height: 15),

                Text(
                  "Thông báo mục tiêu",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                _buildToggleRow(
                  "Ăn mừng mốc 80%",
                  _isBudgetAlert,
                  (val) async {
                    setState(() => _isBudgetAlert = val);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('isMilestoneAlert', val);
                  },
                  subtitle: "Nhận thông báo khi mục tiêu sắp hoàn thành",
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 20),

            _buildSectionCard(
              title: "BẢO MẬT",
              icon: Icons.shield_outlined,
              isDark: isDark,
              children: [
                _buildActionRow(
                  "Đổi mật khẩu",
                  icon: Icons.chevron_right,
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        backgroundColor: isDark
                            ? const Color(0xFF1F2937)
                            : Colors.white,
                        title: Text(
                          "Đăng xuất",
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        content: Text(
                          "Bạn có chắc chắn muốn đăng xuất tài khoản?",
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.black87,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text(
                              "Hủy",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool('isLoggedIn', false);
                              await prefs.remove('currentUsername');

                              if (context.mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                  (route) => false,
                                );
                              }
                            },
                            child: const Text(
                              "Xác nhận",
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
                icon: Icon(
                  Icons.logout,
                  color: isDark ? Colors.redAccent : AppColors.dangerRed,
                ),
                label: Text(
                  "Đăng xuất",
                  style: TextStyle(
                    color: isDark ? Colors.redAccent : AppColors.dangerRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(0xFF7F1D1D).withOpacity(0.2)
                      : const Color(0xFFFEF2F2),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(Color primaryBlue, bool isDark) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF374151) : Colors.white,
                  width: 4,
                ),
              ),
              child: CircleAvatar(
                radius: 45,
                backgroundImage: _imageFile != null
                    ? FileImage(_imageFile!) as ImageProvider
                    : NetworkImage(
                        'https://ui-avatars.com/api/?name=$_username&background=1E3A8A&color=fff&size=256',
                      ),
              ),
            ),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _username,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "$_username@gmail.com",
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey.shade400 : const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool isTitlePrimary = false,
    String? badgeText,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isDark ? Colors.blueAccent : const Color(0xFF1E3A8A),
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: isTitlePrimary ? 18 : 13,
                  fontWeight: FontWeight.bold,
                  color: isTitlePrimary
                      ? (isDark ? Colors.white : const Color(0xFF1E3A8A))
                      : (isDark
                            ? Colors.grey.shade400
                            : const Color(0xFF6B7280)),
                  letterSpacing: isTitlePrimary ? 0 : 1.2,
                ),
              ),
              if (badgeText != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF064E3B)
                        : const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF34D399)
                          : const Color(0xFF059669),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildActionRow(
    String title, {
    IconData? icon,
    String? trailingText,
    Color? textColor,
    Color? iconColor,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color:
                    textColor ??
                    (isDark ? Colors.white : const Color(0xFF111827)),
              ),
            ),
            if (icon != null)
              Icon(
                icon,
                color:
                    iconColor ??
                    (isDark ? Colors.grey.shade400 : const Color(0xFF6B7280)),
                size: 20,
              ),
            if (trailingText != null)
              Text(
                trailingText,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.blueAccent : const Color(0xFF1E3A8A),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow(
    String title,
    bool value,
    ValueChanged<bool> onChanged, {
    String? subtitle,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.grey.shade400
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF059669),
            inactiveThumbColor: isDark ? Colors.grey.shade300 : Colors.white,
            inactiveTrackColor: isDark
                ? const Color(0xFF4B5563)
                : const Color(0xFFD1D5DB),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(
    String title,
    double current,
    double total,
    Color color,
    bool isDark, {
    String? deadline,
  }) {
    double progress = current / total;
    if (progress > 1.0) progress = 1.0;

    String formatCurrency(double amount) {
      return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} VNĐ';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF4B5563),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (deadline != null && deadline.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Hạn chót: $deadline',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: formatCurrency(current),
                    style: TextStyle(
                      color: isDark
                          ? Colors.blueAccent
                          : const Color(0xFF1E3A8A),
                    ),
                  ),
                  TextSpan(
                    text: ' / ',
                    style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade500
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                  TextSpan(
                    text: formatCurrency(total),
                    style: TextStyle(
                      color: isDark
                          ? Colors.blueAccent
                          : const Color(0xFF1E3A8A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: isDark
                ? const Color(0xFF374151)
                : color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
