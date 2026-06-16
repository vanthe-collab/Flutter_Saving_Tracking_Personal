import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/database_helper.dart';
import '../../models/transaction_model.dart';

class GoalDetailScreen extends StatefulWidget {
  final Map<String, dynamic> goal;

  const GoalDetailScreen({super.key, required this.goal});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  late Map<String, dynamic> _currentGoal;

  @override
  void initState() {
    super.initState();
    // Tạo bản sao dữ liệu mục tiêu để thoải mái chỉnh sửa
    _currentGoal = Map.from(widget.goal);
  }

  // Hàm format tiền
  String formatCurrency(double amount) {
    String result = amount.toStringAsFixed(0);
    return result.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  // Hàm lấy Icon tương ứng
  IconData getIconForCategory(int categoryId) {
    switch (categoryId) {
      case 0:
        return Icons.flight_takeoff;
      case 1:
        return Icons.devices_other;
      case 2:
        return Icons.health_and_safety_outlined;
      case 3:
        return Icons.home_outlined;
      default:
        return Icons.track_changes;
    }
  }

  // Hàm nạp tiền riêng cho mục tiêu này
  void _showAddMoneyToGoalDialog() {
    TextEditingController amountController = TextEditingController();

    // Lấy trạng thái Dark Mode cho Dialog
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          //  Đổi nền Dialog theo Theme
          backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Nạp tiền vào mục tiêu',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF003D9B),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mục tiêu: ${_currentGoal['name']}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: 'Nhập số tiền nạp...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF374151) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? Colors.transparent : Colors.grey.shade400,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? Colors.transparent : Colors.grey.shade400,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF003D9B)),
                  ),
                  prefixIcon: Icon(
                    Icons.add_circle_outline,
                    color: isDark ? Colors.grey.shade400 : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Hủy',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003D9B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                if (amountController.text.isNotEmpty) {
                  double amountToAdd =
                      double.tryParse(amountController.text) ?? 0.0;
                  if (amountToAdd > 0) {
                    setState(() {
                      _currentGoal['saved'] += amountToAdd;
                    });

                    await DatabaseHelper.instance.updateGoalSavedAmount(
                      _currentGoal['name'],
                      amountToAdd,
                    );

                    final newTx = TransactionModel(
                      title: _currentGoal['name'],
                      subtitle: 'Nạp từ chi tiết mục tiêu',
                      amount: amountToAdd,
                      date: DateTime.now(),
                      category: _currentGoal['category'],
                    );
                    await DatabaseHelper.instance.insertTransaction(newTx);

                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Đã nạp ${formatCurrency(amountToAdd)}đ thành công!',
                        ),
                        backgroundColor: const Color(0xFF00734C),
                      ),
                    );
                  }
                }
              },
              child: const Text('Xác Nhận Nạp'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // KIỂM TRA SÁNG / TỐI
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Màu primary cho đồng bộ
    const Color primaryBlue = Color(0xFF003D9B);

    double progress = _currentGoal['target'] > 0
        ? (_currentGoal['saved'] / _currentGoal['target'])
        : 0;
    if (progress > 1.0) progress = 1.0;

    double remaining = _currentGoal['target'] - _currentGoal['saved'];
    if (remaining < 0) remaining = 0;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.pop(context, _currentGoal);
      },
      child: Scaffold(
        // ĐỔI MÀU NỀN SCAFFOLD
        backgroundColor: isDark
            ? const Color(0xFF111827)
            : const Color(0xFFF8F9FB),

        // ĐỒNG BỘ APPBAR NHƯ MÀN TẠO MỤC TIÊU
        appBar: AppBar(
          backgroundColor: isDark
              ? const Color(0xFF111827)
              : const Color(0xFFF8F9FB),
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: CircleAvatar(
              backgroundColor: isDark
                  ? Colors.white.withOpacity(0.1)
                  : primaryBlue.withOpacity(0.1),
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDark ? Colors.white : primaryBlue,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context, _currentGoal),
              ),
            ),
          ),
          title: Text(
            'Chi Tiết Mục Tiêu',
            style: TextStyle(
              color: isDark ? Colors.white : primaryBlue,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),

        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon to đùng
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  // Nền icon khi Dark Mode
                  color: isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFD0E0FF).withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  getIconForCategory(_currentGoal['category']),
                  size: 64,
                  // Đổi màu Icon cho dễ nhìn trên nền tối
                  color: isDark ? Colors.blue[300] : primaryBlue,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _currentGoal['name'],
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? Colors.white
                      : Colors.black, // Màu tên mục tiêu
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cần đạt: ${formatCurrency(_currentGoal['target'])} VNĐ',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey.shade400 : Colors.grey,
                ),
              ),
              const SizedBox(height: 40),

              // Thẻ hiển thị tiến độ
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  // MÀU NỀN CỦA THẺ TIẾN ĐỘ
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
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Đã tiết kiệm',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey.shade400 : Colors.grey,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00734C), // Màu xanh lá giữ nguyên
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${formatCurrency(_currentGoal['saved'])} đ',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          // Đổi màu số tiền tiết kiệm cho sáng sủa
                          color: isDark ? Colors.blue[400] : primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        // Nền thanh tiến độ
                        backgroundColor: isDark
                            ? const Color(0xFF374151)
                            : Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF00734C),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Còn lại:',
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade400 : Colors.grey,
                          ),
                        ),
                        Text(
                          '${formatCurrency(remaining)} đ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : Colors.black, // Đổi màu số tiền còn lại
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Nút bấm nạp tiền
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _showAddMoneyToGoalDialog,
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Nạp tiền vào mục tiêu này',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
