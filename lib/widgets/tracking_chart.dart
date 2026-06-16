import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../utils/app_colors.dart';

class TrackingChart extends StatefulWidget {
  final List<TransactionModel> transactions;
  final DateTime? anchorDate;

  const TrackingChart({super.key, required this.transactions, this.anchorDate});

  @override
  State<TrackingChart> createState() => _TrackingChartState();
}

class _TrackingChartState extends State<TrackingChart> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.anchorDate ?? DateTime.now();
  }

  // Hàm format hiển thị số tiền chính xác có dấu phẩy
  String _formatCurrency(double amount) {
    if (amount == 0) return '0';
    String result = amount.toStringAsFixed(0);
    return result.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  // Hàm làm gọn số tiền trên trục Y (hiện M hoặc K)
  String _formatYAxis(double amount) {
    if (amount == 0) return '0';
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final DateTime now = widget.anchorDate ?? DateTime.now();

    List<DateTime> last5Months = List.generate(5, (index) {
      return DateTime(now.year, now.month - (4 - index));
    });

    Map<String, double> monthlyTotals = {};
    for (var date in last5Months) {
      monthlyTotals['${date.year}-${date.month}'] = 0.0;
    }

    for (var tx in widget.transactions) {
      String key = '${tx.date.year}-${tx.date.month}';
      if (monthlyTotals.containsKey(key)) {
        monthlyTotals[key] = monthlyTotals[key]! + tx.amount;
      }
    }

    double maxAmount = 15000000;
    for (var amount in monthlyTotals.values) {
      if (amount > maxAmount) maxAmount = amount;
    }

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Biểu đồ theo dõi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.more_horiz,
                  color: isDark ? Colors.grey.shade400 : AppColors.outline,
                ),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                      _formatYAxis(maxAmount),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey.shade500 : Colors.grey,
                      ),
                    ),
                    Text(
                      _formatYAxis(maxAmount * 0.66),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey.shade500 : Colors.grey,
                      ),
                    ),
                    Text(
                      _formatYAxis(maxAmount * 0.33),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey.shade500 : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
                Positioned.fill(
                  left: 32, // Đẩy sang phải một xíu để không đè lên trục Y
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
                        double amount = monthlyTotals[key] ?? 0.0;
                        double heightFraction = maxAmount > 0
                            ? amount / maxAmount
                            : 0.0;

                        bool isActive =
                            (date.month == _selectedDate.month &&
                            date.year == _selectedDate.year);

                        // HIỂN THỊ LABEL CHÍNH XÁC, CÓ CẢ 0đ
                        String? label = isActive
                            ? '${_formatCurrency(amount)} đ'
                            : null;

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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white : AppColors.onSurface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.black : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
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
                          ? const Color(0xFF80FFC0)
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
                    ? const Color(0xFF80FFC0)
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
