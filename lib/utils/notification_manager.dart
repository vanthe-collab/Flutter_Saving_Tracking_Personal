import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationManager {
  static const String _key = 'app_notifications';

  // Thêm thông báo mới
  static Future<void> saveNotification(String title, String message) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> notifs = prefs.getStringList(_key) ?? [];

    final newNotif = {
      'title': title,
      'message': message,
      'date': DateTime.now().toIso8601String(),
      'isRead': false, // Chưa đọc
    };

    notifs.insert(0, jsonEncode(newNotif)); // Thêm lên đầu danh sách
    await prefs.setStringList(_key, notifs);
  }

  // Lấy danh sách thông báo
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> notifs = prefs.getStringList(_key) ?? [];
    return notifs.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  // Đếm số thông báo chưa đọc
  static Future<int> getUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> notifs = prefs.getStringList(_key) ?? [];
    return notifs.where((e) => jsonDecode(e)['isRead'] == false).length;
  }

  // Đánh dấu tất cả là đã đọc
  static Future<void> markAllAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> notifs = prefs.getStringList(_key) ?? [];
    List<String> updated = notifs.map((e) {
      var map = jsonDecode(e);
      map['isRead'] = true;
      return jsonEncode(map);
    }).toList();
    await prefs.setStringList(_key, updated);
  }
}