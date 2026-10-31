import '../models/surah.dart';

class QuranPhonetics {
  // Map of Muqatta'at (الحروف المقطعة) to their exact spoken recitation tokens
  static final Map<String, List<String>> spokenEquivalents = {
    'الم': ['الف', 'لام', 'ميم'],
    'المص': ['الف', 'لام', 'ميم', 'صاد'],
    'الر': ['الف', 'لام', 'را'],
    'المر': ['الف', 'لام', 'ميم', 'را'],
    'كهيعص': ['كاف', 'ها', 'يا', 'عين', 'صاد'],
    'طه': ['طا', 'ها'],
    'طسم': ['طا', 'سين', 'ميم'],
    'طس': ['طا', 'سين'],
    'يس': ['يا', 'سين'],
    'ص': ['صاد'],
    'حم': ['حا', 'ميم'],
    'عسق': ['عين', 'سين', 'قاف'],
    'ق': ['قاف'],
    'ن': ['نون'],
  };

  // Uthmanic script spelling variations to normal spoken Arabic
  static final Map<String, String> uthmanicToSpoken = {
    'الصلوة': 'الصلاة',
    'صلوة': 'صلاة',
    'الزكوة': 'الزكاة',
    'زكوة': 'زكاة',
    'الحيوة': 'الحياة',
    'حيوة': 'حياة',
    'الربوا': 'الربا',
    'ربوا': 'ربا',
    'مشكوة': 'مشكاة',
    'ابرهيم': 'ابراهيم',
    'اسمعيل': 'اسماعيل',
    'اسحق': 'اسحاق',
    'هرون': 'هارون',
    'سلم': 'سلام',
  };

  /// Checks if target word matches spoken tokens starting at tokenIndex.
  /// Returns the number of tokens consumed (> 0 means match, 0 means no match).
  static int matchWord(String targetWord, List<String> spokenTokens, int tokenIndex) {
    if (tokenIndex >= spokenTokens.length) return 0;

    final normTarget = Ayah.normalizeArabic(targetWord);
    final spokenToken = spokenTokens[tokenIndex];

    // 1. Direct text match
    if (normTarget == spokenToken) return 1;

    // 2. Muqatta'at (الحروف المقطعة) phonetic comparison
    if (spokenEquivalents.containsKey(normTarget)) {
      final expected = spokenEquivalents[normTarget]!;
      // Check if sequential tokens match (e.g. "الف" then "لام" then "ميم")
      bool fullMatch = true;
      for (int i = 0; i < expected.length; i++) {
        if (tokenIndex + i >= spokenTokens.length || spokenTokens[tokenIndex + i] != expected[i]) {
          fullMatch = false;
          break;
        }
      }
      if (fullMatch) {
        return expected.length; // Consumed all 3 tokens!
      }

      // Check if recognized as one joined phrase "الفلاميم"
      final joined = expected.join('');
      if (spokenToken == joined || spokenToken == expected.join(' ')) {
        return 1;
      }
    }

    // 3. Uthmanic script normalizations (e.g. الصلوة -> الصلاة)
    if (uthmanicToSpoken.containsKey(normTarget)) {
      final spoken = Ayah.normalizeArabic(uthmanicToSpoken[normTarget]!);
      if (spokenToken == spoken) return 1;
    }

    // 4. Minor grammatical ending / prefix match
    if (spokenToken.length >= 3 && normTarget.length >= 3) {
      if (spokenToken == normTarget || spokenToken.startsWith(normTarget) || normTarget.startsWith(spokenToken)) {
        return 1;
      }
    }

    return 0;
  }

  /// Checks if spokenToken is a valid prefix of targetWord (user is currently articulating the word)
  static bool isPrefixOfWord(String targetWord, String spokenToken) {
    if (spokenToken.isEmpty) return true;
    final normTarget = Ayah.normalizeArabic(targetWord);
    final normSpoken = Ayah.normalizeArabic(spokenToken);
    if (normSpoken.isEmpty) return true;
    return normTarget.startsWith(normSpoken);
  }
}
