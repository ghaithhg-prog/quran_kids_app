class Ayah {
  final int number;
  final String text;
  final List<String> words;
  final String normalizedText;

  Ayah({
    required this.number,
    required this.text,
  })  : words = parseCleanWords(text),
        normalizedText = normalizeArabic(text);

  String getAudioUrl(int surahNumber, {String reciter = 'Abdul_Basit_Murattal_192kbps'}) {
    final s = surahNumber.toString().padLeft(3, '0');
    final a = number.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$reciter/$s$a.mp3';
  }

  /// Parses text into clean pronounceable Arabic words.
  /// Completely strips Quranic waqf/pause marks (ۚ ۖ ۗ ۘ ۙ ۛ ۜ), decorative symbols, dots and non-letters.
  static List<String> parseCleanWords(String rawText) {
    final rawTokens = rawText.trim().split(RegExp(r'\s+'));
    final List<String> cleanList = [];

    for (final token in rawTokens) {
      // Strip waqf marks, stop signs, brackets, dots, and non-phonetic signs
      final cleaned = token.replaceAll(
        RegExp(r'[\u06D6-\u06ED\u0610-\u061A\u0600-\u060F\.\,\;\:\?\!«»\(\)\[\]\{\}\-_~۝۞۩\u0660-\u06690-9]'),
        '',
      ).trim();

      // Only accept if it contains at least one true Arabic letter
      if (RegExp(r'[\u0621-\u064A]').hasMatch(cleaned)) {
        cleanList.add(cleaned);
      }
    }
    return cleanList;
  }

  /// Normalizes Arabic text for accurate speech recognition comparison
  static String normalizeArabic(String input) {
    String text = input;
    // Remove all diacritics, harakat, waqf signs, and quranic symbols
    text = text.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED\u0610-\u061A\u0600-\u060F]'), '');
    // Normalize Alef variations
    text = text.replaceAll(RegExp(r'[إأآاٱ]'), 'ا');
    // Normalize Yaa / Alef Maksura
    text = text.replaceAll('ى', 'ي');
    // Normalize Taa Marbuta
    text = text.replaceAll('ة', 'ه');
    // Keep ONLY Arabic letters and spaces
    text = text.replaceAll(RegExp(r'[^\s\u0621-\u064A]'), ' ');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class Surah {
  final int number;
  final String name;
  final String englishName;
  final String revelationType;
  final int totalAyahs;
  List<Ayah> ayahs;

  Surah({
    required this.number,
    required this.name,
    required this.englishName,
    required this.revelationType,
    required this.totalAyahs,
    this.ayahs = const [],
  });

  bool get isLoaded => ayahs.isNotEmpty;
}
