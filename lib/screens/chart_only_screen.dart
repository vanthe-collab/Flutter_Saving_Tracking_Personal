import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../widgets/tracking_chart.dart';
import '../widgets/goal_tracking_chart.dart';
import '../widgets/completed_goals_chart.dart';
import '../utils/app_colors.dart';
import '../utils/notification_manager.dart';
import 'notifications_screen.dart';

class ChartOnlyScreen extends StatefulWidget {
  final List<TransactionModel> transactions;
  final List<Map<String, dynamic>> goals;
  final VoidCallback? onBackPressed; // THÊM BIẾN NÀY ĐỂ KÍCH HOẠT NÚT BACK

  const ChartOnlyScreen({
    super.key,
    required this.transactions,
    required this.goals,
    this.onBackPressed, //đưa nó vào hàm khởi tạo
  });

  @override
  State<ChartOnlyScreen> createState() => _ChartOnlyScreenState();
}

class _ChartOnlyScreenState extends State<ChartOnlyScreen> {
  String _username = "Người dùng";
  File? _avatarImage;
  int _unreadNotifs = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Hàm tải dữ liệu Avatar và Chuông thông báo
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    int count = await NotificationManager.getUnreadCount();

    if (mounted) {
      setState(() {
        _username = prefs.getString('currentUsername') ?? "Người dùng";
        String? path = prefs.getString('avatarPath');
        if (path != null) {
          _avatarImage = File(path);
        }
        _unreadNotifs = count;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF111827)
          : const Color(0xFFF8F9FA),

      // APPBAR VỚI ĐẦY ĐỦ BACK, TITLE, AVATAR, CHUÔNG
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // NÚT MŨI TÊN BÊN TRÁI
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : AppColors.primaryBlue,
          ),
          onPressed: () {
            // Khi bấm thì gọi ngược ra màn hình MainDashboard
            if (widget.onBackPressed != null) {
              widget.onBackPressed!();
            }
          },
        ),
        // TIÊU ĐỀ Ở GIỮA
        title: Text(
          'Thống Kê',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.primaryBlue,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        // CHUÔNG VÀ AVATAR BÊN PHẢI
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
              ).then((_) => _loadUserData());
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
            child: CircleAvatar(
              radius: 16,
              backgroundImage: _avatarImage != null
                  ? FileImage(_avatarImage!) as ImageProvider
                  : NetworkImage(
                      'https://ui-avatars.com/api/?name=$_username&background=1E3A8A&color=fff',
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BIỂU ĐỒ 1
            Text(
              'Tổng quan tất cả dòng tiền',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade400 : Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            TrackingChart(transactions: widget.transactions),

            const SizedBox(height: 32),
            Divider(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            ),
            const SizedBox(height: 32),

            // BIỂU ĐỒ 2
            Text(
              'Chi tiết từng mục tiêu',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade400 : Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            GoalTrackingChart(
              transactions: widget.transactions,
              goals: widget.goals,
            ),

            const SizedBox(height: 32),
            Divider(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            ),
            const SizedBox(height: 32),

            // BIỂU ĐỒ 3: MỤC TIÊU ĐÃ HOÀN THÀNH
            Text(
              'Bảng vàng thành tích',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade400 : Colors.grey,
              ),
            ),
            const SizedBox(height: 16),

            CompletedGoalsChart(
              goals: widget.goals,
              transactions: widget.transactions,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
