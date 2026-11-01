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

    // Muqatta'at (Alif Lam Meem)
    expect(QuranPhonetics.matchWord('الم', ['الف', 'لام', 'ميم'], 0), equals(3));
    expect(QuranPhonetics.matchWord('الم', ['الفلاميم'], 0), greaterThan(0));

    // Wrong word should NOT match
    expect(QuranPhonetics.matchWord('الرحيم', ['الكريم'], 0), equals(0));
    expect(QuranPhonetics.matchWord('الحمد', ['قل'], 0), equals(0));
  });
}