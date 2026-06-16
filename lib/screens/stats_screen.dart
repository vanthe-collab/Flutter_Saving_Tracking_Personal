import 'package:flutter/material.dart';
import 'package:personal_tracking_money_project/utils/database_helper.dart';
import '../models/transaction_model.dart';
import '../utils/app_colors.dart';
import '../widgets/goal_distribution.dart';
import '../screens/achievements_card.dart';

class StatsScreen extends StatefulWidget {
  final List<TransactionModel> transactions;
  final List<Map<String, dynamic>> goals;
  final VoidCallback? onCreateGoal;
  final Function(String)? onNavigateToDeposit;
  final VoidCallback? onDataChanged;

  const StatsScreen({
    super.key,
    required this.transactions,
    required this.goals,
    this.onCreateGoal,
    this.onNavigateToDeposit,
    this.onDataChanged,
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _selectedTimeRange = 0; // 0: Tháng này, 1: Quý này, 2: Năm nay

  // Hàm format tiền tệ
  String _formatCurrency(double amount) {
    String s = amount.toInt().toString();
    String result = '';
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && i % 3 == 0) result = ',$result';
      result = s[s.length - 1 - i] + result;
    }
    return result;
  }

  // HÀM HIỂN THỊ DANH SÁCH GIAO DỊCH ĐÃ LỌC
  void _showFilteredTransactionsBottomSheet(
    List<TransactionModel> list,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Cho phép vuốt cao lên
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6, // Mở lên chiếm 60% màn hình
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
                  // Thanh ngang kéo thả
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
                    'Chi tiết Giao dịch',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Danh sách giao dịch
                  Expanded(
                    child: list.isEmpty
                        ? Center(
                            child: Text(
                              "Không có giao dịch nào trong kỳ này.",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey,
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: list.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: isDark
                                  ? const Color(0xFF374151)
                                  : Colors.grey.shade200,
                            ),
                            itemBuilder: (context, index) {
                              final tx = list[index];
                              String dateStr =
                                  "${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}/${tx.date.year}";
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: tx.iconBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(tx.icon, color: tx.iconColor),
                                ),
                                title: Text(
                                  tx.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                subtitle: Text(
                                  "$dateStr   •   ${tx.subtitle}",
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey,
                                  ),
                                ),
                                trailing: Text(
                                  '+ ${_formatCurrency(tx.amount)} đ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00734C),
                                  ),
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

    // 1. Lọc dữ liệu giao dịch theo nút thời gian được chọn
    final now = DateTime.now();
    List<TransactionModel> filteredTx = [];

    if (_selectedTimeRange == 0) {
      filteredTx = widget.transactions
          .where((tx) => tx.date.month == now.month && tx.date.year == now.year)
          .toList();
    } else if (_selectedTimeRange == 1) {
      int currentQuarter = (now.month - 1) ~/ 3 + 1;
      filteredTx = widget.transactions.where((tx) {
        int txQuarter = (tx.date.month - 1) ~/ 3 + 1;
        return txQuarter == currentQuarter && tx.date.year == now.year;
      }).toList();
    } else {
      filteredTx = widget.transactions
          .where((tx) => tx.date.year == now.year)
          .toList();
    }

    double totalSavings = filteredTx.fold(0, (sum, tx) => sum + tx.amount);

    // ĐÃ SỬA CHÍ CHÓA: Thay thế Scaffold bằng Container để tránh lỗi lồng cấu trúc giao diện làm ẩn phần Thành tích
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: 24,
            right: 24,
            top: 32,
            bottom: 100,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 896),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER TIÊU ĐỀ ---
                  Text(
                    'Tổng Quan Tiết Kiệm',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nắm bắt nhanh tình hình tài chính và tiến độ của bạn.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? Colors.grey.shade400
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- BỘ LỌC THỜI GIAN ---
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1F2937)
                          : AppColors.surfaceContainerLowest,
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF374151)
                            : AppColors.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0D003D9B),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _buildTimeRangeOption('Tháng này', 0, isDark),
                        _buildTimeRangeOption('Quý này', 1, isDark),
                        _buildTimeRangeOption('Năm nay', 2, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- CARD TỔNG TIẾT KIỆM ---
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1F2937)
                          : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF374151)
                            : AppColors.surfaceContainer,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14003D9B),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Stack(
                      children: [
                        Positioned(
                          top: -24,
                          right: -24,
                          child: Container(
                            width: 128,
                            height: 128,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.blue.withOpacity(0.05)
                                  : AppColors.secondaryContainer.withOpacity(
                                      0.2,
                                    ),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(128),
                              ),
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TỔNG TIẾT KIỆM KÌ NÀY',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : AppColors.onSurfaceVariant,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  _formatCurrency(totalSavings),
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.blueAccent
                                        : AppColors.primary,
                                    letterSpacing: -1.2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'VND',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.trending_up,
                                  size: 16,
                                  color: AppColors.secondary,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  '+15%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _selectedTimeRange == 0
                                      ? 'so với tháng trước'
                                      : (_selectedTimeRange == 1
                                            ? 'so với quý trước'
                                            : 'so với năm trước'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey.shade500
                                        : AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- KHỐI ĐỒNG BỘ HIỂN THỊ THÀNH TÍCH ĐƯỢC FIX GIAO DIỆN ---
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= 768) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: GoalDistribution(
                                goals: widget.goals,
                                onCreateGoal: widget.onCreateGoal,
                                onGoalSelected: widget.onNavigateToDeposit,
                                onViewAllTransactions: () {
                                  _showFilteredTransactionsBottomSheet(
                                    filteredTx,
                                    isDark,
                                  );
                                },
                                onDeleteGoal: (goalName) async {
                                  await DatabaseHelper.instance.deleteGoal(
                                    goalName,
                                  );
                                  if (widget.onDataChanged != null) {
                                    widget.onDataChanged!();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 1,
                              child: AchievementsCard(
                                transactions: widget.transactions,
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            GoalDistribution(
                              goals: widget.goals,
                              onCreateGoal: widget.onCreateGoal,
                              onGoalSelected: widget.onNavigateToDeposit,
                              onViewAllTransactions: () {
                                _showFilteredTransactionsBottomSheet(
                                  filteredTx,
                                  isDark,
                                );
                              },
                              onDeleteGoal: (goalName) async {
                                await DatabaseHelper.instance.deleteGoal(
                                  goalName,
                                );
                                if (widget.onDataChanged != null) {
                                  widget.onDataChanged!();
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            AchievementsCard(
                              transactions: widget.transactions,
                            ), // Hiển thị 6 nhiệm vụ cố định phía dưới mượt mà
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeRangeOption(String text, int index, bool isDark) {
    bool isActive = _selectedTimeRange == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTimeRange = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark
                      ? const Color(0xFF003D9B)
                      : AppColors.primaryContainer)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: isActive
                  ? (isDark ? Colors.white : AppColors.onPrimaryContainer)
                  : (isDark
                        ? Colors.grey.shade400
                        : AppColors.onSurfaceVariant),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
