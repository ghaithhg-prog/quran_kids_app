import 'package:flutter_test/flutter_test.dart';
import 'package:quran_kids_app/services/quran_phonetics.dart';

void main() {
  test('Phonetics matchWord handles continuous recitation variations', () {
    // Al-Hamd variations
    expect(QuranPhonetics.matchWord('الحمد', ['الحمد'], 0), greaterThan(0));
    expect(QuranPhonetics.matchWord('الحمد', ['لحمد'], 0), greaterThan(0));
    expect(QuranPhonetics.matchWord('الحمد', ['والحمد'], 0), greaterThan(0));
    expect(QuranPhonetics.matchWord('الحمد', ['الحمدلله'], 0), greaterThan(0));

    // Lil-lah variations
    expect(QuranPhonetics.matchWord('لله', ['لله'], 0), greaterThan(0));
    expect(QuranPhonetics.matchWord('لله', ['الله'], 0), greaterThan(0));
    expect(QuranPhonetics.matchWord('لله', ['ولله'], 0), greaterThan(0));

    // Al-Alameen variations
    expect(QuranPhonetics.matchWord('العالمين', ['العالمين'], 0), greaterThan(0));
    expect(QuranPhonetics.matchWord('العالمين', ['عالمين'], 0), greaterThan(0));
    expect(QuranPhonetics.matchWord('العالمين', ['لعالمين'], 0), greaterThan(0));

    // Al-Rahman variations
    expect(QuranPhonetics.matchWord('الرحمن', ['الرحمن'], 0), greaterThan(0));
    expect(QuranPhonetics.matchWord('الرحمن', ['رحمن'], 0), greaterThan(0));

    // Al-Sirat variations
    expect(QuranPhonetics.matchWord('الصراط', ['الصراط'], 0), greaterThan(0));
    expect(QuranPhonetics.matchWord('الصراط', ['صراط'], 0), greaterThan(0));
    expect(QuranPhonetics.matchWord('الصراط', ['سراط'], 0), greaterThan(0));
    expect(QuranPhonetics.matchWord('الصراط', ['السراط'], 0), greaterThan(0));

    // Al-Mustaqeem variations
    expect(QuranPhonetics.matchWord('المستقيم', ['المستقيم'], 0), greaterThan(0));
    expect(QuranPhonetics.matchWord('المستقيم', ['مستقيم'], 0), greaterThan(0));

    // Al-Ladheena variations
    expect(QuranPhonetics.matchWord('الذين', ['الذين'], 0), greaterThan(0));
    expect(QuranPhonetics.matchWord('الذين', ['لذين'], 0), greaterThan(0));
    expect(QuranPhonetics.matchWord('الذين', ['الزين'], 0), greaterThan(0));

    // Al-Dhallen
    expect(QuranPhonetics.matchWord('الضالين', ['الضالين'], 0), greaterThan(0));
    expect(QuranPhonetics.matchWord('الضالين', ['ضالين'], 0), greaterThan(0));

    // Muqatta'at (Alif Lam Meem & other surah openers)
    expect(QuranPhonetics.matchWord('الم', ['الف', 'لام', 'ميم'], 0), equals(3));
    expect(QuranPhonetics.matchWord('الم', ['الم'], 0), greaterThan(0));
    expect(QuranPhonetics.matchWord('الم', ['ألم'], 0), greaterThan(0));
    expect(QuranPhonetics.matchWord('الم', ['الفلاميم'], 0), greaterThan(0));
    expect(QuranPhonetics.isPrefixOfWord('الم', 'الف'), isTrue);
    expect(QuranPhonetics.isPrefixOfWord('الم', 'لام'), isTrue);
    expect(QuranPhonetics.isPrefixOfWord('الم', 'ميم'), isTrue);

    expect(QuranPhonetics.matchWord('طه', ['طا', 'ها'], 0), equals(2));
    expect(QuranPhonetics.matchWord('طه', ['طاء', 'هاء'], 0), equals(2));
    expect(QuranPhonetics.matchWord('يس', ['يا', 'سين'], 0), equals(2));
    expect(QuranPhonetics.matchWord('يس', ['ياء', 'سين'], 0), equals(2));
    expect(QuranPhonetics.matchWord('كهيعص', ['كاف', 'ها', 'يا', 'عين', 'صاد'], 0), equals(5));

    // Verify Ayah Recitation for MemorizeScreen
    expect(QuranPhonetics.verifyAyahRecitation(['الم'], ['الف', 'لام', 'ميم']).isEmpty, isTrue);
    expect(QuranPhonetics.verifyAyahRecitation(['الم'], ['الم']).isEmpty, isTrue);
    expect(QuranPhonetics.verifyAyahRecitation(['طه'], ['طا', 'ها']).isEmpty, isTrue);
    expect(QuranPhonetics.verifyAyahRecitation(['يس'], ['يا', 'سين']).isEmpty, isTrue);

    // Lafz Al-Jalalah variations (الله <-> لله)
    expect(QuranPhonetics.matchWord('الله', ['الله'], 0), greaterThan(0));
    expect(QuranPhonetics.matchWord('الله', ['لله'], 0), greaterThan(0));
    expect(QuranPhonetics.matchWord('لله', ['الله'], 0), greaterThan(0));
    expect(QuranPhonetics.matchWord('لله', ['لله'], 0), greaterThan(0));

    // Compound tokens expansion
    final expanded = QuranPhonetics.expandCompoundTokens(['الحمدلله', 'رب', 'العالمين']);
    expect(expanded, equals(['الحمد', 'لله', 'رب', 'العالمين']));

    // Prefix checking (user in middle of articulating word - should NOT match yet!)
    expect(QuranPhonetics.matchWord('نستعين', ['نست'], 0), equals(0));
    expect(QuranPhonetics.isPrefixOfWord('نستعين', 'نست'), isTrue);
    expect(QuranPhonetics.matchWord('المستقيم', ['المس'], 0), equals(0));
    expect(QuranPhonetics.isPrefixOfWord('المستقيم', 'المس'), isTrue);

    // Exact word match
    expect(QuranPhonetics.matchWord('نستعين', ['نستعين'], 0), greaterThan(0));

    // Wrong words should NEVER match!
    expect(QuranPhonetics.matchWord('الرحيم', ['الكريم'], 0), equals(0));
    expect(QuranPhonetics.matchWord('نستعين', ['نستغيث'], 0), equals(0));
    expect(QuranPhonetics.matchWord('الحمد', ['قل'], 0), equals(0));
  });
}