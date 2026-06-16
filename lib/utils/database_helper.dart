import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // Nâng lên v6 để dọn sạch bộ nhớ cache SQLite kẹt trên máy Xiaomi
    _database = await _initDB('savings_tracker_v6.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3, // Tăng lên version 3 để quản lý bảng thành tích mới
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // Tự động tạo bảng thành tích bổ sung cho tài khoản cũ
      await db.execute('''
        CREATE TABLE IF NOT EXISTS achievements (
          id TEXT PRIMARY KEY,
          username TEXT NOT NULL,
          current_progress REAL DEFAULT 0,
          is_unlocked INTEGER DEFAULT 0
        )
      ''');
    }
  }

  Future<String> _getCurrentUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('currentUsername') ?? 'unknown';
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id $idType,
        username TEXT NOT NULL UNIQUE,
        password $textType
      )
    ''');

    await db.execute('''
      CREATE TABLE goals (
        id $idType,
        username $textType, 
        name $textType,
        target $realType,
        saved $realType,
        category $intType,
        deadline $textType,
        period $intType,
        image TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id $idType,
        username $textType,
        title $textType,
        subtitle $textType,
        amount $realType,
        date $textType,
        category $intType
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name $textType,
        icon_code_point $textType,
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 5. BẢNG THÀNH TÍCH MỚI CẬP NHẬT
    await db.execute('''
      CREATE TABLE achievements (
        id TEXT,
        username TEXT,
        current_progress REAL,
        is_unlocked INTEGER,
        PRIMARY KEY (id, username)
      )
    ''');

    await db.insert('users', {
      'username': 'admin',
      'password': '123',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    final List<Map<String, dynamic>> defaultCategories = [
      {
        'id': 0,
        'name': 'Du lịch',
        'icon_code_point': Icons.flight_takeoff.codePoint.toString(),
        'is_default': 1,
      },
      {
        'id': 1,
        'name': 'Điện tử',
        'icon_code_point': Icons.devices_other.codePoint.toString(),
        'is_default': 1,
      },
      {
        'id': 2,
        'name': 'Dự phòng / Sức khỏe',
        'icon_code_point': Icons.health_and_safety_outlined.codePoint
            .toString(),
        'is_default': 1,
      },
      {
        'id': 3,
        'name': 'Nhà cửa',
        'icon_code_point': Icons.home_outlined.codePoint.toString(),
        'is_default': 1,
      },
    ];

    for (var category in defaultCategories) {
      await db.insert(
        'categories',
        category,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  // --- LOGIC THAO TÁC CẬP NHẬT TIẾN ĐỘ THÀNH TÍCH ĐỘNG ---
  Future<void> updateAchievementProgress(
    String badgeId,
    double progress,
    int isUnlocked,
  ) async {
    final db = await database;
    final currentUsername = await _getCurrentUsername();

    await db.insert(
      'achievements',
      {
        'id': badgeId,
        'username': currentUsername,
        'current_progress': progress,
        'is_unlocked': isUnlocked,
      },
      conflictAlgorithm:
          ConflictAlgorithm.replace, // Nếu trùng thì đè tiến độ mới lên
    );
  }

  Future<List<Map<String, dynamic>>> getSavedAchievements() async {
    final db = await database;
    final currentUsername = await _getCurrentUsername();
    return await db.query(
      'achievements',
      where: 'username = ?',
      whereArgs: [currentUsername],
    );
  }

  // ===============================================
  // CÁC HÀM CRUD KHÁC GIỮ NGUYÊN BẢN GỐC
  // ===============================================
  Future<int> insertGoal(Map<String, dynamic> goal) async {
    final db = await database;
    final currentUsername = await _getCurrentUsername();
    Map<String, dynamic> goalWithUser = Map.from(goal);
    goalWithUser['username'] = currentUsername;
    return await db.insert('goals', goalWithUser);
  }

  Future<int> updateGoalImage(String name, String imagePath) async {
    final db = await database;
    final currentUsername = await _getCurrentUsername();
    return await db.update(
      'goals',
      {'image': imagePath},
      where: 'name = ? AND username = ?',
      whereArgs: [name, currentUsername],
    );
  }

  Future<int> deleteGoal(String name) async {
    final db = await database;
    final currentUsername = await _getCurrentUsername();
    await db.delete(
      'transactions',
      where: 'title = ? AND username = ?',
      whereArgs: [name, currentUsername],
    );
    return await db.delete(
      'goals',
      where: 'name = ? AND username = ?',
      whereArgs: [name, currentUsername],
    );
  }

  Future<List<Map<String, dynamic>>> getGoals() async {
    final db = await database;
    final currentUsername = await _getCurrentUsername();
    return await db.query(
      'goals',
      where: 'username = ?',
      whereArgs: [currentUsername],
    );
  }

  Future<int> updateGoalSavedAmount(String name, double amountToAdd) async {
    final db = await database;
    final currentUsername = await _getCurrentUsername();
    final List<Map<String, dynamic>> maps = await db.query(
      'goals',
      where: 'name = ? AND username = ?',
      whereArgs: [name, currentUsername],
    );
    if (maps.isNotEmpty) {
      double currentSaved = maps.first['saved'] as double;
      return await db.update(
        'goals',
        {'saved': currentSaved + amountToAdd},
        where: 'name = ? AND username = ?',
        whereArgs: [name, currentUsername],
      );
    }
    return 0;
  }

  Future<int> insertCategory(Category category) async {
    final db = await database;
    return await db.insert('categories', category.toMap());
  }

  Future<List<Category>> getCategories() async {
    final db = await database;
    final result = await db.query('categories');
    return result.map((json) => Category.fromMap(json)).toList();
  }

  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await database;
    final currentUsername = await _getCurrentUsername();
    Map<String, dynamic> txMap = transaction.toMap();
    txMap['username'] = currentUsername;
    return await db.insert('transactions', txMap);
  }

  Future<List<TransactionModel>> getTransactions() async {
    final db = await database;
    final currentUsername = await _getCurrentUsername();
    final String query = '''
      SELECT t.*, c.icon_code_point FROM transactions t
      LEFT JOIN categories c ON t.category = c.id
      WHERE t.username = ? ORDER BY t.date DESC
    ''';
    final result = await db.rawQuery(query, [currentUsername]);
    return result
        .map((json) => TransactionModel.fromMapWithCategory(json))
        .toList();
  }

  Future<void> resetUserData() async {
    final db = await database;
    final currentUsername = await _getCurrentUsername();
    await db.delete(
      'transactions',
      where: 'username = ?',
      whereArgs: [currentUsername],
    );
    await db.delete(
      'goals',
      where: 'username = ?',
      whereArgs: [currentUsername],
    );
    await db.delete(
      'achievements',
      where: 'username = ?',
      whereArgs: [currentUsername],
    );
  }
}
