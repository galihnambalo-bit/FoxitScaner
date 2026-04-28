// lib/screens/preview_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/document_model.dart';
import '../services/scanner_service.dart';
import '../utils/app_theme.dart';

class PreviewScreen extends StatefulWidget {
  final List<File> imageFiles;
  const PreviewScreen({super.key, required this.imageFiles});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  ImageFilter _selectedFilter = ImageFilter.magic;
  final _nameController = TextEditingController();
  bool _isSaving = false;
  int _currentPage = 0;
  final _pageController = PageController();

  final _filters = [
    (ImageFilter.original, 'Original', Icons.image),
    (ImageFilter.magic, 'Magic', Icons.auto_fix_high),
    (ImageFilter.bw, 'H&P', Icons.contrast),
    (ImageFilter.grayscale, 'Abu', Icons.invert_colors),
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text =
        'Dokumen_${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _savePdf() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nama dokumen')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ScannerService().createPdfFromImages(
        imageFiles: widget.imageFiles,
        docName: name,
        filter: _selectedFilter,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF berhasil disimpan!'),
            backgroundColor: AppTheme.success,
          ),
        );
        // Kembali ke home dengan signal sukses (home akan tampilkan interstitial)
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal simpan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Preview & Simpan',
            style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _savePdf,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Simpan PDF',
                    style:
                        TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Image Preview
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemCount: widget.imageFiles.length,
              itemBuilder: (_, i) => Center(
                child: InteractiveViewer(
                  child: Image.file(widget.imageFiles[i]),
                ),
              ),
            ),
          ),
          // Page indicator
          if (widget.imageFiles.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '${_currentPage + 1} / ${widget.imageFiles.length}',
                style: const TextStyle(color: Colors.white60),
              ),
            ),
          // Filter selector
          Container(
            height: 80,
            color: Colors.black,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filters.length,
              itemBuilder: (_, i) {
                final (filter, label, icon) = _filters[i];
                final selected = _selectedFilter == filter;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = filter),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.primaryBlue
                          : Colors.white12,
                      borderRadius: BorderRadius.circular(20),
                      border: selected
                          ? Border.all(color: Colors.white, width: 1.5)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon,
                            color: Colors.white,
                            size: 18),
                        const SizedBox(width: 6),
                        Text(label,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Name input & save button
          Container(
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Nama dokumen',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.edit, color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _savePdf,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: const Text('Simpan'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
