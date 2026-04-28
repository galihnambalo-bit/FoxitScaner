// lib/services/database_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/document_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'docscanner.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE documents (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            pdfPath TEXT NOT NULL,
            thumbnailPath TEXT,
            pageCount INTEGER DEFAULT 1,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            fileSize INTEGER DEFAULT 0,
            hasOcr INTEGER DEFAULT 0,
            ocrText TEXT
          )
        ''');
      },
    );
  }

  Future<void> insertDocument(DocumentModel doc) async {
    final db = await database;
    await db.insert(
      'documents',
      doc.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DocumentModel>> getAllDocuments() async {
    final db = await database;
    final maps = await db.query(
      'documents',
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => DocumentModel.fromMap(map)).toList();
  }

  Future<void> updateDocument(DocumentModel doc) async {
    final db = await database;
    await db.update(
      'documents',
      doc.toMap(),
      where: 'id = ?',
      whereArgs: [doc.id],
    );
  }

  Future<void> deleteDocument(String id) async {
    final db = await database;
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateOcrText(String id, String ocrText) async {
    final db = await database;
    await db.update(
      'documents',
      {'hasOcr': 1, 'ocrText': ocrText},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
