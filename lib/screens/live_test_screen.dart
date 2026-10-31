import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/surah.dart';
import '../data/quran_data.dart';
import '../services/progress_service.dart';
import '../services/quran_service.dart';
import '../services/quran_phonetics.dart';

class TestWord {
  final int ayahNumber;
  final int wordIndexInAyah;
  final String text;
  final String normalized;
  bool isRevealed;

  TestWord({
    required this.ayahNumber,
    required this.wordIndexInAyah,
    required this.text,
    required this.normalized,
    this.isRevealed = false,
  });
}

class LiveTestScreen extends StatefulWidget {
  final Surah surah;

  const LiveTestScreen({super.key, required this.surah});

  @override
  State<LiveTestScreen> createState() => _LiveTestScreenState();
}

class _LiveTestScreenState extends State<LiveTestScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late stt.SpeechToText _speech;
  bool _speechEnabled = false;
  bool _isListening = false;

  bool _isLoading = true;
  List<Ayah> _ayahs = [];
  final List<TestWord> _allWords = [];
  int _currentWordIndex = 0;

  Timer? _hesitationTimer;
  String? _hintMessage;
  String? _errorMessage;
  String _selectedReciter = 'Abdul_Basit_Murattal_192kbps';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
    _loadSurah();
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onError: (val) {
          debugPrint('STT Error: $val');
          if (mounted && _isListening) {
            _restartListening();
          }
        },
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            if (mounted && _isListening && _currentWordIndex < _allWords.length) {
              _restartListening();
            }
          }
        },
      );
    } catch (e) {
      _speechEnabled = false;
    }
  }

  Future<void> _loadSurah() async {
    setState(() => _isLoading = true);
    final loaded = await QuranService.loadSurahAyahs(widget.surah.number);
    if (!mounted) return;

    _allWords.clear();
    for (final ayah in loaded) {
      for (int w = 0; w < ayah.words.length; w++) {
        final rawWord = ayah.words[w];
        _allWords.add(TestWord(
          ayahNumber: ayah.number,
          wordIndexInAyah: w,
          text: rawWord,
          normalized: Ayah.normalizeArabic(rawWord),
        ));
      }
    }

    setState(() {
      _ayahs = loaded;
      _isLoading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showStartPrompt();
    });
  }

  @override
  void dispose() {
    _hesitationTimer?.cancel();
    _speech.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _showStartPrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              const Icon(Icons.mic, color: Color(0xFF00897B), size: 28),
              const SizedBox(width: 8),
              Text('اختبار التسميع المباشر 🎙️', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مرحباً بك في اختبار سورة ${widget.surah.name}!\n',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              _buildRuleRow('🎯', 'رتّل السورة من حفظك بصوت واضح في المايكروفون.'),
              const SizedBox(height: 8),
              _buildRuleRow('✨', 'كل كلمة تنطقها صحيحة ستظهر مباشرة على الشاشة!'),
              const SizedBox(height: 8),
              _buildRuleRow('⏳', 'إذا توقفت لأكثر من 4 ثوانٍ، سيساعدك التطبيق بالكلمة التالية.'),
              const SizedBox(height: 8),
              _buildRuleRow('🏆', 'شرط النجاح: قراءة السورة كاملة صحيحة 100%!'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _startListening();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('ابدأ الاختبار الآن! 🚀', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleRow(String icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: GoogleFonts.cairo(fontSize: 13, height: 1.4))),
      ],
    );
  }

  void _resetHesitationTimer() {
    _hesitationTimer?.cancel();
    if (_currentWordIndex >= _allWords.length) return;

    _hesitationTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || !_isListening || _currentWordIndex >= _allWords.length) return;
      final nextWord = _allWords[_currentWordIndex];
      setState(() {
        _hintMessage = '⏳ توقفت أكثر من 4 ثوانٍ! الكلمة التالية هي: « ${nextWord.text} »';
      });
    });
  }

  Future<void> _startListening() async {
    if (!_speechEnabled) {
      final available = await _speech.initialize();
      if (!available) {
        _showSnack('يرجى منح صلاحية المايكروفون للتطبيق لتتمكن من التسميع.');
        return;
      }
      _speechEnabled = true;
    }

    setState(() {
      _isListening = true;
      _errorMessage = null;
      _hintMessage = null;
    });

    _resetHesitationTimer();

    final locales = await _speech.locales();
    String localeId = 'ar-SA';
    final hasArabic = locales.any((l) => l.localeId.startsWith('ar'));
    if (hasArabic) {
      localeId = locales.firstWhere((l) => l.localeId.startsWith('ar')).localeId;
    }

    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: localeId,
        partialResults: true,
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: false,
      ),
      onResult: (result) {
        _processSpokenText(result.recognizedWords);
      },
    );
  }

  void _restartListening() async {
    if (!_isListening || _currentWordIndex >= _allWords.length) return;
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted && _isListening) {
      _startListening();
    }
  }

  void _stopListening() async {
    _hesitationTimer?.cancel();
    await _speech.stop();
    setState(() => _isListening = false);
  }

  void _processSpokenText(String recognized) {
    if (_currentWordIndex >= _allWords.length) return;

    final rawTokens = recognized
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (rawTokens.isEmpty) return;

    final normTokens = rawTokens.map((w) => Ayah.normalizeArabic(w)).toList();

    for (int i = 0; i < rawTokens.length; i++) {
      if (_currentWordIndex >= _allWords.length) break;

      final normToken = normTokens[i];
      if (normToken.isEmpty) continue;

      final target = _allWords[_currentWordIndex];
      final consumed = QuranPhonetics.matchWord(target.text, normTokens, i);

      if (consumed > 0) {
        // Immediate match upon speaking the correct word!
        setState(() {
          target.isRevealed = true;
          _currentWordIndex++;
          _hintMessage = null;
          _errorMessage = null;
        });
        _resetHesitationTimer();
        i += (consumed - 1);

        if (_currentWordIndex >= _allWords.length) {
          _onTestSuccess();
          return;
        }
      } else {
        // Immediate error if the latest spoken word did not match target
        if (i == rawTokens.length - 1 && normToken.length >= 2) {
          setState(() {
            _errorMessage = '❌ خطأ: نطقتَ « ${rawTokens[i]} » والصواب: « ${target.text} »';
            _hintMessage = null;
          });
          _resetHesitationTimer();
        }
      }
    }
  }



  void _onTestSuccess() {
    _stopListening();
    ProgressService.saveProgress(widget.surah.number, stars: 3, round: 7);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            children: [
              const Text('🏆 🌟 🌟 🌟 🏆', style: TextStyle(fontSize: 34)),
              const SizedBox(height: 8),
              Text(
                'نجحت في الاختبار بجدارة!',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          content: Text(
            'ما شاء الله تبارك الله!\nلقد رتّلت سورة ${widget.surah.name} كاملة صحيحة 100% عن ظهر قلب!\nتم منحك 3 نجوم ذهبية ⭐⭐⭐',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontSize: 15, height: 1.6),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _currentWordIndex = 0;
                  for (var w in _allWords) {
                    w.isRevealed = false;
                  }
                });
                _startListening();
              },
              icon: const Icon(Icons.refresh),
              label: Text('إعادة الاختبار', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA000),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              icon: const Icon(Icons.check_circle),
              label: Text('تم، سورة أخرى', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _restartTest() {
    _stopListening();
    setState(() {
      _currentWordIndex = 0;
      for (var w in _allWords) {
        w.isRevealed = false;
      }
      _hintMessage = null;
      _errorMessage = null;
    });
    _startListening();
    _showSnack('تمت إعادة الاختبار من البداية. رتّل الآن بصوتك!');
  }

  Future<void> _playHintAudio() async {
    if (_currentWordIndex >= _allWords.length) return;
    final targetWord = _allWords[_currentWordIndex];
    final ayah = _ayahs.firstWhere((a) => a.number == targetWord.ayahNumber);
    final url = ayah.getAudioUrl(widget.surah.number, reciter: _selectedReciter);
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      debugPrint('Audio error: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _allWords.isEmpty ? 0.0 : (_currentWordIndex / _allWords.length).clamp(0.0, 1.0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7F6),
        appBar: AppBar(
          backgroundColor: const Color(0xFF00897B),
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'اختبار سورة ${widget.surah.name}',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'إعادة الاختبار من البداية',
              onPressed: _restartTest,
            ),
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: _showStartPrompt,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00897B)))
            : Column(
                children: [
                  // Progress Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF00897B),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(22),
                        bottomRight: Radius.circular(22),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'الكلمات المقروءة صحيحة: $_currentWordIndex من ${_allWords.length}',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: GoogleFonts.cairo(
                                color: const Color(0xFFFFD54F),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD54F)),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ],
                    ),
                  ),

                  // Reciter Selector Card
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.volume_up, color: Color(0xFF00897B), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'صوت الشيخ للمساعدة:',
                          style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedReciter,
                              isExpanded: true,
                              style: GoogleFonts.cairo(fontSize: 11, color: Colors.black87),
                              items: QuranData.reciters.map((r) {
                                return DropdownMenuItem<String>(
                                  value: r['id'],
                                  child: Text(
                                    r['name']!,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedReciter = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Hint / Hesitation / Error Banner
                  if (_hintMessage != null || _errorMessage != null)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _errorMessage != null ? const Color(0xFFFFEBEE) : const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _errorMessage != null ? Colors.red.shade300 : Colors.amber.shade400,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _errorMessage != null ? Icons.error_outline : Icons.lightbulb_outline,
                            color: _errorMessage != null ? Colors.red : Colors.amber.shade900,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage ?? _hintMessage!,
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _errorMessage != null ? Colors.red.shade900 : Colors.brown.shade800,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.volume_up, color: Color(0xFF00897B)),
                            tooltip: 'استمع لنطق الشيخ',
                            onPressed: _playHintAudio,
                          ),
                        ],
                      ),
                    ),

                  // Verses Text Display (Words appear dynamically as child recites correctly)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            Text(
                              'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.amiri(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF00897B),
                              ),
                            ),
                            const Divider(height: 24),
                            ...List.generate(_ayahs.length, (ayahIdx) {
                              final ayah = _ayahs[ayahIdx];
                              final wordsForThisAyah = _allWords
                                  .where((w) => w.ayahNumber == ayah.number)
                                  .toList();

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 8,
                                  children: [
                                    ...wordsForThisAyah.map((w) {
                                      if (w.isRevealed) {
                                        return AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE8F5E9),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            w.text,
                                            style: GoogleFonts.amiri(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF1B5E20),
                                              height: 1.6,
                                            ),
                                          ),
                                        );
                                      } else {
                                        // Hidden placeholder
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          child: Text(
                                            '• • •',
                                            style: TextStyle(
                                              color: Colors.grey.shade300,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      }
                                    }),
                                    // Ayah number circle
                                    Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: wordsForThisAyah.every((w) => w.isRevealed)
                                            ? const Color(0xFF00897B)
                                            : Colors.grey.shade300,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${ayah.number}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Action Bar & Microphone Button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _restartTest,
                            icon: const Icon(Icons.refresh, size: 18, color: Color(0xFFE65100)),
                            label: Text(
                              'إعادة',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: const Color(0xFFE65100),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFFFA000)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (_isListening) {
                                  _stopListening();
                                } else {
                                  _startListening();
                                }
                              },
                              icon: Icon(
                                _isListening ? Icons.stop : Icons.mic,
                                size: 24,
                                color: Colors.white,
                              ),
                              label: Text(
                                _isListening ? 'إيقاف التسميع' : 'ابدأ التسميع بصوتك 🎙️',
                                style: GoogleFonts.cairo(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isListening ? Colors.red.shade600 : const Color(0xFF00897B),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
