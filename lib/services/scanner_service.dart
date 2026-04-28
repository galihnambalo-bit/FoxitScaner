// lib/services/scanner_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';
import '../models/document_model.dart';
import 'database_service.dart';

enum ImageFilter { original, bw, magic, grayscale }

class ScannerService {
  static final ScannerService _instance = ScannerService._internal();
  factory ScannerService() => _instance;
  ScannerService._internal();

  final _db = DatabaseService();
  final _uuid = const Uuid();

  // ============================================================
  // IMAGE PROCESSING
  // ============================================================

  Future<File> applyFilter(File imageFile, ImageFilter filter) async {
    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return imageFile;

    img.Image processed;
    switch (filter) {
      case ImageFilter.bw:
        // Hitam putih dengan threshold
        final gray = img.grayscale(image);
        processed = _applyThreshold(gray, 128);
        break;
      case ImageFilter.magic:
        // Magic filter - kontras tinggi
        final gray = img.grayscale(image);
        processed = img.adjustColor(gray, contrast: 1.5, brightness: 1.1);
        break;
      case ImageFilter.grayscale:
        processed = img.grayscale(image);
        break;
      case ImageFilter.original:
      default:
        processed = image;
    }

    final dir = await getTemporaryDirectory();
    final outPath = '${dir.path}/filtered_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outFile = File(outPath);
    await outFile.writeAsBytes(img.encodeJpg(processed, quality: 90));
    return outFile;
  }

  img.Image _applyThreshold(img.Image image, int threshold) {
    final result = img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final val = r > threshold ? 255 : 0;
        result.setPixelRgb(x, y, val, val, val);
      }
    }
    return result;
  }

  // ============================================================
  // PDF CREATION
  // ============================================================

  Future<DocumentModel> createPdfFromImages({
    required List<File> imageFiles,
    required String docName,
    ImageFilter filter = ImageFilter.magic,
  }) async {
    final pdf = pw.Document();
    final processedImages = <Uint8List>[];

    // Process semua gambar
    for (final imageFile in imageFiles) {
      final filtered = await applyFilter(imageFile, filter);
      final bytes = await filtered.readAsBytes();
      processedImages.add(bytes);
    }

    // Tambahkan ke PDF
    for (final imageBytes in processedImages) {
      final pdfImage = pw.MemoryImage(imageBytes);
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          build: (context) => pw.Center(
            child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

    // Simpan PDF
    final dir = await getExternalStorageDirectory();
    final pdfDir = Directory('${dir.path}/pdfs');
    if (!await pdfDir.exists()) await pdfDir.create(recursive: true);

    final id = _uuid.v4();
    final pdfPath = '${pdfDir.path}/$id.pdf';
    final pdfFile = File(pdfPath);
    await pdfFile.writeAsBytes(await pdf.save());

    // Simpan thumbnail (gambar pertama)
    String? thumbPath;
    if (processedImages.isNotEmpty) {
      final thumbDir = Directory('${dir.path}/thumbnails');
      if (!await thumbDir.exists()) await thumbDir.create(recursive: true);
      thumbPath = '${thumbDir.path}/$id.jpg';
      await File(thumbPath).writeAsBytes(processedImages[0]);
    }

    final fileSize = await pdfFile.length();
    final now = DateTime.now();

    final doc = DocumentModel(
      id: id,
      name: docName,
      pdfPath: pdfPath,
      thumbnailPath: thumbPath,
      pageCount: imageFiles.length,
      createdAt: now,
      updatedAt: now,
      fileSize: fileSize,
    );

    await _db.insertDocument(doc);
    return doc;
  }

  // ============================================================
  // OCR
  // ============================================================
  Future<String> extractTextFromImage(File imageFile) async {
    // Google ML Kit text recognition
    // Import di screen yang menggunakannya untuk lazy loading
    try {
      // Diimplementasikan di ocr_service.dart terpisah
      return '';
    } catch (e) {
      debugPrint('OCR error: $e');
      return '';
    }
  }

  // ============================================================
  // FILE MANAGEMENT
  // ============================================================
  Future<void> deleteDocumentFiles(DocumentModel doc) async {
    try {
      final pdfFile = File(doc.pdfPath);
      if (await pdfFile.exists()) await pdfFile.delete();
      
      if (doc.thumbnailPath != null) {
        final thumbFile = File(doc.thumbnailPath!);
        if (await thumbFile.exists()) await thumbFile.delete();
      }
    } catch (e) {
      debugPrint('Delete file error: $e');
    }
  }
}
