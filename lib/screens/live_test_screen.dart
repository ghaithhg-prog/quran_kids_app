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
  bool neededCorrection;

  TestWord({
    required this.ayahNumber,
    required this.wordIndexInAyah,
    required this.text,
    required this.normalized,
    this.isRevealed = false,
    this.neededCorrection = false,
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
  int _consumedTokenCount = 0;
  int _directCorrectCount = 0;
  int _correctedCount = 0;
  String _speechLocaleId = 'ar-SA';

  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _liveAyahKeys = {};
  int _lastScrolledAyahNumber = -1;

  Timer? _hesitationTimer;
  String? _hintMessage;
  String? _errorMessage;
  String _selectedReciter = 'Abdul_Basit_Murattal_192kbps';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _audioPlayer.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gain,
      ),
    ));
    _initSpeech();
    _loadSurah();
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onError: (val) {
          debugPrint('STT Error: ${val.errorMsg}');
        },
        onStatus: (val) {
          debugPrint('STT Status: $val');
          if (val == 'done' || val == 'notListening') {
            if (mounted && _isListening && _currentWordIndex < _allWords.length) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted && _isListening && !_speech.isListening) {
                  _startListening();
                }
              });
            }
          }
        },
      );
      if (_speechEnabled) {
        final locales = await _speech.locales();
        final hasArabic = locales.any((l) => l.localeId.startsWith('ar'));
        if (hasArabic) {
          _speechLocaleId = locales.firstWhere((l) => l.localeId.startsWith('ar')).localeId;
        }
      }
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
    _scrollController.dispose();
    _hesitationTimer?.cancel();
    _speech.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _scrollToCurrentWordAyah() {
    if (_currentWordIndex >= _allWords.length || !mounted) return;
    final currentAyahNumber = _allWords[_currentWordIndex].ayahNumber;
    if (currentAyahNumber != _lastScrolledAyahNumber) {
      _lastScrolledAyahNumber = currentAyahNumber;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final keyContext = _liveAyahKeys[currentAyahNumber]?.currentContext;
        if (keyContext != null) {
          Scrollable.ensureVisible(
            keyContext,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
            alignment: 0.5,
          );
        } else if (_scrollController.hasClients) {
          final maxScroll = _scrollController.position.maxScrollExtent;
          final total = _ayahs.isEmpty ? 1 : _ayahs.length;
          final targetOffset = (((currentAyahNumber - 1) / total) * maxScroll).clamp(0.0, maxScroll);
          await _scrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
          if (!mounted) return;
          final lateCtx = _liveAyahKeys[currentAyahNumber]?.currentContext;
          if (lateCtx != null && lateCtx.mounted) {
            Scrollable.ensureVisible(
              lateCtx,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: 0.5,
            );
          }
        }
      });
    }
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
              _buildRuleRow('🎯', 'رتّل السورة من حفظك بصوت واضح في المايكروفون دون النظر للمصحف.'),
              const SizedBox(height: 8),
              _buildRuleRow('✨', 'كل كلمة تنطقها صحيحة ستظهر مباشرة على الشاشة باللون الأخضر!'),
              const SizedBox(height: 8),
              _buildRuleRow('💡', 'إذا أخطأت في كلمة ننبهك فوراً، وإذا توقفت 4 ثوانٍ نساعدك بنطق الكلمة التالية.'),
              const SizedBox(height: 8),
              _buildRuleRow('🏆', 'شرط النجاح: تحقيق نسبة 90% فأكثر من الكلمات صحيحة مباشرة.'),
              const SizedBox(height: 8),
              _buildRuleRow('🌟', 'جائزة التميز الذهبية 🏆: عند قراءة السورة بنسبة 100% دون أي خطأ!'),
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
      nextWord.neededCorrection = true; // Mark that assistance was given
      setState(() {
        _errorMessage = null;
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
    _scrollToCurrentWordAyah();

    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: _speechLocaleId,
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
        pauseFor: const Duration(seconds: 15),
        listenFor: const Duration(minutes: 10),
        cancelOnError: false,
      ),
      onResult: (result) {
        _processSpokenText(result.recognizedWords);
      },
    );
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

    final expandedTokens = QuranPhonetics.expandCompoundTokens(rawTokens);
    final normTokens = expandedTokens.map((w) => Ayah.normalizeArabic(w)).toList();

    // Reset consumed token pointer if speech engine started a new utterance
    if (expandedTokens.length < _consumedTokenCount) {
      _consumedTokenCount = 0;
    }

    bool anyAdvanced = false;
    int tokenIdx = _consumedTokenCount;

    while (tokenIdx < normTokens.length && _currentWordIndex < _allWords.length) {
      final target = _allWords[_currentWordIndex];
      final consumed = QuranPhonetics.matchWord(target.text, normTokens, tokenIdx);

      if (consumed > 0) {
        // Immediate match!
        if (!target.neededCorrection) {
          _directCorrectCount++;
        } else {
          _correctedCount++;
        }
        target.isRevealed = true;
        _currentWordIndex++;
        tokenIdx += consumed;
        _consumedTokenCount = tokenIdx;
        _hintMessage = null;
        _errorMessage = null;
        anyAdvanced = true;
      } else {
        // Did not match target at tokenIdx.
        // Check if tokenIdx is a filler/noise token and the NEXT token matches target:
        if (tokenIdx + 1 < normTokens.length &&
            QuranPhonetics.matchWord(target.text, normTokens, tokenIdx + 1) > 0) {
          tokenIdx++;
          _consumedTokenCount = tokenIdx;
          continue;
        }

        // Check if child is in the middle of articulating the target word (prefix)
        final spokenNorm = normTokens[tokenIdx];
        if (QuranPhonetics.isPrefixOfWord(target.text, spokenNorm)) {
          break; // wait for remaining syllables
        }

        // If the token is a completed wrong word (length >= 2)
        if (spokenNorm.length >= 2) {
          target.neededCorrection = true;
          setState(() {
            _errorMessage = '❌ الكلمة خاطئة: نطقتَ « ${expandedTokens[tokenIdx]} »';
            _hintMessage = null;
          });
          tokenIdx++;
          _consumedTokenCount = tokenIdx;
        } else {
          break;
        }
      }
    }

    if (anyAdvanced) {
      setState(() {});
      _resetHesitationTimer();
      _scrollToCurrentWordAyah();

      if (_currentWordIndex >= _allWords.length) {
        _onTestSuccess();
        return;
      }
    }
  }

  void _onTestSuccess() async {
    _stopListening();
    final totalWords = _allWords.length;
    final int score = totalWords > 0 ? ((_directCorrectCount / totalWords) * 100).round() : 100;
    final bool isPassed = score >= 90;
    final bool isPerfect = score == 100;

    await ProgressService.saveTestResult(
      widget.surah.number,
      score: score,
      directCount: _directCorrectCount,
      correctedCount: _correctedCount,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            children: [
              Text(
                isPerfect
                    ? '🏆 🌟 🌟 🌟 🏆'
                    : isPassed
                        ? '🌟 ⭐ 🌟'
                        : score >= 60
                            ? '👏 📈'
                            : '📖 🔄',
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(height: 6),
              Text(
                isPerfect
                    ? 'حافظ متقن بامتياز! 100%'
                    : isPassed
                        ? 'مبارك! نجحت في الاختبار ($score%)'
                        : score >= 60
                            ? 'أداء جيد ومحاولة ممتازة! ($score%)'
                            : 'للأسف لم تنجح، أعد المحاولة! ($score%)',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isPassed
                      ? const Color(0xFF2E7D32)
                      : score >= 60
                          ? const Color(0xFFE65100)
                          : Colors.red.shade700,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isPerfect
                    ? 'ما شاء الله تبارك الرحمن!\nلقد رتّلت سورة ${widget.surah.name} كاملة صحيحة 100% دون أي خطأ!\nتم منحك وسام وجائزة التميز الذهبية 🏆'
                    : isPassed
                        ? 'أحسنت يا بطل القرآن!\nتجاوزت شرط النجاح (90%) بجدارة في سورة ${widget.surah.name}!'
                        : score >= 60
                            ? 'أداء طيب في سورة ${widget.surah.name}، واقتربت من نسبة النجاح المطلوبة (90%). أعد الاختبار الآن لتفوز بالجائزة!'
                            : 'لا تقلق يا بطل، الحفظ يحتاج إلى التكرار! ننصحك بالانتقال إلى «رحلة مراحل الحفظ» لتثبيت السورة ثم إعادة الاختبار.',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('كلمات صحيحة مباشرة:', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32))),
                        Text('$_directCorrectCount من $totalWords', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32))),
                      ],
                    ),
                    const Divider(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('كلمات أصلحناها لك بلطف:', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.brown.shade700)),
                        Text('$_correctedCount', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.brown.shade700)),
                      ],
                    ),
                    const Divider(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('المعدل النهائي:', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold)),
                        Text(
                          '$score%',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isPassed ? const Color(0xFF2E7D32) : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _restartTest();
              },
              icon: const Icon(Icons.refresh),
              label: Text('إعادة الاختبار', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA000),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (!isPassed)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                icon: const Icon(Icons.menu_book),
                label: Text('رحلة الحفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
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
                backgroundColor: const Color(0xFF00897B),
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
    _lastScrolledAyahNumber = -1;
    setState(() {
      _currentWordIndex = 0;
      _consumedTokenCount = 0;
      _directCorrectCount = 0;
      _correctedCount = 0;
      for (var w in _allWords) {
        w.isRevealed = false;
        w.neededCorrection = false;
      }
      _hintMessage = null;
      _errorMessage = null;
      _isListening = false;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    }
    _showSnack('تمت إعادة الاختبار من البداية. اضغط على «ابدأ التسميع بصوتك» عند استعدادك!');
  }

  Future<void> _playHintAudio() async {
    if (_currentWordIndex >= _allWords.length) return;
    final targetWord = _allWords[_currentWordIndex];
    final ayah = _ayahs.firstWhere((a) => a.number == targetWord.ayahNumber);
    final url = ayah.getAudioUrl(widget.surah.number, reciter: _selectedReciter);
    try {
      await _audioPlayer.setVolume(1.0);
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
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle, color: Color(0xFF81C784), size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      'صحيحة مباشرة: $_directCorrectCount',
                                      style: GoogleFonts.cairo(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.lightbulb, color: Color(0xFFFFD54F), size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      'أصلحناها لك: $_correctedCount',
                                      style: GoogleFonts.cairo(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
                        controller: _scrollController,
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
                                key: _liveAyahKeys.putIfAbsent(ayah.number, () => GlobalKey()),
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
