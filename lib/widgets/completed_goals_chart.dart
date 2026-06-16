import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../utils/app_colors.dart';

class CompletedGoalsChart extends StatefulWidget {
  final List<Map<String, dynamic>> goals;
  final List<TransactionModel>
  transactions; // Cần transactions để dò ngày hoàn thành
  final DateTime? anchorDate;

  const CompletedGoalsChart({
    super.key,
    required this.goals,
    required this.transactions,
    this.anchorDate,
  });

  @override
  State<CompletedGoalsChart> createState() => _CompletedGoalsChartState();
}

class _CompletedGoalsChartState extends State<CompletedGoalsChart> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.anchorDate ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final DateTime now = widget.anchorDate ?? DateTime.now();

    // 1. Tạo 5 tháng gần nhất
    List<DateTime> last5Months = List.generate(5, (index) {
      return DateTime(now.year, now.month - (4 - index));
    });

    // 2. Lọc các mục tiêu ĐÃ HOÀN THÀNH
    List<Map<String, dynamic>> completedGoals = widget.goals.where((g) {
      double target = (g['target'] as num?)?.toDouble() ?? 0.0;
      double saved = (g['saved'] as num?)?.toDouble() ?? 0.0;
      return target > 0 && saved >= target;
    }).toList();

    // 3. Phân loại mục tiêu vào các tháng hoàn thành
    Map<String, List<String>> monthlyCompletedGoals = {};
    for (var date in last5Months) {
      monthlyCompletedGoals['${date.year}-${date.month}'] = [];
    }

    for (var goal in completedGoals) {
      String name = goal['name'].toString();

      // Lấy tất cả giao dịch nạp tiền của mục tiêu này
      var txs = widget.transactions.where((t) => t.title == name).toList();
      DateTime? completionDate;

      if (txs.isNotEmpty) {
        // Sắp xếp giao dịch mới nhất lên đầu, lấy ngày của giao dịch cuối cùng làm mốc hoàn thành
        txs.sort((a, b) => b.date.compareTo(a.date));
        completionDate = txs.first.date;
      }

      if (completionDate != null) {
        String key = '${completionDate.year}-${completionDate.month}';
        if (monthlyCompletedGoals.containsKey(key)) {
          monthlyCompletedGoals[key]!.add(name);
        }
      }
    }

    // 4. Tìm tháng có số mục tiêu hoàn thành nhiều nhất để chia tỷ lệ trục Y
    int maxCount = 0;
    for (var list in monthlyCompletedGoals.values) {
      if (list.length > maxCount) maxCount = list.length;
    }
    // Cố định trục Y tối thiểu là 3 để biểu đồ không bị quá cao khi chỉ có 1 mục tiêu
    int yAxisMax = maxCount < 3 ? 3 : maxCount;

    // Lấy danh sách tên mục tiêu của tháng đang chọn để hiển thị ở dưới
    List<String> selectedMonthGoals =
        monthlyCompletedGoals['${_selectedDate.year}-${_selectedDate.month}'] ??
        [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events,
                color: isDark ? const Color(0xFFFBBF24) : Colors.amber,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Số mục tiêu hoàn thành',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // KHUNG BIỂU ĐỒ (TRỤC X VÀ CỘT)
          SizedBox(
            height: 192,
            width: double.infinity,
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$yAxisMax',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey.shade500 : Colors.grey,
                      ),
                    ),
                    Text(
                      '${(yAxisMax / 2).ceil()}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey.shade500 : Colors.grey,
                      ),
                    ),
                    Text(
                      '0',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey.shade500 : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
                Positioned.fill(
                  left: 24,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? Colors.grey.shade700
                              : AppColors.surfaceContainerHigh,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: last5Months.map((date) {
                        String key = '${date.year}-${date.month}';
                        int count = monthlyCompletedGoals[key]?.length ?? 0;
                        double heightFraction = count / yAxisMax;

                        bool isActive =
                            (date.month == _selectedDate.month &&
                            date.year == _selectedDate.year);
                        String? label = isActive && count > 0 ? '$count' : null;

                        return _buildChartBar(
                          'T${date.month}',
                          heightFraction > 0 ? heightFraction : 0.05,
                          isActive,
                          isDark,
                          label: label,
                          onTap: () => setState(() => _selectedDate = date),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // HIỂN THỊ CHI TIẾT TÊN MỤC TIÊU BÊN DƯỚI
          if (selectedMonthGoals.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF374151)
                    : AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.transparent : AppColors.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🏆 Đạt được trong T${_selectedDate.month}:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...selectedMonthGoals.map(
                    (name) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '• $name',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Chưa có mục tiêu hoàn thành trong T${_selectedDate.month}',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade500 : Colors.grey,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChartBar(
    String monthLabel,
    double heightFraction,
    bool isActive,
    bool isDark, {
    String? label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (label != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white : const Color(0xFFFBBF24),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.black : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: heightFraction,
                  child: Container(
                    width: 24,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFFFBBF24)
                          : (isDark
                                ? const Color(0xFF374151)
                                : AppColors.surfaceContainerHigh),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              monthLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive
                    ? const Color(0xFFFBBF24)
                    : (isDark
                          ? Colors.grey.shade400
                          : AppColors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
