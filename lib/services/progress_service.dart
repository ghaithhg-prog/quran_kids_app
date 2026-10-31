import 'package:shared_preferences/shared_preferences.dart';

class ProgressService {
  static const String _starsPrefix = 'stars_';
  static const String _roundPrefix = 'round_';
  static const String _lastSurahKey = 'last_memorized_surah';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static int getStars(int surahNumber) {
    return _prefs?.getInt('$_starsPrefix$surahNumber') ?? 0;
  }

  static int getSavedRound(int surahNumber) {
    return _prefs?.getInt('$_roundPrefix$surahNumber') ?? 1;
  }

  static Future<void> saveProgress(int surahNumber, {required int stars, required int round}) async {
    await init();
    final currentStars = getStars(surahNumber);
    if (stars > currentStars) {
      await _prefs?.setInt('$_starsPrefix$surahNumber', stars);
    }
    await _prefs?.setInt('$_roundPrefix$surahNumber', round);
    await _prefs?.setInt(_lastSurahKey, surahNumber);
  }

  static int getLastSurahNumber() {
    return _prefs?.getInt(_lastSurahKey) ?? 1;
  }

  static int getCompletedSurahsCount() {
    if (_prefs == null) return 0;
    int count = 0;
    for (int i = 1; i <= 114; i++) {
      if (getStars(i) >= 3) {
        count++;
      }
    }
    return count;
  }

  static int getTotalStars() {
    if (_prefs == null) return 0;
    int total = 0;
    for (int i = 1; i <= 114; i++) {
      total += getStars(i);
    }
    return total;
  }
}
