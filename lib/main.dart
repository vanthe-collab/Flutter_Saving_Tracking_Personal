import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'screens/login_screen.dart';
import 'screens/main_dashboard_screen.dart';
import 'utils/theme_manager.dart'; //Import ThemeManager vào

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Đọc bộ nhớ để biết lần trước user xài nền đen hay trắng
  await ThemeManager.initTheme();

  // 2. Đọc bộ nhớ xem user đã đăng nhập chưa
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(SavingsTrackerApp(isLoggedIn: isLoggedIn));
}

class SavingsTrackerApp extends StatelessWidget {
  final bool isLoggedIn;

  const SavingsTrackerApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    // Vẫn phải bọc MaterialApp để nó biết khi nào cần vẽ lại màu
    return ValueListenableBuilder<bool>(
      valueListenable:
          ThemeManager.isDarkModeNotifier, // Lắng nghe từ file ThemeManager
      builder: (context, isDark, child) {
        return MaterialApp(
          title: 'Savings Tracker',
          debugShowCheckedModeBanner: false,

          // Giao diện Sáng (Light Theme)
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF4F7FC),
            primaryColor: const Color(0xFF1E3A8A),
            fontFamily: 'Inter',
          ),

          // Giao diện Tối (Dark Theme)
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF111827),
            primaryColor: const Color(0xFF3B82F6),
            fontFamily: 'Inter',
          ),

          // Công tắc quyết định
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,

          // Điều hướng đăng nhập
          home: isLoggedIn ? const MainDashboardScreen() : const LoginScreen(),
        );
      },
    );
  }
}
