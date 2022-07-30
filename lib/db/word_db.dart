import 'dart:async';

import 'package:follow/models/word_model.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class WordDatabase {
  static var database;

  static Future<void> openDb() async {
    database = openDatabase(
      join(await getDatabasesPath(), 'word.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE words(word TEXT PRIMARY KEY)',
        );
      },
      version: 1,
    );
  }

  static Future<void> insertWord(Word word) async {
    final db = await database;

    await db.insert(
      'words',
      word.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Word>> words() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query('words');

    return List.generate(maps.length, (i) {
      return Word(
        word: maps[i]['word'],
      );
    });
  }

  static Future<bool> haveWord(String word) async {
    final db = await database;

    final result = await db
        .rawQuery('SELECT COUNT(word) FROM words WHERE word = \'$word\'');
    return Sqflite.firstIntValue(result) != 0 ? true : false;
  }

  static Future<void> updateWord(Word word) async {
    final db = await database;

    await db.update(
      'words',
      word.toMap(),
      where: 'word = ?',
      whereArgs: [word.word],
    );
  }

  static Future<void> deleteWord(String word) async {
    final db = await database;

    await db.delete(
      'words',
      where: 'word = ?',
      whereArgs: [word],
    );
  }

  static Future<void> close() async {
    final db = await database;

    await db.close();
  }
}
