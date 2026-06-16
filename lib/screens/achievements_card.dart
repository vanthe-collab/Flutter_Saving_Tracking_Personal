import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../utils/database_helper.dart';
import '../utils/notification_manager.dart'; // Đồng bộ hệ thống thông báo chuông
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';

class BadgeAchievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isUnlocked;
  final double progress;
  final String progressText;

  BadgeAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isUnlocked,
    required this.progress,
    required this.progressText,
  });
}

class AchievementsCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final VoidCallback?
  onProgressChanged; // Callback đồng bộ chuông thông báo trang cha

  const AchievementsCard({
    super.key,
    required this.transactions,
    this.onProgressChanged,
  });

  @override
  State<AchievementsCard> createState() => _AchievementsCardState();
}

class _AchievementsCardState extends State<AchievementsCard> {
  bool _isDbLoading = true;

  @override
  void initState() {
    super.initState();
    _checkWeeklyResetAndLoad();
  }

  // --- TỰ ĐỘNG KIỂM TRA RESET THEO TUẦN ĐỘNG ---
  Future<void> _checkWeeklyResetAndLoad() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      int weekOfYear = _getWeekNumber(now);
      String currentWeekKey = "${now.year}-W$weekOfYear";
      String? savedWeekKey = prefs.getString('saved_achievement_week');

      if (savedWeekKey != null && savedWeekKey != currentWeekKey) {
        final db = await DatabaseHelper.instance.database;
        String currentUsername =
            prefs.getString('currentUsername') ?? 'unknown';

        await db.delete(
          'achievements',
          where: 'username = ?',
          whereArgs: [currentUsername],
        );

        debugPrint(
          "🔄 TOÀN LOG: Tự động Reset nhiệm vụ tuần mới: $currentWeekKey",
        );
      }

