import 'package:sqflite/sqflite.dart';
// Đi ra ngoài thư mục models để vào utils lấy kết nối dùng chung
import '../utils/database_helper.dart';

class DatabaseUsers {
  static final DatabaseUsers instance = DatabaseUsers._init();
  DatabaseUsers._init();

  // DÙNG CHUNG KẾT NỐI: Lấy trực tiếp thực thể database từ DatabaseHelper để tránh bị treo luồng trên Windows
  Future<Database> get database async {
    return await DatabaseHelper.instance.database;
  }

  /// Hàm kiểm tra thông tin tài khoản khi đăng nhập
  Future<bool> checkLogin(String username, String password) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> result = await db.query(
        'users',
        where: 'username = ? AND password = ?',
        whereArgs: [username, password],
      );
      return result.isNotEmpty;
    } catch (e) {
      print("Lỗi checkLogin: $e");
      return false;
    }
  }

  /// Hàm đăng ký tài khoản mới vào bảng users
  Future<int> registerUser(String username, String password) async {
    final db = await database;
    try {
      return await db.insert('users', {
        'username': username,
        'password': password,
      });
    } catch (e) {
      return -1; // Trả về -1 nếu trùng username
    }
  }

  Future<bool> updatePassword(
    String username,
    String oldPassword,
    String newPassword,
  ) async {
    final db = await database;
    // 1. Kiểm tra mật khẩu cũ có đúng không
    final List<Map<String, dynamic>> result = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, oldPassword],
    );

    if (result.isNotEmpty) {
      // 2. Nếu đúng, update mật khẩu mới
      await db.update(
        'users',
        {'password': newPassword},
        where: 'username = ?',
        whereArgs: [username],
      );
      return true;
    }
    return false;
  }
}
