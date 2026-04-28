// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/ad_service.dart';
import 'utils/app_theme.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientasi portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Inisialisasi AdMob dan preload semua iklan
  await AdService().initialize();

  runApp(const DocScannerApp());
}

class DocScannerApp extends StatefulWidget {
  const DocScannerApp({super.key});

  @override
  State<DocScannerApp> createState() => _DocScannerAppState();
}

class _DocScannerAppState extends State<DocScannerApp>
    with WidgetsBindingObserver {
  bool _appFirstOpen = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AdService().dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Tampilkan App Open Ad saat app kembali ke foreground
    if (state == AppLifecycleState.resumed) {
      if (!_appFirstOpen) {
        AdService().showAppOpenAd();
      } else {
        _appFirstOpen = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foxit Scanner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
