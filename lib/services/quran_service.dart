import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/surah.dart';
import '../data/quran_data.dart';

class QuranService {
  static Future<List<Ayah>> loadSurahAyahs(int surahNumber) async {
    // 1. Check built-in offline list
    if (QuranData.offlineAyahs.containsKey(surahNumber)) {
      final texts = QuranData.offlineAyahs[surahNumber]!;
      return List.generate(
        texts.length,
        (i) => Ayah(number: i + 1, text: texts[i]),
      );
    }

    // 2. Check local SharedPreferences cache
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('cached_surah_$surahNumber');
    if (cachedData != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(cachedData);
        return jsonList
            .map((item) => Ayah(number: item['number'], text: item['text']))
            .toList();
      } catch (e) {
        // Fallback to network if cache corrupted
      }
    }

    // 3. Fetch from free Al-Quran Cloud API
    try {
      final response = await http
          .get(Uri.parse('https://api.alquran.cloud/v1/surah/$surahNumber/quran-uthmani'))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> ayahsRaw = data['data']['ayahs'];

        final List<Ayah> result = [];
        for (int i = 0; i < ayahsRaw.length; i++) {
          String text = ayahsRaw[i]['text'] as String;
          // Strip duplicate Basmalah on ayah 1 for surahs > 1 except At-Tawbah (9)
          if (i == 0 && surahNumber != 1 && surahNumber != 9) {
            text = text.replaceFirst(RegExp(r'^بِسْمِ [^\s]+ [^\s]+ [^\s]+\s*'), '').trim();
          }
          result.add(Ayah(number: i + 1, text: text));
        }

        // Cache the fetched ayahs locally
        final cacheJson = jsonEncode(result
            .map((a) => {'number': a.number, 'text': a.text})
            .toList());
        await prefs.setString('cached_surah_$surahNumber', cacheJson);

        return result;
      }
    } catch (e) {
      // In case of network error, return empty or retryable state
    }

    return [];
  }
}
