import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category_model.dart';
import '../utils/database_helper.dart';
import '../utils/notification_manager.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart'; // 👉 THÊM IMPORT NÀY ĐỂ GỌI MÀN HÌNH SETTINGS

class CreateGoalScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onGoalCreated;
  final VoidCallback onCancel;

  const CreateGoalScreen({
    super.key,
    required this.onGoalCreated,
    required this.onCancel,
  });

  @override
  State<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends State<CreateGoalScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _depositController = TextEditingController();
  final TextEditingController _customPeriodController =
  TextEditingController(); // Controller chu kỳ tự nhập

  // QUẢN LÝ STATE DANH MỤC ĐỘNG TỪ DATABASE
  List<Category> _categories = [];
  int? _selectedCategoryId;
  bool _isLoadingCategories = true;

  // QUẢN LÝ STATE CHU KỲ NHẮC NHỞ
  String _selectedPeriodOption =
      '7'; // Mặc định gợi ý nhanh: Hàng tuần (7 ngày)
  String? _periodError;
  DateTime? _selectedDeadlineDate; // Giữ biến ngày để validate chu kỳ

  String? _nameError;
  String? _amountError;
  String? _dateError;

  String _username = "Người dùng";
  File? _avatarImage;
  int _unreadNotifs = 0;

  @override
  void initState() {
    super.initState();
    _loadCategoriesFromDB();
    _loadAppBarData();
  }

  Future<void> _loadAppBarData() async {
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

  Future<void> _loadCategoriesFromDB() async {
    try {
      final data = await DatabaseHelper.instance.getCategories();
      setState(() {
        _categories = data;
        if (_categories.isNotEmpty && _selectedCategoryId == null) {
          _selectedCategoryId = _categories.first.id;
        }
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() => _isLoadingCategories = false);
    }
  }

  void _showAddCategoryDialog() {
    final TextEditingController dialogController = TextEditingController();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    IconData chosenIcon = Icons.star_border_rounded;
    final List<IconData> pickerIcons = [
      Icons.star_border_rounded,
      Icons.local_mall_outlined,
      Icons.restaurant,
      Icons.flight_takeoff,
      Icons.directions_car_outlined,
      Icons.school_outlined,
      Icons.sports_esports_outlined,
      Icons.favorite_border,
      Icons.attach_money_rounded,
      Icons.work_outline,
      Icons.pets,
      Icons.shopping_cart_outlined,
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Text(
                "Thêm danh mục mới",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: dialogController,
                    autofocus: true,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: "Vd: Du lịch, Học tập...",
                      hintStyle: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade500,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF374151)
                          : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.transparent
                              : Colors.grey.shade400,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.transparent
                              : Colors.grey.shade400,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF003399)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Chọn biểu tượng:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
                    width: double.maxFinite,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: pickerIcons.length,
                      itemBuilder: (context, index) {
                        final icon = pickerIcons[index];
                        final isIconSelected = (chosenIcon == icon);
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              chosenIcon = icon;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isIconSelected
                                  ? const Color(0xFF80FFC0)
                                  : (isDark
                                  ? const Color(0xFF374151)
                                  : Colors.grey.shade100),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isIconSelected
                                    ? const Color(0xFF003399)
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              icon,
                              color: isIconSelected
                                  ? Colors.black87
                                  : (isDark ? Colors.white : Colors.black87),
                              size: 22,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Hủy",
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003399),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    final catName = dialogController.text.trim();
                    if (catName.isNotEmpty) {
                      final newCategory = Category(
                        name: catName,
                        iconCodePoint: chosenIcon.codePoint.toString(),
                        isDefault: false,
                      );
                      final insertedId = await DatabaseHelper.instance
                          .insertCategory(newCategory);
                      if (mounted) Navigator.pop(context);
                      await _loadCategoriesFromDB();
                      setState(() {
                        _selectedCategoryId = insertedId;
                      });
                    }
                  },
                  child: const Text(
                    "Thêm",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _selectedDeadlineDate = picked;
        _dateController.text = "${picked.day}/${picked.month}/${picked.year}";
        _dateError = null;
        _periodError = null; // Reset error chu kỳ để check lại
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _depositController.dispose();
    _customPeriodController.dispose();
    super.dispose();
  }

  InputDecoration _inputStyle(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF374151) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.transparent : Colors.grey.shade200,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.transparent : Colors.grey.shade200,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF003399)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    const Color primaryBlue = Color(0xFF003399);
    const Color mintGreen = Color(0xFF80FFC0);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF111827)
          : const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
              onPressed: widget.onCancel,
            ),
          ),
        ),
        title: Text(
          "Tạo Mục Tiêu Mới",
          style: TextStyle(
            color: isDark ? Colors.white : primaryBlue,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _unreadNotifs > 0,
              label: Text(_unreadNotifs.toString()),
              child: Icon(
                Icons.notifications_active,
                color: isDark ? Colors.white : primaryBlue,
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              ).then((_) => _loadAppBarData());
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
            // 👉 ĐÃ THÊM GESTURE DETECTOR ĐỂ NHẤN VÀO AVATAR CHUYỂN SANG SETTINGS
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(
                      onBackPressed: () => Navigator.pop(context), // Xử lý nút back của Settings
                    ),
                  ),
                ).then((_) => _loadAppBarData()); // Quay lại thì load lại Avatar & Chuông
              },
              child: CircleAvatar(
                radius: 16,
                backgroundImage: _avatarImage != null
                    ? FileImage(_avatarImage!) as ImageProvider
                    : NetworkImage(
                  'https://ui-avatars.com/api/?name=$_username&background=1E3A8A&color=fff',
                ),
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
            Text(
              "Bắt đầu Hành trình",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : primaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Lên kế hoạch rõ ràng để đạt được ước mơ tiếp theo của bạn.",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.all(20),
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
                  // --- Tên Mục Tiêu ---
                  Text(
                    "Tên Mục Tiêu",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    onChanged: (val) {
                      if (_nameError != null) setState(() => _nameError = null);
                    },
                    decoration: _inputStyle(
                      "Vd: Mua điện thoại mới, Chuyến đi...",
                      isDark,
                    ).copyWith(errorText: _nameError),
                  ),
                  const SizedBox(height: 20),

                  // --- Số Tiền Mục Tiêu ---
                  Text(
                    "Số Tiền Mục Tiêu",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    onChanged: (val) {
                      if (_amountError != null)
                        setState(() => _amountError = null);
                    },
                    decoration: _inputStyle("0", isDark).copyWith(
                      errorText: _amountError,
                      suffixIcon: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF4B5563)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "VNĐ",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey.shade300 : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- Thời Hạn Đạt Được ---
                  Text(
                    "Thời Hạn Đạt Được",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _dateController,
                    onTap: _selectDate,
                    readOnly: true,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: _inputStyle("mm/dd/yyyy", isDark).copyWith(
                      errorText: _dateError,
                      prefixIcon: const Icon(
                        Icons.calendar_today_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- ĐÃ THÊM: CHU KỲ NHẮC NHỞ NẠP TIỀN (GỢI Ý ĐỘNG + TỰ NHẬP) ---
                  Text(
                    "Chu Kỳ Nhắc Nhở Nạp Tiền",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _selectedPeriodOption,
                    dropdownColor: isDark
                        ? const Color(0xFF1F2937)
                        : Colors.white,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 15,
                    ),
                    decoration: _inputStyle(
                      "Chọn chu kỳ",
                      isDark,
                    ).copyWith(errorText: _periodError),
                    items: const [
                      DropdownMenuItem(
                        value: '7',
                        child: Text('Hàng tuần (7 ngày)'),
                      ),
                      DropdownMenuItem(
                        value: '14',
                        child: Text('2 tuần một lần (14 ngày)'),
                      ),
                      DropdownMenuItem(
                        value: '30',
                        child: Text('Hàng tháng (30 ngày)'),
                      ),
                      DropdownMenuItem(
                        value: 'custom',
                        child: Text('Tự tùy chỉnh nhập số ngày...'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedPeriodOption = value!;
                        _periodError = null;
                        if (_selectedPeriodOption != 'custom') {
                          _customPeriodController.clear();
                        }
                      });
                    },
                  ),

                  // Ô nhập số ngày tự chọn (Chỉ hiện khi chọn 'custom')
                  if (_selectedPeriodOption == 'custom') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customPeriodController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      onChanged: (val) {
                        if (_periodError != null)
                          setState(() => _periodError = null);
                      },
                      decoration:
                      _inputStyle(
                        "Nhập số ngày muốn nhắc nhở (Vd: 3, 5, 45...)",
                        isDark,
                      ).copyWith(
                        errorText: _periodError,
                        prefixIcon: const Icon(Icons.av_timer, size: 20),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // --- Gửi Vào Lần Đầu ---
                  Text(
                    "Gửi Vào Lần Đầu (Tùy chọn)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _depositController,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    keyboardType: TextInputType.number,
                    decoration: _inputStyle(
                      "0",
                      isDark,
                    ).add_icon(Icons.account_balance_wallet_outlined),
                  ),
                  const SizedBox(height: 25),

                  // --- CHỌN DANH MỤC ---
                  Text(
                    "Chọn Danh Mục",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _isLoadingCategories
                      ? const Center(child: CircularProgressIndicator())
                      : Builder(
                    builder: (context) {
                      double itemWidth =
                          (MediaQuery.of(context).size.width - 110) / 3;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ..._categories.map((cat) {
                            final iconData = IconData(
                              int.parse(cat.iconCodePoint),
                              fontFamily: 'MaterialIcons',
                            );
                            return _buildCategoryItem(
                              id: cat.id ?? 0,
                              icon: iconData,
                              label: cat.name,
                              activeColor: mintGreen,
                              width: itemWidth,
                              isDark: isDark,
                            );
                          }),
                          GestureDetector(
                            onTap: _showAddCategoryDialog,
                            child: Container(
                              width: itemWidth,
                              height: 100,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF374151)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.transparent
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.grey.shade600,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Thêm mới",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(height: 1),
                  ),

                  // --- NÚT TẠO MỤC TIÊU ---
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        setState(() {
                          // Validate Tên
                          if (_nameController.text.trim().isEmpty) {
                            _nameError = "Chưa nhập tên kìa!";
                          } else {
                            _nameError = null;
                          }

                          // Validate Số tiền
                          if (_amountController.text.trim().isEmpty) {
                            _amountError = "Nhập số tiền vào em nhé!";
                          } else if (double.tryParse(
                            _amountController.text.replaceAll(',', ''),
                          ) ==
                              null) {
                            _amountError = "Số tiền không hợp lệ!";
                          } else {
                            _amountError = null;
                          }

                          // Validate Ngày hạn
                          if (_dateController.text.trim().isEmpty) {
                            _dateError = "Chưa chọn hạn deadline!";
                          } else {
                            _dateError = null;
                          }

                          // Validate Chu Kỳ Ràng Buộc
                          int calculatedPeriod = 0;
                          if (_selectedPeriodOption == 'custom') {
                            final customText = _customPeriodController.text
                                .trim();
                            if (customText.isEmpty) {
                              _periodError = "Hãy gõ số ngày chu kỳ mong muốn!";
                            } else {
                              final intValue = int.tryParse(customText);
                              if (intValue == null || intValue <= 0) {
                                _periodError =
                                "Chu kỳ phải là một số ngày nguyên dương!";
                              } else {
                                calculatedPeriod = intValue;
                                _periodError = null;
                              }
                            }
                          } else {
                            calculatedPeriod = int.parse(_selectedPeriodOption);
                          }

                          // RÀNG BUỘC PHỤ: Kiểm tra số ngày chu kỳ với khoảng cách Deadline thực tế
                          if (_periodError == null &&
                              _selectedDeadlineDate != null) {
                            final totalDaysToDeadline =
                                _selectedDeadlineDate!
                                    .difference(DateTime.now())
                                    .inDays +
                                    1;
                            if (calculatedPeriod > totalDaysToDeadline) {
                              _periodError =
                              "Chu kỳ nhắc ($calculatedPeriod ngày) dài hơn cả thời gian đạt mục tiêu ($totalDaysToDeadline ngày)!";
                            }
                          }

                          // Nếu Form hoàn toàn hợp lệ
                          if (_nameError == null &&
                              _amountError == null &&
                              _dateError == null &&
                              _periodError == null) {
                            Map<String, dynamic> newGoal = {
                              'name': _nameController.text.trim(),
                              'amount': _amountController.text.trim(),
                              'date': _dateController.text.trim(),
                              'deposit': _depositController.text.trim().isEmpty
                                  ? "0"
                                  : _depositController.text.trim(),
                              'category': _selectedCategoryId ?? 0,
                              'period':
                              calculatedPeriod,
                            };
                            widget.onGoalCreated(newGoal);
                          }
                        });
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            "Tạo Mục Tiêu",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem({
    required int id,
    required IconData icon,
    required String label,
    required Color activeColor,
    required double width,
    required bool isDark,
  }) {
    final isSelected = (_selectedCategoryId == id);
    final bgColor = isSelected
        ? activeColor
        : (isDark ? const Color(0xFF374151) : Colors.white);
    final itemColor = isSelected
        ? Colors.black87
        : (isDark ? Colors.white : Colors.black87);

    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryId = id),
      child: Container(
        width: width,
        height: 100,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? Colors.transparent : Colors.grey.shade200),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: itemColor),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: itemColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Extension helper để viết ngắn gọn prefix icon
extension InputDecorationExtension on InputDecoration {
  InputDecoration add_icon(IconData icon) {
    return copyWith(prefixIcon: Icon(icon, size: 20));
  }
}