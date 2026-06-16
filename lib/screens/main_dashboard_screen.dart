import 'package:flutter/material.dart';
import 'package:personal_tracking_money_project/screens/chart_only_screen.dart';
import '../screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/create_new_target_screen.dart';
import '../utils/app_colors.dart';
import '../models/transaction_model.dart';
import '../screens/stats_screen.dart';
import '../utils/database_helper.dart';
import 'dart:io';
import '../utils/notification_manager.dart';
import 'notifications_screen.dart';
import 'deposit_screen.dart';
import 'package:intl/intl.dart';

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _selectedNavIndex = 0;
  List<Map<String, dynamic>> inProgressGoals = [];
  List<TransactionModel> _transactions = [];
  List<String> goals = [];
  String? _selectedGoal;
  File? _avatarImage;
  int _unreadNotifs = 0;
  String _username = "Người dùng";

  String? _initialFilterGoalName;

  // Load cả ảnh và tên người dùng
  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    String? path = prefs.getString('avatarPath');
    String savedName = prefs.getString('currentUsername') ?? "Người dùng";

    if (mounted) {
      setState(() {
        if (path != null) _avatarImage = File(path);
        _username = savedName;
      });
    }
  }

  // Mang "máy quét ngầm" quay trở lại để chuông hiện số 1, 2
  Future<void> _loadUnreadNotifications() async {
    try {
      final dbGoals = await DatabaseHelper.instance.getGoals();
      final allTransactions = await DatabaseHelper.instance.getTransactions();
      final now = DateTime.now();

      List<Map<String, String>> potentialNotifications = [];

      // A. QUÉT MỤC TIÊU
      for (var goal in dbGoals) {
        String goalName = goal['name'];
        double target = (goal['target'] as num).toDouble();
        double saved = (goal['saved'] as num).toDouble();
        String? deadlineStr = goal['deadline'];

        if (goalName == 'Emergency Fund') continue;

        double progressPercentage = target > 0 ? (saved / target) * 100 : 0;

        if (saved >= target) {
          potentialNotifications.add({
            'title': "🎉 Chúc mừng! Bạn đã hoàn thành mục tiêu [$goalName]",
            'message':
                "Tuyệt vời! Bạn đã tích lũy đủ ${target.toStringAsFixed(0)}đ cho mục tiêu [$goalName]. Ước mơ của bạn đã thành hiện thực!",
          });
        }

        if (progressPercentage >= 80 && saved < target) {
          potentialNotifications.add({
            'title': "🚀 Khởi sắc! Mục tiêu [$goalName] đã đạt hơn 80%",
            'message':
                "Mục tiêu [$goalName] của bạn đã hoàn thành được ${progressPercentage.toStringAsFixed(0)}% chặng đường. Chỉ còn một chút nữa thôi, cố lên nhé!",
          });
        }

        if (saved < target && deadlineStr != null && deadlineStr.isNotEmpty) {
          int periodDays = (goal['period'] as num?)?.toInt() ?? 7;
          if (periodDays <= 0) periodDays = 7;

          int finalDaysLeft = -1;
          try {
            List<String> dateParts = deadlineStr.split('/');
            DateTime deadlineDate = dateParts.length == 3
                ? DateTime(
                    int.parse(dateParts[2]),
                    int.parse(dateParts[1]),
                    int.parse(dateParts[0]),
                  )
                : DateTime.parse(deadlineStr);
            finalDaysLeft = deadlineDate.difference(now).inDays;
          } catch (e) {}

          DateTime lastDepositDate;
          final txHistory = allTransactions
              .where((tx) => tx.title == goalName)
              .toList();
          if (txHistory.isNotEmpty) {
            txHistory.sort((a, b) => b.date.compareTo(a.date));
            lastDepositDate = txHistory.first.date;
          } else {
            lastDepositDate = now.subtract(Duration(days: periodDays));
          }

          DateTime nextPaymentDeadline = lastDepositDate.add(
            Duration(days: periodDays),
          );
          int daysLeftToPay = nextPaymentDeadline.difference(now).inDays;

          if (finalDaysLeft >= 0 && finalDaysLeft <= 3) {
            potentialNotifications.add({
              'title': "⚠️ Hạn chót mục tiêu [$goalName] sắp hết!",
              'message':
                  "Mục tiêu [$goalName] của bạn ${finalDaysLeft == 0 ? 'ngay hôm nay' : 'chỉ còn đúng $finalDaysLeft ngày'} là đến thời hạn cuối cùng!",
            });
          }

          if (daysLeftToPay >= 0 && daysLeftToPay <= 3) {
            potentialNotifications.add({
              'title': "🔔 Nhắc nhở: Chu kỳ nạp tiền mục tiêu [$goalName]",
              'message':
                  "${daysLeftToPay == 0 ? 'Hôm nay đã đến' : 'Đã gần đến (Còn $daysLeftToPay ngày nữa)'} chu kỳ tích lũy tiếp theo chặng $periodDays ngày của bạn.",
            });
          }
        }
      }

      // B. QUÉT NHIỆM VỤ TUẦN
      double totalMoney = 0;
      int roundUpCount = 0;
      Set<String> uniqueDays = {};
      final dateFormat = DateFormat('yyyy-MM-dd');

      for (var tx in allTransactions) {
        totalMoney += tx.amount;
        uniqueDays.add(dateFormat.format(tx.date));
        if (tx.subtitle.toLowerCase().contains('làm tròn') ||
            tx.subtitle.toLowerCase().contains('auto save') ||
            tx.subtitle.toLowerCase().contains('tiền lẻ')) {
          roundUpCount++;
        }
      }

      int maxStreak = 1;
      if (uniqueDays.isNotEmpty) {
        List<DateTime> sortedDates =
            uniqueDays.map((d) => DateTime.parse(d)).toList()
              ..sort((a, b) => a.compareTo(b));
        int currentStreak = 1;
        for (int i = 0; i < sortedDates.length - 1; i++) {
          if (sortedDates[i + 1].difference(sortedDates[i]).inDays == 1) {
            currentStreak++;
            if (currentStreak > maxStreak) maxStreak = currentStreak;
          } else if (sortedDates[i + 1].difference(sortedDates[i]).inDays > 1) {
            currentStreak = 1;
          }
        }
      }

      final taskChecks = [
        {
          'unlocked': allTransactions.length >= 10,
          'name': "Kiện Tướng Tích Lũy",
        },
        {'unlocked': totalMoney >= 2000000, 'name': "Đại Gia Tiết Kiệm"},
        {'unlocked': maxStreak >= 3, 'name': "Kỷ Luật Thép"},
        {'unlocked': roundUpCount >= 5, 'name': "Trùm Làm Tròn"},
        {'unlocked': totalMoney >= 500000, 'name': "Sắp Cán Đích"},
        {'unlocked': totalMoney >= 1000000, 'name': "Đạt Được Ước Mơ"},
      ];

      for (var task in taskChecks) {
        if (task['unlocked'] == true) {
          potentialNotifications.add({
            'title': "🏆 Chúc mừng! Bạn đã hoàn thành nhiệm vụ tuần",
            'message':
                "Bạn đã xuất sắc chinh phục thử thách tuần [${task['name']}] thành công. Tiến độ đã được ghi nhận vào Phòng Truyền Thống!",
          });
        }
      }

      // C. LƯU VÀO DB
      final currentNotifs = await NotificationManager.getNotifications();
      for (var notif in potentialNotifications) {
        bool isAlreadyNotified = currentNotifs.any(
          (n) =>
              n['title'] == notif['title'] && n['message'] == notif['message'],
        );
        if (!isAlreadyNotified) {
          await NotificationManager.saveNotification(
            notif['title']!,
            notif['message']!,
          );
        }
      }
    } catch (e) {
      debugPrint("Lỗi quét tổng hợp thông báo: $e");
    }

    // ĐẾM SỐ LƯỢNG CHƯA ĐỌC VÀ HIỂN THỊ LÊN CHUÔNG
    int count = await NotificationManager.getUnreadCount();
    if (mounted) setState(() => _unreadNotifs = count);
  }

  @override
  void initState() {
    super.initState();
    _refreshData();
    _loadAvatar();
    _loadUnreadNotifications();
  }

  Future<void> _refreshData() async {
    final dbGoals = await DatabaseHelper.instance.getGoals();
    bool hasEmergencyFund = dbGoals.any((g) => g['name'] == 'Emergency Fund');
    if (!hasEmergencyFund) {
      await DatabaseHelper.instance.insertGoal({
        'name': 'Emergency Fund',
        'target': 5000000.0,
        'saved': 0.0,
        'category': 2,
        'deadline': '2030-12-31',
        'period': 7,
      });
      return _refreshData();
    }
    final dbTransactions = await DatabaseHelper.instance.getTransactions();

    setState(() {
      inProgressGoals = List<Map<String, dynamic>>.from(dbGoals);
      _transactions = dbTransactions;
      goals = inProgressGoals.map((g) {
        int category = g['category'] ?? 0;
        String emoji = '🎯';
        if (category == 0)
          emoji = '✈️';
        else if (category == 1)
          emoji = '💻';
        else if (category == 2)
          emoji = '🛡️';
        else if (category == 3)
          emoji = '🏠';
        return '$emoji ${g['name']}';
      }).toList();

      if (goals.isNotEmpty &&
          (_selectedGoal == null || !goals.contains(_selectedGoal))) {
        _selectedGoal = goals.first;
      }
    });

    await _loadUnreadNotifications();
    await _loadAvatar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: (_selectedNavIndex == 0 || _selectedNavIndex == 2)
          ? _buildAppBar()
          : null,
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    switch (_selectedNavIndex) {
      case 0:
        return StatsScreen(
          transactions: _transactions,
          goals: inProgressGoals,
          onDataChanged: _refreshData,
          onCreateGoal: () => setState(() => _selectedNavIndex = 1),
          onNavigateToDeposit: (clickedGoalName) {
            setState(() {
              _initialFilterGoalName = clickedGoalName;
              try {
                _selectedGoal = goals.firstWhere(
                  (g) => g.contains(clickedGoalName),
                );
              } catch (e) {}
              _selectedNavIndex = 2;
            });
          },
        );
      case 1:
        return CreateGoalScreen(
          onGoalCreated: (newGoal) async {
            String rawName = newGoal['name'];
            double targetAmount =
                double.tryParse(
                  newGoal['amount'].toString().replaceAll(
                    RegExp(r'[^0-9]'),
                    '',
                  ),
                ) ??
                0.0;
            double initialDeposit =
                double.tryParse(
                  newGoal['deposit'].toString().replaceAll(
                    RegExp(r'[^0-9]'),
                    '',
                  ),
                ) ??
                0.0;
            int categoryId = newGoal['category'] ?? 0;
            await DatabaseHelper.instance.insertGoal({
              'name': rawName,
              'target': targetAmount,
              'saved': initialDeposit,
              'category': categoryId, // Dùng biến vừa tạo
              'deadline': newGoal['date'],
              'period': newGoal['period'] ?? 7,
            });

            //lịch sử nạp lần đầu
            if (initialDeposit > 0) {
              final newTx = TransactionModel(
                title: rawName,
                subtitle: 'Nạp tiền lần đầu',
                amount: initialDeposit,
                date: DateTime.now(),
                category: categoryId,
              );
              await DatabaseHelper.instance.insertTransaction(newTx);
            }
            await _refreshData();
            setState(() => _selectedNavIndex = 0);
          },
          onCancel: () => setState(() => _selectedNavIndex = 0),
        );
      case 2:
        return DepositScreen(
          inProgressGoals: inProgressGoals,
          goals: goals,
          transactions: _transactions,
          initialSelectedGoal: _selectedGoal,
          filterGoalName: _initialFilterGoalName,
          onRefresh: _refreshData,
          onClearFilter: () {
            setState(() {
              _initialFilterGoalName = null;
            });
          },
        );
      case 3:
        return ChartOnlyScreen(
          transactions: _transactions,
          goals: inProgressGoals,
          onBackPressed: () => setState(() => _selectedNavIndex = 0),
        );
      case 4:
        return SettingsScreen(
          onDataChanged: _refreshData,
          onBackPressed: () => setState(() => _selectedNavIndex = 0),
        );
      default:
        return const SizedBox();
    }
  }

  PreferredSizeWidget _buildAppBar() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? const Color(0xFF374151)
                  : AppColors.outlineVariant,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Nhấn vào Avatar thì chuyển sang Settings và đồng bộ hình ảnh
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedNavIndex = 4; // Nhảy sang tab Cài đặt
                    });
                  },
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage: _avatarImage != null
                        ? FileImage(_avatarImage!) as ImageProvider
                        : NetworkImage(
                            'https://ui-avatars.com/api/?name=$_username&background=1E3A8A&color=fff',
                          ),
                  ),
                ),
                Text(
                  'Savings Tracker',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF003D9B),
                  ),
                ),
                IconButton(
                  icon: Badge(
                    isLabelVisible: _unreadNotifs > 0,
                    label: Text(_unreadNotifs.toString()),
                    child: Icon(
                      Icons.notifications_active,
                      color: isDark ? Colors.white : AppColors.primaryBlue,
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  ).then((_) => _loadUnreadNotifications()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.dashboard_rounded, 'Dashboard', 0, isDark),
            _buildNavItem(Icons.flag_outlined, 'Goals', 1, isDark),
            _buildNavItem(Icons.payments_outlined, 'Deposits', 2, isDark),
            _buildNavItem(Icons.insert_chart_outlined, 'Charts', 3, isDark),
            _buildNavItem(Icons.settings, 'Settings', 4, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool isDark) {
    bool isActive = _selectedNavIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedNavIndex = index;
          if (index != 2) {
            _initialFilterGoalName = null;
          }
        });
        _loadUnreadNotifications();
        _loadAvatar();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: isActive
                ? const EdgeInsets.symmetric(horizontal: 20, vertical: 4)
                : const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive
                  ? (isDark
                        ? Colors.blue.withOpacity(0.2)
                        : AppColors.secondaryContainer)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(
              icon,
              color: isActive
                  ? (isDark
                        ? Colors.blueAccent
                        : AppColors.onSecondaryContainer)
                  : (isDark
                        ? Colors.grey.shade500
                        : AppColors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive
                  ? (isDark ? Colors.blueAccent : AppColors.onSurface)
                  : (isDark
                        ? Colors.grey.shade500
                        : AppColors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
