import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/surah.dart';
import '../data/quran_data.dart';
import '../services/progress_service.dart';
import '../services/quran_service.dart';
import 'live_test_screen.dart';

class MemorizeScreen extends StatefulWidget {
  final Surah surah;

  const MemorizeScreen({super.key, required this.surah});

  @override
  State<MemorizeScreen> createState() => _MemorizeScreenState();
}

class _MemorizeScreenState extends State<MemorizeScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late stt.SpeechToText _speech;
  bool _speechEnabled = false;
  bool _isListening = false;
  int _listeningAyahIndex = -1;
  String _recognizedWords = '';
  String? _speechFeedback;
  bool _speechSuccess = false;

  int _currentRound = 1;
  final int _maxRounds = 7;
  int _currentPlayingAyahIndex = -1;
  bool _isPlaying = false;
  String _selectedReciter = 'Abdul_Basit_Murattal_192kbps';
  bool _isLoadingAyahs = true;
  List<Ayah> _ayahs = [];

  // Set of masked word keys per ayah: "ayahIndex-wordIndex"
  final Set<String> _maskedWordsKeys = {};
  // Set of words revealed by tapping
  final Set<String> _revealedWords = {};

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
    _loadSurahData();
    _setupAudioPlayer();
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onError: (val) => debugPrint('STT error: $val'),
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            if (mounted && _isListening) {
              setState(() => _isListening = false);
            }
          }
        },
      );
    } catch (e) {
      _speechEnabled = false;
    }
  }

  Future<void> _loadSurahData() async {
    setState(() => _isLoadingAyahs = true);
    final savedRound = ProgressService.getSavedRound(widget.surah.number);
    _currentRound = savedRound > 1 ? savedRound : 1;

    final loaded = await QuranService.loadSurahAyahs(widget.surah.number);
    if (mounted) {
      setState(() {
        _ayahs = loaded;
        _isLoadingAyahs = false;
      });
      _generateMaskedWords();
      // Show explanation if on round 1
      if (_currentRound == 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showExplanationDialog();
        });
      }
    }
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      if (_currentPlayingAyahIndex < _ayahs.length - 1) {
        _playAyah(_currentPlayingAyahIndex + 1);
      } else {
        setState(() {
          _isPlaying = false;
          _currentPlayingAyahIndex = -1;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _speech.stop();
    super.dispose();
  }

  // Generates randomized masked words per ayah according to round level
  void _generateMaskedWords() {
    _maskedWordsKeys.clear();
    _revealedWords.clear();

    if (_currentRound <= 3 || _ayahs.isEmpty) return;

    final random = Random(widget.surah.number * 100 + _currentRound);

    for (int a = 0; a < _ayahs.length; a++) {
      final totalWords = _ayahs[a].words.length;
      if (totalWords == 0) continue;

      int wordsToMask = 0;
      if (_currentRound == 4) {
        // Round 4: Mask 1 random word per ayah
        wordsToMask = 1;
      } else if (_currentRound == 5) {
        // Round 5: Mask ~35% of words
        wordsToMask = max(1, (totalWords * 0.35).round());
      } else if (_currentRound == 6) {
        // Round 6: Mask ~65% of words
        wordsToMask = max(1, (totalWords * 0.65).round());
      } else {
        // Round 7: Mask 100% of words (full recall!)
        wordsToMask = totalWords;
      }

      final indices = List<int>.generate(totalWords, (i) => i)..shuffle(random);
      for (int i = 0; i < wordsToMask; i++) {
        _maskedWordsKeys.add('$a-${indices[i]}');
      }
    }
  }

  Future<void> _playAyah(int index) async {
    if (index >= _ayahs.length) return;
    setState(() {
      _currentPlayingAyahIndex = index;
      _isPlaying = true;
    });

    final ayah = _ayahs[index];
    final url = ayah.getAudioUrl(widget.surah.number, reciter: _selectedReciter);
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
      _currentPlayingAyahIndex = -1;
    });
  }

  void _togglePlayAll() {
    if (_isPlaying) {
      _stopAudio();
    } else {
      _playAyah(0);
    }
  }

  // Speech Recognition & Recitation Verification
  Future<void> _startListeningForAyah(int ayahIndex) async {
    _stopAudio();
    if (!_speechEnabled) {
      final available = await _speech.initialize();
      if (!available) {
        _showSnack('تعذر تشغيل المايكروفون. يرجى التأكد من منحه الصلاحية في هاتفك.');
        return;
      }
      _speechEnabled = true;
    }

    setState(() {
      _isListening = true;
      _listeningAyahIndex = ayahIndex;
      _recognizedWords = '';
      _speechFeedback = null;
      _speechSuccess = false;
    });

    // Try Arabic locale if available
    final locales = await _speech.locales();
    String localeId = 'ar-SA';
    final hasArabic = locales.any((l) => l.localeId.startsWith('ar'));
    if (hasArabic) {
      localeId = locales.firstWhere((l) => l.localeId.startsWith('ar')).localeId;
    }

    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: localeId,
      ),
      onResult: (result) {
        setState(() {
          _recognizedWords = result.recognizedWords;
        });

        if (result.finalResult || !_speech.isListening) {
          _verifyRecitation(ayahIndex, _recognizedWords);
        }
      },
    );
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
    if (_recognizedWords.isNotEmpty && _listeningAyahIndex != -1) {
      _verifyRecitation(_listeningAyahIndex, _recognizedWords);
    }
  }

  void _verifyRecitation(int ayahIndex, String spoken) {
    setState(() => _isListening = false);
    final targetAyah = _ayahs[ayahIndex];
    final targetNorm = targetAyah.normalizedText;
    final spokenNorm = Ayah.normalizeArabic(spoken);

    final targetWords = targetNorm.split(RegExp(r'\s+'));
    final spokenWords = spokenNorm.split(RegExp(r'\s+'));

    // Find missing or incorrect words
    final List<String> missedWords = [];
    for (final tw in targetWords) {
      if (!spokenWords.contains(tw)) {
        missedWords.add(tw);
      }
    }

    if (missedWords.isEmpty || spokenWords.length >= targetWords.length - 1 && missedWords.length <= 1) {
      // Success!
      setState(() {
        _speechSuccess = true;
        _speechFeedback = 'ما شاء الله! قراءة صحيحة ومتقنة أحسنت! 🌟';
        // Reveal masked words in this ayah as a reward
        for (int w = 0; w < targetAyah.words.length; w++) {
          _revealedWords.add('$ayahIndex-$w');
        }
      });
    } else {
      // Find the first missing word in original text with diacritics
      String originalMissed = '';
      for (int i = 0; i < targetAyah.words.length; i++) {
        if (missedWords.contains(Ayah.normalizeArabic(targetAyah.words[i]))) {
          originalMissed = targetAyah.words[i];
          break;
        }
      }

      setState(() {
        _speechSuccess = false;
        _speechFeedback = 'انتبه! نسيت أو نطقت بالخطأ كلمة: « $originalMissed ».\nاضغط على زر الصوت لتسمع الشيخ كيف ينطقها ثم أعد المحاولة!';
      });
    }
  }

  void _onWordTapped(int ayahIndex, int wordIndex) {
    final key = '$ayahIndex-$wordIndex';
    setState(() {
      _revealedWords.add(key);
    });
    // Give audio feedback for this ayah
    _playAyah(ayahIndex);
  }

  void _previousRound() {
    if (_currentRound <= 1) return;
    _stopAudio();
    setState(() {
      _currentRound--;
    });
    _generateMaskedWords();
    ProgressService.saveProgress(
      widget.surah.number,
      stars: _calculateStarsForRound(_currentRound),
      round: _currentRound,
    );
    _showRoundInfoBanner();
  }

  void _restartMemorization() {
    _stopAudio();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.refresh, color: Color(0xFFE65100), size: 26),
              const SizedBox(width: 8),
              Text('إعادة الحفظ من البداية', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Text(
            'هل تريد إعادة حفظ سورة ${widget.surah.name} من المرحلة الأولى؟',
            style: GoogleFonts.cairo(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey.shade700)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _currentRound = 1;
                });
                _generateMaskedWords();
                ProgressService.saveProgress(
                  widget.surah.number,
                  stars: 0,
                  round: 1,
                );
                _showRoundInfoBanner();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('نعم، أعد من البداية', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _nextRound() async {
    _stopAudio();
    if (_currentRound < 6) {
      setState(() {
        _currentRound++;
      });
      _generateMaskedWords();
      ProgressService.saveProgress(
        widget.surah.number,
        stars: _calculateStarsForRound(_currentRound),
        round: _currentRound,
      );
      _showRoundInfoBanner();
    } else {
      // Round 7 is the Live Speech Test!
      setState(() {
        _currentRound = 7;
      });
      final passed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => LiveTestScreen(surah: widget.surah),
        ),
      );
      if (passed == true && mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  int _calculateStarsForRound(int r) {
    if (r >= 7) return 3;
    if (r >= 5) return 2;
    if (r >= 3) return 1;
    return 0;
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

  void _showExplanationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              const Icon(Icons.menu_book, color: Color(0xFF00897B), size: 28),
              const SizedBox(width: 8),
              Text('خطة الحفظ المتقن 📖', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مرحباً بك في حفظ سورة ${widget.surah.name}!\nإليك خطوات الحفظ الذكي:',
                style: GoogleFonts.cairo(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 12),
              _buildStepItem('1️⃣', 'المراحل 1 - 3: استماع وتكرار', 'نقرأ السورة كاملة 3 مرات مع الشيخ الذي تختاره، لترديدها وسماعها بوضوح.'),
              const SizedBox(height: 8),
              _buildStepItem('2️⃣', 'المرحلة 4: إخفاء عشوائي بسيط', 'سنخفي كلمات عشوائية، وعليك تذكرها بمفردك أو الضغط عليها لتظهر لك.'),
              const SizedBox(height: 8),
              _buildStepItem('3️⃣', 'المراحل 5 - 6: إخفاء متدرج', 'سنزيد عدد الكلمات المخفية تدريجياً لتقوية ذاكرتك.'),
              const SizedBox(height: 8),
              _buildStepItem('4️⃣', 'المرحلة 7: التسميع الكامل 🏆', 'تختفي كل الآيات، وتسمّعها بصوتك عبر المايكروفون ليصحح لك التطبيق!'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('هيا نبدأ الحفظ! 🚀', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(String num, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(num, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.cairo(color: Colors.black87, fontSize: 12, height: 1.4),
              children: [
                TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00897B))),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showRoundInfoBanner() {
    String msg = '';
    if (_currentRound == 2 || _currentRound == 3) {
      msg = 'الآن التكرار رقم $_currentRound من 3. استمع وكرر مع الشيخ!';
    } else if (_currentRound == 4) {
      msg = '💡 بدأ التحدي! قمنا بإخفاء كلمات عشوائية، تذكرها واقرأها!';
    } else if (_currentRound == 5) {
      msg = '🌟 تقدم ممتاز! الآن أخفينا المزيد من الكلمات، ركز وتذكر!';
    } else if (_currentRound == 6) {
      msg = '🔥 أحسنت! بقي قليل من الكلمات فقط ظاهرة، اقتربت من الحفظ الكامل!';
    } else if (_currentRound == 7) {
      msg = '🏆 التحدي الأخير! كل الآيات مخفية، سمّعها بصوتك عبر المايكروفون!';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
        backgroundColor: const Color(0xFF1E88E5),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }



  String _getRoundLabel() {
    if (_currentRound <= 3) {
      return 'تكرار وقراءة كاملة ($_currentRound من 3)';
    } else if (_currentRound == 4) {
      return 'المرحلة 4: إخفاء عشوائي بسيط';
    } else if (_currentRound == 5) {
      return 'المرحلة 5: إخفاء متوسط (35%)';
    } else if (_currentRound == 6) {
      return 'المرحلة 6: إخفاء متقدم (65%)';
    } else {
      return 'المرحلة 7: تسميع كامل غيباً! 🏆';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8F9),
        appBar: AppBar(
          backgroundColor: const Color(0xFF00897B),
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'سورة ${widget.surah.name}',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'إعادة الحفظ من البداية',
              onPressed: _restartMemorization,
            ),
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'طريقة الحفظ',
              onPressed: _showExplanationDialog,
            ),
          ],
        ),
        body: _isLoadingAyahs
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF00897B)),
                    SizedBox(height: 12),
                    Text('جاري تجهيز آيات السورة الكريمة...'),
                  ],
                ),
              )
            : Column(
                children: [
                  // Top Reciter Selection Card
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFF00897B).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.record_voice_over, color: Color(0xFF00897B), size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'اختيار القارئ:',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: const Color(0xFF00897B),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedReciter,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00897B)),
                              style: GoogleFonts.cairo(fontSize: 13, color: Colors.black87),
                              items: QuranData.reciters.map((r) {
                                return DropdownMenuItem<String>(
                                  value: r['id'],
                                  child: Text(
                                    r['name']!,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                );
                              }).toList(),
                              onChanged: (newReciter) {
                                if (newReciter != null) {
                                  setState(() => _selectedReciter = newReciter);
                                  if (_isPlaying) _stopAudio();
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Progress & Round Bar
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00897B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _getRoundLabel(),
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade700,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'مرحلة $_currentRound / $_maxRounds',
                                style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _currentRound / _maxRounds,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD54F)),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ],
                    ),
                  ),

                  // Feedback & Speech Recognition Bar
                  if (_speechFeedback != null)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _speechSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _speechSuccess ? const Color(0xFF4CAF50) : const Color(0xFFE57373),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _speechSuccess ? Icons.check_circle : Icons.warning_amber_rounded,
                            color: _speechSuccess ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _speechFeedback!,
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _speechSuccess ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Ayahs List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: _ayahs.length,
                      itemBuilder: (context, ayahIndex) {
                        final ayah = _ayahs[ayahIndex];
                        final isCurrentlyPlaying = _currentPlayingAyahIndex == ayahIndex;
                        final isListeningToThis = _isListening && _listeningAyahIndex == ayahIndex;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: isCurrentlyPlaying ? 3 : 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isListeningToThis
                                  ? Colors.red
                                  : (isCurrentlyPlaying ? const Color(0xFF00897B) : Colors.transparent),
                              width: 2,
                            ),
                          ),
                          color: isCurrentlyPlaying ? const Color(0xFFE0F2F1) : Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Top row of Ayah card: number & action buttons
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: const Color(0xFF00897B),
                                      child: Text(
                                        '${ayah.number}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    // Speech recognition microphone button
                                    IconButton(
                                      icon: Icon(
                                        isListeningToThis ? Icons.mic : Icons.mic_none,
                                        color: isListeningToThis ? Colors.red : const Color(0xFFE65100),
                                        size: 26,
                                      ),
                                      tooltip: 'سمّع الآية بالمايكروفون',
                                      onPressed: () {
                                        if (isListeningToThis) {
                                          _stopListening();
                                        } else {
                                          _startListeningForAyah(ayahIndex);
                                        }
                                      },
                                    ),
                                    // Audio play button
                                    IconButton(
                                      icon: Icon(
                                        isCurrentlyPlaying && _isPlaying
                                            ? Icons.stop_circle_outlined
                                            : Icons.play_circle_fill,
                                        color: const Color(0xFF00897B),
                                        size: 30,
                                      ),
                                      tooltip: 'استمع للشيخ',
                                      onPressed: () {
                                        if (isCurrentlyPlaying && _isPlaying) {
                                          _stopAudio();
                                        } else {
                                          _playAyah(ayahIndex);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // Words rendering with random masking & tap-to-reveal
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 8,
                                  children: List.generate(ayah.words.length, (wordIndex) {
                                    final word = ayah.words[wordIndex];
                                    final key = '$ayahIndex-$wordIndex';
                                    final isMasked = _maskedWordsKeys.contains(key) && !_revealedWords.contains(key);

                                    if (isMasked) {
                                      return GestureDetector(
                                        onTap: () => _onWordTapped(ayahIndex, wordIndex),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFECB3),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: const Color(0xFFFFA000),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Text(
                                            '؟ ؟ ؟',
                                            style: GoogleFonts.cairo(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFFE65100),
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    final isRevealed = _revealedWords.contains(key) && _maskedWordsKeys.contains(key);

                                    return Text(
                                      word,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.amiri(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: isRevealed ? const Color(0xFFE65100) : const Color(0xFF263238),
                                        height: 1.7,
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom Action Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          if (_currentRound > 1) ...[
                            OutlinedButton.icon(
                              onPressed: _previousRound,
                              icon: const Icon(Icons.arrow_forward, size: 16, color: Color(0xFFE65100)),
                              label: Text(
                                'السابق',
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: const Color(0xFFE65100),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFFFA000)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          OutlinedButton.icon(
                            onPressed: _togglePlayAll,
                            icon: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: const Color(0xFF00897B),
                              size: 20,
                            ),
                            label: Text(
                              _isPlaying ? 'إيقاف' : 'استماع للسورة',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: const Color(0xFF00897B),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF00897B), width: 1.5),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _nextRound,
                              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                              label: Text(
                                _currentRound < _maxRounds ? 'المرحلة التالية ⭐' : 'إنهاء وتتويج 🏆',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF9800),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
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
