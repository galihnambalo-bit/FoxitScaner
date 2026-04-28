// lib/screens/home_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../models/document_model.dart';
import '../services/ad_service.dart';
import '../services/database_service.dart';
import '../services/scanner_service.dart';
import '../utils/ad_constants.dart';
import '../utils/app_theme.dart';
import 'scan_screen.dart';
import 'document_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseService();
  List<DocumentModel> _documents = [];
  bool _isLoading = true;

  // Native Ad
  NativeAd? _nativeAd;
  bool _nativeAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    _loadNativeAd();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: AdConstants.nativeAdId,
      listener: NativeAdListener(
        onAdLoaded: (_) => setState(() => _nativeAdLoaded = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _nativeAd = null;
        },
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: AppTheme.lightBlue,
        cornerRadius: 12,
        callToActionTextStyle: NativeTemplateTextStyle(
          backgroundColor: AppTheme.primaryBlue,
          textColor: Colors.white,
          style: NativeTemplateFontStyle.normal,
          size: 14,
        ),
      ),
    )..load();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    final docs = await _db.getAllDocuments();
    setState(() {
      _documents = docs;
      _isLoading = false;
    });
  }

  Future<void> _deleteDocument(DocumentModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Dokumen'),
        content: Text('Hapus "${doc.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ScannerService().deleteDocumentFiles(doc);
      await _db.deleteDocument(doc.id);
      await _loadDocuments();
    }
  }

  Future<void> _shareDocument(DocumentModel doc) async {
    final file = XFile(doc.pdfPath);
    await Share.shareXFiles([file], text: doc.name);
  }

  void _openScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (result == true) {
      await _loadDocuments();
      // Tampilkan interstitial setelah scan selesai & PDF tersimpan
      if (mounted) {
        AdService().showInterstitialAd();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.document_scanner, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'Foxit Scanner',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {/* TODO: search */},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {/* TODO: settings */},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDocuments,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScanner,
        icon: const Icon(Icons.camera_alt),
        label: const Text('Scan Dokumen'),
      ),
    );
  }

  Widget _buildBody() {
    if (_documents.isEmpty) {
      return _buildEmptyState();
    }

    // Sisipkan native ad setelah item ke-3
    final List<Widget> items = [];
    for (int i = 0; i < _documents.length; i++) {
      items.add(_buildDocumentCard(_documents[i]));
      // Sisipkan native ad di posisi ke-3 dan setiap 8 item berikutnya
      if ((i == 2 || (i > 2 && (i - 2) % 8 == 0)) && _nativeAdLoaded && _nativeAd != null) {
        items.add(_buildNativeAdCard());
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        _buildStatsHeader(),
        const SizedBox(height: 16),
        ...items,
      ],
    );
  }

  Widget _buildStatsHeader() {
    final totalSize = _documents.fold<int>(0, (sum, doc) => sum + doc.fileSize);
    String formattedSize;
    if (totalSize < 1024 * 1024) {
      formattedSize = '${(totalSize / 1024).toStringAsFixed(1)} KB';
    } else {
      formattedSize = '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryBlue, AppTheme.accentBlue],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('${_documents.length}', 'Dokumen', Icons.folder),
          Container(width: 1, height: 40, color: Colors.white30),
          _buildStatItem(
            _documents.fold<int>(0, (s, d) => s + d.pageCount).toString(),
            'Halaman',
            Icons.pages,
          ),
          Container(width: 1, height: 40, color: Colors.white30),
          _buildStatItem(formattedSize, 'Total', Icons.storage),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildDocumentCard(DocumentModel doc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentDetailScreen(document: doc),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 60,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.lightBlue,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
                ),
                child: doc.thumbnailPath != null && File(doc.thumbnailPath!).existsSync()
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(doc.thumbnailPath!), fit: BoxFit.cover),
                      )
                    : const Icon(Icons.picture_as_pdf, color: AppTheme.primaryBlue, size: 32),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.pages, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('${doc.pageCount} hal',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                        const SizedBox(width: 12),
                        const Icon(Icons.storage, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(doc.formattedSize,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    if (doc.hasOcr)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('OCR',
                            style: TextStyle(
                                color: AppTheme.success,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
              // Actions
              PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'open') {
                    OpenFilex.open(doc.pdfPath);
                  } else if (action == 'share') {
                    _shareDocument(doc);
                  } else if (action == 'delete') {
                    _deleteDocument(doc);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'open',
                      child: Row(children: [
                        Icon(Icons.open_in_new, size: 18),
                        SizedBox(width: 8),
                        Text('Buka'),
                      ])),
                  const PopupMenuItem(
                      value: 'share',
                      child: Row(children: [
                        Icon(Icons.share, size: 18),
                        SizedBox(width: 8),
                        Text('Bagikan'),
                      ])),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Hapus', style: TextStyle(color: Colors.red)),
                      ])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNativeAdCard() {
    return Container(
      height: 80,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: AdWidget(ad: _nativeAd!),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.lightBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.document_scanner,
                size: 60, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 24),
          const Text('Belum Ada Dokumen',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Tekan tombol Scan untuk mulai\nmemindai dokumen pertama Anda',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _openScanner,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Mulai Scan'),
          ),
        ],
      ),
    );
  }
}
