// lib/models/document_model.dart
class DocumentModel {
  final String id;
  String name;
  String pdfPath;
  String? thumbnailPath;
  int pageCount;
  final DateTime createdAt;
  DateTime updatedAt;
  int fileSize;
  bool hasOcr;
  String? ocrText;

  DocumentModel({
    required this.id,
    required this.name,
    required this.pdfPath,
    this.thumbnailPath,
    this.pageCount = 1,
    required this.createdAt,
    required this.updatedAt,
    this.fileSize = 0,
    this.hasOcr = false,
    this.ocrText,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'pdfPath': pdfPath,
      'thumbnailPath': thumbnailPath,
      'pageCount': pageCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'fileSize': fileSize,
      'hasOcr': hasOcr ? 1 : 0,
      'ocrText': ocrText,
    };
  }

  factory DocumentModel.fromMap(Map<String, dynamic> map) {
    return DocumentModel(
      id: map['id'] as String,
      name: map['name'] as String,
      pdfPath: map['pdfPath'] as String,
      thumbnailPath: map['thumbnailPath'] as String?,
      pageCount: map['pageCount'] as int? ?? 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      fileSize: map['fileSize'] as int? ?? 0,
      hasOcr: (map['hasOcr'] as int? ?? 0) == 1,
      ocrText: map['ocrText'] as String?,
    );
  }

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
