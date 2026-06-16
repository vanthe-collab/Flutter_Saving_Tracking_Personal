import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager {
  // 1. Đặt ở đây để gọi từ bất kỳ file nào
  static final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier(false);

  // 2. Gọi 1 lần duy nhất lúc mở app để đọc bộ nhớ
  static Future<void> initTheme() async {
    final prefs = await SharedPreferences.getInstance();
    isDarkModeNotifier.value = prefs.getBool('isDarkMode') ?? false;
  }

  // 3. Gọi khi user gạt nút ở màn hình Cài đặt
  static Future<void> toggleTheme(bool isDark) async {
    isDarkModeNotifier.value = isDark; // Đổi màu app ngay lập tức
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark); // Lưu vào máy
  }
}