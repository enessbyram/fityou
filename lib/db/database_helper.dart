// lib/db/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('fityou.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_info (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        height REAL,
        weight REAL,
        birth_date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE goal (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        target_weight REAL,
        days INTEGER,
        start_date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE steps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        step_count INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE water (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        amount_ml INTEGER
      )
    ''');
  }

  // ---------- USER ----------
  Future<int> insertUser(Map<String, dynamic> data) async {
    final db = await instance.database;
    return await db.insert('user_info', data);
  }

  Future<Map<String, dynamic>?> getUser() async {
    final db = await instance.database;
    final res = await db.query('user_info', limit: 1);
    if (res.isNotEmpty) return res.first;
    return null;
  }

  Future<int> updateUser(Map<String, dynamic> data) async {
    final db = await instance.database;
    final existing = await db.query('user_info', limit: 1);
    if (existing.isNotEmpty) {
      return await db.update('user_info', data, where: 'id = ?', whereArgs: [existing.first['id']]);
    } else {
      return await insertUser(data);
    }
  }

  // ---------- GOAL ----------
  Future<int> insertGoal(Map<String, dynamic> data) async {
    final db = await instance.database;
    await db.delete('goal'); // tek hedef mantığı
    return await db.insert('goal', data);
  }

  Future<Map<String, dynamic>?> getGoal() async {
    final db = await instance.database;
    final res = await db.query('goal', limit: 1);
    if (res.isNotEmpty) return res.first;
    return null;
  }

  Future<int> deleteGoal() async {
    final db = await instance.database;
    return await db.delete('goal');
  }

  // ---------- STEPS ----------
  Future<int> insertOrUpdateSteps(String date, int stepCount) async {
    final db = await instance.database;
    final res = await db.query('steps', where: 'date = ?', whereArgs: [date]);
    if (res.isNotEmpty) {
      return await db.update('steps', {'step_count': stepCount}, where: 'date = ?', whereArgs: [date]);
    } else {
      return await db.insert('steps', {'date': date, 'step_count': stepCount});
    }
  }

  Future<int> getStepsByDate(String date) async {
    final db = await instance.database;
    final res = await db.query('steps', where: 'date = ?', whereArgs: [date], limit: 1);
    if (res.isNotEmpty) return res.first['step_count'] as int;
    return 0;
  }

  // ---------- WATER ----------
  Future<int> insertWater(String date, int amountMl) async {
    final db = await instance.database;
    return await db.insert('water', {'date': date, 'amount_ml': amountMl});
  }

  Future<int> getWaterByDate(String date) async {
    final db = await instance.database;
    final res = await db.rawQuery('SELECT SUM(amount_ml) as total FROM water WHERE date = ?', [date]);
    if (res.isNotEmpty && res.first['total'] != null) {
      final total = res.first['total'];
      if (total is int) return total;
      if (total is double) return total.toInt();
    }
    return 0;
  }
}
