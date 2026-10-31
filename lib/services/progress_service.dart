import 'package:shared_preferences/shared_preferences.dart';

class ProgressService {
  static const String _starsPrefix = 'stars_';
  static const String _roundPrefix = 'round_';
  static const String _scorePrefix = 'score_';
  static const String _prizePrefix = 'prize_';
  static const String _directPrefix = 'direct_';
  static const String _correctedPrefix = 'corrected_';
  static const String _lastSurahKey = 'last_memorized_surah';
  static const String _guideSeenKey = 'has_seen_guide_v1';

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

  // --- Test Scores & Statistics ---

  static bool hasTested(int surahNumber) {
    return _prefs?.containsKey('$_scorePrefix$surahNumber') ?? false;
  }

  static int getScore(int surahNumber) {
    return _prefs?.getInt('$_scorePrefix$surahNumber') ?? 0;
  }

  static int getDirectCorrect(int surahNumber) {
    return _prefs?.getInt('$_directPrefix$surahNumber') ?? 0;
  }

  static int getCorrectedCount(int surahNumber) {
    return _prefs?.getInt('$_correctedPrefix$surahNumber') ?? 0;
  }

  static bool hasPrize(int surahNumber) {
    return (_prefs?.getBool('$_prizePrefix$surahNumber') ?? false) || getScore(surahNumber) == 100;
  }

  static Future<void> saveTestResult(
    int surahNumber, {
    required int score,
    required int directCount,
    required int correctedCount,
  }) async {
    await init();
    final previousScore = getScore(surahNumber);
    if (score >= previousScore) {
      await _prefs?.setInt('$_scorePrefix$surahNumber', score);
      await _prefs?.setInt('$_directPrefix$surahNumber', directCount);
      await _prefs?.setInt('$_correctedPrefix$surahNumber', correctedCount);
    }

    if (score == 100) {
      await _prefs?.setBool('$_prizePrefix$surahNumber', true);
      await saveProgress(surahNumber, stars: 3, round: 7);
    } else if (score >= 90) {
      await saveProgress(surahNumber, stars: 2, round: 7);
    } else if (score >= 60) {
      await saveProgress(surahNumber, stars: 1, round: 7);
    }
  }

  static int getLastSurahNumber() {
    return _prefs?.getInt(_lastSurahKey) ?? 1;
  }

  /// Number of surahs passed with success threshold (score >= 90%)
  static int getPassedSurahsCount() {
    if (_prefs == null) return 0;
    int count = 0;
    for (int i = 1; i <= 114; i++) {
      if (getScore(i) >= 90) {
        count++;
      }
    }
    return count;
  }

  /// Number of surahs mastered with 100% and golden prize
  static int getPrizeCount() {
    if (_prefs == null) return 0;
    int count = 0;
    for (int i = 1; i <= 114; i++) {
      if (hasPrize(i)) {
        count++;
      }
    }
    return count;
  }

  /// Check if child memorized the entire Quran with 100% in all 114 surahs
  static bool isCompleteQuranHafiz() {
    if (_prefs == null) return false;
    for (int i = 1; i <= 114; i++) {
      if (!hasPrize(i)) {
        return false;
      }
    }
    return true;
  }

  static int getCompletedSurahsCount() {
    if (_prefs == null) return 0;
    int count = 0;
    for (int i = 1; i <= 114; i++) {
      if (getStars(i) >= 2 || getScore(i) >= 90) {
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

  // --- Explanatory Guide Flag ---

  static bool hasSeenGuide() {
    return _prefs?.getBool(_guideSeenKey) ?? false;
  }

  static Future<void> markGuideSeen() async {
    await init();
    await _prefs?.setBool(_guideSeenKey, true);
  }
}
