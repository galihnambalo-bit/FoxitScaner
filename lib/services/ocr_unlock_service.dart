// lib/services/ocr_unlock_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class OcrUnlockService {
  static const String _keyUnlockedUntil = 'ocr_unlocked_until';

  // Cek apakah OCR sedang terbuka (dalam 1 jam setelah nonton rewarded ad)
  static Future<bool> isOcrUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    final unlockedUntilMs = prefs.getInt(_keyUnlockedUntil) ?? 0;
    return DateTime.now().millisecondsSinceEpoch < unlockedUntilMs;
  }

  // Buka OCR selama 1 jam
  static Future<void> unlockOcrFor1Hour() async {
    final prefs = await SharedPreferences.getInstance();
    final until = DateTime.now().add(const Duration(hours: 1));
    await prefs.setInt(_keyUnlockedUntil, until.millisecondsSinceEpoch);
  }

  // Sisa waktu OCR terbuka
  static Future<Duration> remainingTime() async {
    final prefs = await SharedPreferences.getInstance();
    final unlockedUntilMs = prefs.getInt(_keyUnlockedUntil) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (unlockedUntilMs <= now) return Duration.zero;
    return Duration(milliseconds: unlockedUntilMs - now);
  }
}
