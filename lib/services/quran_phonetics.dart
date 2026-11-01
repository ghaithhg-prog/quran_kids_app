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
    if (w == 'الله' || w == 'لله') return w;
    if (w.startsWith('ال') && w.length > 3) {
      return w.substring(2);
    }
    // Also if Alif was dropped in speech (e.g. 'لحمد', 'لعالمين')
    if (w.startsWith('ل') && w.length > 3) {
      return w.substring(1);
    }
    return w;
  }

  /// Splits compound speech tokens that are often transcribed together
  static List<String> expandCompoundTokens(List<String> tokens) {
    final List<String> expanded = [];
    for (final token in tokens) {
      final norm = Ayah.normalizeArabic(token);
      if (norm == 'الحمدلله' || norm == 'ولحمدلله') {
        if (norm.startsWith('و')) expanded.add('و');
        expanded.add('الحمد');
        expanded.add('لله');
      } else if (norm == 'بسمالله') {
        expanded.add('بسم');
        expanded.add('الله');
      } else if (norm == 'انشاءالله' || norm == 'انشاالله') {
        expanded.add('ان');
        expanded.add('شاء');
        expanded.add('الله');
      } else if (norm == 'سبحانالله') {
        expanded.add('سبحان');
        expanded.add('الله');
      } else if (norm == 'ماشاءالله' || norm == 'ماشاالله') {
        expanded.add('ما');
        expanded.add('شاء');
        expanded.add('الله');
      } else if (norm.startsWith('ياايها') || norm.startsWith('ياأيها')) {
        expanded.add('يا');
        expanded.add('ايها');
      } else if (norm.startsWith('يا') && norm.length > 3 && !norm.startsWith('يوم')) {
        expanded.add('يا');
        expanded.add(norm.substring(2));
      } else if (norm.startsWith('هاانتم') || norm.startsWith('هاأنتم')) {
        expanded.add('ها');
        expanded.add('انتم');
      } else {
        expanded.add(token);
      }
    }
    return expanded;
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

    // 1.1 Qira'at / Dagger-Alif variations (e.g. مالك <-> ملك)
    if ((normTarget == 'مالك' && spokenToken == 'ملك') || (normTarget == 'ملك' && spokenToken == 'مالك')) {
      return 1;
    }

    // 1.2 Lafz Al-Jalalah (الله <-> لله)
    if ((normTarget == 'الله' && (spokenToken == 'الله' || spokenToken == 'لله')) ||
        (normTarget == 'لله' && (spokenToken == 'لله' || spokenToken == 'الله'))) {
      return 1;
    }

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

    // 7. Compound / Joined tokens (e.g. "الحمدلله" starts with "الحمد")
    if (spokenToken.startsWith(normTarget) && spokenToken.length > normTarget.length) {
      return 1;
    }

    return 0;
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
