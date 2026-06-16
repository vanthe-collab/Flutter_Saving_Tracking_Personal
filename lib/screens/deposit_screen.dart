import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path_helper;
import 'dart:io';
import '../models/transaction_model.dart';
import '../utils/database_helper.dart';
import '../utils/notification_manager.dart';
import '../utils/app_colors.dart';
import 'goal_detail_screen.dart';

class DepositScreen extends StatefulWidget {
  final List<Map<String, dynamic>> inProgressGoals;
  final List<String> goals;
  final List<TransactionModel> transactions;
  final String? initialSelectedGoal;
  final String?
  filterGoalName; // Nhận biến lọc mục tiêu từ trang dashboard truyền sang
  final Future<void> Function() onRefresh;
  final VoidCallback
  onClearFilter; // Callback để đồng bộ xóa tên mục tiêu lưu tạm ở trang cha

  const DepositScreen({
    super.key,
    required this.inProgressGoals,
    required this.goals,
    required this.transactions,
    this.initialSelectedGoal,
    this.filterGoalName,
    required this.onRefresh,
    required this.onClearFilter,
  });

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  String? _selectedGoal;
  final TextEditingController _amountController = TextEditingController();
  File? _quickDepositImage;

  // State cục bộ quản lý bộ lọc để có thể thay đổi/tắt filter ngay tại trang nạp tiền này
  String? _activeFilterGoalName;

  @override
  void initState() {
    super.initState();
    _selectedGoal = widget.initialSelectedGoal;
    if (_selectedGoal == null && widget.goals.isNotEmpty) {
      _selectedGoal = widget.goals.first;
    }
    _activeFilterGoalName = widget.filterGoalName;
  }

  @override
  void didUpdateWidget(covariant DepositScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Đồng bộ lại filter mới nếu người dùng bấm chọn mục tiêu khác ngoài dashboard rồi nhảy vào lại
    if (widget.filterGoalName != oldWidget.filterGoalName) {
      setState(() {
        _activeFilterGoalName = widget.filterGoalName;
        _selectedGoal = widget.initialSelectedGoal;
      });
    }
  }

