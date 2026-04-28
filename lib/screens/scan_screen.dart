import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/scanner_service.dart';
import '../utils/app_theme.dart';
import 'preview_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final List<File> _scannedImages = [];
  bool _isScanning = false;
  final _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_scannedImages.isEmpty ? 'Scan Dokumen' : '${_scannedImages.length} Halaman',
            style: const TextStyle(color: Colors.white)),
        actions: [
          if (_scannedImages.isNotEmpty)
            TextButton(
              onPressed: _goToPreview,
              child: const Text('Selanjutnya', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _scannedImages.isEmpty ? _buildEmptyScanArea() : _buildScannedPreview(),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyScanArea() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200, height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.accentBlue, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt, color: Colors.white54, size: 64),
                SizedBox(height: 16),
                Text('Tekan tombol kamera\nuntuk scan dokumen',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannedPreview() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, childAspectRatio: 0.75,
        crossAxisSpacing: 4, mainAxisSpacing: 4,
      ),
      itemCount: _scannedImages.length,
      itemBuilder: (context, index) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(_scannedImages[index], fit: BoxFit.cover),
            ),
            Positioned(top: 4, left: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
            Positioned(top: 4, right: 4,
              child: GestureDetector(
                onTap: () => setState(() => _scannedImages.removeAt(index)),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(icon: Icons.photo_library, label: 'Galeri', onTap: _pickFromGallery),
          GestureDetector(
            onTap: _isScanning ? null : _takePhoto,
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isScanning ? Colors.grey : AppTheme.primaryBlue,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: _isScanning
                  ? const Padding(padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.camera_alt, color: Colors.white, size: 32),
            ),
          ),
          _buildActionButton(
            icon: Icons.arrow_forward,
            label: _scannedImages.isEmpty ? 'Preview' : '${_scannedImages.length} hal',
            onTap: _scannedImages.isEmpty ? null : _goToPreview,
            enabled: _scannedImages.isNotEmpty,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, VoidCallback? onTap, bool enabled = true}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(shape: BoxShape.circle, color: enabled ? Colors.white12 : Colors.white10),
            child: Icon(icon, color: enabled ? Colors.white : Colors.white38, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: enabled ? Colors.white : Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _takePhoto() async {
    await Permission.camera.request();
    if (!await Permission.camera.isGranted) return;
    setState(() => _isScanning = true);
    try {
      final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
      if (photo != null) setState(() => _scannedImages.add(File(photo.path)));
    } catch (e) {
      debugPrint('Camera error: $e');
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final images = await _picker.pickMultiImage(imageQuality: 90);
      if (images.isNotEmpty) setState(() => _scannedImages.addAll(images.map((x) => File(x.path))));
    } catch (e) {
      debugPrint('Gallery error: $e');
    }
  }

  void _goToPreview() {
    if (_scannedImages.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PreviewScreen(imageFiles: List.from(_scannedImages)),
    )).then((saved) {
      if (saved == true && mounted) Navigator.pop(context, true);
    });
  }
}
