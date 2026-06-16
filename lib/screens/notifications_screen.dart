import 'package:flutter/material.dart';
import '../utils/notification_manager.dart';
import '../utils/app_colors.dart';
import '../utils/database_helper.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAllNotificationsAndLoad();
  }

  // --- HÀM 1: TỰ ĐỘNG QUÉT TỔNG HỢP (MỤC TIÊU + NHIỆM VỤ TUẦN) ĐỂ GHI THẲNG VÀO DANH SÁCH ---
  Future<void> _checkAllNotificationsAndLoad() async {
    try {
      final dbGoals = await DatabaseHelper.instance.getGoals();
      final allTransactions = await DatabaseHelper.instance.getTransactions();
      final now = DateTime.now();

      // Danh sách chứa toàn bộ thông báo hợp lệ sau khi quét để check lưu DB một thể
      List<Map<String, String>> potentialNotifications = [];

      // ========================================================
      // PHẦN A: QUÉT TIẾN ĐỘ VÀ CHU KỲ CỦA CÁC MỤC TIÊU (GOALS)
      // ========================================================
      for (var goal in dbGoals) {
        String goalName = goal['name'];
        double target = (goal['target'] as num).toDouble();
        double saved = (goal['saved'] as num).toDouble();
        String? deadlineStr = goal['deadline'];

        if (goalName == 'Emergency Fund') continue;

        double progressPercentage = target > 0 ? (saved / target) * 100 : 0;

        // 1. Kiểm tra mốc Hoàn thành (100% mục tiêu)
        if (saved >= target) {
          potentialNotifications.add({
            'title': "🎉 Chúc mừng! Bạn đã hoàn thành mục tiêu [$goalName]",
            'message':
                "Tuyệt vời! Bạn đã tích lũy đủ ${target.toStringAsFixed(0)}đ cho mục tiêu [$goalName]. Ước mơ của bạn đã thành hiện thực!",
          });
        }

        // 2. Kiểm tra mốc tiến độ lớn hơn hoặc bằng 80%
        if (progressPercentage >= 80 && saved < target) {
          potentialNotifications.add({
            'title': "🚀 Khởi sắc! Mục tiêu [$goalName] đã đạt hơn 80%",
            'message':
                "Mục tiêu [$goalName] của bạn đã hoàn thành được ${progressPercentage.toStringAsFixed(0)}% chặng đường. Chỉ còn một chút nữa thôi, cố lên nhé!",
          });
        }

        // 3. Kiểm tra điều kiện ngày tháng (Chu kỳ & Hạn chót) nếu mục tiêu chưa hoàn thành
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
          } catch (e) {
            debugPrint("Lỗi phân tích hạn chót: $e");
          }

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

      // ========================================================
      // PHẦN B: ĐÃ THÊM - QUÉT TIẾN ĐỘ 6 NHIỆM VỤ TUẦN ĐỂ IN RA
      // ========================================================
      double totalMoney = 0;
      int totalCount = allTransactions.length;
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

      int maxStreak = 0;
      if (uniqueDays.isNotEmpty) {
        List<DateTime> sortedDates =
            uniqueDays.map((d) => DateTime.parse(d)).toList()
              ..sort((a, b) => a.compareTo(b));
        int currentStreak = 1;
        maxStreak = 1;
        for (int i = 0; i < sortedDates.length - 1; i++) {
          if (sortedDates[i + 1].difference(sortedDates[i]).inDays == 1) {
            currentStreak++;
            if (currentStreak > maxStreak) maxStreak = currentStreak;
          } else if (sortedDates[i + 1].difference(sortedDates[i]).inDays > 1) {
            currentStreak = 1;
          }
        }
      }

      // Mảng kiểm tra điều kiện mở khóa của từng nhiệm vụ tuần để add thông báo chúc mừng
      final taskChecks = [
        {'unlocked': totalCount >= 10, 'name': "Kiện Tướng Tích Lũy"},
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

      // ========================================================
      // PHẦN C: TIẾN HÀNH LƯU ĐỒNG BỘ VÀO DATABASE (CHỐNG TRÙNG)
      // ========================================================
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

    // Nạp hết vào DB xong xuôi, gọi hàm 2 kéo dữ liệu lên hiển thị ra giao diện
    await _loadNotifications();
  }

  // --- HÀM 2: CHỈ ĐOẠN LÔI DỮ LIỆU TỪ DB LÊN HIỂN THỊ TRÊN LISTVIEW ---
  Future<void> _loadNotifications() async {
    final notifs = await NotificationManager.getNotifications();
    if (mounted) {
      setState(() {
        _notifications = notifs;
        _isLoading = false;
      });
    }
  }

  String _formatDate(String isoString) {
    try {
      DateTime d = DateTime.parse(isoString);
      return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} lúc ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : AppColors.bgGrey,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        title: Text(
          "Thông báo",
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.primaryBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : AppColors.primaryBlue,
        ),
        elevation: 1,
        actions: [
          if (_notifications.any((n) => n['isRead'] != true))
            TextButton.icon(
              onPressed: () async {
                await NotificationManager.markAllAsRead();
                await _loadNotifications();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã đánh dấu đọc tất cả thông báo!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.done_all, size: 18, color: Colors.amber),
              label: const Text(
                "Đọc hết",
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? const Center(child: Text("Không có thông báo nào."))
          : ListView.separated(
              itemCount: _notifications.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark ? const Color(0xFF374151) : Colors.grey.shade300,
              ),
              itemBuilder: (context, index) {
                final notif = _notifications[index];
                final isRead = notif['isRead'] == true;

                return Container(
                  color: isRead
                      ? Colors.transparent
                      : (isDark
                            ? const Color(0xFF374151).withOpacity(0.5)
                            : Colors.blue.withOpacity(0.05)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: isDark
                          ? const Color(0xFF1F2937)
                          : Colors.white,
                      child: Icon(
                        Icons.notifications,
                        color: isRead ? Colors.grey : Colors.amber,
                      ),
                    ),
                    title: Text(
                      notif['title'],
                      style: TextStyle(
                        fontWeight: isRead
                            ? FontWeight.normal
                            : FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          notif['message'],
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(notif['date']),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