  String _formatCurrency(double amount) {
    String s = amount.toInt().toString();
    String result = '';
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && i % 3 == 0) result = ',$result';
      result = s[s.length - 1 - i] + result;
    }
    return result;
  }

  Future<void> _pickQuickDepositImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image == null) return;

      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName =
          'tx_cover_${DateTime.now().millisecondsSinceEpoch}${path_helper.extension(image.path)}';
      final String targetPath = '${appDir.path}/$fileName';
      final File savedImage = await File(image.path).copy(targetPath);

      setState(() {
        _quickDepositImage = savedImage;
      });
    } catch (e) {
      _showSnackBar('Không thể tải ảnh: $e');
    }
  }

  Future<void> _logTransaction(
    String goalName,
    double amount,
    int categoryId,
    String? txImagePath, {
    bool isEmergencyRoundUp = false,
  }) async {
    final now = DateTime.now();
    double currentProgress = 0.0;
    try {
      var goal = widget.inProgressGoals.firstWhere(
        (g) => g['name'] == goalName,
      );
      double target = (goal['target'] as num).toDouble();
      double currentSaved = (goal['saved'] as num).toDouble();
      if (target > 0) {
        currentProgress = (currentSaved + amount) / target;
        if (currentProgress > 1.0) currentProgress = 1.0;
      }
    } catch (e) {}

    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    String imageTag = txImagePath != null ? '| [TX_IMAGE:$txImagePath]' : '';

    // Ghi chú rõ ràng nếu đây là khoản tiền lẻ tự động trích vào quỹ khẩn cấp
    final String typeTag = isEmergencyRoundUp
        ? 'Emergency Round-up'
        : 'Manual Deposit';
    final String customSubtitle =
        '$timeStr • $typeTag | [SNAPSHOT_PROGRESS:${currentProgress.toString()}] $imageTag';

    final newTx = TransactionModel(
      title: goalName,
      subtitle: customSubtitle,
      amount: amount,
      date: DateTime.now(),
      category: categoryId,
    );
    await DatabaseHelper.instance.insertTransaction(newTx);
  }

  // --- NÂNG CẤP LOGIC XỬ LÝ NẠP TIỀN: KIỂM TRA ĐIỀU KIỆN LÀM TRÒN VÀ BẬT DIALOG SUGGESTION ---
  Future<void> _handleDeposit() async {
    if (_amountController.text.isEmpty || _selectedGoal == null) return;
    final amountText = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final double? amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) return;

    String cleanTitle = _selectedGoal!;
    if (cleanTitle.contains(' '))
      cleanTitle = cleanTitle.substring(cleanTitle.indexOf(' ') + 1);

    var goal = widget.inProgressGoals.firstWhere(
      (g) => g['name'] == cleanTitle,
    );
    int category = goal['category'];

    final prefs = await SharedPreferences.getInstance();
    bool isAutoSave = prefs.getBool('isAutoSave') ?? true;
    double nextTenThousand = (amount / 10000).ceil() * 10000;
    double remainder = nextTenThousand - amount;

    // Nếu cấu hình bật tự động làm tròn, tiền dư > 0 và không phải nạp cho Quỹ khẩn cấp
    if (isAutoSave && remainder > 0 && cleanTitle != 'Emergency Fund') {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.tips_and_updates, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Round-up Suggestion',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              'Bạn có muốn làm tròn số tiền thành ${_formatCurrency(nextTenThousand)} VND không?\n\n'
              '• ${_formatCurrency(amount)} VND chuyển đến mục tiêu [$cleanTitle]\n'
              '• ${_formatCurrency(remainder)} VND chuyển đến [Quỹ khẩn cấp]',
              style: TextStyle(
                color: isDark ? Colors.grey.shade300 : Colors.black87,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _executeNormalDeposit(cleanTitle, amount, category);
                },
                child: Text(
                  'No, just ${_formatCurrency(amount)}',
                  style: const TextStyle(color: Colors.grey),
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
                  Navigator.pop(dialogContext);
                  await _executeRoundUpDeposit(
                    cleanTitle,
                    amount,
                    category,
                    remainder,
                  );
                },
                child: Text('Yes, deposit ${_formatCurrency(nextTenThousand)}'),
              ),
            ],
          );
        },
      );
    } else {
      await _executeNormalDeposit(cleanTitle, amount, category);
    }
  }

  // HÀM THỰC THI 1: CHỈ NẠP TIỀN THƯỜNG KHÔNG LÀM TRÒN
  Future<void> _executeNormalDeposit(
    String title,
    double amount,
    int category,
  ) async {
    String? imgPath = _quickDepositImage?.path;
    await _logTransaction(title, amount, category, imgPath);
    await DatabaseHelper.instance.updateGoalSavedAmount(title, amount);

    setState(() {
      _amountController.clear();
      _quickDepositImage = null;
    });
    await widget.onRefresh();
    _showSnackBar('Nạp tiền thành công vào $title!');
  }

  // HÀM THỰC THI 2: TRÍCH KHẢO LÀM TRÒN TIỀN DƯ SANG EMERGENCY FUND
  Future<void> _executeRoundUpDeposit(
    String title,
    double amount,
    int category,
    double remainder,
  ) async {
    String? imgPath = _quickDepositImage?.path;

    // Lưu khoản tiền gốc cho mục tiêu hiện tại
    await _logTransaction(title, amount, category, imgPath);
    await DatabaseHelper.instance.updateGoalSavedAmount(title, amount);

    // Trích phần tiền thừa chuyển thẳng vào Emergency Fund (Category mặc định là 2)
    await DatabaseHelper.instance.updateGoalSavedAmount(
      'Emergency Fund',
      remainder,
    );
    await _logTransaction(
      'Emergency Fund',
      remainder,
      2,
      null,
      isEmergencyRoundUp: true,
    );

    setState(() {
      _amountController.clear();
      _quickDepositImage = null;
    });
    await widget.onRefresh();
    _showSnackBar(
      'Làm tròn thành công! Đã tiết kiệm thêm ${_formatCurrency(remainder)} VND vào Quỹ khẩn cấp.',
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool hasSelectedImage =
        _quickDepositImage != null && _quickDepositImage!.existsSync();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lịch sử nạp tiền',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedGoal,
                  dropdownColor: isDark
                      ? const Color(0xFF374151)
                      : Colors.white,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  items: widget.goals
                      .map(
                        (val) => DropdownMenuItem(value: val, child: Text(val)),
                      )
                      .toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedGoal = newValue;
                      // TỰ ĐỘNG CẬP NHẬT BỘ LỌC LỊCH SỬ KHI USER CHỦ ĐỘNG ĐỔI DROPDOWN TẠI TRANG NÀY LUÔN CHO TIỆN
                      if (newValue != null) {
                        String cleanTitle = newValue;
                        if (cleanTitle.contains(' '))
                          cleanTitle = cleanTitle.substring(
                            cleanTitle.indexOf(' ') + 1,
                          );
                        _activeFilterGoalName = cleanTitle;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: const InputDecoration(
                    hintText: 'Nhập số tiền...',
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _pickQuickDepositImage,
                  child: Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF374151)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: hasSelectedImage
                        ? Image.file(_quickDepositImage!, fit: BoxFit.cover)
                        : const Center(
                            child: Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 36,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003D9B),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _handleDeposit,
                  child: const Center(child: Text('Nạp tiền')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // --- THANH ĐIỀU KHIỂN BỘ LỌC LỊCH SỬ VÀ NÚT TẤT CẢ THEO Ý BẠN ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _activeFilterGoalName != null
                    ? "Lịch sử của: $_activeFilterGoalName"
                    : "Tất cả lịch sử nạp",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.amber : const Color(0xFF003D9B),
                ),
              ),
              if (_activeFilterGoalName != null)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _activeFilterGoalName = null;
                    });
                    widget.onClearFilter();
                  },
                  icon: const Icon(Icons.history, size: 16, color: Colors.grey),
                  label: const Text(
                    "Hiện tất cả",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _buildTransactionHistory(),
        ],
      ),
    );
  }

  void _showDepositDetailDialog(
    Map<String, dynamic> snapshotGoal,
    String fullTimeStr,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    double target = (snapshotGoal['target'] as num).toDouble();
    double saved = (snapshotGoal['saved'] as num).toDouble();
    double progress = target > 0 ? (saved / target) : 0.0;
    if (progress > 1.0) progress = 1.0;

    String? imgPath = snapshotGoal['image'];
    bool hasImg =
        imgPath != null && imgPath.isNotEmpty && File(imgPath).existsSync();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            snapshotGoal['name'],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 140,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF374151)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  image: hasImg
                      ? DecorationImage(
                          image: FileImage(File(imgPath!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: !hasImg
                    ? const Center(
                        child: Text(
                          'Không có ảnh kỉ niệm',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                'Thời gian nạp: $fullTimeStr',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tiến độ thời điểm đó:',
                    style: TextStyle(fontSize: 13),
                  ),
                  Text(
                    '${(progress * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00734C),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Đã tích lũy: ${_formatCurrency(saved)} VND',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Mục tiêu tổng: ${_formatCurrency(target)} VND',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: isDark
                      ? const Color(0xFF374151)
                      : Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF00734C),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransactionHistory() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    List<TransactionModel> displayedList = widget.transactions;
    if (_activeFilterGoalName != null) {
      displayedList = widget.transactions
          .where((tx) => tx.title == _activeFilterGoalName)
          .toList();
    }

    if (displayedList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            "Không có lịch sử nạp tiền nào.",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayedList.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final tx = displayedList[index];
        IconData categoryIcon = Icons.monetization_on;
        if (tx.category == 0)
          categoryIcon = Icons.flight_takeoff;
        else if (tx.category == 1)
          categoryIcon = Icons.devices_other;
        else if (tx.category == 2)
          categoryIcon = Icons.health_and_safety_outlined;
        else if (tx.category == 3)
          categoryIcon = Icons.home_outlined;

        String fullTimeStr =
            "${tx.date.day}/${tx.date.month}/${tx.date.year} lúc ${tx.date.hour.toString().padLeft(2, '0')}:${tx.date.minute.toString().padLeft(2, '0')}";

        return ListTile(
          onTap: () async {
            try {
              final originalGoal = widget.inProgressGoals.firstWhere(
                (g) => g['name'] == tx.title,
              );
              Map<String, dynamic> snapshotGoal = Map.from(originalGoal);

              double frozenProgress = (originalGoal['target'] > 0)
                  ? (originalGoal['saved'] / originalGoal['target'])
                  : 0.0;
              if (tx.subtitle.contains('[SNAPSHOT_PROGRESS:')) {
                final startIdx =
                    tx.subtitle.indexOf('[SNAPSHOT_PROGRESS:') +
                    '[SNAPSHOT_PROGRESS:'.length;
                final endIdx = tx.subtitle.indexOf(']', startIdx);
                frozenProgress =
                    double.tryParse(tx.subtitle.substring(startIdx, endIdx)) ??
                    frozenProgress;
              }
              snapshotGoal['saved'] = originalGoal['target'] * frozenProgress;

              String? txImage;
              if (tx.subtitle.contains('[TX_IMAGE:')) {
                final startIdx =
                    tx.subtitle.indexOf('[TX_IMAGE:') + '[TX_IMAGE:'.length;
                final endIdx = tx.subtitle.indexOf(']', startIdx);
                txImage = tx.subtitle.substring(startIdx, endIdx);
              }
              snapshotGoal['image'] = txImage;

              _showDepositDetailDialog(snapshotGoal, fullTimeStr);
            } catch (e) {}
          },
          leading: CircleAvatar(child: Icon(categoryIcon)),
          title: Text(tx.title),
          subtitle: Text(fullTimeStr),
          trailing: Text('+ ${_formatCurrency(tx.amount)} VND'),
        );
      },
    );
  }
}
