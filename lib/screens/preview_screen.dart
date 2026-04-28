import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
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
  bool _isProcessingPreview = false;
  int _currentPage = 0;
  final _pageController = PageController();

  // Cache preview hasil filter per halaman per filter
  final Map<String, Uint8List?> _previewCache = {};

  final _filters = [
    (ImageFilter.original, 'Original', Icons.image),
    (ImageFilter.magic, 'Magic', Icons.auto_fix_high),
    (ImageFilter.bw, 'H&P', Icons.contrast),
    (ImageFilter.grayscale, 'Abu-abu', Icons.invert_colors),
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text =
        'Dokumen_${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}';
    // Preload preview halaman pertama semua filter
    _preloadCurrentPage();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String _cacheKey(int pageIndex, ImageFilter filter) =>
      '${pageIndex}_${filter.name}';

  Future<void> _preloadCurrentPage() async {
    for (final (filter, _, _) in _filters) {
      await _getFilteredPreview(_currentPage, filter);
    }
  }

  Future<Uint8List?> _getFilteredPreview(int pageIndex, ImageFilter filter) async {
    final key = _cacheKey(pageIndex, filter);
    if (_previewCache.containsKey(key)) return _previewCache[key];

    try {
      final bytes = await widget.imageFiles[pageIndex].readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;

      // Resize untuk preview agar cepat
      final resized = img.copyResize(image, width: 800);

      img.Image processed;
      switch (filter) {
        case ImageFilter.bw:
          final gray = img.grayscale(resized);
          processed = _applyThreshold(gray, 128);
          break;
        case ImageFilter.magic:
          final gray = img.grayscale(resized);
          processed = img.adjustColor(gray, contrast: 1.5, brightness: 1.1);
          break;
        case ImageFilter.grayscale:
          processed = img.grayscale(resized);
          break;
        case ImageFilter.original:
        default:
          processed = resized;
      }

      final result = Uint8List.fromList(img.encodeJpg(processed, quality: 85));
      _previewCache[key] = result;
      return result;
    } catch (e) {
      debugPrint('Preview error: $e');
      return null;
    }
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

  Future<void> _onFilterChanged(ImageFilter filter) async {
    setState(() {
      _selectedFilter = filter;
      _isProcessingPreview = true;
    });
    await _getFilteredPreview(_currentPage, filter);
    if (mounted) setState(() => _isProcessingPreview = false);
  }

  Future<void> _onPageChanged(int index) async {
    setState(() {
      _currentPage = index;
      _isProcessingPreview = true;
    });
    await _preloadCurrentPage();
    if (mounted) setState(() => _isProcessingPreview = false);
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
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Simpan PDF',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Image Preview dengan filter realtime
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: widget.imageFiles.length,
              itemBuilder: (_, i) {
                return Center(
                  child: InteractiveViewer(
                    child: FutureBuilder<Uint8List?>(
                      future: _getFilteredPreview(i, _selectedFilter),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.file(widget.imageFiles[i]),
                              Container(
                                color: Colors.black45,
                                child: const CircularProgressIndicator(
                                    color: Colors.white),
                              ),
                            ],
                          );
                        }
                        if (snapshot.hasData && snapshot.data != null) {
                          return Image.memory(snapshot.data!);
                        }
                        return Image.file(widget.imageFiles[i]);
                      },
                    ),
                  ),
                );
              },
            ),
          ),

          // Processing indicator
          if (_isProcessingPreview)
            const LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              color: AppTheme.accentBlue,
            ),

          // Page indicator
          if (widget.imageFiles.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_currentPage + 1} / ${widget.imageFiles.length}',
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),

          // Filter selector
          Container(
            height: 76,
            color: Colors.black,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              itemCount: _filters.length,
              itemBuilder: (_, i) {
                final (filter, label, icon) = _filters[i];
                final selected = _selectedFilter == filter;
                return GestureDetector(
                  onTap: () => _onFilterChanged(filter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
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
                        Icon(icon, color: Colors.white, size: 18),
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

          // Nama dokumen + tombol simpan
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
                          width: 16, height: 16,
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
