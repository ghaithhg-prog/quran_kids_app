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

  /// Normalizes a word phonetically, handling:
  /// - Dialectal / child substitutions: ص -> س, ذ -> ز, ث -> س, ظ -> ز/ض
  static String _phoneticBase(String w) {
    return w
        .replaceAll('ص', 'س')
        .replaceAll('ذ', 'ز')
        .replaceAll('ث', 'س')
        .replaceAll('ظ', 'ز')
        .replaceAll('ة', 'ه');
  }

  /// Strips leading 'ال' (Al-) or 'ل' if present for root comparison
  static String _stripAl(String w) {
    if (w.startsWith('ال') && w.length > 3) {
      return w.substring(2);
    }
    // Also if Alif was dropped in speech (e.g. 'لحمد', 'لعالمين')
    if (w.startsWith('ل') && w.length > 3) {
      return w.substring(1);
    }
    return w;
  }

  /// Checks if target word matches spoken tokens starting at tokenIndex.
  /// Returns the number of tokens consumed (> 0 means match, 0 means no match).
  static int matchWord(String targetWord, List<String> spokenTokens, int tokenIndex) {
    if (tokenIndex >= spokenTokens.length) return 0;

    final normTarget = Ayah.normalizeArabic(targetWord);
    final spokenToken = spokenTokens[tokenIndex];

    if (normTarget.isEmpty || spokenToken.isEmpty) return 0;

    // 1. Direct text match
    if (normTarget == spokenToken) return 1;

    // 2. Muqatta'at (الحروف المقطعة) phonetic comparison
    if (spokenEquivalents.containsKey(normTarget)) {
      final expected = spokenEquivalents[normTarget]!;
      bool fullMatch = true;
      for (int i = 0; i < expected.length; i++) {
        if (tokenIndex + i >= spokenTokens.length || spokenTokens[tokenIndex + i] != expected[i]) {
          fullMatch = false;
          break;
        }
      }
      if (fullMatch) {
        return expected.length;
      }

      final joined = expected.join('');
      if (spokenToken == joined || spokenToken == expected.join(' ') || spokenToken.startsWith('الفلام')) {
        return 1;
      }
    }

    // 3. Uthmanic script normalizations (e.g. الصلوة -> الصلاة)
    if (uthmanicToSpoken.containsKey(normTarget)) {
      final spoken = Ayah.normalizeArabic(uthmanicToSpoken[normTarget]!);
      if (spokenToken == spoken) return 1;
    }

    // 4. Definite article 'ال' (Al-) and 'ل' variations (e.g. الحمد <-> لحمد <-> حمد)
    final targetNoAl = _stripAl(normTarget);
    final spokenNoAl = _stripAl(spokenToken);

    if (targetNoAl == spokenNoAl || targetNoAl == spokenToken || normTarget == spokenNoAl) {
      return 1;
    }

    // 5. Common prefixes: 'و' (wa-), 'ف' (fa-), 'ب' (bi-)
    if (spokenToken.startsWith('و') && spokenToken.length > 2) {
      final sub = spokenToken.substring(1);
      if (sub == normTarget || sub == targetNoAl || _stripAl(sub) == targetNoAl) return 1;
    }
    if (spokenToken.startsWith('ف') && spokenToken.length > 2) {
      final sub = spokenToken.substring(1);
      if (sub == normTarget || sub == targetNoAl || _stripAl(sub) == targetNoAl) return 1;
    }
    if (spokenToken.startsWith('ب') && spokenToken.length > 2) {
      final sub = spokenToken.substring(1);
      if (sub == normTarget || sub == targetNoAl || _stripAl(sub) == targetNoAl) return 1;
    }
    if (normTarget.startsWith('و') && normTarget.length > 2) {
      final sub = normTarget.substring(1);
      if (sub == spokenToken || sub == spokenNoAl) return 1;
    }

    // 6. Phonetic letters normalization (س/ص, ز/ذ, إلخ)
    final tPhonetic = _phoneticBase(normTarget);
    final sPhonetic = _phoneticBase(spokenToken);
    if (tPhonetic == sPhonetic) return 1;

    final tPhoneticNoAl = _phoneticBase(targetNoAl);
    final sPhoneticNoAl = _phoneticBase(spokenNoAl);
    if (tPhoneticNoAl == sPhoneticNoAl) return 1;

    // 7. Compound tokens (e.g. "الحمدلله" contains "الحمد" and "لله")
    if (spokenToken.startsWith(normTarget) && spokenToken.length >= normTarget.length) {
      return 1;
    }
    if (normTarget == 'لله' || normTarget == 'الله') {
      if (spokenToken.endsWith('لله') || spokenToken.endsWith('الله')) {
        return 1;
      }
    }

    // 8. Grammatical ending / prefix match for words of length >= 3
    if (spokenToken.length >= 3 && normTarget.length >= 3) {
      if (spokenToken.startsWith(normTarget) || normTarget.startsWith(spokenToken)) {
        return 1;
      }
      if (spokenNoAl.length >= 3 && targetNoAl.length >= 3) {
        if (spokenNoAl.startsWith(targetNoAl) || targetNoAl.startsWith(spokenNoAl)) {
          return 1;
        }
      }
    }

    // 9. Levenshtein fuzzy match for slight mishearings (length >= 4)
    if (normTarget.length >= 4 && spokenToken.length >= 4) {
      if (_levenshtein(normTarget, spokenToken) <= 1) return 1;
      if (_levenshtein(targetNoAl, spokenNoAl) <= 1) return 1;
    }

    return 0;
  }

  static int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        final cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((a, b) => a < b ? a : b);
      }
      for (int j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }

  /// Checks if spokenToken is a valid prefix of targetWord (user is currently articulating the word)
  static bool isPrefixOfWord(String targetWord, String spokenToken) {
    if (spokenToken.isEmpty) return true;
    final normTarget = Ayah.normalizeArabic(targetWord);
    final normSpoken = Ayah.normalizeArabic(spokenToken);
    if (normSpoken.isEmpty) return true;
    if (normTarget.startsWith(normSpoken)) return true;

    final tNoAl = _stripAl(normTarget);
    final sNoAl = _stripAl(normSpoken);
    return tNoAl.startsWith(sNoAl) || normTarget.startsWith(sNoAl);
  }
}
