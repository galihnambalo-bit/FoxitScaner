// lib/services/ocr_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'database_service.dart';

class OcrService {
  static final OcrService _instance = OcrService._internal();
  factory OcrService() => _instance;
  OcrService._internal();

  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _db = DatabaseService();

  // OCR dipanggil hanya ketika user sudah nonton rewarded ad
  Future<String> recognizeText(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      debugPrint('OCR recognition error: $e');
      return '';
    }
  }

  // OCR untuk seluruh PDF (berdasarkan gambar-gambar yang sudah diproses)
  Future<String> recognizeTextFromImages(List<File> imageFiles) async {
    final buffer = StringBuffer();
    for (int i = 0; i < imageFiles.length; i++) {
      final text = await recognizeText(imageFiles[i]);
      if (text.isNotEmpty) {
        buffer.writeln('--- Halaman ${i + 1} ---');
        buffer.writeln(text);
        buffer.writeln();
      }
    }
    return buffer.toString();
  }

  Future<void> saveOcrToDocument(String docId, String ocrText) async {
    await _db.updateOcrText(docId, ocrText);
  }

  void dispose() {
    _textRecognizer.close();
  }
}