      await prefs.setString('saved_achievement_week', currentWeekKey);
    } catch (e) {
      debugPrint("Lỗi kiểm tra reset tuần: $e");
    }

    if (mounted) {
      setState(() {
        _isDbLoading = false;
      });
    }
  }

  int _getWeekNumber(DateTime date) {
    int dayOfYear = int.parse(DateFormat("D").format(date));
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  List<BadgeAchievement> _calculateAchievements() {
    double totalMoney = 0;
    int totalCount = widget.transactions.length;
    int roundUpCount = 0;

    Set<String> uniqueDays = {};
    final dateFormat = DateFormat('yyyy-MM-dd');

    for (var tx in widget.transactions) {
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
      List<DateTime> sortedDates = uniqueDays
          .map((d) => DateTime.parse(d))
          .toList();
      sortedDates.sort((a, b) => a.compareTo(b));

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

    // 6 NHIỆM VỤ TUẦN CỐ ĐỊNH
    final rawBadges = [
      BadgeAchievement(
        id: "kiên_tuong",
        title: "🎯 Kiện Tướng Tích Lũy",
        description:
            "Nhiệm vụ tuần: Thực hiện nạp tiền tích lũy ít nhất 10 lần",
        icon: Icons.gavel_rounded,
        color: Colors.orange,
        isUnlocked: totalCount >= 10,
        progress: (totalCount / 10).clamp(0.0, 1.0),
        progressText: "$totalCount/10 lần",
      ),
      BadgeAchievement(
        id: "dai_gia",
        title: "💰 Đại Gia Tiết Kiệm",
        description: "Nhiệm vụ tuần: Tích lũy tổng tài sản đạt mốc 2,000,000đ",
        icon: Icons.monetization_on,
        color: Colors.amber,
        isUnlocked: totalMoney >= 2000000,
        progress: (totalMoney / 2000000).clamp(0.0, 1.0),
        progressText: "${(totalMoney / 1000).toStringAsFixed(0)}k/2,000k",
      ),
      BadgeAchievement(
        id: "ky_luat_thep",
        title: "🔥 Kỷ Luật Thép",
        description:
            "Nhiệm vụ tuần: Thực hiện nạp tiền đều đặn liên tiếp 3 ngày",
        icon: Icons.local_fire_department_rounded,
        color: Colors.redAccent,
        isUnlocked: maxStreak >= 3,
        progress: (maxStreak / 3).clamp(0.0, 1.0),
        progressText: "$maxStreak/3 ngày",
      ),
      BadgeAchievement(
        id: "trum_lam_tron",
        title: "🪙 Trùm Làm Tròn",
        description:
            "Nhiệm vụ tuần: Tích lũy 5 lần từ heo đất Auto Save tiền lẻ",
        icon: Icons.donut_large_rounded,
        color: Colors.teal,
        isUnlocked: roundUpCount >= 5,
        progress: (roundUpCount / 5).clamp(0.0, 1.0),
        progressText: "$roundUpCount/5 lần",
      ),
      BadgeAchievement(
        id: "sap_can_dich",
        title: "⚡ Sắp Cán Đích",
        description:
            "Nhiệm vụ tuần: Có ít nhất 1 mục tiêu vượt mốc 80% tiến độ",
        icon: Icons.trending_up_rounded,
        color: Colors.blueAccent,
        isUnlocked: totalMoney >= 500000,
        progress: totalMoney >= 500000
            ? 1.0
            : (totalMoney / 500000).clamp(0.0, 1.0),
        progressText: totalMoney >= 500000 ? "1/1" : "0/1",
      ),
      BadgeAchievement(
        id: "dat_uoc_mo",
        title: "🏆 Đạt Được Ước Mơ",
        description:
            "Nhiệm vụ tuần: Hoàn thành tích lũy đạt đủ 100% một mục tiêu",
        icon: Icons.workspace_premium_rounded,
        color: Colors.purple,
        isUnlocked: totalMoney >= 1000000,
        progress: (totalMoney / 1000000).clamp(0.0, 1.0),
        progressText: totalMoney >= 1000000 ? "1/1" : "0/1",
      ),
    ];

    // Cập nhật SQLite và kích hoạt thông báo chuông
    for (var b in rawBadges) {
      DatabaseHelper.instance.updateAchievementProgress(
        b.id,
        b.progress,
        b.isUnlocked ? 1 : 0,
      );

      if (b.isUnlocked) {
        // Đã sửa đổi văn phong chuẩn hóa: Chúc mừng hoàn thành nhiệm vụ tuần rõ ràng
        String notifTitle = "🏆 Hoàn thành nhiệm vụ tuần: ${b.title}";
        String notifMessage =
            "Chúc mừng bạn đã xuất sắc vượt qua thử thách tuần [${b.title}] trong Phòng Truyền Thống!";

        NotificationManager.getNotifications().then((currentNotifs) async {
          bool isAlreadyNotified = currentNotifs.any(
            (n) => n['title'] == notifTitle && n['message'] == notifMessage,
          );

          if (!isAlreadyNotified) {
            await NotificationManager.saveNotification(
              notifTitle,
              notifMessage,
            );
            widget.onProgressChanged
                ?.call(); // Báo trang cha làm mới số đếm trên chuông
          }
        });
      }
    }

    return rawBadges;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isDbLoading) return const Center(child: CircularProgressIndicator());

    final List<BadgeAchievement> badges = _calculateAchievements();
    int unlockedCount = badges.where((b) => b.isUnlocked).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "🏆 Thử Thách Tuần ($unlockedCount/${badges.length})",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                "Nhiệm vụ",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Column(
            mainAxisSize: MainAxisSize.min,
            children: badges.map((badge) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: CustomPaint(
                  painter: badge.isUnlocked
                      ? null
                      : DashedBorderPainter(
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                        ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: badge.isUnlocked
                          ? badge.color.withOpacity(isDark ? 0.1 : 0.06)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: badge.isUnlocked
                          ? Border.all(color: badge.color.withOpacity(0.5))
                          : null,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: badge.isUnlocked
                              ? badge.color.withOpacity(0.2)
                              : (isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200),
                          child: Icon(
                            badge.icon,
                            color: badge.isUnlocked
                                ? badge.color
                                : (isDark
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade600),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                badge.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: badge.isUnlocked
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : (isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade500),
                                ),
                              ),
                              const SizedBox(height: 2),

                              // ĐÃ SỬA: Loại bỏ maxLines và overflow để hiển thị đầy đủ text, tự động xuống hàng thông thoáng
                              Text(
                                badge.description,
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.3, // Tạo khoảng giãn dòng đẹp mắt
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: badge.progress,
                                        backgroundColor: isDark
                                            ? const Color(0xFF111827)
                                            : Colors.grey.shade200,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              badge.isUnlocked
                                                  ? badge.color
                                                  : Colors.grey.shade400,
                                            ),
                                        minHeight: 5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    badge.progressText,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: badge.isUnlocked
                                          ? badge.color
                                          : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.dashLength = 5.0,
    this.gap = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );
    final Path path = Path()..addRRect(rrect);
    for (final PathMetric pathMetric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        final double nextDistance = distance + dashLength;
        canvas.drawPath(pathMetric.extractPath(distance, nextDistance), paint);
        distance = nextDistance + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
