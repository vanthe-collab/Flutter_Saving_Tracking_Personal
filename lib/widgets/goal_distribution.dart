import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class GoalDistribution extends StatelessWidget {
  final List<Map<String, dynamic>> goals;
  final VoidCallback? onCreateGoal;
  final Function(String)? onGoalSelected;
  final Function(String)? onDeleteGoal;

  // 1. Thêm hàm callback này để báo ra ngoài khi bấm nút
  final VoidCallback? onViewAllTransactions;

  const GoalDistribution({
    super.key,
    required this.goals,
    this.onCreateGoal,
    this.onGoalSelected,
    this.onDeleteGoal,
    this.onViewAllTransactions,
  });

  String _formatCurrency(double amount) {
    String s = amount.toInt().toString();
    String result = '';
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && i % 3 == 0) result = ',$result';
      result = s[s.length - 1 - i] + result;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    // BẮT TRẠNG THÁI SÁNG / TỐI
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        // Đổi màu nền khối to nhất
        color: isDark ? const Color(0xFF1F2937) : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF374151) : AppColors.surfaceContainer),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F003D9B),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tiến độ mục tiêu',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.onSurface,
                ),
              ),
              TextButton(
                onPressed: () {
                  if (onViewAllTransactions != null) {
                    onViewAllTransactions!();
                  }
                },
                child: Text(
                  'Xem tất cả',
                  style: TextStyle(
                    color: isDark ? Colors.blueAccent : const Color(0xFF003D9B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Nếu chưa có mục tiêu nào
          if (goals.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                'Bạn chưa có mục tiêu nào đang thực hiện.',
                style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey),
              ),
            ),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index];
              final String title = goal['name'];
              final double savedAmount = goal['saved'] as double;
              final double targetAmount = goal['target'] as double;
              //Hạn chót
              final String deadline = goal['deadline'] ?? '';
              double progress = targetAmount > 0 ? (savedAmount / targetAmount) : 0;
              if (progress > 1.0) progress = 1.0;

              IconData icon = Icons.savings;
              int category = goal['category'] ?? -1;
              switch (category) {
                case 0:
                  icon = Icons.flight_takeoff;
                  break;
                case 1:
                  icon = Icons.devices_other;
                  break;
                case 2:
                  icon = Icons.health_and_safety_outlined;
                  break;
                case 3:
                  icon = Icons.home_outlined;
                  break;
              }

              return GestureDetector(
                onTap: () {
                  if (onGoalSelected != null) {
                    onGoalSelected!(title);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    // Đổi màu từng thẻ mục tiêu
                    color: isDark ? const Color(0xFF374151) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border: Border.all(color: isDark ? Colors.transparent : AppColors.surfaceContainer),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              //  Nền của Icon
                              color: isDark ? const Color(0xFF4B5563) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, color: isDark ? Colors.white70 : Colors.black54, size: 20),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: isDark ? Colors.grey.shade400 : Colors.grey),
                            //  Màu nền Popup xóa mục tiêu
                            color: isDark ? const Color(0xFF1F2937) : Colors.white,
                            onSelected: (value) {
                              if (value == 'delete' && onDeleteGoal != null) {
                                onDeleteGoal!(title);
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    SizedBox(width: 8),
                                    Text('Xoá mục tiêu', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black, //  Màu tên mục tiêu
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hạn chót: $deadline\nĐã nạp: ${_formatCurrency(savedAmount)} / ${_formatCurrency(targetAmount)} đ',
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade400 : Colors.grey, // Màu text phụ
                          fontSize: 12,
                          height: 1.5, // Tăng khoảng cách dòng lên chút cho dễ đọc
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tiến độ: ${(progress * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF00734C), // Lục sáng hơn cho nền tối
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${_formatCurrency(savedAmount)} đ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isDark ? Colors.white : Colors.black, // Màu số tiền
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: isDark ? const Color(0xFF4B5563) : Colors.grey.shade200, // Nền thanh tiến độ
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? const Color(0xFF34D399) : const Color(0xFF00734C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // NÚT TẠO MỤC TIÊU MỚI
          GestureDetector(
            onTap: () {
              if (onCreateGoal != null) onCreateGoal!();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                // Màu nền và viền nút thêm mục tiêu
                color: isDark ? const Color(0xFF374151) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? const Color(0xFF4B5563) : Colors.grey.shade300, width: 1.5),
              ),
              child: Column(
                children: [
                  Icon(Icons.add, color: isDark ? Colors.blueAccent : const Color(0xFF003D9B), size: 28),
                  const SizedBox(height: 8),
                  Text(
                    'Tạo Mục Tiêu Mới',
                    style: TextStyle(
                      color: isDark ? Colors.blueAccent : const Color(0xFF003D9B),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}