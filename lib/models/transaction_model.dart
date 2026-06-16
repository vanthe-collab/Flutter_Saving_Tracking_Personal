import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class TransactionModel {
  int? id;
  final String title;
  final String subtitle;
  final double amount;
  final DateTime date;
  final int category; // vẫn là category_id từ DB

  // 3 trường giao diện — tự động tính theo category
  late IconData icon;
  late Color iconBg;
  late Color iconColor;

  TransactionModel({
    this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.category,
    String? iconCodePoint, // THÊM: truyền vào nếu là category custom từ DB
  }) {
    // Nếu có iconCodePoint từ DB → dùng nó, ngược lại fallback về switch cũ
    if (iconCodePoint != null) {
      _initUIFromCodePoint(iconCodePoint);
    } else {
      _initUI();
    }
  }

  // ── Dùng cho category custom lưu trong DB ──────────────────────────────
  void _initUIFromCodePoint(String codePoint) {
    final value = int.tryParse(codePoint) ?? 0;
    icon = IconData(value, fontFamily: 'MaterialIcons');

    // Tạo màu dựa theo category id để mỗi danh mục có màu riêng
    final colors = _colorPalette(category);
    iconBg = colors[0];
    iconColor = colors[1];
  }

  // ── Giữ nguyên switch cũ cho 6 danh mục seed mặc định ─────────────────
  void _initUI() {
    switch (category) {
      case 0: // Du lịch (seed id = 1 nếu autoincrement từ 1)
        icon = Icons.flight_takeoff;
        iconBg = AppColors.primaryFixed;
        iconColor = AppColors.primaryContainer;
        break;
      case 1: // Điện tử
        icon = Icons.devices_other;
        iconBg = const Color(0xFFFFDDB3).withOpacity(0.4);
        iconColor = const Color(0xFF7D5200);
        break;
      case 2: // Dự phòng / Sức khỏe
        icon = Icons.health_and_safety_outlined;
        iconBg = AppColors.secondaryContainer.withOpacity(0.3);
        iconColor = AppColors.onSecondaryContainer;
        break;
      case 3: // Nhà cửa
        icon = Icons.home_outlined;
        iconBg = Colors.purple.withOpacity(0.2);
        iconColor = Colors.purple;
        break;
      default:
        icon = Icons.track_changes;
        iconBg = const Color(0xFFDAE2FF).withOpacity(0.5);
        iconColor = const Color(0xFF0052CC);
    }
  }

  // ── Bảng màu xoay vòng cho category id bất kỳ ─────────────────────────
  List<Color> _colorPalette(int id) {
    const palettes = [
      [Color(0xFFE3F2FD), Color(0xFF1565C0)], // blue
      [Color(0xFFFFF3E0), Color(0xFFE65100)], // orange
      [Color(0xFFE8F5E9), Color(0xFF2E7D32)], // green
      [Color(0xFFF3E5F5), Color(0xFF6A1B9A)], // purple
      [Color(0xFFFFEBEE), Color(0xFFC62828)], // red
      [Color(0xFFE0F7FA), Color(0xFF00695C)], // teal
    ];
    final pair = palettes[id % palettes.length];
    return [pair[0], pair[1]];
  }

  // ── DB serialization ───────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
    };
  }

  /// Dùng khi chỉ có dữ liệu từ bảng transactions (không JOIN categories)
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      title: map['title'],
      subtitle: map['subtitle'],
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date']),
      category: map['category'],
    );
  }

  /// Dùng khi query có JOIN với bảng categories để lấy icon_code_point
  factory TransactionModel.fromMapWithCategory(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      title: map['title'],
      subtitle: map['subtitle'],
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date']),
      category: map['category'],
      iconCodePoint: map['icon_code_point'] as String?, // từ JOIN
    );
  }
}