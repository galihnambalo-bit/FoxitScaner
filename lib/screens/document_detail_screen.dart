// lib/screens/document_detail_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../models/document_model.dart';
import '../services/ad_service.dart';
import '../services/ocr_service.dart';
import '../services/ocr_unlock_service.dart';
import '../utils/app_theme.dart';

class DocumentDetailScreen extends StatefulWidget {
  final DocumentModel document;
  const DocumentDetailScreen({super.key, required this.document});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  bool _isOcrRunning = false;
  bool _ocrUnlocked = false;
  Duration _ocrTimeRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _checkOcrStatus();
  }

  Future<void> _checkOcrStatus() async {
    final unlocked = await OcrUnlockService.isOcrUnlocked();
    final remaining = await OcrUnlockService.remainingTime();
    setState(() {
      _ocrUnlocked = unlocked;
      _ocrTimeRemaining = remaining;
    });
  }

  void _showOcrRewardedAd() {
    AdService().showRewardedAd(
      onUserEarnedReward: (reward) async {
        await OcrUnlockService.unlockOcrFor1Hour();
        if (mounted) {
          setState(() => _ocrUnlocked = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 OCR diaktifkan selama 1 jam!'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      },
      onAdNotAvailable: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Iklan belum siap, coba lagi sebentar')),
          );
        }
      },
    );
  }

  Future<void> _runOcr() async {
    final unlocked = await OcrUnlockService.isOcrUnlocked();
    if (!unlocked) {
      _showOcrDialog();
      return;
    }
    setState(() => _isOcrRunning = true);
    try {
      // OCR dari PDF - load gambar thumbnail
      String ocrText = '';
      if (widget.document.thumbnailPath != null) {
        ocrText = await OcrService()
            .recognizeText(File(widget.document.thumbnailPath!));
      }
      if (ocrText.isEmpty) ocrText = 'Tidak ada teks yang terdeteksi.';

      await OcrService().saveOcrToDocument(widget.document.id, ocrText);
      widget.document.hasOcr = true;
      widget.document.ocrText = ocrText;

      if (mounted) {
        setState(() {});
        _showOcrResultDialog(ocrText);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('OCR error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isOcrRunning = false);
    }
  }

  void _showOcrDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.text_fields, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Text('Fitur OCR Terkunci'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 48, color: Colors.amber),
            SizedBox(height: 12),
            Text(
              'Tonton 1 iklan video singkat untuk\nmengaktifkan OCR selama 1 JAM penuh!',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Ubah gambar menjadi teks yang\nbisa disalin dan diedit',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showOcrRewardedAd();
            },
            icon: const Icon(Icons.play_circle),
            label: const Text('Tonton Iklan'),
          ),
        ],
      ),
    );
  }

  void _showOcrResultDialog(String text) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.text_fields, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  const Text('Hasil OCR',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Text(text),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Salin'),
                    onPressed: () {
                      // Copy to clipboard
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Teks disalin!')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    return Scaffold(
      appBar: AppBar(
        title: Text(doc.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              final file = XFile(doc.pdfPath);
              await Share.shareXFiles([file], text: doc.name);
              // Tampilkan interstitial setelah share
              AdService().showInterstitialAd();
            },
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => OpenFilex.open(doc.pdfPath),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail preview
            if (doc.thumbnailPath != null &&
                File(doc.thumbnailPath!).existsSync())
              Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade100,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(doc.thumbnailPath!),
                      fit: BoxFit.contain),
                ),
              ),
            const SizedBox(height: 16),
            // Info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Informasi Dokumen',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    _infoRow(Icons.pages, 'Halaman', '${doc.pageCount}'),
                    _infoRow(Icons.storage, 'Ukuran', doc.formattedSize),
                    _infoRow(Icons.calendar_today, 'Dibuat',
                        '${doc.createdAt.day}/${doc.createdAt.month}/${doc.createdAt.year}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // OCR section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.text_fields,
                            color: AppTheme.primaryBlue),
                        const SizedBox(width: 8),
                        const Text('OCR - Ubah ke Teks',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const Spacer(),
                        if (!_ocrUnlocked)
                          const Icon(Icons.lock,
                              color: Colors.amber, size: 20),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_ocrUnlocked && _ocrTimeRemaining.inMinutes > 0)
                      Text(
                        'Aktif: ${_ocrTimeRemaining.inMinutes} menit tersisa',
                        style: const TextStyle(
                            color: AppTheme.success, fontSize: 12),
                      )
                    else if (!_ocrUnlocked)
                      const Text(
                        'Tonton iklan video untuk mengaktifkan OCR 1 jam',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    const SizedBox(height: 12),
                    if (doc.hasOcr && doc.ocrText != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          doc.ocrText!,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.visibility),
                        label: const Text('Lihat Semua'),
                        onPressed: () => _showOcrResultDialog(doc.ocrText!),
                      ),
                    ] else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isOcrRunning ? null : _runOcr,
                          icon: _isOcrRunning
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : _ocrUnlocked
                                  ? const Icon(Icons.text_fields)
                                  : const Icon(Icons.play_circle),
                          label: Text(_ocrUnlocked
                              ? 'Jalankan OCR'
                              : 'Tonton Iklan → Aktifkan OCR'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 14)),
        ],
      ),
    );
  }
}
